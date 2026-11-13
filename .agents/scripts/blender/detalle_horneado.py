"""Las capas que se hornean desde la malla para pintar detalle en el color de un objeto.

Lo usa `texturizar_utiles.py`. Cada capa sale de Cycles como una
emisión, en la UV del objeto, y vuelve como una matriz en lineal. Quien llama decide cómo se
mezclan. La copia que se hornea trae el color de cada cara en el atributo `color_base`.
"""

from pathlib import Path

import bpy  # type: ignore[import-not-found]
import numpy as np


def preparar_cycles() -> tuple:
    """Deja la escena lista para hornear y devuelve lo que había, para `restaurar`."""
    escena = bpy.context.scene
    antes = (escena.render.engine, escena.cycles.samples, escena.render.bake.use_selected_to_active)
    escena.render.engine = "CYCLES"
    escena.cycles.samples = 48
    escena.render.bake.use_selected_to_active = False
    return antes


def restaurar(antes: tuple) -> None:
    escena = bpy.context.scene
    escena.render.engine, escena.cycles.samples, escena.render.bake.use_selected_to_active = antes


def copia_con_color(objeto, color_de_cada_cara: list[tuple[float, float, float]]):
    """Una copia suelta del objeto, sin materiales, con el color de cada cara como atributo."""
    copia = objeto.copy()
    copia.data = objeto.data.copy()
    for modificador in list(copia.modifiers):
        copia.modifiers.remove(modificador)
    bpy.context.scene.collection.objects.link(copia)
    color = copia.data.color_attributes.new("color_base", "FLOAT_COLOR", "CORNER")
    for cara in copia.data.polygons:
        r, g, b = color_de_cada_cara[cara.index]
        for lazo in cara.loop_indices:
            color.data[lazo].color = (r, g, b, 1.0)
    copia.data.materials.clear()
    for cara in copia.data.polygons:
        cara.material_index = 0
    return copia


def descartar(copia) -> None:
    malla = copia.data
    bpy.data.objects.remove(copia)
    bpy.data.meshes.remove(malla)


RANURA = "ranura_original"


def guardar_ranuras(malla, materiales) -> list[str]:
    """El material original de cada cara, por nombre. La primera corrida lo escribe en la malla."""
    orden = sorted(materiales)
    if RANURA not in malla.attributes:
        atributo = malla.attributes.new(RANURA, "INT", "FACE")
        for cara in malla.polygons:
            atributo.data[cara.index].value = orden.index(malla.materials[cara.material_index].name)
    return [orden[dato.value] for dato in malla.attributes[RANURA].data]


def desplegar(objeto, columna: int, columnas: int, lado: int, margen: int) -> None:
    """Una UV nueva para el objeto, en la columna que le toca de la textura compartida."""
    malla = objeto.data
    while malla.uv_layers:
        malla.uv_layers.remove(malla.uv_layers[0])
    malla.uv_layers.new(name="UVMap")
    bpy.ops.object.select_all(action="DESELECT")
    objeto.select_set(True)
    bpy.context.view_layer.objects.active = objeto
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.03, scale_to_bounds=True)
    bpy.ops.object.mode_set(mode="OBJECT")
    borde = margen / lado
    for dato in malla.uv_layers[0].data:
        dato.uv.x = (columna + borde + dato.uv.x * (1 - 2 * borde)) / columnas
        dato.uv.y = borde + dato.uv.y * (1 - 2 * borde)


def unir_ranuras(objeto, originales: list[str], une: dict[str, str]) -> None:
    malla = objeto.data
    indice = {material.name: i for i, material in enumerate(malla.materials)}
    for cara in malla.polygons:
        nombre = originales[cara.index]
        cara.material_index = indice[une.get(nombre, nombre)]


def cablear(destino: Path, materiales) -> None:
    imagen = bpy.data.images.load(bpy.path.relpath(str(destino)), check_existing=True)
    imagen.reload()
    for nombre in materiales:
        arbol = bpy.data.materials[nombre].node_tree
        principal = next(n for n in arbol.nodes if n.type == "BSDF_PRINCIPLED")
        for nodo in [n for n in arbol.nodes if n.type == "TEX_IMAGE"]:
            arbol.nodes.remove(nodo)
        textura = arbol.nodes.new("ShaderNodeTexImage")
        textura.image = imagen
        textura.interpolation = "Closest"
        arbol.links.new(textura.outputs["Color"], principal.inputs["Base Color"])


def capas(copia, lado: int, margen: int) -> list[np.ndarray]:
    """Color base, forma, uso y altura de la copia, en ese orden."""
    return [hornear(copia, armar, lado, margen) for armar in (color_base, forma, uso, altura)]


