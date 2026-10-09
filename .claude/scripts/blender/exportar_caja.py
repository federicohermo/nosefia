"""Exporta las tres piezas de assets/source/puestos/caja_registradora.blend.

blender fuente.blend --background --python exportar_caja.py -- assets/models
"""

import json
import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]
from mathutils import Matrix, Vector

salida = Path(sys.argv[sys.argv.index("--") + 1]).resolve()
datos = {}
for nombre, destino in (
    ("cajaregistradora-col", "caja_registradora"),
    ("lector de productos-col", "lector_de_productos"),
    ("ticket-convcol", "ticket_impreso"),
):
    objeto = bpy.data.objects[nombre]
    posicion = objeto.matrix_world.translation.copy()
    matriz = objeto.matrix_world.copy()
    objeto.data.transform(Matrix.Translation(-posicion) @ matriz)
    # Al hornear una escala negativa, la orientacion de las caras tambien cambia.
    if matriz.determinant() < 0:
        objeto.data.flip_normals()
    objeto.matrix_world = Matrix.Identity(4)
    objeto.name = destino
    if destino == "ticket_impreso":
        puntos = [vertice.co.copy() for vertice in objeto.data.vertices]
        centro = Vector(
            [(min(p[i] for p in puntos) + max(p[i] for p in puntos)) / 2 for i in range(3)]
        )
        objeto.data.transform(Matrix.Translation(-centro))
        posicion += centro
    bpy.ops.object.select_all(action="DESELECT")
    objeto.select_set(True)
    bpy.context.view_layer.objects.active = objeto
    for material in objeto.data.materials:
        for nodo in material.node_tree.nodes:
            if nodo.type != "TEX_IMAGE" or nodo.image is None:
                continue
            imagen = nodo.image
            ancho, alto = imagen.size
            if max(ancho, alto) > 1024:
                factor = 1024 / max(ancho, alto)
                imagen.scale(round(ancho * factor), round(alto * factor))
    bpy.ops.export_scene.gltf(
        filepath=str(salida / (destino + ".glb")),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_cameras=False,
        export_lights=False,
    )
    puntos = [vertice.co for vertice in objeto.data.vertices]
    datos[destino] = {
        "origen_godot": [posicion.x, posicion.z, -posicion.y],
        "minimo_blender": [min(p[i] for p in puntos) for i in range(3)],
        "maximo_blender": [max(p[i] for p in puntos) for i in range(3)],
        "caras": len(objeto.data.polygons),
    }
print(json.dumps(datos, indent=2))
