"""Retira divisores macizos y continúa las repisas alrededor de las cabeceras.

Sin --aplicar modifica sólo la sesión de Blender. --aplicar guarda la fuente canónica.
"""

import argparse
from dataclasses import dataclass, field
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
MARCA = 'estantes_continuos_v1'
ESPESOR = 0.03
LIMITE_DEL_DIVISOR = 0.5594


@dataclass
class Repisa:
    clave: str
    caras: set
    minimo: Vector
    maximo: Vector
    etiquetas: list = field(default_factory=list)


def medir_repisas(objeto, bm):
    _, mundo, estantes = medir('A')
    inversa = objeto.matrix_world.inverted()
    salida = {}
    for clave, estante in estantes.items():
        caras = {bm.faces[i] for i in estante.caras}
        puntos = [vert.co for cara in caras for vert in cara.verts]
        salida[clave] = Repisa(
            clave, caras,
            Vector(tuple(min(p[eje] for p in puntos) for eje in range(3))),
            Vector(tuple(max(p[eje] for p in puntos) for eje in range(3))),
        )
    for cara in bm.faces:
        if cara.material_index != 4:
            continue
        candidatas = []
        for clave, estante in estantes.items():
            if cara.normal.dot(estante.mira) > 0.99:
                candidatas.append((abs(cara.calc_center_median().z
                                        - (inversa @ estante.origen).z), clave))
        salida[min(candidatas)[1]].etiquetas.append(cara)
    mundo.free()
    return salida


def cerrar_divisores(bm):
    cuerpo = _islas(bm)[0]
    retirar = [cara for cara in cuerpo
               if all(abs(v.co.x) > LIMITE_DEL_DIVISOR for v in cara.verts)]
    if len(cuerpo) != 86 or len(retirar) != 52:
        raise ValueError('El cuerpo de la góndola cambió; revisar los divisores')
    conservadas = set(cuerpo) - set(retirar)
    bmesh.ops.delete(bm, geom=retirar, context='FACES')
    bordes = [arista for arista in bm.edges if arista.is_boundary
              and any(cara in conservadas for cara in arista.link_faces)]
    if len(bordes) != 16:
        raise ValueError('Los cuatro cierres del respaldo no tienen cuatro aristas')
    resultado = bmesh.ops.holes_fill(bm, edges=bordes, sides=4)['faces']
    if len(resultado) != 4:
        raise ValueError('No se cerraron los cuatro extremos del respaldo')
    for cara in resultado:
        cara.material_index = 0
        cara.smooth = False
        for capa in bm.loops.layers.uv.values():
            for loop in cara.loops:
                loop[capa].uv = (loop.vert.co.y, loop.vert.co.z)
    return len(retirar)


def mover_etiquetas(repisa, normal):
    direccion = Vector((0, 1, 0)) if normal.x else Vector((1, 0, 0))
    grupos = {}
    for cara in repisa.etiquetas:
        centro = cara.calc_center_median()
        grupos.setdefault(round(centro.dot(direccion), 4), []).append((centro, cara))
    for grupo in grupos.values():
        inferior = min(v.co.z for _, c in grupo for v in c.verts)
        superior = max(v.co.z for _, c in grupo for v in c.verts)
        escala = min(1.0, (ESPESOR - 0.004) / (superior - inferior))
        centro_z = (inferior + superior) / 2
        avance = ((repisa.maximo.x if normal.x > 0 else repisa.minimo.x)
                  if normal.x else
                  (repisa.maximo.y if normal.y > 0 else repisa.minimo.y))
        for centro, cara in grupo:
            for vertice in cara.verts:
                relativo = vertice.co - centro
                vertice.co += direccion * relativo.dot(direccion) * (escala - 1)
                vertice.co.z = (repisa.maximo.z - ESPESOR / 2
                                + (vertice.co.z - centro_z) * escala)
                if normal.x:
                    vertice.co.x = avance + normal.x * 0.0005
                else:
                    vertice.co.y = avance + normal.y * 0.0005


