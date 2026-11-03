"""Hornea la capa de biseles de cada etiqueta de producto. Corre adentro de Blender.

    blender --background assets/models/SEPT_JUEGOS_PROTOTIPO.blend --python-exit-code 1 \
        --python .claude/scripts/blender/hornear_biseles.py -- [--solo RUTA ...] [--destino CARPETA]

Lo lanza `hornear_biseles.py` de la raíz. **No se corre a mano.** Para cada etiqueta de
`lib.atlas.ETIQUETAS` busca en el `.blend` un objeto que la use, copia el objeto entero y hornea
sólo la ranura de esa etiqueta, sobre su UV. El porqué de la capa está en `lib/biseles.py`.

## Qué se hornea

Tres pasadas de Cycles sobre la copia:

- **Brillo fino:** cuánto se desvía la normal de un bisel de `BRILLO_EN_TEXELES` de ancho.
- **Banda:** lo mismo con `BANDA_EN_TEXELES`.
- **Oclusión:** el ambiente que llega a cada punto, hasta `DISTANCIA_DE_OCLUSION`.

Más una cuarta, de cobertura, para saber qué píxeles de la imagen cubre alguna cara. **Lo que no
cubre ninguna queda sin capa**: sin esto la oclusión lo dejaría negro.

## Tres cosas que muerden

- **Las normales suaves inventan biseles.** En una lata, el vértice del borde promedia la tapa y
  el costado, y la normal suave se inclina a lo largo de todo el alto. La copia se hornea con
  caras planas, y los quiebres de menos de `UMBRAL_DE_ARISTA` (las facetas de un cilindro) no
  cuentan como arista.
- **La escena guarda `use_selected_to_active` en verdad.** Con eso, el horneado exige un objeto
  activo distinto del seleccionado y falla con «No valid selected objects». Se apaga acá.
- **La copia se hornea sola.** Con la góndola cerca, la oclusión oscurece todo el producto con la
  sombra del estante, y esa luz ya está horneada en el modelo. Se apagan para el render todos los
  objetos menos la copia, y la capa agrega sólo lo que es del producto.
"""

import sys
from pathlib import Path

import bmesh
import bpy  # type: ignore[import-not-found]  # sólo existe adentro de Blender
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from blender.aplicar_atlas import clave_de  # noqa: E402
from lib import atlas as lib_atlas  # noqa: E402
from lib import biseles  # noqa: E402
from lib.blender import achicada  # noqa: E402

MUESTRAS_DE_LA_OCLUSION = 48
MUESTRAS_DEL_BISEL = 12
MARGEN = 8


def _ranuras_por_etiqueta() -> dict[str, tuple["bpy.types.Object", int]]:
    """El primer objeto, por nombre, que usa cada etiqueta, y la ranura donde la usa."""
    claves = {lib_atlas.normalizar(c) for c in lib_atlas.ETIQUETAS}
    elegidas: dict[str, tuple[bpy.types.Object, int]] = {}
    for objeto in sorted(bpy.data.objects, key=lambda o: o.name):
        if objeto.type != "MESH" or not objeto.data.polygons:
            continue
        usadas = {p.material_index for p in objeto.data.polygons}
        for indice, ranura in enumerate(objeto.material_slots):
            material = ranura.material
            if indice not in usadas or material is None or not material.use_nodes:
                continue
            for nodo in material.node_tree.nodes:
                if nodo.type == "TEX_IMAGE" and nodo.image:
                    clave = clave_de(nodo.image)
                    if clave in claves and clave not in elegidas:
                        elegidas[clave] = (objeto, indice)
    return elegidas


def _copiar(objeto: "bpy.types.Object") -> "bpy.types.Object":
    """Una copia con la transformación aplicada. Conserva todas las caras: sin las tapas, una
    lata es un tubo abierto y la oclusión mira para adentro."""
    escena = bpy.context.scene
    malla = objeto.data.copy()
    copia = bpy.data.objects.new("bisel_" + objeto.name, malla)
    escena.collection.objects.link(copia)
    copia.matrix_world = objeto.matrix_world.copy()
    bpy.context.view_layer.update()
    for otro in bpy.context.view_layer.objects:
        otro.select_set(False)
    copia.select_set(True)
    bpy.context.view_layer.objects.active = copia
    trozo = bmesh.new()
    trozo.from_mesh(malla)
    if all(len(arista.link_faces) == 2 for arista in trozo.edges):
        bmesh.ops.recalc_face_normals(trozo, faces=trozo.faces)
    trozo.to_mesh(malla)
    trozo.free()
    malla.shade_flat()
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return copia


