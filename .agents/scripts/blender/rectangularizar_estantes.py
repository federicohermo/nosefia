"""Cambia las bandejas por repisas horizontales y conserva el cuerpo de las góndolas.

Sin --aplicar trabaja en memoria. --aplicar guarda únicamente la fuente canónica.
"""

import argparse
from dataclasses import dataclass, field
import json
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / '.claude/scripts'))
sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.consola import configurar
from acomodar import Estante, _cara_de_arriba, _islas

FUENTE = RAIZ / 'assets/models/SEPT_JUEGOS_PROTOTIPO.blend'
ESPESOR = 0.06
SEPARACION = 0.002
MARCA = 'bandejas_rectangulares_v1'
MUEBLES = {
    'gondolanueva-col': {
        'geometria': (906, 694),
        'bandejas': {
            'A.este': (6, 4, 5, 1),
            'A.oeste': (16, 14, 15, 11),
            'A.sur': (2, 67, 9, 8),
            'A.norte': (24, 72, 28, 25),
        },
        'etiquetas': 48,
        'mensulas': (3, 7, 10, 12, 13, 17, 26, 27, 29, 30, 31, 32, 68, 69, 73, 74),
    },
    'gondolanueva-col.001': {
        'geometria': (170, 111),
        'bandejas': {'N.sur': (4, 2, 1, 3)},
        'etiquetas': 16,
    },
}


@dataclass
class Bandeja:
    clave: str
    caras: list
    origen: Vector
    u: Vector
    v: Vector
    ancho: float
    fondo: float
    chapa: int
    frente: int
    zocalo: tuple | None = None
    etiquetas: list = field(default_factory=list)
    mensulas: list = field(default_factory=list)


def medir_bandejas(objeto, datos, bm):
    mundo = bm.copy()
    mundo.transform(objeto.matrix_world)
    mundo.normal_update()
    islas = _islas(mundo)
    bm.faces.ensure_lookup_table()
    bm.verts.ensure_lookup_table()
    salida = []
    for prefijo, indices in datos['bandejas'].items():
        for nivel, indice in enumerate(indices):
            isla = islas[indice]
            if len(isla) not in (18, 22, 28):
                raise ValueError(f'{objeto.name}: cambió la isla {indice}')
            clave = f'{prefijo}.{nivel}'
            apoyo = Estante(clave, isla, _cara_de_arriba(isla))
            horizontal = Vector((apoyo.v.x, apoyo.v.y, 0))
            bandeja = Bandeja(
                clave, [bm.faces[c.index] for c in isla], apoyo.origen.copy(),
                apoyo.u.copy(), horizontal.normalized(), apoyo.largo,
                apoyo.fondo * horizontal.length, 0, 3,
            )
            base = {v for c in isla if c.material_index == 2 for v in c.verts}
            if base:
                minimo = Vector(tuple(min(v.co[eje] for v in base) for eje in range(3)))
                maximo = Vector(tuple(max(v.co[eje] for v in base) for eje in range(3)))
                maximo.z = apoyo.origen.z - ESPESOR
                bandeja.zocalo = (minimo, maximo)
            salida.append(bandeja)
    etiquetas = [
        isla[0] for isla in islas
        if len(isla) == 1 and isla[0].material_index == 4
    ]
    if len(etiquetas) != datos['etiquetas']:
        raise ValueError(f'{objeto.name}: cambió la cantidad de etiquetas')
    for cara in etiquetas:
        centro = cara.calc_center_median()
        candidatas = [b for b in salida if cara.normal.dot(-b.v) > 0.5]
        bandeja = min(candidatas, key=lambda b: abs(centro.z - b.origen.z))
        bandeja.etiquetas.append(bm.faces[cara.index])
    for indice in datos.get('mensulas', ()):
        isla = islas[indice]
        if len(isla) != 10 or any(c.material_index != 0 for c in isla):
            raise ValueError(f'{objeto.name}: cambió la ménsula {indice}')
        puntos = [v.co for c in isla for v in c.verts]
        centro = sum(puntos, Vector()) / len(puntos)
        prefijo = 'A.norte' if centro.y > objeto.matrix_world.translation.y else 'A.sur'
        bandeja = min((b for b in salida if b.clave.startswith(prefijo)),
                      key=lambda b: abs(centro.z - b.origen.z))
        superiores = {v for c in isla if c.normal.z > 0.5 for v in c.verts}
        inferiores = {v for c in isla if c.normal.z < -0.5 for v in c.verts}
        if superiores & inferiores or superiores | inferiores != {v for c in isla for v in c.verts}:
            raise ValueError(f'{objeto.name}: perfil inesperado en la ménsula {indice}')
        bandeja.mensulas.append((
            [bm.verts[v.index] for v in superiores],
            [bm.verts[v.index] for v in inferiores],
        ))
    mundo.free()
    return salida


