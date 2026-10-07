"""Preparar la plantilla fijada; una caché o un fallback oficial no evitan las guardias.

El WASM medido en Windows sólo identifica la importación local. Compilar el mismo código
en Linux puede producir otro binario: la caché guarda su propia huella y procedencia.
"""

import argparse
import configparser
import hashlib
import json
import os
import platform
import re
import runpy
import shutil
import stat
import subprocess
import sys
import tempfile
import urllib.request
import uuid
import venv
import zipfile
from pathlib import Path, PurePosixPath

RAIZ = Path(__file__).resolve().parents[2]
METADATA = RAIZ / ".github/patches/godot-web-compilacion.json"
DESTINO = RAIZ / "build/templates/web_release.zip"
ARCHIVOS = {
    "godot.js", "godot.wasm", "godot.html", "godot.audio.worklet.js",
    "godot.audio.position.worklet.js", "godot.service.worker.js", "godot.offline.html",
}
OPCIONES = [
    "platform=web", "target=template_release", "threads=yes", "optimize=size", "lto=thin",
]


def sha256(contenido: bytes) -> str:
    return hashlib.sha256(contenido).hexdigest()


def validar_zip(ruta: Path) -> dict[str, str]:
    try:
        with zipfile.ZipFile(ruta) as archivo:
            nombres = archivo.namelist()
            if len(nombres) != len(set(nombres)) or set(nombres) != ARCHIVOS:
                raise ValueError("ZIP no contiene los siete archivos de la plantilla web")
            if archivo.testzip() is not None:
                raise ValueError("CRC del ZIP inválido")
            wasm = archivo.read("godot.wasm")
            if not wasm.startswith(b"\0asm\x01\0\0\0"):
                raise ValueError("Cabecera WASM inválida")
            js = archivo.read("godot.js")
            if not js:
                raise ValueError("ZIP contiene JavaScript vacío")
            return {"wasm_sha256": sha256(wasm), "js_sha256": sha256(js)}
    except (OSError, zipfile.BadZipFile, RuntimeError) as error:
        raise ValueError(f"ZIP inválido: {error}") from error


def archivos_del_parche(parche: Path) -> set[str]:
    lineas = parche.read_text(encoding="utf-8").splitlines()
    return {linea.removeprefix("+++ b/") for linea in lineas if linea.startswith("+++ b/")}


def _identidad(metadata: Path, raiz: Path) -> tuple[dict, Path, dict]:
    datos = json.loads(metadata.read_text(encoding="utf-8"))
    version = (raiz / ".godot-version").read_text(encoding="utf-8").strip()
    if datos["version_del_motor"] != version:
        raise ValueError("La versión de metadata no coincide con .godot-version")
    if datos["opciones"] != OPCIONES:
        raise ValueError("Opciones de compilación distintas de la plantilla validada")
    if not re.fullmatch(r"[0-9a-f]{40}", datos["commit_del_motor"]):
        raise ValueError("Commit del motor inválido")
    campos_sha = ("fuente_zip_sha256", "emsdk_zip_sha256")
    huellas = {campo: datos[campo] for campo in campos_sha}
    for ruta, del_archivo in datos["archivos"].items():
        for campo in ("original_sha256", "modificado_sha256"):
            huellas[f"{ruta}: {campo}"] = del_archivo[campo]
    for campo, huella in huellas.items():
        if not re.fullmatch(r"[0-9a-f]{64}", huella):
            raise ValueError(f"SHA256 inválido: {campo}")
    for campo in ("emscripten", "scons"):
        if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", datos[campo]):
            raise ValueError(f"Versión inválida: {campo}")
    parche = (metadata.parent / datos["parche"]).resolve()
    # Un archivo del parche sin huella en la receta se compilaría sin comprobar.
    sin_par = sorted(archivos_del_parche(parche) ^ set(datos["archivos"]))
    if sin_par:
        raise ValueError(f"El parche y las huellas de metadata difieren en: {sin_par}")
    claves = ("version_del_motor", "commit_del_motor", "emscripten", "scons", "opciones")
    identidad = {clave: datos[clave] for clave in (*claves, *campos_sha, "archivos")}
    identidad["parche_sha256"] = sha256(parche.read_bytes().replace(b"\r\n", b"\n"))
    identidad["preparador_sha256"] = sha256(
        Path(__file__).read_bytes().replace(b"\r\n", b"\n")
    )
    identidad["formato"] = 1
    return datos, parche, identidad


