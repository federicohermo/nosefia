"""Hornea en una sola textura el detalle del balde y de la mopa: oclusión, bordes, uso y hebras.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/texturizar_utiles.py -- [--aplicar]

Sin `--aplicar` deja la textura en la carpeta temporal y no guarda nada. Con `--aplicar` escribe
`TEXTURA` y guarda la fuente canónica. Después va `exportar_modelo.py`.

## Por qué

El balde y la mopa eran colores lisos: en el cuartito, contra los bloques con relieve, se leían
como juguetes. El detalle va horneado en el color, como el bisel de las etiquetas, porque la luz
del juego no deja brillo que un mapa de relieve pueda mover.

## Qué cambia

- Los dos objetos ganan una UV, la mitad izquierda de la textura para el balde y la derecha para
  la mopa. La geometría no se toca.
- Cada cara guarda su color original en el atributo `RANURA`, y de ahí se hornea: correrlo de
  nuevo da la misma textura.
- Las ranuras que el juego pinta con el mismo shader se unen. El color ya viaja en la textura, y
  cada ranura es un dibujo más. Los nombres que el juego busca siguen estando.
"""

import sys
import tempfile
from pathlib import Path

import bpy  # type: ignore[import-not-found]
import numpy as np

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))
from lib.consola import configurar  # noqa: E402

TEXTURA = RAIZ / "assets/source/textures/props/utiles_de_limpieza.png"
LADO = 512
MARGEN = 8
RANURA = "ranura_original"

#: El color liso que tenía cada material, en lineal. Es la base de lo que se hornea.
COLORES = {
    "util_plastico_azul": (0.035, 0.16, 0.32),
    "util_plastico_claro": (0.06, 0.23, 0.42),
    "util_borde_crema": (0.68, 0.72, 0.7),
    "util_asa_grafito": (0.08, 0.105, 0.12),
    "util_mango_acero": (0.36, 0.42, 0.45),
    "util_fibra_cruda": (0.72, 0.7, 0.62),
    "util_fibra_sombra": (0.58, 0.57, 0.5),
}
FIBRAS = ("util_fibra_cruda", "util_fibra_sombra")

#: Qué ranura absorbe a cuál en cada objeto, y en qué mitad de la textura cae su UV.
OBJETOS = {
    "balde-col": {"une": {"util_asa_grafito": "util_borde_crema"}, "columna": 0},
    "mopa-col": {
        "une": {"util_asa_grafito": "util_plastico_azul", "util_fibra_sombra": "util_fibra_cruda"},
        "columna": 1,
    },
}


def guardar_ranuras(malla) -> list[str]:
    """El material original de cada cara, por nombre. La primera corrida lo escribe en la malla."""
    orden = sorted(COLORES)
    if RANURA not in malla.attributes:
        atributo = malla.attributes.new(RANURA, "INT", "FACE")
        for cara in malla.polygons:
            atributo.data[cara.index].value = orden.index(malla.materials[cara.material_index].name)
    return [orden[dato.value] for dato in malla.attributes[RANURA].data]


def desplegar(objeto, columna: int) -> None:
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
    borde = MARGEN / LADO
    for dato in malla.uv_layers[0].data:
        dato.uv.x = (columna + borde + dato.uv.x * (1 - 2 * borde)) * 0.5
        dato.uv.y = borde + dato.uv.y * (1 - 2 * borde)


def copia_para_hornear(objeto, originales: list[str]):
    copia = objeto.copy()
    copia.data = objeto.data.copy()
    bpy.context.scene.collection.objects.link(copia)
    color = copia.data.color_attributes.new("color_base", "FLOAT_COLOR", "CORNER")
    for cara in copia.data.polygons:
        r, g, b = COLORES[originales[cara.index]]
        for lazo in cara.loop_indices:
            color.data[lazo].color = (r, g, b, 1.0)
    copia.data.materials.clear()
    for cara in copia.data.polygons:
        cara.material_index = 0
    return copia


def hornear(copia, armar) -> np.ndarray:
    imagen = bpy.data.images.new("horneado", LADO, LADO, alpha=False, float_buffer=True, is_data=True)
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
    bpy.ops.object.bake(type="EMIT", margin=MARGEN, use_clear=True)
    pixeles = np.empty(LADO * LADO * 4, dtype=np.float32)
    imagen.pixels.foreach_get(pixeles)
    bpy.data.images.remove(imagen)
    bpy.data.materials.remove(material)
    return pixeles.reshape(LADO, LADO, 4)[..., :3].copy()


def _color_base(nodos, enlaces):
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


def _forma(nodos, enlaces):
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


def _uso(nodos, enlaces):
    """R: manchas anchas. G: hebras a lo largo del objeto. B: rayones finos."""
    juntar = nodos.new("ShaderNodeCombineColor")
    enlaces.new(_ruido(nodos, enlaces, (1, 1, 1), 11.0, 6.0), juntar.inputs["Red"])
    enlaces.new(_ruido(nodos, enlaces, (1, 1, 0.03), 70.0, 2.0), juntar.inputs["Green"])
    enlaces.new(_ruido(nodos, enlaces, (1, 1, 0.08), 70.0, 1.0), juntar.inputs["Blue"])
    return juntar.outputs["Color"]