def colocar_etiquetas(objeto, bandeja):
    matriz = objeto.matrix_world
    inversa = matriz.inverted()
    grupos = {}
    for cara in bandeja.etiquetas:
        puntos = [matriz @ vert.co for vert in cara.verts]
        centro = sum(puntos, Vector()) / len(puntos)
        normal = matriz.to_3x3() @ cara.normal
        arriba = normal.cross(bandeja.u).normalized()
        if arriba.z < 0:
            arriba.negate()
        offsets = [((p - centro).dot(bandeja.u), (p - centro).dot(arriba)) for p in puntos]
        alto = max(p[1] for p in offsets) - min(p[1] for p in offsets)
        avance = (centro - bandeja.origen).dot(bandeja.u)
        grupos.setdefault(round(avance, 4), []).append((centro.z, cara, offsets, alto, avance))
    for grupo in grupos.values():
        grupo.sort(key=lambda etiqueta: etiqueta[0])
        alto_total = sum(e[3] for e in grupo) + SEPARACION * (len(grupo) - 1)
        escala = min(1.0, (ESPESOR - 0.004) / alto_total)
        alto_total *= escala
        z = bandeja.origen.z - ESPESOR / 2 - alto_total / 2
        for _, cara, offsets, alto, avance in grupo:
            alto *= escala
            centro = bandeja.origen + bandeja.u * avance - bandeja.v * 0.0005
            centro.z = z + alto / 2
            for vert, (u, v) in zip(cara.verts, offsets):
                vert.co = inversa @ (centro + bandeja.u * u * escala
                                     + Vector((0, 0, v * escala)))
            z += alto + SEPARACION * escala


def construir_bandeja(objeto, bm, bandeja):
    inversa = objeto.matrix_world.inverted()
    for superiores, inferiores in bandeja.mensulas:
        for vertices, profundidad in ((superiores, ESPESOR), (inferiores, ESPESOR + 0.02)):
            for vertice in vertices:
                punto = objeto.matrix_world @ vertice.co
                punto.z = bandeja.origen.z - profundidad
                vertice.co = inversa @ punto
    superior = [
        bandeja.origen,
        bandeja.origen + bandeja.u * bandeja.ancho,
        bandeja.origen + bandeja.u * bandeja.ancho + bandeja.v * bandeja.fondo,
        bandeja.origen + bandeja.v * bandeja.fondo,
    ]
    puntos = superior + [p - Vector((0, 0, ESPESOR)) for p in superior]
    bloques = [(puntos, [bandeja.chapa, bandeja.chapa, bandeja.frente,
                         bandeja.chapa, bandeja.chapa, bandeja.chapa])]
    if bandeja.zocalo is not None:
        minimo, maximo = bandeja.zocalo
        base = [Vector((x, y, z)) for z in (maximo.z, minimo.z)
                for x, y in ((minimo.x, minimo.y), (maximo.x, minimo.y),
                             (maximo.x, maximo.y), (minimo.x, maximo.y))]
        bloques.append((base, [2] * 6))
    caras = ((0, 1, 2, 3), (7, 6, 5, 4), (4, 5, 1, 0),
             (5, 6, 2, 1), (6, 7, 3, 2), (7, 4, 0, 3))
    for bloque, materiales in bloques:
        vertices = [bm.verts.new(inversa @ punto) for punto in bloque]
        for esquinas, material in zip(caras, materiales):
            cara = bm.faces.new([vertices[i] for i in esquinas])
            cara.material_index = material
            cara.smooth = False
            for capa in bm.loops.layers.uv.values():
                for loop, uv in zip(cara.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
                    loop[capa].uv = uv


def aplicar():
    informe = []
    for nombre, datos in MUEBLES.items():
        objeto = bpy.data.objects[nombre]
        malla = objeto.data
        if malla.get(MARCA):
            informe.append({'objeto': nombre, 'estado': 'ya aplicado'})
            continue
        if (len(malla.vertices), len(malla.polygons)) != datos['geometria']:
            raise ValueError(f'{nombre}: la geometría cambió; revisar antes de aplicar')
        materiales = [m.name if m else '' for m in malla.materials]
        if (len(materiales) != 5 or 'Chapa pintada' not in materiales[0]
                or 'Portaprecio' not in materiales[3] or 'Etiqueta por grupo' not in materiales[4]):
            raise ValueError(f'{nombre}: cambiaron los materiales de las bandejas')
        bm = bmesh.new()
        bm.from_mesh(malla)
        bm.normal_update()
        bandejas = medir_bandejas(objeto, datos, bm)
        for bandeja in bandejas:
            colocar_etiquetas(objeto, bandeja)
        viejos = {v for bandeja in bandejas for cara in bandeja.caras for v in cara.verts}
        bmesh.ops.delete(bm, geom=list(viejos), context='VERTS')
        for bandeja in bandejas:
            construir_bandeja(objeto, bm, bandeja)
            informe.append({
                'objeto': nombre, 'bandeja': bandeja.clave,
                'ancho': bandeja.ancho, 'fondo': bandeja.fondo,
                'altura': bandeja.origen.z, 'espesor': ESPESOR,
                'etiquetas': len(bandeja.etiquetas),
                'zocalo': [list(v) for v in bandeja.zocalo] if bandeja.zocalo else None,
            })
        bm.normal_update()
        bm.to_mesh(malla)
        bm.free()
        malla.update()
        malla[MARCA] = True
    return informe


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
    print(json.dumps({'guardado': opciones.aplicar, 'bandejas': informe}, indent=2))


if __name__ == '__main__':
    main()
