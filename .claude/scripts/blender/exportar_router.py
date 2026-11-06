"""Exporta el router de assets/source/puestos/router.blend como una sola malla.

blender router.blend --background --python-exit-code 1 --python exportar_router.py -- assets/models

Las cinco piezas del artista (cuerpo, antenas, luces y botones, patas y botón de encendido) se
unen en una malla con un material por pieza. Las tres imágenes de las luces no viajan en el GLB:
las pone `importar_caja.gd` al importar, porque el estado del router cambia la textura y no la
malla. Misma correspondencia que la caja registradora: se evalúa antes de aplicar la
transformación, se refleja X y se corrige el sentido de las caras. La posición va por la
impresión, relativa al cuerpo, y la fuente no se guarda.
"""

import json
import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]
from mathutils import Matrix

CUERPO = "router-col"
PIEZAS = (CUERPO, "antenas-col", "luces_botones-col", "patasrouter-col", "powerrouter_col")
# El juego reconoce por su nombre los tres materiales que llevan las luces del atlas del artista.
MATERIALES = {
    "Material.004": "router_cuerpo",
    "Material.027": "router_antenas",
    "Material.019": "router_luces",
    "Material.020": "router_patas",
    "Material.026": "router_encendido",
}

salida = Path(sys.argv[sys.argv.index("--") + 1]).resolve()
reflejo = Matrix.Diagonal((-1, 1, 1, 1))
origen = bpy.data.objects[CUERPO].matrix_world.translation.copy()
grafo = bpy.context.evaluated_depsgraph_get()

for nombre in PIEZAS:
    objeto = bpy.data.objects[nombre]
    matriz = objeto.matrix_world.copy()
    # Evaluar antes de quitar la escala: los modificadores trabajan en el espacio del artista.
    malla = bpy.data.meshes.new_from_object(
        objeto.evaluated_get(grafo), preserve_all_data_layers=True, depsgraph=grafo
    )
    objeto.modifiers.clear()
    objeto.parent = None
    objeto.data = malla
    transformacion = reflejo @ Matrix.Translation(-origen) @ matriz
    objeto.data.transform(transformacion)
    if transformacion.determinant() < 0:
        objeto.data.flip_normals()
    objeto.matrix_world = Matrix.Identity(4)

bpy.ops.object.select_all(action="DESELECT")
for nombre in PIEZAS:
    bpy.data.objects[nombre].select_set(True)
cuerpo = bpy.data.objects[CUERPO]
bpy.context.view_layer.objects.active = cuerpo
bpy.ops.object.join()
cuerpo.name = "router"
for material in cuerpo.data.materials:
    material.name = MATERIALES[material.name]
bpy.ops.export_scene.gltf(
    filepath=str(salida / "router.glb"),
    export_format="GLB",
    use_selection=True,
    export_apply=True,
    export_yup=True,
    export_cameras=False,
    export_lights=False,
    export_image_format="NONE",
)
posicion = reflejo @ origen
puntos = [vertice.co for vertice in cuerpo.data.vertices]
print(
    json.dumps(
        {
            "origen_godot": [posicion.x, posicion.z, -posicion.y],
            "minimo_blender": [min(p[i] for p in puntos) for i in range(3)],
            "maximo_blender": [max(p[i] for p in puntos) for i in range(3)],
            "caras": len(cuerpo.data.polygons),
            "materiales": [material.name for material in cuerpo.data.materials],
        },
        indent=2,
    )
)