def _altura(nodos, enlaces):
    coordenadas = nodos.new("ShaderNodeTexCoord")
    return coordenadas.outputs["Generated"]


def pintar(base, forma, uso, altura) -> np.ndarray:
    """El color final, en lineal, desde las capas horneadas."""
    oclusion, arista, grano = forma[..., 0:1], forma[..., 1:2], forma[..., 2:3]
    manchas, hebras, rayones = uso[..., 0:1], uso[..., 1:2], uso[..., 2:3]
    alto = altura[..., 2:3]
    es_fibra = np.zeros(base.shape[:2] + (1,), dtype=bool)
    for nombre in FIBRAS:
        es_fibra |= np.abs(base - np.array(COLORES[nombre])).sum(axis=2, keepdims=True) < 0.02

    luz = 0.5 + 0.5 * np.clip(oclusion, 0, 1) ** 1.3
    plastico = base * luz * (0.93 + 0.14 * grano)
    suciedad = np.clip((manchas - 0.48) * 4, 0, 1) * np.clip(1 - alto * 3.2, 0, 1)
    velo = np.clip((manchas - 0.58) * 5, 0, 1) * 0.35
    plastico = plastico * (1 - 0.55 * np.maximum(suciedad, velo))
    raya = np.clip((np.abs(rayones - 0.5) - 0.2) * 25, 0, 1) * np.clip((manchas - 0.4) * 4, 0, 1)
    plastico = plastico + (0.55 - plastico) * raya * 0.35
    canto = np.clip(arista * 5, 0, 1)
    plastico = plastico + (np.minimum(plastico * 1.7 + 0.05, 1) - plastico) * canto * 0.7

    fibra = base * (0.45 + 0.55 * np.clip(oclusion, 0, 1)) * (0.62 + 0.76 * hebras)
    return np.clip(np.where(es_fibra, fibra, plastico), 0, 1)


def a_srgb(lineal: np.ndarray) -> np.ndarray:
    return np.where(lineal <= 0.0031308, lineal * 12.92, 1.055 * lineal ** (1 / 2.4) - 0.055)


def escribir(color: np.ndarray, destino: Path) -> None:
    imagen = bpy.data.images.new("utiles", LADO, LADO, alpha=False)
    rgba = np.ones((LADO, LADO, 4), dtype=np.float32)
    rgba[..., :3] = a_srgb(color)
    imagen.pixels.foreach_set(rgba.ravel())
    imagen.filepath_raw = str(destino)
    imagen.file_format = "PNG"
    imagen.save()
    bpy.data.images.remove(imagen)


def unir_ranuras(objeto, originales: list[str], une: dict[str, str]) -> None:
    malla = objeto.data
    indice = {material.name: i for i, material in enumerate(malla.materials)}
    for cara in malla.polygons:
        nombre = originales[cara.index]
        cara.material_index = indice[une.get(nombre, nombre)]


def cablear(destino: Path) -> None:
    imagen = bpy.data.images.load(bpy.path.relpath(str(destino)), check_existing=True)
    imagen.reload()
    for nombre in COLORES:
        arbol = bpy.data.materials[nombre].node_tree
        principal = next(n for n in arbol.nodes if n.type == "BSDF_PRINCIPLED")
        for nodo in [n for n in arbol.nodes if n.type == "TEX_IMAGE"]:
            arbol.nodes.remove(nodo)
        textura = arbol.nodes.new("ShaderNodeTexImage")
        textura.image = imagen
        textura.interpolation = "Closest"
        arbol.links.new(textura.outputs["Color"], principal.inputs["Base Color"])


def main() -> None:
    configurar()
    aplicar = "--aplicar" in sys.argv
    escena = bpy.context.scene
    antes = (escena.render.engine, escena.cycles.samples, escena.render.bake.use_selected_to_active)
    escena.render.engine = "CYCLES"
    escena.cycles.samples = 48
    escena.render.bake.use_selected_to_active = False

    color = np.zeros((LADO, LADO, 3), dtype=np.float32)
    for nombre, datos in OBJETOS.items():
        objeto = bpy.data.objects[nombre]
        originales = guardar_ranuras(objeto.data)
        desplegar(objeto, datos["columna"])
        copia = copia_para_hornear(objeto, originales)
        capas = [hornear(copia, armar) for armar in (_color_base, _forma, _uso, _altura)]
        malla = copia.data
        bpy.data.objects.remove(copia)
        bpy.data.meshes.remove(malla)
        mitad = slice(datos["columna"] * LADO // 2, (datos["columna"] + 1) * LADO // 2)
        color[:, mitad] = pintar(*capas)[:, mitad]
        unir_ranuras(objeto, originales, datos["une"])
        print(f"{nombre}: {len(originales)} caras horneadas")

    escena.render.engine, escena.cycles.samples, escena.render.bake.use_selected_to_active = antes
    destino = TEXTURA if aplicar else Path(tempfile.gettempdir()) / TEXTURA.name
    escribir(color, destino)
    print(f"textura: {destino}")
    if aplicar:
        cablear(destino)
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")


if __name__ == "__main__":
    main()
