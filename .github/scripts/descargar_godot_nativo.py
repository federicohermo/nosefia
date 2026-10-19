from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import sys
import tempfile
import urllib.parse
import urllib.request
import uuid
import zipfile

import preparar_godot_nativo as constructor


RAIZ = Path(__file__).resolve().parents[2]
LOCK = Path(".github/patches/godot-native-artefactos.json")


def identidad(raiz: Path, plataforma: str) -> dict:
    datos = json.loads((raiz / LOCK).read_text(encoding="utf-8"))
    if type(datos.get("formato")) is not int or datos["formato"] != 1:
        raise ValueError("formato del lock nativo no soportado")
    artefacto = datos["plataformas"][plataforma]
    for campo in ("receta_sha256", "archivo_sha256", "manifiesto_sha256"):
        if not isinstance(artefacto[campo], str) or not re.fullmatch(
            r"[0-9a-f]{64}", artefacto[campo]
        ):
            raise ValueError(f"SHA256 del lock no válido: {campo}")
    url = urllib.parse.urlsplit(artefacto["url"])
    if (
        url.scheme != "https" or url.netloc != "github.com"
        or url.query or url.fragment
        or not re.fullmatch(
            r"/federicohermo/nosefia/releases/download/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+\.zip",
            url.path,
        )
    ):
        raise ValueError("la descarga debe pertenecer a una release pública del repositorio")
    receta = constructor.identidad(raiz, plataforma)["receta_sha256"]
    if artefacto["receta_sha256"] != receta:
        raise ValueError("el lock no coincide con la receta nativa actual")
    return dict(artefacto, plataforma=plataforma)


def _enlace(ruta: Path) -> bool:
    if ruta.is_symlink():
        return True
    try:
        atributos = getattr(ruta.lstat(), "st_file_attributes", 0)
    except FileNotFoundError:
        return False
    return bool(atributos & 0x400)


def _destino_seguro(destino: Path) -> Path:
    destino = destino.absolute()
    if any(_enlace(ruta) for ruta in (destino, *destino.parents)):
        raise ValueError("el destino y sus padres no pueden ser enlaces")
    if destino.exists() and not destino.is_dir():
        raise ValueError("el destino del motor debe ser un directorio")
    return destino


def comprobar(raiz: Path, plataforma: str, destino: Path) -> dict:
    esperado = identidad(raiz, plataforma)
    destino = _destino_seguro(destino)
    manifiesto = destino / constructor.MANIFIESTO
    if _enlace(manifiesto) or constructor.sha256(manifiesto) != esperado["manifiesto_sha256"]:
        raise ValueError("SHA256 del manifiesto no coincide con el lock")
    return constructor.validar(destino, raiz, plataforma)


def _extraer(archivo: Path, destino: Path, esperado: dict) -> set[str]:
    if constructor.sha256(archivo) != esperado["archivo_sha256"]:
        raise ValueError("SHA256 del archivo descargado no coincide con el lock")
    with zipfile.ZipFile(archivo) as paquete:
        infos = paquete.infolist()
        nombres = set()
        normalizados = set()
        archivos = set()
        for info in infos:
            nombre = info.filename.rstrip("/")
            constructor._relativa(nombre)
            modo = info.external_attr >> 16
            if (
                info.orig_filename != info.filename or nombre.casefold() in normalizados
                or stat.S_ISLNK(modo)
                or stat.S_IFMT(modo) not in (0, stat.S_IFREG, stat.S_IFDIR)
            ):
                raise ValueError("el ZIP contiene duplicados, enlaces o entradas no válidas")
            nombres.add(nombre)
            normalizados.add(nombre.casefold())
            if not info.is_dir():
                archivos.add(nombre)
        if constructor.MANIFIESTO not in archivos:
            raise ValueError("el ZIP no contiene su manifiesto")
        contenido = paquete.read(constructor.MANIFIESTO)
        if hashlib.sha256(contenido).hexdigest() != esperado["manifiesto_sha256"]:
            raise ValueError("SHA256 del manifiesto descargado no coincide con el lock")
        manifiesto = json.loads(contenido)
        declarados = manifiesto["archivos"]
        if not isinstance(declarados, dict) or not declarados:
            raise ValueError("el manifiesto no declara archivos")
        for nombre in declarados:
            constructor._relativa(nombre)
        if archivos != set(declarados) | {constructor.MANIFIESTO}:
            raise ValueError("el ZIP contiene archivos fuera del manifiesto")
        carpetas = {
            padre.as_posix()
            for nombre in archivos
            for padre in PurePosixPath(nombre).parents
            if padre.as_posix() != "."
        }
        if nombres - archivos - carpetas:
            raise ValueError("el ZIP contiene directorios fuera del manifiesto")
        destino.mkdir()
        for nombre in sorted(archivos):
            salida = destino / nombre
            salida.parent.mkdir(parents=True, exist_ok=True)
            with paquete.open(nombre) as entrada, salida.open("xb") as flujo:
                shutil.copyfileobj(entrada, flujo)
            if esperado["plataforma"] == "linux-x86_64" and nombre == manifiesto["entrypoint"]:
                salida.chmod(0o755)
    return archivos


