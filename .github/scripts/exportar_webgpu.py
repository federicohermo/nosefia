"""Exportar el juego a la web con el motor WebGPU, desde una copia aislada del árbol.

    python .github/scripts/exportar_webgpu.py <destino> [--renderizador mobile|forward_plus]
        [--editor RUTA] [--plantilla RUTA] [--hilos] [--autoload RUTA]

Deja `<destino>/web` con el export y `<destino>/huellas.json`. `<destino>` tiene que ser una
carpeta nueva. El árbol real no se toca: sigue en Godot 4.7.2 y con su propio caché de importación.

La copia sale de `git archive HEAD`. En ella:

- El renderizador es el que se pide (por defecto `mobile`). El editor borra del `project.godot` la
  línea del renderizador cuando vale `forward_plus`, el valor por defecto: por eso se escribe acá y
  se comprueba al terminar.
- Sale `addons/godot_mcp/commands`, que el preset ya excluye del paquete. El horneador de sombreadores
  lee todos los scripts del proyecto, y encontrar `sdfgi_enabled` ahí le hace hornear las
  variantes de SDFGI de Forward+.
- La plantilla es la WebGPU, y con `--hilos` el preset pide hilos.

**Se exporta con ventana, nunca con `--headless`:** sin ventana el export no hornea sombreadores, y el
navegador los convierte al vuelo. El editor y la plantilla tienen que tener el mismo hash de versión:
va en la clave de cada sombreador horneado.
"""

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
PLANTILLA = RAIZ / "build/templates/webgpu_release.zip"
ARCHIVOS_DEL_EXPORT = ("index.html", "index.js", "index.pck", "index.wasm", "index.shaders.pck")


def sha256(ruta: Path) -> str:
    return hashlib.sha256(ruta.read_bytes()).hexdigest()


def ajustar_proyecto(ajustes: str, renderizador: str, autoload: str | None) -> str:
    """El `project.godot` de la copia, con el renderizador pedido."""
    ajustes = re.sub(r'renderer/rendering_method="[^"]*"\n', "", ajustes)
    ajustes, cambios = re.subn(
        r"\[rendering\]\n\n",
        f'[rendering]\n\nrenderer/rendering_method="{renderizador}"\n',
        ajustes,
        count=1,
    )
    if cambios != 1:
        raise ValueError("project.godot cambió de forma: no tiene su sección [rendering]")
    if autoload is not None:
        ajustes, cambios = re.subn(
            r"\[autoload\]\n\n", f'[autoload]\n\nJornadaDirecta="*{autoload}"\n', ajustes, count=1
        )
        if cambios != 1:
            raise ValueError("project.godot cambió de forma: no tiene su sección [autoload]")
    return ajustes


def ajustar_presets(presets: str, plantilla: str, hilos: bool, hilo_de_render: bool) -> str:
    """El `export_presets.cfg` de la copia, con la plantilla WebGPU."""
    presets, cambios = re.subn(
        r'custom_template/release="[^"]*"', f'custom_template/release="{plantilla}"', presets
    )
    presets, hilos_cambiados = re.subn(
        r"variant/thread_support=\w+", f"variant/thread_support={str(hilos).lower()}", presets
    )
    if cambios != 1 or hilos_cambiados != 1:
        raise ValueError("export_presets.cfg cambió de forma: no se pudo ajustar la copia")
    # Sin la clave, el motor usa su valor por defecto, que es encendido.
    presets = re.sub(r"variant/separate_render_thread=\w+\n", "", presets)
    return presets.replace(
        "variant/thread_support=",
        f"variant/separate_render_thread={str(hilo_de_render).lower()}\nvariant/thread_support=",
        1,
    )


def renderizador_de(proyecto: Path) -> str | None:
    coincidencia = re.search(r'renderer/rendering_method="([^"]*)"', (proyecto / "project.godot").read_text(encoding="utf-8"))
    return coincidencia.group(1) if coincidencia else None


def _correr(comando: list[str], log: Path, cwd: Path) -> int:
    with log.open("wb") as salida:
        return subprocess.run(comando, cwd=cwd, stdout=salida, stderr=subprocess.STDOUT).returncode


