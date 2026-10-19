from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import platform
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import urllib.request
import uuid
import venv
import zipfile


RAIZ = Path(__file__).resolve().parents[2]
METADATA = Path(".github/patches/godot-native-compilacion.json")
DOCKERFILE = Path(".github/containers/godot-native/Dockerfile")
PLATAFORMAS = ("linux-x86_64", "windows-x86_64")
MANIFIESTO = "manifiesto.json"


def sha256(archivo: Path) -> str:
    with archivo.open("rb") as entrada:
        return hashlib.file_digest(entrada, "sha256").hexdigest()


def _texto_lf(archivo: Path) -> bytes:
    return archivo.read_bytes().replace(b"\r\n", b"\n")


def _digest(datos: bytes) -> str:
    return hashlib.sha256(datos).hexdigest()


def _json(datos: dict) -> bytes:
    return json.dumps(datos, sort_keys=True, separators=(",", ":")).encode("utf-8")


def _guardar(ruta: Path, datos: dict) -> None:
    ruta.write_text(json.dumps(datos, indent=2) + "\n", encoding="utf-8")


def plataforma_actual() -> str:
    if platform.machine().lower() not in ("amd64", "x86_64"):
        raise ValueError("el editor nativo sólo tiene perfiles x86_64")
    nombres = {"Linux": "linux-x86_64", "Windows": "windows-x86_64"}
    try:
        return nombres[platform.system()]
    except KeyError as error:
        raise ValueError("el editor nativo sólo tiene perfiles Linux y Windows") from error


def _relativa(nombre: str) -> PurePosixPath:
    ruta = PurePosixPath(nombre)
    if (
        not nombre or "\\" in nombre or ":" in nombre or ruta.is_absolute()
        or any(ord(letra) < 32 for letra in nombre)
        or any(parte in (".", "..") for parte in nombre.split("/"))
        or ruta.as_posix() != nombre
    ):
        raise ValueError(f"ruta de artefacto no válida: {nombre!r}")
    return ruta


def _archivo(carpeta: Path, nombre: str) -> Path:
    relativa = _relativa(nombre)
    actual = carpeta
    if carpeta.is_symlink():
        raise ValueError("el directorio de artefacto no puede ser un enlace")
    for parte in relativa.parts:
        actual /= parte
        if actual.is_symlink():
            raise ValueError(f"el artefacto no admite enlaces: {nombre}")
    if not actual.resolve().is_relative_to(carpeta.resolve()):
        raise ValueError("el archivo sale del directorio del artefacto")
    return actual


def _receta(raiz: Path, plataforma: str) -> tuple[dict, Path]:
    if plataforma not in PLATAFORMAS:
        raise ValueError(f"plataforma no soportada: {plataforma}")
    metadata = raiz / METADATA
    datos = json.loads(metadata.read_text(encoding="utf-8"))
    version = (raiz / ".godot-version").read_text(encoding="utf-8").strip()
    if datos["formato"] != 1 or datos["version_del_motor"] != version:
        raise ValueError("la receta nativa no coincide con .godot-version o su formato")
    if not re.fullmatch(r"[0-9a-f]{40}", datos["commit_del_motor"]):
        raise ValueError("el commit del motor no es una referencia completa")
    for nombre in ("fuente_zip_sha256", "parche_sha256"):
        if not re.fullmatch(r"[0-9a-f]{64}", datos[nombre]):
            raise ValueError(f"hash no válido en receta: {nombre}")
    parche = _archivo(metadata.parent, datos["parche"])
    if _digest(_texto_lf(parche)) != datos["parche_sha256"]:
        raise ValueError("el hash del parche no coincide con la receta")
    modificados = {
        linea.removeprefix("+++ b/")
        for linea in _texto_lf(parche).decode("utf-8").splitlines()
        if linea.startswith("+++ b/")
    }
    if modificados != set(datos["archivos"]) or not modificados:
        raise ValueError("el parche y los archivos de la receta difieren")
    for nombre, huellas in datos["archivos"].items():
        _relativa(nombre)
        for clave in ("original_sha256", "modificado_sha256"):
            if not re.fullmatch(r"[0-9a-f]{64}", huellas[clave]):
                raise ValueError(f"hash de fuente no válido: {nombre}")
    if not re.fullmatch(r"[a-z0-9_]+", datos["build_name"]):
        raise ValueError("build_name no válido")
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", datos["scons"]):
        raise ValueError("versión de SCons no válida")
    epoch = datos["source_date_epoch"]
    if isinstance(epoch, bool) or not isinstance(epoch, int) or epoch < 0:
        raise ValueError("SOURCE_DATE_EPOCH debe ser un entero no negativo")
    perfil = datos["plataformas"][plataforma]
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", perfil["version_compilador"]):
        raise ValueError("versión del compilador no válida")
    return datos, parche


