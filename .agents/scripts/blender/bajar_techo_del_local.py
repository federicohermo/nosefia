"""Bajar el techo del salón hasta donde llega la mira del jugador.

Edición de un paso sobre la fuente con los ventanales terminados. --aplicar guarda la fuente.
Por encima del CORTE, el salón se comprime en altura: el cielorraso, los dinteles, los
ventanales y la losa bajan juntos y conservan sus proporciones. Lo de abajo no se mueve:
puertas, ventanilla, heladeras y góndolas. El baño y el depósito conservan su geometría.
"""

import importlib.util
import sys
from pathlib import Path

import bpy
from mathutils import Vector

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))
from lib.consola import configurar

configurar()
spec = importlib.util.spec_from_file_location(
    "local", Path(__file__).with_name("reformular_local.py"))
local = importlib.util.module_from_spec(spec)
spec.loader.exec_module(local)

MARCA = "local_techo_bajo_v1"
TECHO = 3.50
# Arriba de la puerta de entrada y del paso al depósito, que terminan en 2.886.
CORTE = 2.95
LOSA = 4.40
# La cara exterior de la pared del baño queda en x = 8.08 y no se toca.
BORDE_DEL_BANO = 8.0
VENTANALES = ["local_marco_frente-col", "local_marco_ventanal-col",
              "local_vidrio_frente_0", "local_vidrio_frente_1", "local_vidrio_sobre_entrada",
              *(f"local_vidrio_ventanal_{i}" for i in range(4))]


def bajar(z):
    return CORTE + (z - CORTE) * (TECHO - CORTE) / (local.TECHO - CORTE)


def en_el_salon(v):
    return (local.X0 - .121 <= v.x <= BORDE_DEL_BANO
            and local.Y0 - .121 <= v.y <= local.Y1 + .001)


def comprimir(objeto, alcanza):
    inv = objeto.matrix_world.inverted()
    movidos = 0
    for vertice in objeto.data.vertices:
        mundo = objeto.matrix_world @ vertice.co
        if CORTE < mundo.z and alcanza(mundo):
            mundo.z = bajar(mundo.z)
            vertice.co = inv @ mundo
            movidos += 1
    objeto.data.update()
    return movidos


def lo_que_atraviesa_el_techo():
    restos = []
    for objeto in bpy.data.objects:
        if objeto.type != "MESH" or objeto.name == "almacen-col":
            continue
        caja = [objeto.matrix_world @ Vector(v) for v in objeto.bound_box]
        centro = sum(caja, Vector()) / 8
        if (local.X0 < centro.x < local.X1 and local.Y0 - .2 < centro.y < local.Y1
                and max(v.z for v in caja) > TECHO):
            restos.append(objeto.name)
    return restos


def aplicar():
    edificio = bpy.data.objects["almacen-col"]
    # Arriba de la losa sigue el frente del depósito, que no baja.
    print("almacen-col:", comprimir(edificio, lambda v: en_el_salon(v) and v.z <= LOSA + .001))
    for nombre in VENTANALES:
        print(f"{nombre}:", comprimir(bpy.data.objects[nombre], lambda v: True))
    # bound_box sale del depsgraph: sin actualizar, mide la malla de antes.
    bpy.context.view_layer.update()
    restos = lo_que_atraviesa_el_techo()
    if restos:
        raise SystemExit(f"Quedan objetos del salón por encima del techo: {restos}")
    print(f"Techo del salón a {TECHO} m, {TECHO - local.PISO:.3f} m sobre el piso")


if __name__ == "__main__":
    if "--aplicar" not in sys.argv:
        raise SystemExit("Pasar --aplicar para guardar la fuente.")
    if bpy.context.scene.get(MARCA):
        raise SystemExit("El techo del salón ya está bajo.")
    aplicar()
    bpy.context.scene[MARCA] = True
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
