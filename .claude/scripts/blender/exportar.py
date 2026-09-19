"""El exportador, del lado de Blender. Lo corre `exportar_modelo.py`; no se corre a mano.

    blender <fuente>.blend --background --python .claude/scripts/blender/exportar.py -- <destino>

Vive acá y no en `.claude/scripts/` porque **importa `bpy`**, que sólo existe adentro de Blender:
un módulo así en la raíz del harness lo importaría `unittest discover` y la suite se caería.

## Las opciones no son gusto: son las que reproducen el par

Están medidas reexportando hasta dar con los mismos bytes que el `.glb` commiteado. Formato GLB,
imágenes AUTO, `export_apply`, `use_visible`, `export_yup`, sin cámaras ni luces.

**`use_visible` importa**: sin él entran los objetos de la colección oculta, que no son parte del
juego.

## Y los modificadores `Array` se apagan POR NOMBRE, **con su sufijo**

Son **Geometry Nodes llamados `Array`**, no modificadores de tipo `ARRAY`: apagar por tipo no
apaga ninguno y los productos salen multiplicados igual. Y el nombre exacto tampoco alcanza:
Blender numera el duplicado, así que hay `Array.001` — 34 de ellos acá — y cada uno que queda
prendido duplica su producto. La regla está en `lib/blender.es_un_array()`, con su medición. Blender 5.0 no realizaba esas instancias
al exportar y 5.2 sí, así que con el modificador activo el producto sale como una fila entera.

El juego necesita **una unidad**: el puesto de reposición toma la superficie 0 de cada grupo como
el modelo de una y apila copias separadas por su AABB. Con la fila entera, dos productos vecinos
se pisan y el test de apoyos del modelo da rojo — un síntoma que no nombra ni a Blender ni al
modificador, que es lo que lo vuelve caro.
"""

import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]  # sólo existe adentro de Blender

# La decisión de qué nombre cuenta vive en `lib/`, donde la suite del harness la puede ejercer:
# acá adentro corre el Python de Blender y nada de esto se puede importar desde un test.
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from lib.blender import MODIFICADOR, es_un_array  # noqa: E402


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
    try:
        exportar(destino)
    finally:
        restaurar(apagados)
    print(f"exportado: {destino}")


if __name__ == "__main__":
    main()