def identidad(raiz: Path, plataforma: str) -> dict:
    datos, parche = _receta(raiz, plataforma)
    entradas = {
        "formato": 1,
        "plataforma": plataforma,
        "receta_sha256": _digest(_texto_lf(raiz / METADATA)),
        "parche_sha256": _digest(_texto_lf(parche)),
        "preparador_sha256": _digest(_texto_lf(Path(__file__))),
        "dockerfile_sha256": _digest(_texto_lf(raiz / DOCKERFILE)),
    }
    return {
        "receta_sha256": _digest(_json(entradas)),
        "plataforma": plataforma,
        "version_del_motor": datos["version_del_motor"],
        "build_name": datos["build_name"],
        "opciones": datos["opciones_comunes"] + datos["plataformas"][plataforma]["opciones"],
        "toolchain": {
            "compilador": datos["plataformas"][plataforma]["compilador"],
            "version_compilador": datos["plataformas"][plataforma]["version_compilador"],
            "scons": datos["scons"],
        },
        "entradas": entradas,
    }


def _cabecera_y_marca(archivo: Path, plataforma: str, marca: str) -> None:
    with archivo.open("rb") as entrada:
        cabecera = entrada.read(64)
        if plataforma == "linux-x86_64":
            if (
                len(cabecera) < 20 or cabecera[:6] != b"\x7fELF\x02\x01"
                or int.from_bytes(cabecera[18:20], "little") != 62
            ):
                raise ValueError("el binario Linux no es ELF x86_64")
        else:
            if len(cabecera) < 64 or cabecera[:2] != b"MZ":
                raise ValueError("el binario Windows no es PE x86_64")
            entrada.seek(int.from_bytes(cabecera[60:64], "little"))
            pe = entrada.read(6)
            if pe[:4] != b"PE\0\0" or pe[4:6] != b"\x64\x86":
                raise ValueError("el binario Windows no es PE x86_64")
        entrada.seek(0)
        buscada = marca.encode("ascii")
        cola = b""
        while bloque := entrada.read(1024 * 1024):
            if buscada in cola + bloque:
                return
            cola = bloque[-len(buscada):]
    raise ValueError("el ejecutable no contiene la identidad del build nativo corregido")