def _inventario(destino: Path, permitidos: set[str]) -> list[Path]:
    _destino_seguro(destino)
    if not destino.exists():
        return []
    rutas = list(destino.rglob("*"))
    carpetas = {
        padre.as_posix()
        for nombre in permitidos
        for padre in PurePosixPath(nombre).parents
        if padre.as_posix() != "."
    }
    for ruta in rutas:
        nombre = ruta.relative_to(destino).as_posix()
        if _enlace(ruta) or (
            ruta.is_dir() and nombre not in carpetas
        ) or (not ruta.is_dir() and (not ruta.is_file() or nombre not in permitidos)):
            raise ValueError("el destino contiene archivos ajenos o enlaces; elegí otro destino vacío")
    return rutas


def descargar(raiz: Path, plataforma: str, destino: Path) -> dict:
    esperado = identidad(raiz, plataforma)
    destino = _destino_seguro(destino)
    try:
        return comprobar(raiz, plataforma, destino)
    except (OSError, ValueError, KeyError, TypeError):
        pass
    destino.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".godot-descarga-", dir=destino.parent) as temporal:
        carpeta = Path(temporal)
        archivo = carpeta / "motor.zip"
        with urllib.request.urlopen(esperado["url"], timeout=120) as entrada, archivo.open("xb") as salida:
            shutil.copyfileobj(entrada, salida)
        nuevo = carpeta / "motor"
        permitidos = _extraer(archivo, nuevo, esperado)
        comprobar(raiz, plataforma, nuevo)
        anteriores = _inventario(destino, permitidos)
        respaldo = destino.with_name(f".{destino.name}-{uuid.uuid4().hex}.anterior")
        if destino.exists():
            os.replace(destino, respaldo)
        try:
            os.replace(nuevo, destino)
        except OSError:
            if respaldo.exists() and not destino.exists():
                os.replace(respaldo, destino)
            raise
        if respaldo.exists():
            _inventario(respaldo, permitidos)
            for ruta in sorted(anteriores, key=lambda p: len(p.parts), reverse=True):
                anterior = respaldo / ruta.relative_to(destino)
                if anterior.is_dir():
                    anterior.rmdir()
                else:
                    anterior.unlink()
            respaldo.rmdir()
    return comprobar(raiz, plataforma, destino)


def main(argumentos: list[str] | None = None) -> int:
    for flujo in (sys.stdout, sys.stderr):
        if hasattr(flujo, "reconfigure"):
            flujo.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(description="Descargar el motor nativo aprobado sin compilar.")
    parser.add_argument("operacion", choices=("identidad", "descargar", "comprobar"))
    parser.add_argument("--plataforma", choices=constructor.PLATAFORMAS)
    parser.add_argument("--destino", type=Path)
    opciones = parser.parse_args(argumentos)
    try:
        plataforma = opciones.plataforma or constructor.plataforma_actual()
        destino = opciones.destino or RAIZ / "build/godot-native" / plataforma
        if opciones.operacion == "identidad":
            datos = identidad(RAIZ, plataforma)
        elif opciones.operacion == "comprobar":
            datos = comprobar(RAIZ, plataforma, destino)
        else:
            datos = descargar(RAIZ, plataforma, destino)
        print(json.dumps(datos, ensure_ascii=False))
    except (OSError, ValueError, KeyError, TypeError, zipfile.BadZipFile) as error:
        print(f"No se obtuvo el motor nativo aprobado. {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
