"""El exportador, del lado de Blender. Lo corre `exportar_modelo.py`; no se corre a mano.

    blender <fuente>.blend --background --python-exit-code 1 --python \
        .claude/scripts/blender/exportar.py -- <destino>

Vive acá y no en `.claude/scripts/` porque **importa `bpy`**, que sólo existe adentro de Blender:
un módulo así en la raíz del harness lo importaría `unittest discover` y la suite se caería.

## Las opciones no son gusto: son las que reproducen el par

Están medidas reexportando hasta dar con el `.glb` commiteado. Los bytes no coinciden nunca: dos
exportaciones seguidas del mismo `.blend` difieren en el último bit de algunas UV. Formato GLB,
imágenes AUTO, `export_apply`, `use_visible`, `export_yup`, sin cámaras ni luces.

**`use_visible` importa**: sin él entran los objetos de la colección oculta, que no son parte del
juego.

## Y los modificadores `Array` se apagan POR NOMBRE, **con su sufijo**

Son **Geometry Nodes llamados `Array`**, no modificadores de tipo `ARRAY`: apagar por tipo no
apaga ninguno y los productos salen multiplicados igual. Y el nombre exacto tampoco alcanza:
Blender numera el duplicado, así que hay `Array.001`, y cada uno que queda prendido duplica su
producto. La regla está en `lib/blender.es_un_array()`, con su medición. Blender 5.0 no realizaba
esas instancias al exportar y 5.2 sí, así que con el modificador activo el producto sale como una
fila entera.

El juego necesita **una unidad**: el puesto de reposición toma la superficie 0 de cada grupo como
el modelo de una y apila copias separadas por su AABB. Con la fila entera, dos productos vecinos
se pisan y el test de apoyos del modelo da rojo — un síntoma que no nombra ni a Blender ni al
modificador, que es lo que lo vuelve caro.

## Y cada textura viaja achicada al lado de su grupo, sobre una copia

El arte del artista pasa los 9.000 px de lado, y el `.glb` llevaba cada imagen entera: 65 MB, el
95 % en texturas, para un juego que igual las importa a 1024. El lado de cada grupo y de qué grupo
es cada imagen lo decide `lib/blender.py`. Acá se achica **una copia en memoria**, que reemplaza a
la original sólo mientras dura la exportación: ni el `.blend` ni los PNG del artista cambian.

**La copia tiene que quedar marcada como modificada**, o el exportador copia los bytes del archivo
original en vez de codificar los píxeles achicados, y el `.glb` sale igual de pesado sin que nada
lo diga. `scale()` la marca en 5.2; si otra versión dejara de hacerlo, la exportación se corta.
"""

import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]  # sólo existe adentro de Blender

# La decisión de qué nombre cuenta vive en `lib/`, donde la suite del harness la puede ejercer:
# acá adentro corre el Python de Blender y nada de esto se puede importar desde un test.
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from lib.blender import (  # noqa: E402
    COLECCION_DE_GUIA,
    FUENTES,
    LADO_MAXIMO,
    MODIFICADOR,
    achicada,
    es_un_array,
    grupo_de,
)


def apagar_los_array() -> list[tuple[str, str]]:
    """Apaga todo modificador llamado `Array` y devuelve cuáles, para poder restaurarlos."""
    apagados: list[tuple[str, str]] = []
    for objeto in bpy.data.objects:
        for modificador in objeto.modifiers:
            if es_un_array(modificador.name) and modificador.show_viewport:
                modificador.show_viewport = False
                modificador.show_render = False
                apagados.append((objeto.name, modificador.name))
    return apagados


def apagar_la_guia() -> bool:
    """Saca del view layer la colección de las copias, y dice si hizo falta.

    **Son copias linkeadas que el juego dibuja con un `MultiMesh`, no geometría del local.** Se
    quedan en el `.blend` porque son la fuente de dónde va cada unidad, y se ven en el viewport
    porque el artista las acomoda ahí; lo que no pueden es viajar en el `.glb`, o cada producto
    se dibujaría dos veces: una horneada y otra por el grupo.

    Se excluye la colección y no se oculta objeto por objeto: `use_visible` mira el view layer,
    así que excluirla alcanza, y deja el archivo como estaba al restaurarla.
    """
    capa = bpy.context.view_layer.layer_collection.children.get(COLECCION_DE_GUIA)
    if capa is None or capa.exclude:
        return False
    capa.exclude = True
    return True


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