def validar(carpeta: Path, raiz: Path, plataforma: str | None = None) -> dict:
    plataforma = plataforma or plataforma_actual()
    esperado = identidad(raiz, plataforma)
    ruta = _archivo(carpeta, MANIFIESTO)
    datos = json.loads(ruta.read_text(encoding="utf-8"))
    if datos.get("formato") != 1:
        raise ValueError("formato de manifiesto no soportado")
    if datos["receta_sha256"] != esperado["receta_sha256"]:
        raise ValueError("la receta del motor preparado no coincide con la actual")
    if datos["plataforma"] != plataforma:
        raise ValueError("la plataforma del motor preparado no coincide")
    archivos = datos["archivos"]
    entrada = datos["entrypoint"]
    if not isinstance(archivos, dict) or not archivos or entrada not in archivos:
        raise ValueError("el manifiesto no contiene su ejecutable de entrada")
    for nombre, huella in archivos.items():
        if nombre == MANIFIESTO or not re.fullmatch(r"[0-9a-f]{64}", huella):
            raise ValueError("huella de archivo no válida en manifiesto")
        archivo = _archivo(carpeta, nombre)
        if not archivo.is_file() or sha256(archivo) != huella:
            raise ValueError(f"SHA256 del archivo preparado no coincide: {nombre}")
    presentes = {
        ruta.relative_to(carpeta).as_posix()
        for ruta in carpeta.rglob("*") if ruta.is_file() or ruta.is_symlink()
    }
    if presentes != set(archivos) | {MANIFIESTO}:
        raise ValueError("hay archivos del artefacto fuera del manifiesto")
    if datos["binario_sha256"] != archivos[entrada]:
        raise ValueError("el hash del ejecutable de entrada no coincide")
    for campo, valor in esperado["toolchain"].items():
        if datos["toolchain"].get(campo) != valor:
            raise ValueError(f"el toolchain del motor no coincide: {campo}")
    prefijo = esperado["version_del_motor"].replace("-", ".") + "." + esperado["build_name"]
    if datos["version"] != prefijo and not datos["version"].startswith(prefijo + "."):
        raise ValueError("la versión del motor no identifica el build corregido")
    binario = _archivo(carpeta, entrada)
    if plataforma == "linux-x86_64":
        _cabecera_y_marca(binario, plataforma, esperado["build_name"])
    else:
        ejecutables = [nombre for nombre in archivos if nombre.endswith(".exe")]
        reales = [nombre for nombre in ejecutables if not nombre.endswith(".console.exe")]
        if not entrada.endswith(".console.exe") or len(reales) != 1:
            raise ValueError("Windows requiere entrada de consola y un ejecutable real")
        _cabecera_y_marca(_archivo(carpeta, reales[0]), plataforma, esperado["build_name"])
        _cabecera_y_marca(binario, plataforma, "")
    return datos | {"binario": str(binario.resolve())}


def validar_binario(binario: Path, raiz: Path) -> dict:
    if binario.is_symlink():
        raise ValueError("el ejecutable preparado no puede ser un enlace")
    datos = validar(binario.parent, raiz)
    if binario.resolve() != Path(datos["binario"]):
        raise ValueError("el ejecutable no es el entrypoint validado del manifiesto")
    return datos


def _descargar(url: str, archivo: Path, huella: str) -> None:
    if archivo.exists():
        if sha256(archivo) != huella:
            raise ValueError(f"SHA256 de descarga existente no coincide: {archivo}")
        return
    archivo.parent.mkdir(parents=True, exist_ok=True)
    temporal = archivo.with_name(f".{archivo.name}-{uuid.uuid4().hex}")
    try:
        with urllib.request.urlopen(url, timeout=120) as entrada, temporal.open("xb") as salida:
            shutil.copyfileobj(entrada, salida)
        if sha256(temporal) != huella:
            raise ValueError("SHA256 de fuente descargada no coincide con la receta")
        os.replace(temporal, archivo)
    finally:
        temporal.unlink(missing_ok=True)


def _extraer(archivo: Path, destino: Path) -> None:
    if destino.exists():
        raise ValueError("la extracción requiere un directorio nuevo")
    with zipfile.ZipFile(archivo) as paquete:
        nombres = paquete.namelist()
        if len(nombres) != len(set(nombres)) or paquete.testzip() is not None:
            raise ValueError("archivo fuente con duplicados o CRC inválido")
        raices = {PurePosixPath(nombre).parts[0] for nombre in nombres if nombre}
        if len(raices) != 1:
            raise ValueError("archivo fuente sin raíz única")
        for info in paquete.infolist():
            nombre = info.orig_filename.rstrip("/")
            ruta = _relativa(nombre)
            if stat.S_ISLNK(info.external_attr >> 16):
                raise ValueError("el ZIP fuente no admite enlaces")
            if len(ruta.parts) == 1 and not info.is_dir():
                raise ValueError("el ZIP fuente contiene un archivo fuera de su raíz")
        destino.mkdir(parents=True)
        for info in paquete.infolist():
            relativa = PurePosixPath(info.filename).parts[1:]
            if not relativa:
                continue
            salida = destino.joinpath(*relativa)
            if info.is_dir():
                salida.mkdir(parents=True, exist_ok=True)
            else:
                salida.parent.mkdir(parents=True, exist_ok=True)
                with paquete.open(info) as entrada, salida.open("xb") as archivo_salida:
                    shutil.copyfileobj(entrada, archivo_salida)
                if os.name != "nt" and info.external_attr >> 16 & 0o111:
                    salida.chmod(info.external_attr >> 16 & 0o777)