def _validar_preset(raiz: Path, destino: Path) -> None:
    config = configparser.ConfigParser(interpolation=None)
    config.read(raiz / "export_presets.cfg", encoding="utf-8")
    web = [
        nombre for nombre in config.sections()
        if not nombre.endswith(".options")
        and config.get(nombre, "platform", fallback="") == '"Web"'
    ]
    if len(web) != 1:
        raise ValueError("Debe existir un único preset Web")
    seccion = web[0] + ".options"
    ruta = json.loads(config.get(seccion, "custom_template/release", fallback='""'))
    if not ruta:
        raise ValueError("El preset Web usa la plantilla oficial")
    ruta = ruta.removeprefix("res://")
    if (raiz / ruta).resolve() != destino.resolve():
        raise ValueError("La plantilla release del preset no coincide con el destino")
    if config.get(seccion, "variant/thread_support", fallback="") != "true":
        raise ValueError("El preset debe habilitar hilos")
    if config.get(seccion, "variant/extensions_support", fallback="") != "false":
        raise ValueError("El preset debe deshabilitar extensions_support")


def receta_sha256(identidad: dict) -> str:
    receta = {clave: valor for clave, valor in identidad.items() if clave != "preparador_sha256"}
    return sha256(json.dumps(receta, sort_keys=True, separators=(",", ":")).encode("utf-8"))


def _cache(destino: Path, identidad: dict, medido: dict | None) -> dict:
    manifiesto = json.loads(destino.with_suffix(".manifiesto.json").read_text(encoding="utf-8"))
    if manifiesto.get("identidad") != identidad:
        raise ValueError("La identidad de la caché no coincide con fuentes, parche u opciones")
    huellas = validar_zip(destino)
    if manifiesto.get("zip_sha256") != sha256(destino.read_bytes()):
        raise ValueError("SHA256 del ZIP no coincide con el manifiesto")
    if any(manifiesto.get(clave) != valor for clave, valor in huellas.items()):
        raise ValueError("SHA256 de los archivos no coincide con el manifiesto")
    if manifiesto.get("origen") == "importado" and (
        medido is None or medido.get("zip_sha256") != manifiesto["zip_sha256"]
        or medido.get("wasm_sha256") != manifiesto["wasm_sha256"]
        or medido.get("receta_sha256") != receta_sha256(identidad)
    ):
        raise ValueError("La caché importada no coincide con la plantilla local medida")
    return manifiesto


def _publicar(origen: Path, destino: Path, manifiesto: dict) -> None:
    destino.parent.mkdir(parents=True, exist_ok=True)
    nombre = f".plantilla-{uuid.uuid4().hex}"
    zip_nuevo = destino.parent / f"{nombre}.zip"
    manifest_nuevo = destino.parent / f"{nombre}.json"
    # Publicar el manifiesto al final: una interrupción invalida la pareja, nunca la acepta.
    # Crear archivos en la carpeta pública: TemporaryDirectory restringe la DACL en Windows.
    try:
        with origen.open("rb") as entrada, zip_nuevo.open("xb") as salida:
            shutil.copyfileobj(entrada, salida)
        manifiesto["zip_sha256"] = sha256(zip_nuevo.read_bytes())
        with manifest_nuevo.open("x", encoding="utf-8") as salida:
            salida.write(json.dumps(manifiesto, indent=2) + "\n")
        os.replace(zip_nuevo, destino)
        os.replace(manifest_nuevo, destino.with_suffix(".manifiesto.json"))
    finally:
        zip_nuevo.unlink(missing_ok=True)
        manifest_nuevo.unlink(missing_ok=True)


def preparar(
    metadata: Path, destino: Path, desde: Path | None = None, comprobar: bool = False,
    raiz: Path = RAIZ, jobs: int = 4,
) -> dict:
    datos, parche, identidad = _identidad(metadata, raiz)
    _validar_preset(raiz, destino)
    if jobs < 1:
        raise ValueError("jobs debe ser positivo")
    if comprobar and desde is not None:
        raise ValueError("--comprobar no importa ni construye una plantilla")
    (raiz / "build").mkdir(exist_ok=True)
    (raiz / "build/.gdignore").write_text("", encoding="utf-8")
    if desde is None:
        try:
            manifiesto = _cache(destino, identidad, datos.get("plantilla_local"))
            print(f"Plantilla verificada: {destino}", flush=True)
            return manifiesto
        except (ValueError, OSError, KeyError, json.JSONDecodeError) as error:
            if comprobar:
                raise ValueError(f"Caché inválida: {error}") from error
            print(f"Preparando plantilla; caché no reutilizable: {error}", flush=True)
    if desde is not None:
        origen = desde
        huellas = validar_zip(origen)
        medido = datos.get("plantilla_local")
        if medido is None:
            raise ValueError("Importar requiere SHA256 de plantilla_local medida en metadata")
        if medido.get("receta_sha256") != receta_sha256(identidad):
            raise ValueError("La receta de la plantilla local no coincide con fuentes y parche")
        if (
            medido["zip_sha256"] != sha256(origen.read_bytes())
            or medido["wasm_sha256"] != huellas["wasm_sha256"]
        ):
            raise ValueError("SHA256 de la plantilla local no coincide con el artefacto medido")
    else:
        origen = construir(datos, parche, raiz / "build/godot-web", jobs)
        huellas = validar_zip(origen)
    manifiesto = {
        "identidad": identidad, "receta_sha256": receta_sha256(identidad),
        **huellas, "host": platform.platform(),
        "origen": "importado" if desde is not None else "compilado", "jobs": jobs,
    }
    _publicar(origen, destino, manifiesto)
    print(f"Plantilla preparada: {destino}", flush=True)
    return manifiesto


