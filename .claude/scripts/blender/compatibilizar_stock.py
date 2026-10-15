"""Completa una fila corta sin rehacer el reparto artístico ni cambiar los faltantes del juego.

Recibe los mínimos medidos por assets/models/medir_modelo.gd. Sólo amplía las filas que no
alcanzan, con copias enlazadas y el aire del acomodador; las demás poses quedan intactas.
"""

import json
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from lib.gondola import AIRE

sys.path.insert(0, str(Path(__file__).resolve().parent))
from encajar_actroncito import encajar

RAIZ = Path(__file__).resolve().parents[3]


def principal():
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    medidas = json.loads((RAIZ / 'build/integracion_modelo.json').read_text(encoding='utf-8'))
    minimos = medidas[':minimos']['valores']
    grupos = {}
    for objeto in bpy.context.scene.objects:
        if 'producto' in objeto and not objeto.get('fija', True):
            grupos.setdefault(str(objeto['producto']), []).append(objeto)
    cambios = 0
    for producto, objetos in grupos.items():
        frente = sorted((o for o in objetos if o['fila'] == 'adelante'), key=lambda o: o['orden'])
        minimo = minimos.get(producto, 1)
        if len(frente) >= minimo and producto != 'ACTRONCITO':
            continue
        cantidad_frontal = len(frente)
        cantidad_atras = sum(o['fila'] == 'atras' for o in objetos)
        cantidad_reservada = max(0, cantidad_atras - cantidad_frontal)
        for fila in ('atras', 'adelante'):
            copias = sorted((o for o in objetos if o['fila'] == fila), key=lambda o: o['orden'])
            reservas = copias[cantidad_frontal:] if fila == 'atras' else []
            if fila == 'atras':
                copias = copias[:cantidad_frontal]
            if not copias:
                continue
            if producto == 'ACTRONCITO':
                referencias = sorted((o for o in bpy.context.scene.objects
                                      if o.get('producto') == producto and o.get('fija', False)
                                      and o['fila'] == fila), key=lambda o: o['orden'])
                if len(copias) != len(referencias):
                    raise ValueError('Las dos exhibiciones de Actroncito deben tener cuatro lugares')
                base = min((o.matrix_world @ Vector(v)).z
                           for o in copias for v in o.bound_box)
                apoyo = min((o.matrix_world @ Vector(v)).z
                            for o in referencias for v in o.bound_box)
                for copia, referencia in zip(copias, referencias):
                    pose = referencia.matrix_world.copy()
                    pose.translation.z += base - apoyo
                    copia.matrix_world = pose
                cambios += 1
                print(producto, fila, len(copias), 'alineados con la fila inferior')
                continue
            primera, ultima = copias[0].matrix_world.translation, copias[-1].matrix_world.translation
            lateral = (ultima - primera).normalized()
            ancho = max((copias[0].matrix_world @ Vector(v)).dot(lateral)
                        for v in copias[0].bound_box) - min(
                            (copias[0].matrix_world @ Vector(v)).dot(lateral)
                            for v in copias[0].bound_box)
            largo = max((ultima - primera).length, (ancho + AIRE) * (minimo - 1))
            centro = (primera + ultima) / 2
            while len(copias) < minimo:
                copia = copias[0].copy()
                copia.data = copias[0].data
                bpy.data.collections['guia'].objects.link(copia)
                copias.append(copia)
            for indice, copia in enumerate(copias):
                pose = copia.matrix_world.copy()
                pose.translation = centro + lateral * largo * (indice / (minimo - 1) - 0.5)
                copia.matrix_world = pose
                copia['orden'] = indice + (
                    minimo + cantidad_reservada if fila == 'adelante' else 0)
            for indice, copia in enumerate(reservas):
                copia['orden'] = minimo + indice
            cambios += 1
            print(producto, fila, len(copias))
    cambios += encajar()
    if cambios:
        bpy.ops.wm.save_mainfile()
    print('Filas ampliadas:', cambios)


if __name__ == '__main__':
    principal()
