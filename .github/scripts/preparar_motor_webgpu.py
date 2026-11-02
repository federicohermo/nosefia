"""Preparar la plantilla web WebGPU del fork fijado, y lo que hace falta para exportar con ella.

    python .github/scripts/preparar_motor_webgpu.py               # valida o compila la plantilla
    python .github/scripts/preparar_motor_webgpu.py --comprobar   # sólo valida, sin compilar

La receta está en `.github/patches/godot-webgpu-compilacion.json`: el commit del fork, los parches
sobre él, el SDK y las opciones. La plantilla queda en `build/templates/webgpu_release.zip`.
Esta entrega no toca la plantilla WebGL2 ni su preparador.

La fuente se baja del repositorio del fork, no de uno nuestro. `glslangValidator` y
`wgsl_convert_cli` los pide el build: en Linux se compilan o se instalan, y en Windows sin MSVC se
usan los binarios ya hechos que `--herramientas` señala.
"""

import argparse
import importlib.util
import json
import os
import platform
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
METADATA = RAIZ / ".github/patches/godot-webgpu-compilacion.json"
DESTINO = RAIZ / "build/templates/webgpu_release.zip"
ARCHIVOS = {
    "godot.js", "godot.wasm", "godot.html", "godot.audio.worklet.js",
    "godot.audio.position.worklet.js", "godot.service.worker.js", "godot.offline.html",
}
COMMIT_DEL_FORK = "c4b5f43ebb1875ab6fb1881aa66c4185e0c3976f"
# Las mismas opciones que la plantilla WebGL2: lo que el juego no usa se apaga y el WASM pesa menos.
# `threads=no`: la variante con hilos todavía no se mide; ver docs/guides/rendimiento.md.
OPCIONES = [
    "platform=web", "target=template_release", "threads=no", "dlink_enabled=no", "webgpu=yes",
    "opengl3=no", "optimize=size", "lto=full",
    "module_text_server_adv_enabled=no", "module_text_server_fb_enabled=yes",
    "disable_physics_2d=yes", "disable_navigation_2d=yes", "disable_xr=yes", "minizip=no",
    *(f"module_{modulo}_enabled=no" for modulo in (
        "astcenc", "basis_universal", "bmp", "csg", "dds", "enet", "etcpak", "fbx", "gltf",
        "godot_physics_2d", "godot_physics_3d", "gridmap", "hdr", "interactive_music", "jpg",
        "jsonrpc", "ktx", "meshoptimizer", "mobile_vr", "mp3", "msdfgen", "multiplayer",
        "navigation_2d", "noise", "regex", "theora", "tga", "tinyexr", "upnp",
        "vhacd", "visual_shader", "webrtc", "websocket", "webxr", "zip",
        # Del fork y sin uso en el juego: física Box3D (usa Jolt), raycast (sólo el editor hornea),
        # tilemap, mbedtls (en la web HTTPRequest usa el navegador) y metahuman.
        "box3d_physics", "metahuman", "mbedtls", "raycast", "tilemap",
    )),
]


# El editor que exporta con ventana y hornea los sombreadores. Sale del mismo árbol que la plantilla:
# el hash de versión entra en la clave de cada sombreador horneado, y los dos tienen que coincidir.
OPCIONES_DEL_EDITOR = [
    "platform=linuxbsd", "target=editor", "arch=x86_64", "webgpu=yes", "optimize=speed",
    "lto=none", "debug_symbols=no",
]
EDITOR = RAIZ / "build/godot-webgpu/editor/godot.linuxbsd.editor.x86_64"


def _base():
    ruta = Path(__file__).with_name("preparar_plantilla_web.py")
    spec = importlib.util.spec_from_file_location("preparar_plantilla_web", ruta)
    modulo = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(modulo)
    return modulo


base = _base()
sha256 = base.sha256


