"""Encaja la exhibición reponible en su bandeja, más corta que la exhibición inferior."""

import sys
from pathlib import Path

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib.consola import configurar
from lib.gondola import AIRE


def puntos(objeto):
    return [objeto.matrix_world @ v.co for v in objeto.data.vertices]


def encajar():
    copias = [o for o in bpy.context.scene.objects
              if o.get('producto') == 'ACTRONCITO' and not o.get('fija', True)]
    if not copias:
        raise ValueError('Falta la exhibición reponible de Actroncito')
    vertices = [v for o in copias for v in puntos(o)]
    minimo_x, maximo_x = min(v.x for v in vertices), max(v.x for v in vertices)
    base = min(v.z for v in vertices)
    mueble = bpy.data.objects['gondolanueva-col']
    normales = mueble.matrix_world.to_3x3().inverted().transposed()
    planos = []
    for cara in mueble.data.polygons:
        normal = (normales @ cara.normal).normalized()
        cara_vertices = [mueble.matrix_world @ mueble.data.vertices[i].co for i in cara.vertices]
        centro = sum(v.z for v in cara_vertices) / len(cara_vertices)
        if (normal.z > 0.95 and normal.y > 0.1 and abs(centro - base) < 0.1
                and min(v.x for v in cara_vertices) <= minimo_x
                and max(v.x for v in cara_vertices) >= maximo_x):
            planos.append((cara.area, normal, cara_vertices))
    if not planos:
        raise ValueError('No se encontró la bandeja debajo de Actroncito')
    _, normal, apoyo = max(planos, key=lambda p: p[0])
    limite = max(v.y for v in apoyo) - AIRE
    corrimiento = min(0.0, limite - max(v.y for v in vertices))
    cambios = 0
    for objeto in copias:
        antes = objeto.matrix_world.copy()
        pose = antes.copy()
        pose.translation.y += corrimiento
        objeto.matrix_world = pose
        distancia = min(normal.dot(v - apoyo[0]) for v in puntos(objeto))
        pose.translation.z += (0.001 - distancia) / normal.z
        objeto.matrix_world = pose
        if any(abs(antes[i][j] - pose[i][j]) > 0.000001 for i in range(4) for j in range(4)):
            cambios += 1
    print('Actroncito: desplazamiento hacia adentro', corrimiento, '; copias corregidas', cambios)
    return cambios


if __name__ == '__main__':
    configurar()
    if encajar():
        bpy.ops.wm.save_mainfile()