def _ejecutar(comando: list[str], carpeta: Path, log: Path, entorno: dict) -> None:
    print("Ejecutando " + " ".join(comando), file=sys.stderr, flush=True)
    with log.open("ab") as salida:
        proceso = subprocess.Popen(
            comando, cwd=carpeta, env=entorno, stdout=salida, stderr=subprocess.STDOUT
        )
        while True:
            try:
                codigo = proceso.wait(timeout=10)
                break
            except subprocess.TimeoutExpired:
                print(f"Compilación en marcha. Log {log}", file=sys.stderr, flush=True)
    if codigo:
        raise subprocess.CalledProcessError(codigo, comando)


def _validar_fuentes_zip(fuente: Path, archivo: Path, datos: dict) -> None:
    if sha256(archivo) != datos["fuente_zip_sha256"]:
        raise ValueError("el ZIP de procedencia de las fuentes no coincide con la receta")
    with zipfile.ZipFile(archivo) as paquete:
        for info in paquete.infolist():
            if info.is_dir():
                continue
            nombre = PurePosixPath(info.filename).relative_to(
                PurePosixPath(info.filename).parts[0]
            ).as_posix()
            if nombre in datos["archivos"]:
                huella = datos["archivos"][nombre]["modificado_sha256"]
            else:
                with paquete.open(info) as original:
                    huella = hashlib.file_digest(original, "sha256").hexdigest()
            if sha256(_archivo(fuente, nombre)) != huella:
                raise ValueError(f"el árbol incremental modificó una fuente original: {nombre}")


def _fuentes(datos: dict, parche: Path, trabajo: Path, log: Path) -> Path:
    fuente_zip = trabajo / "godot.zip"
    _descargar(
        f"https://codeload.github.com/godotengine/godot/zip/{datos['commit_del_motor']}",
        fuente_zip, datos["fuente_zip_sha256"],
    )
    fuente = trabajo / "source"
    marca = trabajo / "fuentes.json"
    identidad_fuente = {
        clave: datos[clave]
        for clave in ("commit_del_motor", "fuente_zip_sha256", "parche_sha256")
    }
    if fuente.exists():
        if not marca.exists() or json.loads(marca.read_text()) != identidad_fuente:
            raise ValueError("fuentes incrementales sin procedencia compatible")
    else:
        _extraer(fuente_zip, fuente)
        for nombre, huellas in datos["archivos"].items():
            if sha256(_archivo(fuente, nombre)) != huellas["original_sha256"]:
                raise ValueError(f"fuente original no coincide: {nombre}")
        entorno = dict(os.environ, GIT_CEILING_DIRECTORIES=str(fuente.parent.resolve()))
        comando = ["git", "-c", "core.autocrlf=false", "apply"]
        _ejecutar([*comando, "--check", str(parche.resolve())], fuente, log, entorno)
        _ejecutar([*comando, str(parche.resolve())], fuente, log, entorno)
        _guardar(marca, identidad_fuente)
    for nombre, huellas in datos["archivos"].items():
        if sha256(_archivo(fuente, nombre)) != huellas["modificado_sha256"]:
            raise ValueError(f"fuente parcheada no coincide: {nombre}")
    _validar_fuentes_zip(fuente, fuente_zip, datos)
    return fuente


def _scons(trabajo: Path, version: str, log: Path, entorno: dict) -> Path:
    virtual = trabajo / f"scons-{version}"
    python = virtual / ("Scripts/python.exe" if os.name == "nt" else "bin/python")
    if not python.exists():
        venv.EnvBuilder(with_pip=True).create(virtual)
    comprobacion = subprocess.run(
        [str(python), "-c",
         "import importlib.metadata; print(importlib.metadata.version('SCons'))"],
        capture_output=True, text=True, env=entorno,
    )
    if comprobacion.returncode or comprobacion.stdout.strip() != version:
        _ejecutar(
            [str(python), "-m", "pip", "install", "--disable-pip-version-check",
             f"SCons=={version}"],
            trabajo, log, entorno,
        )
    return python


