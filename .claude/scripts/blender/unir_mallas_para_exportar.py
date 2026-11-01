"""Une las mallas fijas del modelo, sólo mientras dura la exportación.

Lo corre `exportar.py`. **No toca el `.blend` guardado**: trabaja sobre copias, oculta las
originales para que `use_visible` las deje afuera, y `restaurar()` deja todo como estaba.

Qué se une y qué no lo decide `lib/union_de_mallas.py`, donde la suite del harness lo puede
ejercer. Acá sólo se recorre la escena y se llama a `bpy.ops.object.join`.
"""

import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]  # sólo existe adentro de Blender
from mathutils import Vector  # type: ignore[import-not-found]

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from lib.repo import RAIZ  # noqa: E402
from lib.union_de_mallas import (  # noqa: E402
    Candidata,
    agrupar,
    leer_ambientes,
    nombre_de_la_union,
    nombres_citados,
)

ESCENA_DE_LAS_HABITACIONES = RAIZ / "src/escenas/puestos/estructura_del_almacen.tscn"
FUENTES_DEL_JUEGO = ("src", "assets/models")


def _textos_del_juego() -> list[str]:
    textos = []
    for carpeta in FUENTES_DEL_JUEGO:
        for patron in ("*.gd", "*.tscn", "*.tres"):
            for archivo in (RAIZ / carpeta).rglob(patron):
                textos.append(archivo.read_text(encoding="utf-8", errors="replace"))
    return textos


def _centro(objeto: "bpy.types.Object") -> tuple[float, float, float]:
    esquinas = [objeto.matrix_world @ Vector(e) for e in objeto.bound_box]
    suma = sum(esquinas, Vector())
    return tuple(suma / 8)  # type: ignore[return-value]


def _capas(objeto: "bpy.types.Object") -> str:
    uv = len(objeto.data.uv_layers)
    colores = ",".join(sorted(atributo.name for atributo in objeto.data.color_attributes))
    return f"uv{uv}|{colores}"


def _es_candidata(objeto: "bpy.types.Object") -> bool:
    if objeto.type != "MESH" or not objeto.visible_get() or objeto.animation_data is not None:
        return False
    if objeto.children or any(m.show_viewport for m in objeto.modifiers):
        return False
    materiales = {m.name for m in objeto.data.materials if m is not None}
    ranuras = len(objeto.data.materials)
    return ranuras == 1 and len(materiales) == 1


def candidatas() -> list[Candidata]:
    resultado = []
    for objeto in bpy.context.view_layer.objects:
        if not _es_candidata(objeto):
            continue
        ancestros = []
        padre = objeto.parent
        while padre is not None:
            ancestros.append(padre.name)
            padre = padre.parent
        resultado.append(
            Candidata(
                nombre=objeto.name,
                centro=_centro(objeto),
                material=objeto.data.materials[0].name,
                ancestros=tuple(ancestros),
                capas=_capas(objeto),
            )
        )
    return resultado


def plan() -> dict[tuple[str, str, str], list[str]]:
    texto_de_escena = ESCENA_DE_LAS_HABITACIONES.read_text(encoding="utf-8")
    return agrupar(
        candidatas(),
        nombres_citados(_textos_del_juego()),
        leer_ambientes(texto_de_escena),
    )


def unir() -> tuple[list[str], list[str]]:
    """Une cada grupo del plan y devuelve `(originales ocultas, uniones creadas)`."""
    ocultas: list[str] = []
    uniones: list[str] = []
    coleccion = bpy.context.scene.collection
    for (ambiente, material, _), nombres in sorted(plan().items()):
        copias = []
        for nombre in nombres:
            original = bpy.data.objects[nombre]
            matriz = original.matrix_world.copy()
            copia = original.copy()
            copia.data = original.data.copy()
            coleccion.objects.link(copia)
            copia.parent = None
            copia.matrix_world = matriz
            copias.append(copia)
            original.hide_set(True)
            ocultas.append(nombre)
        bpy.ops.object.select_all(action="DESELECT")
        for copia in copias:
            copia.select_set(True)
        bpy.context.view_layer.objects.active = copias[0]
        bpy.ops.object.join()
        unido = copias[0]
        unido.name = nombre_de_la_union(ambiente, material)
        unido.data.name = unido.name
        uniones.append(unido.name)
    print(f"mallas unidas: {len(ocultas)} en {len(uniones)} grupos")
    return ocultas, uniones


def restaurar(ocultas: list[str], uniones: list[str]) -> None:
    for nombre in uniones:
        objeto = bpy.data.objects.get(nombre)
        if objeto is not None:
            malla = objeto.data
            bpy.data.objects.remove(objeto, do_unlink=True)
            if malla.users == 0:
                bpy.data.meshes.remove(malla)
    for nombre in ocultas:
        objeto = bpy.data.objects.get(nombre)
        if objeto is not None:
            objeto.hide_set(False)
