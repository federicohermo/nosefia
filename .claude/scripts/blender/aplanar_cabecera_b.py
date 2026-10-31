"""Deja planos los estantes de la cabecera norte de la góndola B. Se aplica una sola vez.

    blender --background --python-exit-code 1 --python \
        .claude/scripts/blender/aplanar_cabecera_b.py -- --aplicar

Sin `--aplicar` sólo informa qué tocaría, y el `.blend` del repo queda como estaba.

Cada estante gira sobre su borde de adelante: la etiqueta queda a la misma altura y baja el fondo.
Giran el estante, sus bandejas y las unidades que apoyan en él. El estante de abajo ya es plano.
"""

import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]  # sólo existe adentro de Blender
from mathutils import Matrix, Vector  # type: ignore[import-not-found]

RAIZ = Path(__file__).resolve().parents[3]
FUENTE = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
MUEBLE = "gondolanueva2-norte-noimp"
BANDEJAS = "gondolanueva2-norte-frente"
CHAPA = "GONDOLA | Chapa pintada blanca"
TANDA = "B.norte."
#: Una chapa de apoyo; las tiras del fondo y del frente son mucho más chicas.
AREA_DE_APOYO = 0.1
#: Hasta dónde llega un estante, medido desde su plano: incluye paletas, labio y etiqueta.
ALCANCE = 0.075
#: Las paletas terminan un poco detrás de la chapa; el panel del fondo está bastante más atrás.
HOLGURA_DEL_FONDO = 0.005


class Rampa:
    """Un estante inclinado: su borde de adelante y cuánto sube hacia el fondo."""

    def __init__(self, objeto, cara):
        puntos = [objeto.matrix_world @ objeto.data.vertices[v].co for v in cara.vertices]
        frente = max(puntos, key=lambda p: p.y)
        fondo = min(puntos, key=lambda p: p.y)
        self.y = frente.y
        self.z = frente.z
        self.fondo = fondo.y
        self.pendiente = (fondo.z - frente.z) / (frente.y - fondo.y)

    def altura(self, y):
        return self.z + self.pendiente * (self.y - y)

    def aplanar(self, punto):
        return Vector((punto.x, punto.y, punto.z - self.pendiente * (self.y - punto.y)))

    def giro(self):
        angulo = Vector((0, self.pendiente, 1)).angle(Vector((0, 0, 1)))
        centro = Vector((0, self.y, self.z))
        return (Matrix.Translation(centro) @ Matrix.Rotation(angulo, 4, "X")
                @ Matrix.Translation(-centro))


def rampas(objeto):
    normal = objeto.matrix_world.to_3x3()
    salida = []
    for cara in objeto.data.polygons:
        material = objeto.material_slots[cara.material_index].material
        mira = (normal @ cara.normal).normalized()
        inclinada = mira.z > 0.9 and mira.y > 0.01
        if material.name == CHAPA and cara.area > AREA_DE_APOYO and inclinada:
            salida.append(Rampa(objeto, cara))
    return sorted(salida, key=lambda r: r.z)


def aplanar_malla(objeto, estantes, alcance):
    tocados = 0
    inversa = objeto.matrix_world.inverted()
    for vertice in objeto.data.vertices:
        mundo = objeto.matrix_world @ vertice.co
        cerca = [r for r in estantes if abs(mundo.z - r.altura(mundo.y)) <= alcance]
        if cerca and mundo.y >= estantes[0].fondo - HOLGURA_DEL_FONDO:
            rampa = min(cerca, key=lambda r: abs(mundo.z - r.altura(mundo.y)))
            vertice.co = inversa @ rampa.aplanar(mundo)
            tocados += 1
    objeto.data.update()
    return tocados


def girar_unidades(estantes):
    tocadas = 0
    for objeto in bpy.context.scene.objects:
        tanda = str(objeto.get("tanda", ""))
        if not tanda.startswith(TANDA):
            continue
        nivel = int(tanda.split("/")[0].rsplit(".", 1)[1])
        if nivel == 0:
            continue
        objeto.matrix_world = estantes[nivel - 1].giro() @ objeto.matrix_world
        tocadas += 1
    return tocadas


def principal():
    bpy.ops.wm.open_mainfile(filepath=str(FUENTE))
    mueble = bpy.data.objects[MUEBLE]
    estantes = rampas(mueble)
    if len(estantes) != 3:
        raise SystemExit(f"Se esperaban 3 estantes inclinados y hay {len(estantes)}; no se tocó nada.")
    for rampa in estantes:
        print(f"estante a {rampa.z:.3f} m, pendiente {rampa.pendiente:.3f}")
    print(f"mueble: {aplanar_malla(mueble, estantes, ALCANCE)} vértices")
    print(f"bandejas: {aplanar_malla(bpy.data.objects[BANDEJAS], estantes, ALCANCE)} vértices")
    print(f"unidades: {girar_unidades(estantes)}")
    if "--aplicar" in sys.argv:
        bpy.ops.wm.save_as_mainfile(filepath=str(FUENTE), check_existing=False)


principal()