def _toolchain(datos: dict, plataforma: str) -> dict:
    perfil = datos["plataformas"][plataforma]
    version = subprocess.check_output(
        [perfil["compilador"], "-dumpfullversion", "-dumpversion"], text=True
    ).strip()
    reportada = version
    evidencia = {}
    esperada = perfil["version_compilador"]
    if (
        version != esperada and plataforma == "windows-x86_64"
        and platform.system() == "Linux"
        and version == esperada.split(".", 1)[0] + "-posix"
    ):
        localizado = shutil.which(perfil["compilador"])
        if not localizado:
            raise ValueError("no se puede resolver el compilador MinGW para verificar su paquete")
        archivo = Path(localizado).resolve(strict=True)
        paquete = "g++-mingw-w64-x86-64-posix"
        propietario = subprocess.check_output(
            ["dpkg-query", "-S", str(archivo)], text=True
        ).splitlines()
        if propietario != [f"{paquete}: {archivo}"]:
            raise ValueError("el compilador MinGW no tiene un único propietario de paquete permitido")
        version_paquete = subprocess.check_output(
            ["dpkg-query", "-W", "-f=${Version}", paquete], text=True
        ).strip()
        if not version_paquete.startswith(esperada + "-"):
            raise ValueError("la versión del paquete MinGW no coincide con la receta")
        verificacion = subprocess.run(
            ["dpkg", "--verify", paquete], capture_output=True, text=True, check=True
        )
        if verificacion.stdout.strip() or verificacion.stderr.strip():
            raise ValueError("el paquete MinGW contiene archivos modificados o no verificables")
        version = version_paquete.split("-", 1)[0]
        evidencia = {
            "paquete_compilador": {
                "nombre": paquete, "version": version_paquete, "archivo": str(archivo),
            },
        }
    if version != esperada:
        raise ValueError(f"compilador no compatible: esperado {esperada}, {version}")
    return {
        "compilador": perfil["compilador"], "version_compilador": version,
        "version_reportada": reportada, "scons": datos["scons"],
        "host": platform.platform(), **evidencia,
    }

def _version_generada(fuente: Path, datos: dict) -> str:
    texto = (fuente / "core/version_generated.gen.h").read_text(encoding="utf-8")
    macros = dict(re.findall(r'^#define GODOT_VERSION_(\w+) (.+)$', texto, re.MULTILINE))
    version = ".".join(macros[clave].strip('"') for clave in (
        "MAJOR", "MINOR", "PATCH", "STATUS", "BUILD"
    ))
    esperado = datos["version_del_motor"].replace("-", ".") + "." + datos["build_name"]
    if version != esperado:
        raise ValueError("la cabecera generada no identifica la versión y el build requeridos")
    return version


def _destino_publicable(destino: Path, nuevos: set[str]) -> tuple[Path, set[str]]:
    destino = destino.absolute()
    if any(ruta.is_symlink() for ruta in (destino, *destino.parents)):
        raise ValueError("el destino publicado y sus padres no pueden ser enlaces")
    anteriores = set()
    manifiesto = destino / MANIFIESTO
    if manifiesto.exists():
        try:
            datos = json.loads(manifiesto.read_text(encoding="utf-8"))
            archivos = datos["archivos"]
            if (
                datos["formato"] != 1 or datos["plataforma"] not in PLATAFORMAS
                or not isinstance(archivos, dict) or not archivos
                or datos["entrypoint"] not in archivos
                or datos["binario_sha256"] != archivos[datos["entrypoint"]]
            ):
                raise ValueError("manifiesto anterior no válido")
            for nombre, huella in archivos.items():
                _relativa(nombre)
                if nombre == MANIFIESTO or not re.fullmatch(r"[0-9a-f]{64}", huella):
                    raise ValueError("archivo anterior sin identidad válida")
            anteriores = set(archivos)
        except (ValueError, KeyError, TypeError, OSError):
            anteriores = set()
    presentes = set()
    if destino.exists():
        for ruta in destino.rglob("*"):
            if ruta.is_symlink():
                raise ValueError("el destino publicado contiene enlaces")
            if ruta.is_file():
                presentes.add(ruta.relative_to(destino).as_posix())
    desconocidos = presentes - nuevos - anteriores - {MANIFIESTO}
    if desconocidos:
        raise ValueError(f"el destino contiene archivos ajenos: {sorted(desconocidos)}")
    return destino, anteriores


