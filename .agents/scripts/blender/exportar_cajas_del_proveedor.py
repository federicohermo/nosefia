"""Exporta una de las dos cajas que el proveedor deja en la jornada 7 como una sola malla.

blender assets/source/puestos/caja_del_proveedor.blend --background --python-exit-code 1 \
    --python exportar_cajas_del_proveedor.py -- assets/models caja_del_proveedor

Las piezas del artista (paredes, solapas, tapa, separadores) se unen en una malla con un material
por pieza. Se evalúa cada una antes de aplicar su transformación, porque los espejos trabajan en
el espacio del artista, y la malla queda con el centro de su base en el origen: el juego la apoya
en el piso sin conocer las medidas. La escala es la del artista: la caja del proveedor mide
lo que dos cajas contenedoras grandes puestas una al lado de la otra. Las imágenes viajan
adentro del GLB, limitadas a 1024 píxeles. La fuente no se guarda.
"""

import json
import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]
from mathutils import Matrix, Vector

LIMITE_DE_IMAGEN = 1024

argumentos = sys.argv[sys.argv.index("--") + 1 :]
salida = Path(argumentos[0]).resolve()
nombre = argumentos[1]

piezas = [objeto for objeto in bpy.data.objects if objeto.type == "MESH"]
grafo = bpy.context.evaluated_depsgraph_get()
for objeto in piezas:
    matriz = objeto.matrix_world.copy()
    malla = bpy.data.meshes.new_from_object(
        objeto.evaluated_get(grafo), preserve_all_data_layers=True, depsgraph=grafo
    )
    objeto.modifiers.clear()
    objeto.parent = None
    objeto.data = malla
    objeto.data.transform(matriz)
    if matriz.determinant() < 0:
        objeto.data.flip_normals()
    objeto.matrix_world = Matrix.Identity(4)

puntos = [vertice.co.copy() for objeto in piezas for vertice in objeto.data.vertices]
minimo = Vector([min(p[i] for p in puntos) for i in range(3)])
maximo = Vector([max(p[i] for p in puntos) for i in range(3)])
centro_de_la_base = Vector(((minimo.x + maximo.x) / 2, (minimo.y + maximo.y) / 2, minimo.z))
for objeto in piezas:
    objeto.data.transform(Matrix.Translation(-centro_de_la_base))

bpy.ops.object.select_all(action="DESELECT")
for objeto in piezas:
    objeto.select_set(True)
cuerpo = piezas[0]
bpy.context.view_layer.objects.active = cuerpo
bpy.ops.object.join()
cuerpo.name = nombre

for material in cuerpo.data.materials:
    for nodo in material.node_tree.nodes:
        if nodo.type != "TEX_IMAGE" or nodo.image is None:
            continue
        imagen = nodo.image
        ancho, alto = imagen.size
        assert ancho > 0 and alto > 0, f"la imagen {imagen.filepath} no se cargó"
        if max(ancho, alto) > LIMITE_DE_IMAGEN:
            factor = LIMITE_DE_IMAGEN / max(ancho, alto)
            imagen.scale(round(ancho * factor), round(alto * factor))

bpy.ops.export_scene.gltf(
    filepath=str(salida / (nombre + ".glb")),
    export_format="GLB",
    use_selection=True,
    export_apply=True,
    export_yup=True,
    export_cameras=False,
    export_lights=False,
)
puntos = [vertice.co for vertice in cuerpo.data.vertices]
print(
    json.dumps(
        {
            "minimo_blender": [min(p[i] for p in puntos) for i in range(3)],
            "maximo_blender": [max(p[i] for p in puntos) for i in range(3)],
            "caras": len(cuerpo.data.polygons),
            "materiales": [material.name for material in cuerpo.data.materials],
        },
        indent=2,
    )
)
