"""Deja un panel central delgado y cuatro plataformas continuas en las góndolas.

Sin --aplicar trabaja en memoria. --aplicar guarda la fuente canónica.
"""

import argparse
import json
from pathlib import Path
import sys

import bmesh
import bpy
from mathutils import Vector

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / '.claude/scripts'))
sys.path.insert(0, str(Path(__file__).resolve().parent))
from acomodar import _islas, medir
from lib.consola import configurar

FUENTE = RAIZ / 'assets/models/SEPT_JUEGOS_PROTOTIPO.blend'
MARCA = 'estructura_central_unica_v1'
ESPESOR_DEL_PANEL = 0.10


def limites(caras):
    puntos = {v for cara in caras for v in cara.verts}
    return tuple(Vector(tuple(func(v.co[eje] for v in puntos) for eje in range(3)))
                 for func in (min, max))


def cara_nueva(bm, vertices, material):
    cara = bm.faces.new(vertices)
    cara.material_index = material
    cara.smooth = False
    cara.normal_update()
    for capa in bm.loops.layers.uv.values():
        for loop in cara.loops:
            p = loop.vert.co
            if abs(cara.normal.x) > 0.9:
                loop[capa].uv = (p.y, p.z)
            elif abs(cara.normal.y) > 0.9:
                loop[capa].uv = (p.x, p.z)
            else:
                loop[capa].uv = (p.x, p.y)
    return cara


def construir_panel(bm, minimo, maximo, muestras):
    minimo.x, maximo.x = -ESPESOR_DEL_PANEL / 2, ESPESOR_DEL_PANEL / 2
    vertices = [bm.verts.new((x, y, z)) for z in (maximo.z, minimo.z)
                for x, y in ((minimo.x, minimo.y), (maximo.x, minimo.y),
                             (maximo.x, maximo.y), (minimo.x, maximo.y))]
    for indices in ((0, 1, 2, 3), (7, 6, 5, 4), (4, 5, 1, 0),
                    (5, 6, 2, 1), (6, 7, 3, 2), (7, 4, 0, 3)):
        cara = cara_nueva(bm, [vertices[i] for i in indices], 0)
        cara.normal_update()
        if abs(cara.normal.x) > 0.9:
            cara.material_index = 1
            original = muestras[1 if cara.normal.x > 0 else -1]
            base, uv_base, du, dv = original
            for capa in bm.loops.layers.uv.values():
                for loop in cara.loops:
                    delta = loop.vert.co - base
                    loop[capa].uv = uv_base + du * delta.y + dv * delta.z


def construir_plataforma(bm, minimo, maximo, encuentro, nivel, lado_attr, nivel_attr):
    xs = (minimo.x, -ESPESOR_DEL_PANEL / 2, ESPESOR_DEL_PANEL / 2, maximo.x)
    ys = (minimo.y, -encuentro, encuentro, maximo.y)
    vertices = {(i, j, k): bm.verts.new((x, y, z))
                for i, x in enumerate(xs) for j, y in enumerate(ys)
                for k, z in enumerate((minimo.z, maximo.z))}
    for i in range(3):
        for j in range(3):
            esquina = ((i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1))
            cara = cara_nueva(bm, [vertices[x, y, 1] for x, y in esquina], 0)
            lado = (4 if j == 0 else 3 if j == 2 else 2 if i == 0 else 1 if i == 2 else 0)
            cara[lado_attr] = lado
            cara[nivel_attr] = nivel
            cara_nueva(bm, [vertices[x, y, 0] for x, y in reversed(esquina)], 0)
    perimetro = [(i, 0) for i in range(4)] + [(3, j) for j in range(1, 4)]
    perimetro += [(i, 3) for i in range(2, -1, -1)] + [(0, j) for j in range(2, 0, -1)]
    for primero, segundo in zip(perimetro, perimetro[1:] + perimetro[:1]):
        cara_nueva(bm, [vertices[*primero, 0], vertices[*segundo, 0],
                        vertices[*segundo, 1], vertices[*primero, 1]], 3)