def publicar(
    fuente: Path, destino: Path, raiz: Path, plataforma: str,
    toolchain: dict, version: str | None = None, fuente_zip: Path | None = None,
) -> dict:
    """Adoptar una salida SCons preservada después de validar fuentes y cabecera generada.

    La llamada sirve al build iniciado manualmente con esta receta. El caller conserva
    el log y la procedencia del toolchain. No ejecuta un PE desde un host Linux.
    """
    datos, _ = _receta(raiz, plataforma)
    esperado = identidad(raiz, plataforma)
    for nombre, huellas in datos["archivos"].items():
        if sha256(_archivo(fuente, nombre)) != huellas["modificado_sha256"]:
            raise ValueError(f"no se puede publicar una fuente sin parche: {nombre}")
    _validar_fuentes_zip(fuente, fuente_zip or fuente.parent / "godot.zip", datos)
    version_generada = _version_generada(fuente, datos)
    if version is not None and version != version_generada and not version.startswith(
        version_generada + "."
    ):
        raise ValueError("la versión ejecutada no coincide con la cabecera de compilación")
    for clave, valor in esperado["toolchain"].items():
        if toolchain.get(clave) != valor:
            raise ValueError(f"procedencia de toolchain no compatible: {clave}")
    origen = fuente / "bin"
    if plataforma == "linux-x86_64":
        ejecutables = [p for p in origen.glob("godot.linuxbsd.editor.x86_64*") if p.is_file()]
        if len(ejecutables) != 1:
            raise ValueError("se esperaba un único editor Linux compilado")
        entrada = f"Godot_v{datos['version_del_motor']}_nosefia_classdb_linux.x86_64"
        distribuir = {entrada: ejecutables[0]}
    else:
        consolas = list(origen.glob("godot.windows.editor.x86_64*.console.exe"))
        if len(consolas) != 1:
            raise ValueError("se esperaba un único editor Windows de consola")
        real = consolas[0].with_name(consolas[0].name.replace(".console.exe", ".exe"))
        if not real.is_file():
            raise ValueError("falta el ejecutable real que requiere la consola Windows")
        entrada = consolas[0].name
        distribuir = {p.name: p for p in (consolas[0], real)}
        for dll in origen.rglob("*.dll"):
            if "build_deps" not in dll.relative_to(origen).parts:
                distribuir[dll.relative_to(origen).as_posix()] = dll
    destino, anteriores = _destino_publicable(destino, set(distribuir))
    destino.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".godot-publicar-", dir=destino.parent) as temporal:
        nuevo = Path(temporal) / "artefacto"
        nuevo.mkdir()
        for nombre, archivo in distribuir.items():
            if archivo.is_symlink():
                raise ValueError("no se distribuyen binarios enlazados")
            salida = _archivo(nuevo, nombre)
            salida.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(archivo, salida)
            if plataforma == "linux-x86_64":
                salida.chmod(salida.stat().st_mode | 0o755)
        huellas = {nombre: sha256(_archivo(nuevo, nombre)) for nombre in distribuir}
        manifiesto = {
            "formato": 1, "receta_sha256": esperado["receta_sha256"],
            "plataforma": plataforma, "entrypoint": entrada,
            "archivos": huellas, "binario_sha256": huellas[entrada],
            "version": version or version_generada,
            "version_origen": "ejecución" if version else "cabecera-generada",
            "toolchain": toolchain,
        }
        _guardar(nuevo / MANIFIESTO, manifiesto)
        validar(nuevo, raiz, plataforma)
        destino.mkdir(parents=True, exist_ok=True)
        (destino / MANIFIESTO).unlink(missing_ok=True)
        for nombre in distribuir:
            salida = _archivo(destino, nombre)
            salida.parent.mkdir(parents=True, exist_ok=True)
            os.replace(_archivo(nuevo, nombre), salida)
        for nombre in anteriores - set(distribuir):
            _archivo(destino, nombre).unlink(missing_ok=True)
        os.replace(nuevo / MANIFIESTO, destino / MANIFIESTO)
    return validar(destino, raiz, plataforma)