def _material(armar, imagen: "bpy.types.Image") -> "bpy.types.Material":
    material = bpy.data.materials.new("bisel")
    material.use_nodes = True
    nodos = material.node_tree
    nodos.nodes.clear()
    salida = nodos.nodes.new("ShaderNodeOutputMaterial")
    emision = nodos.nodes.new("ShaderNodeEmission")
    nodos.links.new(emision.outputs[0], salida.inputs[0])
    armar(nodos, emision)
    textura = nodos.nodes.new("ShaderNodeTexImage")
    textura.image = imagen
    nodos.nodes.active = textura
    textura.select = True
    return material


def _texeles_por_metro(copia, ranura: int, ancho: int, alto: int) -> float:
    """Cuántos texeles de la capa caben en un metro de la etiqueta, medido sobre sus caras."""
    malla = copia.data
    uv = malla.uv_layers.active.data
    superficie = sum(c.area for c in malla.polygons if c.material_index == ranura)
    en_uv = 0.0
    for cara in malla.polygons:
        if cara.material_index != ranura:
            continue
        puntos = [uv[i].uv for i in cara.loop_indices]
        en_uv += 0.5 * abs(
            sum(
                puntos[i][0] * puntos[(i + 1) % len(puntos)][1]
                - puntos[(i + 1) % len(puntos)][0] * puntos[i][1]
                for i in range(len(puntos))
            )
        )
    if superficie <= 0 or en_uv <= 0:
        return 1000.0
    return (en_uv * ancho * alto / superficie) ** 0.5


def _hornear(copia, ranura: int, ancho: int, alto: int, tipo: str, armar) -> np.ndarray:
    """Hornea un tipo en una imagen de `ancho x alto` y devuelve un canal, de arriba a abajo.

    Las caras de las otras ranuras hornean en una imagen de descarte: así no pisan, con su UV,
    la de la etiqueta que se busca.
    """
    imagen = bpy.data.images.new("bisel", ancho, alto, float_buffer=True)
    imagen.colorspace_settings.name = "Non-Color"
    descarte = bpy.data.images.new("descarte", 4, 4, float_buffer=True)
    materiales = [
        _material(armar, imagen if indice == ranura else descarte)
        for indice in range(len(copia.material_slots))
    ]
    copia.data.materials.clear()
    for material in materiales:
        copia.data.materials.append(material)
    bpy.ops.object.bake(type=tipo, margin=MARGEN, margin_type="EXTEND", use_clear=True)
    datos = np.empty(ancho * alto * 4, dtype=np.float32)
    imagen.pixels.foreach_get(datos)
    bpy.data.images.remove(imagen)
    bpy.data.images.remove(descarte)
    for material in materiales:
        bpy.data.materials.remove(material)
    return datos.reshape(alto, ancho, 4)[::-1, :, :3].mean(axis=2)


def _desvio_del_bisel(radio: float):
    def armar(nodos, emision) -> None:
        bisel = nodos.nodes.new("ShaderNodeBevel")
        bisel.inputs["Radius"].default_value = radio
        bisel.samples = MUESTRAS_DEL_BISEL
        plana = nodos.nodes.new("ShaderNodeNewGeometry")
        punto = nodos.nodes.new("ShaderNodeVectorMath")
        punto.operation = "DOT_PRODUCT"
        nodos.links.new(bisel.outputs["Normal"], punto.inputs[0])
        nodos.links.new(plana.outputs["True Normal"], punto.inputs[1])
        resta = nodos.nodes.new("ShaderNodeMath")
        resta.operation = "SUBTRACT"
        resta.inputs[0].default_value = 1.0
        nodos.links.new(punto.outputs["Value"], resta.inputs[1])
        doble = nodos.nodes.new("ShaderNodeMath")
        doble.operation = "MULTIPLY"
        doble.inputs[1].default_value = 2.0
        nodos.links.new(resta.outputs[0], doble.inputs[0])
        arista = nodos.nodes.new("ShaderNodeMath")
        arista.operation = "SUBTRACT"
        arista.use_clamp = True
        arista.inputs[1].default_value = biseles.UMBRAL_DE_ARISTA
        nodos.links.new(doble.outputs[0], arista.inputs[0])
        nodos.links.new(arista.outputs[0], emision.inputs["Color"])

    return armar


def _blanco(nodos, emision) -> None:
    emision.inputs["Color"].default_value = (1.0, 1.0, 1.0, 1.0)


def _sin_cambios(nodos, emision) -> None:
    return None