def verificar_export(carpeta: Path, plantilla: Path) -> None:
    huellas = validar_zip(plantilla)
    for nombre, clave in (("index.wasm", "wasm_sha256"), ("index.js", "js_sha256")):
        try:
            coincide = sha256((carpeta / nombre).read_bytes()) == huellas[clave]
        except OSError as error:
            raise ValueError(f"Falta archivo de exportación: {nombre}") from error
        if not coincide:
            raise ValueError(f"La exportación {nombre} no coincide con la plantilla preparada")
    print(f"Motor de la exportación verificado: {carpeta}", flush=True)


def _descargar(url: str, archivo: Path, esperado: str) -> None:
    if not archivo.exists():
        print(f"Descargando {url}", flush=True)
        archivo.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="descarga-", dir=archivo.parent) as temporal:
            nuevo = Path(temporal) / "fuente.zip"
            with urllib.request.urlopen(url, timeout=120) as respuesta, nuevo.open("wb") as salida:
                shutil.copyfileobj(respuesta, salida)
            if sha256(nuevo.read_bytes()) != esperado:
                raise ValueError("SHA256 de la descarga no coincide con metadata")
            os.replace(nuevo, archivo)
    if sha256(archivo.read_bytes()) != esperado:
        raise ValueError(f"SHA256 del archivo fuente no coincide: {archivo}")


def _extraer(archivo: Path, destino: Path) -> None:
    destino.mkdir(parents=True, exist_ok=False)
    with zipfile.ZipFile(archivo) as paquete:
        if paquete.testzip() is not None:
            raise ValueError("CRC del archivo fuente inválido")
        raices = {PurePosixPath(nombre).parts[0] for nombre in paquete.namelist()}
        if len(raices) != 1:
            raise ValueError("Archivo fuente sin raíz única")
        for entrada in paquete.infolist():
            ruta = PurePosixPath(entrada.filename)
            modo = entrada.external_attr >> 16
            if ruta.is_absolute() or ".." in ruta.parts or stat.S_ISLNK(modo):
                raise ValueError("Ruta insegura en archivo fuente")
            relativa = Path(*ruta.parts[1:])
            salida = destino / relativa
            if not salida.resolve().is_relative_to(destino.resolve()):
                raise ValueError("Ruta fuente fuera del directorio de preparación")
            if entrada.is_dir():
                salida.mkdir(parents=True, exist_ok=True)
            else:
                salida.parent.mkdir(parents=True, exist_ok=True)
                salida.write_bytes(paquete.read(entrada))
                if os.name != "nt" and modo & 0o111:
                    salida.chmod(modo & 0o777)


def _ejecutar(args: list[str], carpeta: Path, log: Path, entorno: dict | None = None) -> None:
    print("Ejecutando: " + " ".join(args), flush=True)
    with log.open("ab") as salida:
        proceso = subprocess.Popen(args, cwd=carpeta, env=entorno, stdout=salida,
                                   stderr=subprocess.STDOUT)
        while True:
            try:
                proceso.wait(timeout=5)
                break
            except subprocess.TimeoutExpired:
                print(f"Proceso {proceso.pid} en marcha; log: {log}", flush=True)
    if proceso.returncode:
        raise subprocess.CalledProcessError(proceso.returncode, args)


def _entorno_sdk(sdk: Path, jobs: int) -> dict:
    entorno = os.environ.copy()
    config = sdk / ".emscripten"
    anterior = os.environ.get("EM_CONFIG")
    try:
        os.environ["EM_CONFIG"] = str(config)
        herramientas = runpy.run_path(str(config))
    finally:
        if anterior is None:
            os.environ.pop("EM_CONFIG", None)
        else:
            os.environ["EM_CONFIG"] = anterior
    node = herramientas["NODE_JS"]
    node = node[0] if isinstance(node, list) else node
    rutas = [sdk, Path(herramientas["EMSCRIPTEN_ROOT"]), Path(herramientas["LLVM_ROOT"]),
             Path(node).parent]
    if "PYTHON" in herramientas:
        rutas.append(Path(herramientas["PYTHON"]).parent)
    entorno.update({
        "EMSDK": str(sdk), "EM_CONFIG": str(config), "EMSDK_NODE": str(node),
        "EMSDK_PYTHON": sys.executable, "EMCC_CORES": str(jobs), "EMSDK_QUIET": "1",
        "PATH": os.pathsep.join(map(str, rutas)) + os.pathsep + entorno.get("PATH", ""),
    })
    return entorno