def preparar(
    raiz: Path = RAIZ, plataforma: str | None = None, destino: Path | None = None,
    jobs: int = 4, trabajo: Path | None = None,
) -> dict:
    plataforma = plataforma or plataforma_actual()
    if jobs < 1:
        raise ValueError("jobs debe ser positivo")
    destino = destino or raiz / "build/godot-native" / plataforma
    try:
        return validar(destino, raiz, plataforma)
    except (ValueError, OSError, KeyError, TypeError, json.JSONDecodeError) as error:
        print(f"Preparando editor nativo. Caché no reutilizable. {error}", file=sys.stderr)
    datos, parche = _receta(raiz, plataforma)
    identidad(raiz, plataforma)
    toolchain = _toolchain(datos, plataforma)
    trabajo = (trabajo or raiz / "build/godot-native-compilacion" / plataforma).resolve()
    trabajo.mkdir(parents=True, exist_ok=True)
    log = trabajo / "compilacion.log"
    fuente = _fuentes(datos, parche, trabajo, log)
    entorno = dict(
        os.environ, BUILD_NAME=datos["build_name"],
        SOURCE_DATE_EPOCH=str(datos["source_date_epoch"]),
        GIT_CEILING_DIRECTORIES=str(fuente.parent.resolve()),
    )
    python = _scons(trabajo, datos["scons"], log, entorno)
    scripts = ["install_accesskit.py"]
    if plataforma == "windows-x86_64":
        scripts += ["install_winrt.py", "install_d3d12_sdk_windows.py"]
    sdk_identidad = {"fuente": datos["fuente_zip_sha256"], "scripts": scripts}
    sdk_marca = trabajo / "sdk.json"
    if not sdk_marca.exists() or json.loads(sdk_marca.read_text()) != sdk_identidad:
        for script in scripts:
            _ejecutar(
                [str(python), str(fuente / "misc/scripts" / script)], fuente, log, entorno
            )
        _guardar(sdk_marca, sdk_identidad)
    _ejecutar(
        [str(python), "-m", "SCons", *datos["opciones_comunes"],
         *datos["plataformas"][plataforma]["opciones"], f"-j{jobs}"],
        fuente, log, entorno,
    )
    return publicar(fuente, destino, raiz, plataforma, toolchain)


def main(argumentos: list[str] | None = None) -> int:
    for flujo in (sys.stdout, sys.stderr):
        if hasattr(flujo, "reconfigure"):
            flujo.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(
        description="Preparar y verificar el editor nativo que incorpora el lock de ClassDB."
    )
    parser.add_argument("operacion", choices=("identidad", "preparar", "comprobar"))
    parser.add_argument("--plataforma", choices=PLATAFORMAS)
    parser.add_argument("--destino", type=Path)
    parser.add_argument("--trabajo", type=Path)
    parser.add_argument("--jobs", type=int, default=4)
    opciones = parser.parse_args(argumentos)
    try:
        plataforma = opciones.plataforma or plataforma_actual()
        destino = opciones.destino or RAIZ / "build/godot-native" / plataforma
        if opciones.operacion == "identidad":
            datos = identidad(RAIZ, plataforma)
        elif opciones.operacion == "comprobar":
            datos = validar(destino, RAIZ, plataforma)
        else:
            datos = preparar(RAIZ, plataforma, destino, opciones.jobs, opciones.trabajo)
        print(json.dumps(datos, ensure_ascii=False))
    except (ValueError, OSError, KeyError, TypeError, zipfile.BadZipFile,
            subprocess.CalledProcessError) as error:
        print(f"No se preparó el motor nativo. {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