def exportar(
    destino: Path, editor: Path, plantilla: Path, renderizador: str, hilos: bool,
    hilo_de_render: bool, autoload: Path | None,
) -> dict:
    if destino.exists():
        raise ValueError(f"`{destino}` ya existe: usar una carpeta nueva por export")
    if not plantilla.is_file():
        raise ValueError(f"falta la plantilla `{plantilla}`: correr antes `preparar_motor_webgpu.py`")
    proyecto, web = destino / "proyecto", destino / "web"
    proyecto.mkdir(parents=True)
    web.mkdir()

    paquete = destino / "arbol.zip"
    subprocess.run(["git", "-C", str(RAIZ), "archive", "--format=zip", "-o", str(paquete), "HEAD"], check=True)
    with zipfile.ZipFile(paquete) as archivo:
        archivo.extractall(proyecto)
    paquete.unlink()
    shutil.rmtree(proyecto / "addons/godot_mcp/commands", ignore_errors=True)
    (proyecto / "build/templates").mkdir(parents=True)
    (proyecto / "build/.gdignore").write_text("", encoding="utf-8")
    plantilla_en_copia = proyecto / "build/templates/webgpu_release.zip"
    shutil.copyfile(plantilla, plantilla_en_copia)

    autoload_res = None
    if autoload is not None:
        (proyecto / "depuracion").mkdir()
        shutil.copyfile(autoload, proyecto / "depuracion" / autoload.name)
        autoload_res = f"res://depuracion/{autoload.name}"
    ajustes = (proyecto / "project.godot").read_text(encoding="utf-8")
    (proyecto / "project.godot").write_text(ajustar_proyecto(ajustes, renderizador, autoload_res), encoding="utf-8", newline="\n")
    presets = (proyecto / "export_presets.cfg").read_text(encoding="utf-8")
    (proyecto / "export_presets.cfg").write_text(
        ajustar_presets(presets, "res://build/templates/webgpu_release.zip", hilos, hilo_de_render), encoding="utf-8", newline="\n"
    )

    base = [str(editor), "--path", str(proyecto)]
    if _correr([*base, "--headless", "--import"], destino / "importar.log", proyecto):
        raise ValueError(f"la importación falló: {destino / 'importar.log'}")
    # Con ventana: sin ella, el export no hornea los sombreadores.
    _correr([*base, "--export-release", "Web", str(web / "index.html")], destino / "exportar.log", proyecto)
    (proyecto / "export/web").mkdir(parents=True)
    _correr([*base, "--headless", "--script", ".github/scripts/armar_paquete_del_mapa.gd"], destino / "mapa.log", proyecto)
    mapa = proyecto / "export/web/mapa_del_corte.pck"
    if mapa.is_file():
        shutil.move(mapa, web / "mapa_del_corte.pck")

    faltan = [n for n in ARCHIVOS_DEL_EXPORT if not (web / n).is_file() or (web / n).stat().st_size == 0]
    if faltan:
        raise ValueError(f"el export no dejó {faltan}: {destino / 'exportar.log'}")
    if not (web / "mapa_del_corte.pck").is_file():
        raise ValueError(f"no se armó el paquete del mapa: {destino / 'mapa.log'}")
    # El editor reescribe el project.godot al exportar: lo que cuenta es lo que quedó.
    obtenido = renderizador_de(proyecto)
    if obtenido != renderizador:
        raise ValueError(f"el renderizador quedó en {obtenido!r} y no en {renderizador!r}")
    with zipfile.ZipFile(plantilla) as archivo:
        wasm_de_la_plantilla = hashlib.sha256(archivo.read("godot.wasm")).hexdigest()
    if sha256(web / "index.wasm") != wasm_de_la_plantilla:
        raise ValueError("index.wasm no es el de la plantilla WebGPU")
    huellas = {
        "renderizador": renderizador,
        "hilos": hilos,
        "hilo_de_render": hilos and hilo_de_render,
        **{n: (web / n).stat().st_size for n in (*ARCHIVOS_DEL_EXPORT, "mapa_del_corte.pck")},
        "wasm_sha256": sha256(web / "index.wasm"),
    }
    (destino / "huellas.json").write_text(json.dumps(huellas, indent=1), encoding="utf-8")
    return huellas


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("destino", type=Path)
    parser.add_argument("--renderizador", choices=("mobile", "forward_plus"), default="mobile")
    parser.add_argument("--editor", type=Path, default=Path(os.environ.get("GODOT_WEBGPU_BIN", "")))
    parser.add_argument("--plantilla", type=Path, default=PLANTILLA)
    parser.add_argument("--hilos", action="store_true")
    parser.add_argument("--sin-hilo-de-render", action="store_true",
                        help="con --hilos, deja el render en el hilo principal")
    parser.add_argument("--autoload", type=Path, help="un script que se carga como autoload, sólo para pruebas")
    args = parser.parse_args()
    if not args.editor.is_file():
        print("Falta el editor del fork: --editor o GODOT_WEBGPU_BIN.", file=sys.stderr)
        return 1
    try:
        huellas = exportar(args.destino.resolve(), args.editor, args.plantilla.resolve(), args.renderizador, args.hilos,
                            not args.sin_hilo_de_render, args.autoload)
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"No se exportó: {error}", file=sys.stderr)
        return 1
    print(json.dumps(huellas, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