def achicar_las_imagenes() -> list[tuple["bpy.types.Image", "bpy.types.Image"]]:
    """Reemplaza cada imagen que pasa el lado de su grupo por una copia achicada, y devuelve los
    pares para deshacerlo.

    La copia conserva la ruta de la original, que es de donde el exportador saca el nombre de la
    imagen en el `.glb`, y Godot el del archivo que extrae: cambiarlo dejaría huérfana la textura
    que los `.res` de `assets/models/` ya referencian.
    """
    pares = []
    for imagen in list(bpy.data.images):
        if imagen.source != "FILE":
            continue
        ancho, alto = imagen.size
        if ancho == 0 or alto == 0:
            continue
        lado = LADO_MAXIMO[grupo_de(ruta_en_fuentes(imagen))]
        nuevo = achicada(ancho, alto, lado)
        if nuevo == (ancho, alto):
            continue
        copia = imagen.copy()
        copia.scale(*nuevo)
        if not copia.is_dirty:
            bpy.data.images.remove(copia)
            restaurar_las_imagenes(pares)
            raise SystemExit(
                f"{imagen.name}: la copia achicada no quedó marcada como modificada, y el "
                "exportador copiaría el archivo original entero."
            )
        imagen.user_remap(copia)
        pares.append((imagen, copia))
    return pares


def restaurar_las_imagenes(pares: list[tuple["bpy.types.Image", "bpy.types.Image"]]) -> None:
    """Vuelve a poner cada original en su lugar y borra las copias."""
    for imagen, copia in pares:
        copia.user_remap(imagen)
        bpy.data.images.remove(copia)


def restaurar(apagados: list[tuple[str, str]]) -> None:
    """Los deja como estaban. El `.blend` no se guarda, pero una sesión interactiva sí los vería."""
    for nombre_objeto, nombre_modificador in apagados:
        objeto = bpy.data.objects.get(nombre_objeto)
        if objeto is None:
            continue
        modificador = objeto.modifiers.get(nombre_modificador)
        if modificador is not None:
            modificador.show_viewport = True
            modificador.show_render = True


def exportar(destino: str) -> None:
    bpy.ops.export_scene.gltf(
        filepath=destino,
        export_format="GLB",
        export_image_format="AUTO",
        export_apply=True,
        use_visible=True,
        export_yup=True,
        export_cameras=False,
        export_lights=False,
    )


def main() -> None:
    # Su salida la captura `exportar_modelo.py`, y en Windows el default no es UTF-8: el primer
    # acento de un nombre de objeto tiraría el script adentro de Blender, con un rastro que
    # nombra a `codecs` y no a la exportación. No importa `lib/consola.py` a propósito — acá
    # corre el Python de Blender, no el del harness.
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    # Blender le pasa al script todo lo que va después de `--`.
    if "--" not in sys.argv:
        raise SystemExit("falta el destino: ... --python exportar.py -- <destino>.glb")
    destino = sys.argv[sys.argv.index("--") + 1]

    apagados = apagar_los_array()
    print(f"modificadores `{MODIFICADOR}` apagados: {len(apagados)}")
    guia_apagada = apagar_la_guia()
    print(f"colección `{COLECCION_DE_GUIA}` excluida: {guia_apagada}")
    achicadas: list[tuple[bpy.types.Image, bpy.types.Image]] = []
    try:
        achicadas = achicar_las_imagenes()
        print(f"texturas achicadas: {len(achicadas)}")
        exportar(destino)
    finally:
        restaurar_las_imagenes(achicadas)
        restaurar(apagados)
        if guia_apagada:
            bpy.context.view_layer.layer_collection.children[COLECCION_DE_GUIA].exclude = False
    print(f"exportado: {destino}")


if __name__ == "__main__":
    main()
