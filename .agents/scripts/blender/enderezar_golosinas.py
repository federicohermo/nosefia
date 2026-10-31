"""Saca la inclinación de las golosinas del exhibidor. Se aplica una sola vez.

    blender --background --python-exit-code 1 --python \
        .claude/scripts/blender/enderezar_golosinas.py -- --aplicar

Sin `--aplicar` guarda en `reports/enderezar-golosinas.blend` y el `.blend` del repo queda como
estaba.

Cada golosina gira sobre su centro y baja o sube hasta su base de antes: queda derecha, en su
lugar de planta y sobre su escalón. No se tocan las caras, las UV ni los materiales.
"""

import math
import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]  # sólo existe adentro de Blender
from mathutils import Matrix, Vector  # type: ignore[import-not-found]

RAIZ = Path(__file__).resolve().parents[3]
FUENTE = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
GOLOSINAS = "exhibido_golosinas"
ECHADA = math.radians(20)
VERTICES_POR_GOLOSINA = 8


def principal():
    bpy.ops.wm.open_mainfile(filepath=str(FUENTE))
    malla = bpy.data.objects[GOLOSINAS].data
    if len(malla.vertices) % VERTICES_POR_GOLOSINA:
        raise SystemExit(f"{GOLOSINAS}: no son cajas de {VERTICES_POR_GOLOSINA} vértices.")
    giro = Matrix.Rotation(ECHADA, 3, "X")
    for inicio in range(0, len(malla.vertices), VERTICES_POR_GOLOSINA):
        vertices = malla.vertices[inicio:inicio + VERTICES_POR_GOLOSINA]
        centro = sum((v.co for v in vertices), Vector()) / VERTICES_POR_GOLOSINA
        base = min(v.co.z for v in vertices)
        derechos = [centro + giro @ (v.co - centro) for v in vertices]
        subida = base - min(p.z for p in derechos)
        for vertice, punto in zip(vertices, derechos):
            vertice.co = punto + Vector((0.0, 0.0, subida))
    malla.update()
    prueba = RAIZ / "reports/enderezar-golosinas.blend"
    destino = FUENTE if "--aplicar" in sys.argv else prueba
    destino.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(destino), check_existing=False)


principal()
