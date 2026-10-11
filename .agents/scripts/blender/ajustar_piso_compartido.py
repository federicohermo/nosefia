"""Unir el piso a los bordes reales del baño y depósito, sin huecos ni superposición."""

import importlib.util
import sys
from pathlib import Path

import bpy

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))
from lib.consola import configurar

configurar()

if __name__ == "__main__":
    if "--aplicar" not in sys.argv:
        raise SystemExit("Pasar --aplicar para guardar la fuente.")
    if bpy.context.scene.get("local_piso_compartido_v7"):
        raise SystemExit("El encuentro del piso ya está corregido.")
    spec = importlib.util.spec_from_file_location(
        "estructura", Path(__file__).with_name("unificar_paredes_local.py"))
    estructura = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(estructura)
    objeto = bpy.data.objects["almacen-col"]
    bordes = {}
    for material in ["bano_piso_gris", "deposito_concreto"]:
        puntos = [objeto.matrix_world @ objeto.data.vertices[i].co
                  for p in objeto.data.polygons
                  if objeto.data.materials[p.material_index].name == material
                  for i in p.vertices]
        if not puntos:
            raise RuntimeError(f"No se encontró el piso {material}.")
        bordes[material] = puntos
    estructura.aplicar(
        escala_del_piso=2.4,
        limite_x_del_piso=min(v.x for v in bordes["bano_piso_gris"]),
        limite_y_del_piso=min(v.y for v in bordes["deposito_concreto"]),
    )
    bpy.context.scene["local_piso_compartido_v7"] = True
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