def uv_del_panel(caras, capa):
    salida = {}
    for signo in (-1, 1):
        cara = max((c for c in caras if c.material_index == 1 and c.normal.x * signo > 0.99),
                   key=lambda c: c.calc_area())
        base = cara.loops[0]
        horizontal = next(loop for loop in cara.loops
                          if abs(loop.vert.co.y - base.vert.co.y) > 0.1
                          and abs(loop.vert.co.z - base.vert.co.z) < 0.0001)
        vertical = next(loop for loop in cara.loops
                        if abs(loop.vert.co.z - base.vert.co.z) > 0.1
                        and abs(loop.vert.co.y - base.vert.co.y) < 0.0001)
        salida[signo] = (base.vert.co.copy(), base[capa].uv.copy(),
                         (horizontal[capa].uv - base[capa].uv)
                         / (horizontal.vert.co.y - base.vert.co.y),
                         (vertical[capa].uv - base[capa].uv)
                         / (vertical.vert.co.z - base.vert.co.z))
    return salida


def ajustar_espesor(malla):
    bm = bmesh.new()
    bm.from_mesh(malla)
    panel = next(isla for isla in _islas(bm) if any(c.material_index == 1 for c in isla))
    minimo, maximo = limites(panel)
    centro = (minimo.x + maximo.x) / 2
    planos = {
        minimo.x: centro - ESPESOR_DEL_PANEL / 2,
        maximo.x: centro + ESPESOR_DEL_PANEL / 2,
    }
    for vertice in bm.verts:
        if vertice.co.x in planos:
            vertice.co.x = planos[vertice.co.x]
    bm.normal_update()
    bm.to_mesh(malla)
    bm.free()
    malla.update()
    return {'espesor_anterior': maximo.x - minimo.x, 'espesor_actual': ESPESOR_DEL_PANEL}


def aplicar():
    objeto = bpy.data.objects['gondolanueva-col']
    malla = objeto.data
    if bpy.data.objects['gondolanueva2-col'].data != malla:
        raise ValueError('Las dos góndolas deben compartir la misma malla')
    if malla.get(MARCA):
        return ajustar_espesor(malla)
    if not malla.get('estantes_continuos_v1'):
        raise ValueError('La fuente debe tener las plataformas rectangulares actuales')
    _, mundo, estantes = medir('A')
    bm = bmesh.new()
    bm.from_mesh(malla)
    bm.normal_update()
    bm.faces.ensure_lookup_table()
    cuerpo = _islas(bm)[0]
    paneles = [c for c in cuerpo if c.material_index == 1 and abs(c.normal.x) > 0.99]
    minimo_panel, maximo_panel = limites(paneles)
    minimo_panel.z = limites(cuerpo)[0].z
    muestras = uv_del_panel(paneles, bm.loops.layers.uv.active)
    plataformas = []
    for nivel in range(4):
        caras = [bm.faces[i] for clave, e in estantes.items() if clave.endswith(f'.{nivel}')
                 for i in e.caras]
        plataformas.append(limites(caras))
    encuentro = min(abs(v.co.y) for c in cuerpo if c.material_index == 1
                    and abs(c.normal.y) > 0.99 for v in c.verts)
    retirar = {v for cara in bm.faces if cara.material_index != 4 for v in cara.verts}
    bmesh.ops.delete(bm, geom=list(retirar), context='VERTS')
    lado_attr = bm.faces.layers.int.new('lado_de_estante')
    nivel_attr = bm.faces.layers.int.new('nivel_de_estante')
    construir_panel(bm, minimo_panel, maximo_panel, muestras)
    for nivel, (minimo, maximo) in enumerate(plataformas):
        construir_plataforma(bm, minimo, maximo, encuentro, nivel, lado_attr, nivel_attr)
    bm.normal_update()
    bm.to_mesh(malla)
    bm.free()
    mundo.free()
    malla.update()
    malla[MARCA] = True
    return {'panel': {'minimo': list(minimo_panel), 'maximo': list(maximo_panel)},
            'plataformas': [{'nivel': n, 'minimo': list(lo), 'maximo': list(hi)}
                            for n, (lo, hi) in enumerate(plataformas)]}


def main():
    configurar()
    argumentos = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--aplicar', action='store_true')
    opciones = parser.parse_args(argumentos)
    bpy.ops.wm.open_mainfile(filepath=str(FUENTE), load_ui=False)
    informe = aplicar()
    if opciones.aplicar:
        bpy.ops.wm.save_mainfile()
    print(json.dumps({'guardado': opciones.aplicar, **informe}, indent=2))


if __name__ == '__main__':
    main()