def hornear(copia, armar, lado: int, margen: int) -> np.ndarray:
    imagen = bpy.data.images.new("horneado", lado, lado, alpha=False, float_buffer=True, is_data=True)
    material = bpy.data.materials.new("horneado")
    material.use_nodes = True
    nodos, enlaces = material.node_tree.nodes, material.node_tree.links
    nodos.clear()
    salida = nodos.new("ShaderNodeOutputMaterial")
    emision = nodos.new("ShaderNodeEmission")
    enlaces.new(emision.outputs["Emission"], salida.inputs["Surface"])
    enlaces.new(armar(nodos, enlaces), emision.inputs["Color"])
    destino = nodos.new("ShaderNodeTexImage")
    destino.image = imagen
    nodos.active = destino
    copia.data.materials.clear()
    copia.data.materials.append(material)
    bpy.ops.object.select_all(action="DESELECT")
    copia.select_set(True)
    bpy.context.view_layer.objects.active = copia
    bpy.ops.object.bake(type="EMIT", margin=margen, use_clear=True)
    pixeles = np.empty(lado * lado * 4, dtype=np.float32)
    imagen.pixels.foreach_get(pixeles)
    bpy.data.images.remove(imagen)
    bpy.data.materials.remove(material)
    return pixeles.reshape(lado, lado, 4)[..., :3].copy()


def color_base(nodos, enlaces):
    atributo = nodos.new("ShaderNodeAttribute")
    atributo.attribute_name = "color_base"
    return atributo.outputs["Color"]


def _ruido(nodos, enlaces, escala, tamano, detalle):
    coordenadas = nodos.new("ShaderNodeTexCoord")
    mapeo = nodos.new("ShaderNodeMapping")
    mapeo.inputs["Scale"].default_value = escala
    ruido = nodos.new("ShaderNodeTexNoise")
    ruido.inputs["Scale"].default_value = tamano
    ruido.inputs["Detail"].default_value = detalle
    enlaces.new(coordenadas.outputs["Object"], mapeo.inputs["Vector"])
    enlaces.new(mapeo.outputs["Vector"], ruido.inputs["Vector"])
    return ruido.outputs["Fac"]


def forma(nodos, enlaces):
    """R: oclusión. G: cuánto se desvía la normal en una arista. B: grano fino."""
    oclusion = nodos.new("ShaderNodeAmbientOcclusion")
    oclusion.only_local = True
    oclusion.samples = 16
    oclusion.inputs["Distance"].default_value = 0.12
    bisel = nodos.new("ShaderNodeBevel")
    bisel.samples = 8
    bisel.inputs["Radius"].default_value = 0.006
    geometria = nodos.new("ShaderNodeNewGeometry")
    punto = nodos.new("ShaderNodeVectorMath")
    punto.operation = "DOT_PRODUCT"
    enlaces.new(bisel.outputs["Normal"], punto.inputs[0])
    enlaces.new(geometria.outputs["Normal"], punto.inputs[1])
    arista = nodos.new("ShaderNodeMath")
    arista.operation = "SUBTRACT"
    arista.inputs[0].default_value = 1.0
    enlaces.new(punto.outputs["Value"], arista.inputs[1])
    juntar = nodos.new("ShaderNodeCombineColor")
    enlaces.new(oclusion.outputs["AO"], juntar.inputs["Red"])
    enlaces.new(arista.outputs["Value"], juntar.inputs["Green"])
    enlaces.new(_ruido(nodos, enlaces, (1, 1, 1), 220.0, 2.0), juntar.inputs["Blue"])
    return juntar.outputs["Color"]


def uso(nodos, enlaces):
    """R: manchas anchas. G: hebras a lo largo del objeto. B: rayones finos."""
    juntar = nodos.new("ShaderNodeCombineColor")
    enlaces.new(_ruido(nodos, enlaces, (1, 1, 1), 11.0, 6.0), juntar.inputs["Red"])
    enlaces.new(_ruido(nodos, enlaces, (1, 1, 0.03), 70.0, 2.0), juntar.inputs["Green"])
    enlaces.new(_ruido(nodos, enlaces, (1, 1, 0.08), 70.0, 1.0), juntar.inputs["Blue"])
    return juntar.outputs["Color"]


def altura(nodos, enlaces):
    coordenadas = nodos.new("ShaderNodeTexCoord")
    return coordenadas.outputs["Generated"]


def a_srgb(lineal: np.ndarray) -> np.ndarray:
    return np.where(lineal <= 0.0031308, lineal * 12.92, 1.055 * lineal ** (1 / 2.4) - 0.055)


def escribir(color: np.ndarray, destino: Path) -> None:
    alto, ancho = color.shape[:2]
    imagen = bpy.data.images.new("detalle", ancho, alto, alpha=False)
    rgba = np.ones((alto, ancho, 4), dtype=np.float32)
    rgba[..., :3] = a_srgb(color)
    imagen.pixels.foreach_set(rgba.ravel())
    imagen.filepath_raw = str(destino)
    imagen.file_format = "PNG"
    imagen.save()
    bpy.data.images.remove(imagen)
