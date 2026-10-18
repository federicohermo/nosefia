"""Corrige las islas de Fernet y el lateral y los discos de Progres.

Sin --aplicar sólo cambia la sesión de Blender. --aplicar guarda la fuente canónica.
"""

import argparse
import json
import math
import sys
from pathlib import Path

import bpy

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / '.claude/scripts'))
from lib.consola import configurar

FUENTE = RAIZ / 'assets/models/SEPT_JUEGOS_PROTOTIPO.blend'
FERNET_RECTANGULOS = {
    11: ((.875, .65985173), (1., .65985173), (1., .84793371), (.875, .84793371)),
    16: ((.75, .65985173), (.875, .65985173), (.875, .84793371), (.75, .84793371)),
    21: ((.875, .84640139), (1., .84640139), (1., .66237265), (.875, .66237265)),
    29: ((.875, .87693453), (1., .87693453), (1., .93901312), (.875, .93901312)),
}
FERNET_VIDRIO = (0, 4, 6, 10, 11, 12, 13, 14, 15, 16, 17, 19, 20, 21, 22, 23, 24, 25)
PROGRES_ANILLO = tuple(range(9, 30)) + (31, 30) + tuple(range(9))
PROGRES_DISCOS = {
    29: ((825.5 / 1278, 1 - 1054 / 1230), .11, 1),
    32: ((449 / 1278, 1 - 1054 / 1230), .11, -1),
}


def corregir():
    fuentes = {'Fernetgod-col': (40, 34), 'pringles3-convcol.001': (64, 34)}
    for nombre, dimensiones in fuentes.items():
        malla = bpy.data.objects[nombre].data
        if (len(malla.vertices), len(malla.polygons)) != dimensiones:
            raise ValueError(f'Cambió la geometría de {nombre}; revisar sus UV antes de aplicar')
        if malla.uv_layers.active is None:
            raise ValueError(f'{nombre} no tiene un mapa UV activo')

    fernet = bpy.data.objects['Fernetgod-col'].data
    uv = fernet.uv_layers.active.data
    for cara, coordenadas in FERNET_RECTANGULOS.items():
        for bucle, coordenada in zip(fernet.polygons[cara].loop_indices, coordenadas):
            uv[bucle].uv = coordenada
    margen = 7 / 1254
    for cara in FERNET_VIDRIO:
        bucles = fernet.polygons[cara].loop_indices
        sector = round(min(uv[b].uv.x for b in bucles) * 8)
        centro = (sector + .5) / 8
        for bucle in bucles:
            uv[bucle].uv.x = (
                sector / 8 + margen if uv[bucle].uv.x < centro else (sector + 1) / 8 - margen
            )

    progres = bpy.data.objects['pringles3-convcol.001'].data
    distancias = [0.]
    anillo_cerrado = PROGRES_ANILLO + PROGRES_ANILLO[:1]
    for primero, segundo in zip(anillo_cerrado, anillo_cerrado[1:]):
        a, b = progres.vertices[primero].co, progres.vertices[segundo].co
        distancias.append(distancias[-1] + math.hypot(b.x - a.x, b.y - a.y))
    minimo, maximo = .035041116, .963120282
    coordenadas_u = {
        vertice: minimo + (maximo - minimo) * distancia / distancias[-1]
        for vertice, distancia in zip(PROGRES_ANILLO, distancias)
    }
    uv = progres.uv_layers.active.data
    for cara in progres.polygons:
        if len(cara.vertices) != 4:
            continue
        for bucle in cara.loop_indices:
            vertice = progres.loops[bucle].vertex_index % 32
            uv[bucle].uv.x = (
                maximo if vertice == 9 and cara.index == 16 else coordenadas_u[vertice]
            )
    radio_x = max(abs(v.co.x) for v in progres.vertices)
    radio_y = max(abs(v.co.y) for v in progres.vertices)
    for cara, (centro, radio, orientacion) in PROGRES_DISCOS.items():
        for bucle in progres.polygons[cara].loop_indices:
            coordenada = progres.vertices[progres.loops[bucle].vertex_index].co
            uv[bucle].uv = (
                centro[0] + orientacion * radio * coordenada.y / radio_y,
                centro[1] + radio * coordenada.x / radio_x,
            )
    print(json.dumps({
        'Fernetgod-col': sorted(set(FERNET_RECTANGULOS) | set(FERNET_VIDRIO)),
        'pringles3-convcol.001': list(range(len(progres.polygons))),
    }))


if __name__ == '__main__':
    configurar()
    argumentos = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--aplicar', action='store_true')
    opciones = parser.parse_args(argumentos)
    if Path(bpy.data.filepath).resolve() != FUENTE.resolve():
        raise ValueError(f'Abrir la fuente canónica antes de aplicar: {FUENTE}')
    corregir()
    if opciones.aplicar:
        bpy.ops.wm.save_as_mainfile(filepath=str(FUENTE))