def construir_repisa(bm, repisa, materiales):
    minimo, maximo = repisa.minimo, repisa.maximo
    puntos = [(x, y, z) for z in (maximo.z, minimo.z)
              for x, y in ((minimo.x, minimo.y), (maximo.x, minimo.y),
                           (maximo.x, maximo.y), (minimo.x, maximo.y))]
    vertices = [bm.verts.new(punto) for punto in puntos]
    caras = ((0, 1, 2, 3), (7, 6, 5, 4), (4, 5, 1, 0),
             (5, 6, 2, 1), (6, 7, 3, 2), (7, 4, 0, 3))
    for indices, material in zip(caras, materiales):
        cara = bm.faces.new([vertices[i] for i in indices])
        cara.material_index = material
        cara.smooth = False
        for capa in bm.loops.layers.uv.values():
            for loop, uv in zip(cara.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
                loop[capa].uv = uv


def aplicar():
    objeto = bpy.data.objects['gondolanueva-col']
    malla = objeto.data
    if malla.get(MARCA):
        return {'estado': 'ya aplicado'}
    if bpy.data.objects['gondolanueva2-col'].data != malla:
        raise ValueError('Las dos góndolas deben compartir la misma malla')
    if not malla.get('bandejas_rectangulares_v1'):
        raise ValueError('Primero debe aplicarse rectangularizar_estantes.py')
    bm = bmesh.new()
    bm.from_mesh(malla)
    bm.normal_update()
    bm.faces.ensure_lookup_table()
    repisas = medir_repisas(objeto, bm)
    originales = {clave: (r.minimo.copy(), r.maximo.copy()) for clave, r in repisas.items()}
    islas = _islas(bm)
    mensulas = [isla for isla in islas if len(isla) == 10
                and all(c.material_index == 0 for c in isla)]
    zocalos = [isla for isla in islas if len(isla) == 6
               and all(c.material_index == 2 for c in isla)]
    ancho = max(abs(v.co.x) for c in islas[0] for v in c.verts)
    encuentro = min(abs(v.co.y) for c in islas[0] if c.material_index == 1
                    and abs(c.normal.y) > 0.99 for v in c.verts)
    retiradas = cerrar_divisores(bm)
    normales = {'oeste': Vector((-1, 0, 0)), 'este': Vector((1, 0, 0)),
                'sur': Vector((0, -1, 0)), 'norte': Vector((0, 1, 0))}
    informe = []
    for clave, repisa in repisas.items():
        _, cara, nivel = clave.split('.')
        repisa.maximo.z = originales[f'A.este.{nivel}'][1].z
        repisa.minimo.z = repisa.maximo.z - ESPESOR
        if cara in ('este', 'oeste'):
            repisa.minimo.y, repisa.maximo.y = -encuentro, encuentro
            if cara == 'este':
                repisa.maximo.x = ancho
            else:
                repisa.minimo.x = -ancho
        else:
            repisa.minimo.x, repisa.maximo.x = -ancho, ancho
            if cara == 'norte':
                repisa.minimo.y = encuentro
            else:
                repisa.maximo.y = -encuentro
        mover_etiquetas(repisa, normales[cara])
        materiales = [0, 0, 0, 0, 0, 0]
        frente = {'sur': 2, 'este': 3, 'norte': 4, 'oeste': 5}[cara]
        materiales[frente] = 3
        if cara in ('sur', 'norte'):
            materiales[3] = materiales[5] = 3
        construir_repisa(bm, repisa, materiales)
        informe.append({'repisa': clave, 'minimo': list(repisa.minimo),
                        'maximo': list(repisa.maximo), 'espesor': ESPESOR})
    for isla in mensulas:
        centro = sum((v.co for c in isla for v in c.verts), Vector())
        cara = 'norte' if centro.y > 0 else 'sur'
        techo = max(v.co.z for c in isla for v in c.verts)
        candidata = min((r for r in repisas.values() if f'.{cara}.' in r.clave),
                        key=lambda r: abs(originales[r.clave][0].z - techo))
        delta = candidata.minimo.z - techo
        for vertice in {v for c in isla for v in c.verts}:
            vertice.co.z += delta
    for isla in zocalos:
        techo = max(v.co.z for c in isla for v in c.verts)
        centro = sum((v.co for c in isla for v in c.verts), Vector())
        cara = ('norte' if centro.y > 0 else 'sur') if abs(centro.y) > abs(centro.x) else (
            'este' if centro.x > 0 else 'oeste')
        nuevo = repisas[f'A.{cara}.0'].minimo.z
        for vertice in {v for c in isla for v in c.verts if abs(v.co.z - techo) < 1e-6}:
            vertice.co.z = nuevo
    viejos = {v for r in repisas.values() for c in r.caras for v in c.verts}
    bmesh.ops.delete(bm, geom=list(viejos), context='VERTS')
    bm.normal_update()
    bm.to_mesh(malla)
    bm.free()
    malla.update()
    malla[MARCA] = True
    return {'caras_de_divisor_retiradas': retiradas, 'repisas': informe}


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
