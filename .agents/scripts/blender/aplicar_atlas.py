"""Apunta los materiales del modelo al atlas, sólo mientras dura la exportación.

Lo corre `exportar.py`, antes de unir mallas y de achicar las imágenes. **No toca el `.blend`
guardado ni los PNG del artista**: cambia en memoria la imagen de cada material de etiqueta, y
la UV1 de las mallas que la usan, y `restaurar()` los devuelve.

## Qué hace

1. Lee el manifiesto de `assets/source/atlas/` y **se corta** si el atlas no corresponde a sus
   fuentes. Un atlas viejo no da ningún error en el juego: la etiqueta de un producto sale con
   el dibujo de otro.
2. Cambia la imagen de cada material de etiqueta por la de su atlas.
3. Lleva la UV1 de cada cara a la celda de su textura. **UV2 no se toca**: es la del horneado.
4. Une los materiales que quedaron iguales. Es lo que habilita unir las mallas que los usan.

## Lo que se corta

Una cara con UV fuera de 0..1 sobre una textura de atlas. Fuera del cuadrado, la textura se
repite; dentro de un atlas esa repetición muestra la etiqueta de al lado.
"""

import sys
import unicodedata
from pathlib import Path

import bpy  # type: ignore[import-not-found]  # sólo existe adentro de Blender
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from lib import atlas as lib_atlas  # noqa: E402
from lib.blender import FUENTES  # noqa: E402

#: Cuánto puede salirse una UV del cuadrado sin que se la tenga por una repetición. Es el
#: error de redondeo del exportador, no una tolerancia de diseño.
TOLERANCIA_UV = 0.02

Restauracion = tuple[list[tuple["bpy.types.Material", str, "bpy.types.Image"]], dict]


def ruta_en_fuentes(imagen: "bpy.types.Image") -> str | None:
    """La ruta del archivo de una imagen adentro de `assets/source/`, o `None` si no sale de ahí.

    Las empaquetadas con la ruta de la máquina donde se armaron no salen de ahí: la ruta no
    existe en esta, y la resolución la deja afuera.
    """
    ruta = Path(bpy.path.abspath(imagen.filepath))
    try:
        return ruta.resolve().relative_to(FUENTES.resolve()).as_posix()
    except (OSError, ValueError):
        return None


def clave_de(imagen: "bpy.types.Image") -> str | None:
    relativa = ruta_en_fuentes(imagen)
    if relativa is None:
        return None
    return unicodedata.normalize("NFC", f"source/{relativa}")


def _manifiesto_al_dia() -> dict:
    manifiesto = lib_atlas.leer()
    motivos = lib_atlas.desfasaje_con_el_disco(manifiesto)
    if motivos:
        raise SystemExit(
            "el atlas no corresponde a sus fuentes:\n  "
            + "\n  ".join(motivos)
            + "\ncorré python .claude/scripts/armar_atlas.py"
        )
    return manifiesto


def _por_clave(manifiesto: dict) -> dict:
    celdas = {}
    for atlas in manifiesto["atlas"]:
        for entrada in atlas["entradas"]:
            celdas[unicodedata.normalize("NFC", entrada["ruta"])] = (atlas, entrada)
    return celdas


def aplicar() -> Restauracion:
    if not lib_atlas.MANIFIESTO.is_file():
        print("atlas: no hay manifiesto, se exporta con las texturas sueltas")
        return [], {}
    manifiesto = _manifiesto_al_dia()
    celdas = _por_clave(manifiesto)
    imagenes_atlas: dict[str, bpy.types.Image] = {}
    cambios: list[tuple[bpy.types.Material, str, bpy.types.Image]] = []
    #: material -> (atlas, entrada), para llevar las UV de las caras que lo usan.
    de_material: dict[bpy.types.Material, tuple[dict, dict]] = {}
    for material in bpy.data.materials:
        if not material.use_nodes:
            continue
        for nodo in material.node_tree.nodes:
            if nodo.type != "TEX_IMAGE" or nodo.image is None:
                continue
            clave = clave_de(nodo.image)
            if clave is None or clave not in celdas:
                continue
            atlas, entrada = celdas[clave]
            if atlas["archivo"] not in imagenes_atlas:
                imagenes_atlas[atlas["archivo"]] = bpy.data.images.load(
                    str(lib_atlas.CARPETA / atlas["archivo"]), check_existing=True
                )
            cambios.append((material, nodo.name, nodo.image))
            nodo.image = imagenes_atlas[atlas["archivo"]]
            de_material[material] = (atlas, entrada)
    originales = _llevar_las_uv(de_material)
    print(f"materiales apuntados al atlas: {len(de_material)}, mallas movidas: {len(originales)}")
    return cambios, originales


def _llevar_las_uv(de_material: dict) -> dict:
    originales: dict = {}
    for malla in bpy.data.meshes:
        if malla.users == 0 or not malla.uv_layers:
            continue
        por_indice = {
            i: de_material[m] for i, m in enumerate(malla.materials) if m in de_material
        }
        if not por_indice:
            continue
        capa = malla.uv_layers[0].uv
        uv = np.empty(len(capa) * 2, dtype=np.float32)
        capa.foreach_get("vector", uv)
        originales[malla.name] = uv.copy()
        uv = uv.reshape(-1, 2)
        nuevo = uv.copy()
        for poligono in malla.polygons:
            destino = por_indice.get(poligono.material_index)
            if destino is None:
                continue
            atlas, entrada = destino
            lazos = np.arange(poligono.loop_start, poligono.loop_start + poligono.loop_total)
            cara = uv[lazos]
            if cara.min() < -TOLERANCIA_UV or cara.max() > 1 + TOLERANCIA_UV:
                raise SystemExit(
                    f"{malla.name}: una cara de {entrada['ruta']} tiene UV fuera de 0..1 "
                    f"({cara.min():.3f}..{cara.max():.3f}). En un atlas la textura no se "
                    "repite: hay que corregir la UV de la malla."
                )
            u = (entrada["x"] + np.clip(cara[:, 0], 0, 1) * entrada["ancho"]) / atlas["ancho"]
            v = 1.0 - (entrada["y"] + (1.0 - np.clip(cara[:, 1], 0, 1)) * entrada["alto"]) / atlas["alto"]
            nuevo[lazos] = np.stack([u, v], axis=1)
        capa.foreach_set("vector", nuevo.reshape(-1))
        malla.update()
    return originales


def restaurar(estado: Restauracion) -> None:
    cambios, originales = estado
    for material, nombre_del_nodo, imagen in cambios:
        material.node_tree.nodes[nombre_del_nodo].image = imagen
    for nombre, uv in originales.items():
        malla = bpy.data.meshes.get(nombre)
        if malla is not None:
            malla.uv_layers[0].uv.foreach_set("vector", uv)
            malla.update()
    carpeta = lib_atlas.CARPETA.resolve()
    for imagen in list(bpy.data.images):
        if Path(bpy.path.abspath(imagen.filepath)).resolve().parent == carpeta:
            bpy.data.images.remove(imagen)
