"""Hornear un albedo más legible conservando el desgaste de la chapa CC0.

Ejecutar en Blender background con --factory-startup. No abre ni guarda el modelo.
La emisión se usa sólo como pase de color de un plano auxiliar; no llega al juego.
"""

import hashlib
import json
import sys
from pathlib import Path

import bpy

RAIZ = Path(__file__).resolve().parents[3]
ORIGEN = RAIZ / (
    "assets/source/textures/warehouse/polyhaven/corrugated-iron-02/1K/"
    "corrugated_iron_02_diff_1k.jpg"
)
DESTINO = RAIZ / "assets/source/textures/warehouse/final/deposito_chapa_color.png"


def hornear():
    imagen = bpy.data.images.load(str(ORIGEN), check_existing=True)
    imagen.colorspace_settings.name = "sRGB"
    escena = bpy.data.scenes.new("HorneadoDelColorDeChapa")
    bpy.context.window.scene = escena
    escena.render.engine = "CYCLES"
    escena.cycles.device = "CPU"
    escena.cycles.samples = 1
    malla = bpy.data.meshes.new("PlanoDeColor")
    malla.from_pydata([(0, 0, 0), (1, 0, 0), (1, 1, 0), (0, 1, 0)], [], [(0, 1, 2, 3)])
    uv = malla.uv_layers.new(name="UVMap")
    for i, punto in enumerate(((0, 0), (1, 0), (1, 1), (0, 1))):
        uv.data[i].uv = punto
    objeto = bpy.data.objects.new("PlanoDeColor", malla)
    escena.collection.objects.link(objeto)
    bpy.context.view_layer.objects.active = objeto
    objeto.select_set(True)
    material = bpy.data.materials.new("TonoDeChapa")
    material.use_nodes = True
    material.node_tree.nodes.clear()
    nodos, enlaces = material.node_tree.nodes, material.node_tree.links
    textura = nodos.new("ShaderNodeTexImage")
    textura.image = imagen
    escala = nodos.new("ShaderNodeVectorMath")
    escala.operation = "SCALE"
    escala.inputs["Scale"].default_value = .9
    suma = nodos.new("ShaderNodeVectorMath")
    suma.operation = "ADD"
    suma.inputs[1].default_value = (.1, .1, .1)
    emision = nodos.new("ShaderNodeEmission")
    salida = nodos.new("ShaderNodeOutputMaterial")
    destino = nodos.new("ShaderNodeTexImage")
    enlaces.new(textura.outputs["Color"], escala.inputs[0])
    enlaces.new(escala.outputs[0], suma.inputs[0])
    enlaces.new(suma.outputs[0], emision.inputs["Color"])
    enlaces.new(emision.outputs[0], salida.inputs["Surface"])
    malla.materials.append(material)
    horneada = bpy.data.images.new("deposito_chapa_color", width=1024, height=1024, alpha=False)
    horneada.colorspace_settings.name = "sRGB"
    destino.image = horneada
    nodos.active = destino
    destino.select = True
    bpy.ops.object.bake(type="EMIT", margin=0, use_clear=True)
    horneada.filepath_raw = str(DESTINO)
    horneada.file_format = "PNG"
    horneada.save()
    procedencia = {
        "source": "../polyhaven/corrugated-iron-02/source.json",
        "license": "CC0-1.0",
        "original": "../polyhaven/corrugated-iron-02/1K/corrugated_iron_02_diff_1k.jpg",
        "original_sha256": hashlib.sha256(ORIGEN.read_bytes()).hexdigest(),
        "file": DESTINO.name,
        "sha256": hashlib.sha256(DESTINO.read_bytes()).hexdigest(),
        "operation": "Blender material bake: linear_color * 0.9 + 0.1; sRGB PNG",
        "generator": ".claude/scripts/blender/tonificar_chapa_del_deposito.py",
        "size": list(horneada.size),
    }
    DESTINO.with_suffix(".source.json").write_text(
        json.dumps(procedencia, indent=2) + "\n", encoding="utf-8")
    return procedencia


if __name__ == "__main__":
    sys.path.insert(0, str(RAIZ / ".claude/scripts"))
    from lib.consola import configurar

    configurar()
    print(json.dumps(hornear(), indent=2))