def validar_zip(ruta: Path) -> dict[str, str]:
    try:
        with zipfile.ZipFile(ruta) as archivo:
            nombres = archivo.namelist()
            if len(nombres) != len(set(nombres)) or set(nombres) != ARCHIVOS:
                raise ValueError(f"el ZIP no trae los siete archivos de la plantilla: {nombres}")
            if archivo.testzip() is not None:
                raise ValueError("CRC del ZIP inválido")
            wasm = archivo.read("godot.wasm")
            if not wasm.startswith(b"\0asm\x01\0\0\0"):
                raise ValueError("cabecera WASM inválida")
            js = archivo.read("godot.js")
            if not js:
                raise ValueError("JavaScript vacío")
            return {"wasm_sha256": sha256(wasm), "js_sha256": sha256(js)}
    except (OSError, zipfile.BadZipFile, RuntimeError) as error:
        raise ValueError(f"ZIP inválido: {error}") from error


def archivos_del_parche(parches: list[Path]) -> set[str]:
    archivos: set[str] = set()
    for parche in parches:
        for linea in parche.read_text(encoding="utf-8").splitlines():
            if linea.startswith("+++ b/"):
                archivos.add(linea.removeprefix("+++ b/"))
    return archivos


def regenerar(metadata: Path, repo_del_motor: Path) -> None:
    """Reescribe el parche y la receta desde los commits del motor sobre el commit fijado.

    `repo_del_motor` es un repositorio git con el commit fijado y encima nuestros commits.
    """
    def git(*args: str) -> bytes:
        return subprocess.run(["git", "-C", str(repo_del_motor), *args], check=True,
                              capture_output=True).stdout

    cambiados = git("diff", "--name-only", COMMIT_DEL_FORK, "HEAD").decode().split()
    parche = git("diff", "--no-color", "--no-ext-diff", COMMIT_DEL_FORK, "HEAD")
    datos = json.loads(metadata.read_text(encoding="utf-8")) if metadata.exists() else {}
    datos.update({
        "commit_del_motor": COMMIT_DEL_FORK,
        "fuente": "https://github.com/Shane-Gadsby/godotwebgpu",
        "parches": ["godot-webgpu.patch"],
        "opciones": OPCIONES,
        "archivos": {
            ruta: {
                "original_sha256": sha256(git("show", f"{COMMIT_DEL_FORK}:{ruta}")),
                "modificado_sha256": sha256(git("show", f"HEAD:{ruta}")),
            }
            for ruta in cambiados
        },
    })
    (metadata.parent / "godot-webgpu.patch").write_bytes(parche)
    metadata.write_text(json.dumps(datos, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Receta regenerada: {len(cambiados)} archivos, {len(parche)} bytes de parche", flush=True)


def identidad(metadata: Path) -> tuple[dict, list[Path], dict]:
    datos = json.loads(metadata.read_text(encoding="utf-8"))
    if datos["opciones"] != OPCIONES:
        raise ValueError("opciones de compilación distintas de las del preparador")
    parches = [(metadata.parent / nombre).resolve() for nombre in datos["parches"]]
    sin_par = sorted(archivos_del_parche(parches) ^ set(datos["archivos"]))
    if sin_par:
        raise ValueError(f"el parche y las huellas de la receta difieren en: {sin_par}")
    huellas = {p.name: sha256(p.read_bytes().replace(b"\r\n", b"\n")) for p in parches}
    huellas["preparador"] = sha256(Path(__file__).read_bytes().replace(b"\r\n", b"\n"))
    clave = {
        campo: datos[campo]
        for campo in ("commit_del_motor", "emscripten", "scons", "opciones", "archivos")
    }
    clave["huellas"] = huellas
    return datos, parches, clave


def aplicar_parches(datos: dict, parches: list[Path], motor: Path, log: Path) -> None:
    entorno_git = os.environ.copy()
    entorno_git["GIT_CEILING_DIRECTORIES"] = str(motor.parent.resolve())
    comando = ["git", "-c", "core.autocrlf=false", "apply"]
    for parche in parches:
        base._ejecutar([*comando, "--check", str(parche)], motor, log, entorno_git)
        base._ejecutar([*comando, str(parche)], motor, log, entorno_git)
    base._comprobar_huellas(motor, datos["archivos"], "modificado")


def construir(datos: dict, parches: list[Path], trabajo: Path, jobs: int, herramientas: Path | None) -> Path:
    trabajo.mkdir(parents=True, exist_ok=True)
    commit, sdk_version = datos["commit_del_motor"], datos["emscripten"]
    fuente, sdk_zip = trabajo / "fork.zip", trabajo / "emsdk.zip"
    base._descargar(f"https://codeload.github.com/Shane-Gadsby/godotwebgpu/zip/{commit}",
                    fuente, datos["fuente_zip_sha256"])
    base._descargar(f"https://codeload.github.com/emscripten-core/emsdk/zip/refs/tags/{sdk_version}",
                    sdk_zip, datos["emsdk_zip_sha256"])
    with tempfile.TemporaryDirectory(prefix="compilacion-", dir=trabajo) as temporal:
        motor, sdk = Path(temporal) / "motor", Path(temporal) / "emsdk"
        base._extraer(fuente, motor)
        base._extraer(sdk_zip, sdk)
        log = trabajo / "compilacion.log"
        base._comprobar_huellas(motor, datos["archivos"], "original")
        aplicar_parches(datos, parches, motor, log)
        sdk_script = str(sdk / "emsdk.py")
        base._ejecutar([sys.executable, sdk_script, "install", sdk_version], sdk, log)
        base._ejecutar([sys.executable, sdk_script, "activate", sdk_version, "--embedded"], sdk, log)
        entorno = base._entorno_sdk(sdk, jobs)
        if herramientas is not None:
            entorno["PATH"] = str(herramientas) + os.pathsep + entorno["PATH"]
            convertidor = herramientas / ("wgsl_convert_cli.exe" if os.name == "nt" else "wgsl_convert_cli")
            if convertidor.is_file():
                (motor / "bin").mkdir(exist_ok=True)
                shutil.copyfile(convertidor, motor / "bin" / convertidor.name)
        virtual = Path(temporal) / "venv"
        base.venv.EnvBuilder(with_pip=True).create(virtual)
        python = virtual / ("Scripts/python.exe" if os.name == "nt" else "bin/python")
        base._ejecutar([str(python), "-m", "pip", "install", "--disable-pip-version-check",
                        f"scons=={datos['scons']}"], motor, log, entorno)
        cache = trabajo / "cache-de-scons"
        base._ejecutar([str(python), "-m", "SCons", *datos["opciones"], f"cache_path={cache}",
                        f"-j{jobs}"], motor, log, entorno)
        candidatos = list((motor / "bin").glob("godot.web.template_release*.zip"))
        if len(candidatos) != 1:
            raise ValueError("la compilación no produjo una única plantilla release")
        validar_zip(candidatos[0])
        resultado = trabajo / "compilada.zip"
        shutil.copyfile(candidatos[0], resultado)
        return resultado


def construir_editor(datos: dict, parches: list[Path], trabajo: Path, jobs: int, herramientas: Path | None) -> Path:
    """Compila el editor de Linux desde la misma fuente y el mismo parche que la plantilla."""
    trabajo.mkdir(parents=True, exist_ok=True)
    fuente = trabajo / "fork.zip"
    base._descargar(f"https://codeload.github.com/Shane-Gadsby/godotwebgpu/zip/{datos['commit_del_motor']}",
                    fuente, datos["fuente_zip_sha256"])
    with tempfile.TemporaryDirectory(prefix="editor-", dir=trabajo) as temporal:
        motor = Path(temporal) / "motor"
        base._extraer(fuente, motor)
        log = trabajo / "compilacion-editor.log"
        base._comprobar_huellas(motor, datos["archivos"], "original")
        aplicar_parches(datos, parches, motor, log)
        entorno = os.environ.copy()
        if herramientas is not None:
            entorno["PATH"] = str(herramientas) + os.pathsep + entorno["PATH"]
            convertidor = herramientas / "wgsl_convert_cli"
            if convertidor.is_file():
                (motor / "bin").mkdir(exist_ok=True)
                shutil.copyfile(convertidor, motor / "bin" / convertidor.name)
        virtual = Path(temporal) / "venv"
        base.venv.EnvBuilder(with_pip=True).create(virtual)
        python = virtual / ("Scripts/python.exe" if os.name == "nt" else "bin/python")
        base._ejecutar([str(python), "-m", "pip", "install", "--disable-pip-version-check",
                        f"scons=={datos['scons']}"], motor, log, entorno)
        cache = trabajo / "cache-de-scons-editor"
        base._ejecutar([str(python), "-m", "SCons", *OPCIONES_DEL_EDITOR, f"cache_path={cache}",
                        f"-j{jobs}"], motor, log, entorno)
        binarios = list((motor / "bin").glob("godot.linuxbsd.editor.x86_64*"))
        if len(binarios) != 1:
            raise ValueError(f"la compilación no produjo un único editor: {binarios}")
        resultado = trabajo / "editor" / binarios[0].name
        resultado.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(binarios[0], resultado)
        resultado.chmod(0o755)
        return resultado


def preparar(metadata: Path, destino: Path, comprobar: bool, jobs: int, herramientas: Path | None) -> dict:
    datos, parches, clave = identidad(metadata)
    manifiesto_ruta = destino.with_suffix(".manifiesto.json")
    try:
        manifiesto = json.loads(manifiesto_ruta.read_text(encoding="utf-8"))
        if manifiesto.get("identidad") != clave:
            raise ValueError("la identidad de la plantilla guardada no coincide con la receta")
        huellas = validar_zip(destino)
        if manifiesto.get("zip_sha256") != sha256(destino.read_bytes()):
            raise ValueError("SHA256 del ZIP distinto del manifiesto")
        if any(manifiesto.get(c) != v for c, v in huellas.items()):
            raise ValueError("SHA256 de los archivos distinto del manifiesto")
        print(f"Plantilla WebGPU verificada: {destino}", flush=True)
        return manifiesto
    except (ValueError, OSError, KeyError, json.JSONDecodeError) as error:
        if comprobar:
            raise ValueError(f"plantilla WebGPU inválida: {error}") from error
        print(f"Preparando la plantilla WebGPU: {error}", flush=True)
    origen = construir(datos, parches, RAIZ / "build/godot-webgpu", jobs, herramientas)
    huellas = validar_zip(origen)
    destino.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(origen, destino)
    manifiesto = {
        "identidad": clave, **huellas, "zip_sha256": sha256(destino.read_bytes()),
        "host": platform.platform(), "jobs": jobs,
    }
    manifiesto_ruta.write_text(json.dumps(manifiesto, indent=2) + "\n", encoding="utf-8")
    print(f"Plantilla WebGPU preparada: {destino}", flush=True)
    return manifiesto


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--metadata", type=Path, default=METADATA)
    parser.add_argument("--destino", type=Path, default=DESTINO)
    parser.add_argument("--jobs", type=int, default=4)
    parser.add_argument("--comprobar", action="store_true")
    parser.add_argument("--editor", action="store_true",
                        help="compila el editor de Linux en vez de la plantilla")
    parser.add_argument("--regenerar", type=Path, metavar="REPO_DEL_MOTOR",
                        help="reescribe el parche y la receta desde el repositorio del motor")
    parser.add_argument("--herramientas", type=Path,
                        help="carpeta con glslangValidator y wgsl_convert_cli ya compilados")
    args = parser.parse_args()
    try:
        if args.regenerar is not None:
            regenerar(args.metadata.resolve(), args.regenerar.resolve())
            return 0
        if args.editor:
            datos, parches, _ = identidad(args.metadata.resolve())
            editor = construir_editor(datos, parches, RAIZ / "build/godot-webgpu", args.jobs, args.herramientas)
            EDITOR.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(editor, EDITOR)
            EDITOR.chmod(0o755)
            print(f"Editor WebGPU preparado: {EDITOR}", flush=True)
            return 0
        preparar(args.metadata.resolve(), args.destino.resolve(), args.comprobar, args.jobs,
                 args.herramientas)
    except (ValueError, OSError, KeyError, subprocess.CalledProcessError) as error:
        print(f"No se preparó la plantilla WebGPU: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
