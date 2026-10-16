"""Compara arte y muebles antes/después sin fiarse del resumen del acomodador."""
import hashlib
import json
import sys
from pathlib import Path

import bpy

argumentos = sys.argv[sys.argv.index("--") + 1:]
base, actual, destino = map(Path, argumentos)
sys.path.insert(0, str(Path.cwd() / ".claude/scripts"))
from lib.reparto import MUEBLES, PRODUCTOS


def huella(datos):
    return hashlib.sha256(json.dumps(datos, sort_keys=True).encode()).hexdigest()


def medir(ruta):
    bpy.ops.wm.open_mainfile(filepath=str(ruta))
    muebles = {}
    piezas = dict(MUEBLES)
    piezas["fuera_de_servicio"] = "heladera_fuera_de_servicio-col"
    piezas.update({o.name: o.name for o in bpy.context.scene.objects
                   if o.type == "MESH" and o.name.startswith("puerta_heladera")})
    for clave, nombre in piezas.items():
        objeto = bpy.data.objects[nombre]
        muebles[clave] = {
            "matriz": [list(f) for f in objeto.matrix_world],
            "vertices": huella([list(v.co) for v in objeto.data.vertices]),
            "poligonos": huella([list(p.vertices) for p in objeto.data.polygons]),
            "dimensiones": list(objeto.dimensions),
        }
    productos = {}
    for producto in PRODUCTOS:
        objeto = bpy.data.objects[producto.objeto]
        productos[producto.clave] = {
            "padre": objeto.parent.name if objeto.parent else None,
            "escala_global": list(objeto.matrix_world.to_scale()),
            "vertices": huella([list(v.co) for v in objeto.data.vertices]),
            "uv": huella([[list(v.uv) for v in capa.data] for capa in objeto.data.uv_layers]),
            "materiales": [m.name if m else None for m in objeto.data.materials],
            "imagenes": sorted({n.image.filepath for m in objeto.data.materials if m and m.use_nodes
                                 for n in m.node_tree.nodes if n.type == "TEX_IMAGE" and n.image}),
        }
    return {"muebles": muebles, "productos": productos}


antes, despues = medir(base), medir(actual)
escalas_conservadas = all(
    max(abs(a - b) for a, b in zip(antes["productos"][p.clave]["escala_global"],
                                  despues["productos"][p.clave]["escala_global"])) <= 0.000001
    for p in PRODUCTOS)
comparables = []
for datos in (antes, despues):
    comparables.append({"muebles": datos["muebles"], "productos": {
        p: {k: v for k, v in d.items() if k != "escala_global"}
        for p, d in datos["productos"].items()}})
identicos = comparables[0] == comparables[1] and escalas_conservadas
reporte = {"antes": antes, "despues": despues, "escalas_conservadas": escalas_conservadas,
           "tolerancia_escala_float": 0.000001, "identicos": identicos}
destino.write_text(json.dumps(reporte, indent=2), encoding="utf-8")
if not identicos:
    raise RuntimeError("Cambió el arte o un mueble fuera del reparto; ver informe")
print("434_ARTE_Y_MUEBLES_IDENTICOS")