def _comprobar_huellas(motor: Path, archivos: dict, estado: str) -> None:
    for ruta, huellas in archivos.items():
        if sha256((motor / ruta).read_bytes()) != huellas[f"{estado}_sha256"]:
            raise ValueError(f"SHA256 del archivo {estado} no coincide: {ruta}")


def _aplicar_parche(datos: dict, parche: Path, motor: Path, log: Path) -> None:
    _comprobar_huellas(motor, datos["archivos"], "original")
    entorno_git = os.environ.copy()
    # Los ZIP no traen .git: impedir que git descubra el repositorio padre del juego.
    entorno_git["GIT_CEILING_DIRECTORIES"] = str(motor.parent.resolve())
    # Un core.autocrlf global de Windows no debe reescribir las fuentes extraídas del ZIP.
    comando = ["git", "-c", "core.autocrlf=false", "apply"]
    _ejecutar([*comando, "--check", str(parche)], motor, log, entorno_git)
    _ejecutar([*comando, str(parche)], motor, log, entorno_git)
    _comprobar_huellas(motor, datos["archivos"], "modificado")


def construir(datos: dict, parche: Path, trabajo: Path, jobs: int) -> Path:
    trabajo.mkdir(parents=True, exist_ok=True)
    commit, sdk_version = datos["commit_del_motor"], datos["emscripten"]
    fuente, sdk_zip = trabajo / "godot.zip", trabajo / "emsdk.zip"
    _descargar(f"https://codeload.github.com/godotengine/godot/zip/{commit}",
               fuente, datos["fuente_zip_sha256"])
    _descargar(f"https://codeload.github.com/emscripten-core/emsdk/zip/refs/tags/{sdk_version}",
               sdk_zip, datos["emsdk_zip_sha256"])
    # Cada intento usa fuentes recién extraídas; ningún build parcial aplica dos veces el parche.
    with tempfile.TemporaryDirectory(prefix="compilacion-", dir=trabajo) as temporal:
        motor, sdk = Path(temporal) / "motor", Path(temporal) / "emsdk"
        _extraer(fuente, motor)
        _extraer(sdk_zip, sdk)
        log = trabajo / "compilacion.log"
        _aplicar_parche(datos, parche, motor, log)
        sdk_script = str(sdk / "emsdk.py")
        _ejecutar([sys.executable, sdk_script, "install", sdk_version], sdk, log)
        _ejecutar([sys.executable, sdk_script, "activate", sdk_version, "--embedded"], sdk, log)
        entorno = _entorno_sdk(sdk, jobs)
        version = (sdk / "upstream/emscripten/emscripten-version.txt").read_text(
            encoding="utf-8"
        ).strip('"\n ')
        if version != sdk_version:
            raise ValueError("Versión de Emscripten instalada distinta de metadata")
        virtual = Path(temporal) / "venv"
        venv.EnvBuilder(with_pip=True).create(virtual)
        python = virtual / ("Scripts/python.exe" if os.name == "nt" else "bin/python")
        _ejecutar([str(python), "-m", "pip", "install", "--disable-pip-version-check",
                   f"scons=={datos['scons']}"], motor, log, entorno)
        _ejecutar([str(python), "-m", "SCons", *datos["opciones"], f"-j{jobs}"],
                   motor, log, entorno)
        candidatos = list((motor / "bin").glob("godot.web.template_release*.zip"))
        if len(candidatos) != 1:
            raise ValueError("La compilación no produjo una única plantilla release")
        validar_zip(candidatos[0])
        resultado = trabajo / "compilada.zip"
        shutil.copyfile(candidatos[0], resultado)
        return resultado


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--metadata", type=Path, default=METADATA)
    parser.add_argument("--destino", type=Path, default=DESTINO)
    parser.add_argument("--desde", type=Path)
    parser.add_argument("--jobs", type=int, default=4)
    parser.add_argument("--comprobar", action="store_true")
    parser.add_argument("--verificar-export", type=Path)
    args = parser.parse_args()
    try:
        preparar(args.metadata.resolve(), args.destino.resolve(), args.desde,
                 args.comprobar or args.verificar_export is not None, jobs=args.jobs)
        if args.verificar_export is not None:
            verificar_export(args.verificar_export, args.destino)
    except (ValueError, OSError, KeyError, configparser.Error,
            subprocess.CalledProcessError) as error:
        print(f"No se preparó la plantilla web: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