def _capa_de(copia, ranura: int, ancho: int, alto: int) -> np.ndarray:
    """La capa de una ranura de la copia: `(alto, ancho, 3)` con luz, brillo y cero, de 0 a 1."""
    escena = bpy.context.scene
    escena.cycles.samples = MUESTRAS_DEL_BISEL
    densidad = _texeles_por_metro(copia, ranura, ancho, alto)
    radio_fino = biseles.radio_en_metros(biseles.BRILLO_EN_TEXELES, densidad)
    radio_ancho = biseles.radio_en_metros(biseles.BANDA_EN_TEXELES, densidad)
    fino = _hornear(copia, ranura, ancho, alto, "EMIT", _desvio_del_bisel(radio_fino))
    banda = _hornear(copia, ranura, ancho, alto, "EMIT", _desvio_del_bisel(radio_ancho))
    cobertura = _hornear(copia, ranura, ancho, alto, "EMIT", _blanco) > 0.5
    escena.cycles.samples = MUESTRAS_DE_LA_OCLUSION
    oclusion = _hornear(copia, ranura, ancho, alto, "AO", _sin_cambios)
    oclusion = np.where(cobertura, oclusion, 1.0)
    oscurecimiento = np.clip(
        biseles.PESO_DE_LA_BANDA * banda + biseles.PESO_DE_LA_OCLUSION * (1.0 - oclusion),
        0.0,
        biseles.OSCURECIMIENTO_MAXIMO,
    )
    brillo = np.clip(biseles.PESO_DEL_BRILLO * fino, 0.0, biseles.BRILLO_MAXIMO)
    capa = np.zeros((alto, ancho, 3), dtype=np.float32)
    capa[..., 0] = 1.0 - oscurecimiento
    capa[..., 1] = np.where(cobertura, brillo, 0.0)
    capa[..., 0] = np.where(cobertura, capa[..., 0], 1.0)
    return capa


def _escribir(capa: np.ndarray, destino: Path) -> None:
    """Escribe el PNG con `Image.save`, que no aplica la transformación de vista de la escena."""
    alto, ancho = capa.shape[:2]
    imagen = bpy.data.images.new("capa", ancho, alto, alpha=False)
    try:
        imagen.colorspace_settings.name = "sRGB"
        rgba = np.ones((alto, ancho, 4), dtype=np.float32)
        rgba[..., :3] = capa
        imagen.pixels.foreach_set(np.ascontiguousarray(rgba[::-1]).reshape(-1))
        imagen.file_format = "PNG"
        imagen.filepath_raw = str(destino)
        destino.parent.mkdir(parents=True, exist_ok=True)
        imagen.save()
    finally:
        bpy.data.images.remove(imagen)


def _preparar_la_escena() -> None:
    escena = bpy.context.scene
    escena.render.engine = "CYCLES"
    escena.cycles.device = "CPU"
    escena.cycles.use_denoising = False
    escena.render.bake.use_selected_to_active = False
    mundo = bpy.data.worlds.new("bisel")
    mundo.use_nodes = True
    mundo.light_settings.distance = biseles.DISTANCIA_DE_OCLUSION
    escena.world = mundo
    for objeto in bpy.data.objects:
        objeto.hide_render = True


def _argumentos() -> tuple[set[str], Path | None]:
    entrada = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    solo: set[str] = set()
    destino = None
    while entrada:
        palabra = entrada.pop(0)
        if palabra == "--solo":
            solo.add(lib_atlas.normalizar(entrada.pop(0)))
        elif palabra == "--destino":
            destino = Path(entrada.pop(0))
    return solo, destino


def main() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    solo, destino = _argumentos()
    _preparar_la_escena()
    elegidas = _ranuras_por_etiqueta()
    faltan = [clave for clave in lib_atlas.ETIQUETAS if clave not in elegidas]
    if faltan:
        raise SystemExit("ningún objeto del modelo usa estas etiquetas:\n  " + "\n  ".join(faltan))
    for clave in lib_atlas.ETIQUETAS:
        if solo and lib_atlas.normalizar(clave) not in solo:
            continue
        objeto, ranura = elegidas[clave]
        medidas = lib_atlas.ancho_alto_png((lib_atlas.ASSETS / clave).read_bytes()[:32])
        ancho, alto = achicada(*medidas, lib_atlas.lado_de(clave))
        copia = _copiar(objeto)
        capa = _capa_de(copia, ranura, ancho, alto)
        malla = copia.data
        bpy.data.objects.remove(copia)
        bpy.data.meshes.remove(malla)
        ruta = biseles.ruta_de_la_capa(clave)
        if destino is not None:
            ruta = destino / ruta.relative_to(biseles.CARPETA)
        _escribir(capa, ruta)
        print(
            f"bisel: {clave} <- {objeto.name}[{ranura}] {ancho}x{alto} "
            f"luz mínima {capa[..., 0].min():.2f} brillo máximo {capa[..., 1].max():.2f}"
        )


if __name__ == "__main__":
    main()
