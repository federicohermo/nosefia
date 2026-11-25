import argparse
from collections.abc import Mapping
from dataclasses import asdict, dataclass
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / ".claude/scripts"))
from lib.godot import validar_motor


IMPORTADORES = {"assets/models/importar_modelo.gd", "assets/models/importar_caja.gd"}
IMPORTADOR_DE_CAJAS = "assets/models/importar_caja.gd"
MATERIAL = "src/escenas/puestos/vidrio_del_local.tres"
EXCLUIDOS = {".github", ".claude", ".agents", "docs", "reports", "specs", "tools"}
MANIFIESTO_IMPORTS = ".huellas-import.json"
_PREFIJO_HASH_IMPORT = re.compile(r"^(.+-[0-9a-f]{32})\.")


@dataclass(frozen=True)
class IdentidadImportacion:
    key: str
    cacheable: bool
    motivo: str
    entradas: int
    motor: str
    sistema: str
    arquitectura: str
    receta_motor_sha256: str
    binario_motor_sha256: str
    artefacto_motor_sha256: str
    alcance: str = "recursos"
    prefijo: str = ""


def archivos_versionados(raiz: Path) -> list[str]:
    salida = subprocess.check_output(["git", "ls-files", "-z"], cwd=raiz)
    return sorted(salida.decode("utf-8").split("\0")[:-1])


def configuracion_importacion(ruta: Path) -> tuple[str, list[str]]:
    texto = ruta.read_text(encoding="utf-8")
    script = re.search(r'^\s*import_script/path\s*=\s*"([^"]*)"\s*$', texto, re.MULTILINE)
    if "import_script/path" in texto and not script:
        raise ValueError(f"opciones del importador no reconocidas: {ruta}")
    destinos = re.search(r"^\s*dest_files\s*=\s*\[(.*?)\]\s*$", texto, re.MULTILINE)
    return (
        script.group(1).removeprefix("res://") if script else "",
        re.findall(r'"([^"]*)"', destinos.group(1)) if destinos else [],
    )


def identidad(
    raiz: Path, sistema: str, arquitectura: str, motor_nativo: dict,
) -> IdentidadImportacion:
    receta = motor_nativo["receta_sha256"]
    binario = motor_nativo["binario_sha256"]
    artefacto = hashlib.sha256(json.dumps(
        motor_nativo["archivos"], sort_keys=True, separators=(",", ":"),
    ).encode("utf-8")).hexdigest()
    if not all(re.fullmatch(r"[0-9a-f]{64}", valor) for valor in (receta, binario)):
        raise ValueError("La identidad del motor nativo requiere receta y binario SHA256")
    nombres = archivos_versionados(raiz)
    seleccion = []
    motivo = "importadores auditados y recursos cubiertos"
    for nombre in nombres:
        ruta = PurePosixPath(nombre)
        if not nombre.endswith(".import") and (ruta.parts[0] in EXCLUIDOS or nombre.endswith(".md")):
            continue
        if ruta.parts[0] in {"src", "test"} and nombre.endswith((".gd", ".gd.uid")):
            continue
        seleccion.append(nombre)
        if nombre.endswith(".import") and nombre[:-7] in nombres:
            seleccion.append(nombre[:-7])
    seleccion = sorted(set(seleccion))
    for nombre in seleccion:
        ruta = raiz / nombre
        if ruta.is_symlink():
            motivo = f"entrada enlazada no soportada: {nombre}"
            break
        if nombre.endswith(".import"):
            script, destinos = configuracion_importacion(ruta)
            if script and script not in IMPORTADORES:
                motivo = f"importador sin auditar: {script}"
                break
            if script == IMPORTADOR_DE_CAJAS:
                if not destinos:
                    motivo = f"salidas de importación no reconocidas: {nombre}"
                    break
                try:
                    for destino in destinos:
                        destino_privado(raiz, destino)
                except ValueError:
                    motivo = f"salidas de importación fuera del directorio privado: {nombre}"
                    break
        if nombre.endswith(".gd") and re.search(
            r"\b(?:EditorImportPlugin|add_import_plugin)\b", ruta.read_text(encoding="utf-8")
        ):
            motivo = f"EditorImportPlugin no soportado: {nombre}"
            break
    else:
        material = (raiz / MATERIAL).read_text(encoding="utf-8")
        referencias = re.findall(r'res://([^"\s]+)', material)
        if re.search(r'type\s*=\s*"(?:Script|GDScript|CSharpScript)"', material) or any(
            ref.endswith((".gd", ".tres", ".res")) or ref not in seleccion
            for ref in referencias
        ):
            motivo = "dependencia del material importado sin auditar"
        else:
            motivo = ""
    motor = (raiz / ".godot-version").read_text(encoding="utf-8").strip()
    if motivo:
        return IdentidadImportacion(
            "", False, motivo, len(seleccion), motor, sistema, arquitectura,
            receta, binario, artefacto,
        )
    huella = hashlib.sha256()
    for valor in ("importaciones-v3", sistema, arquitectura, motor, receta, binario, artefacto):
        datos = valor.encode("utf-8")
        huella.update(len(datos).to_bytes(8, "big") + datos)
    huella.update(hashlib.sha256(Path(__file__).read_bytes()).digest())
    for nombre in (*sorted(IMPORTADORES), MATERIAL):
        huella.update(hashlib.sha256((raiz / nombre).read_bytes()).digest())
    prefijo = f"godot-importaciones-v3-{huella.hexdigest()}"
    for nombre in seleccion:
        archivo = raiz / nombre
        ruta = nombre.encode("utf-8")
        huella.update(len(ruta).to_bytes(8, "big") + ruta)
        huella.update(archivo.stat().st_size.to_bytes(8, "big"))
        with archivo.open("rb") as entrada:
            huella.update(hashlib.file_digest(entrada, "sha256").digest())
    return IdentidadImportacion(
        f"{prefijo}-{huella.hexdigest()}", True,
        "importadores auditados y recursos cubiertos", len(seleccion),
        motor, sistema, arquitectura, receta, binario, artefacto, prefijo=prefijo,
    )


def destino_privado(raiz: Path, destino: str) -> Path:
    prefijo = "res://.godot/imported/"
    nombre = destino.removeprefix(prefijo)
    if not destino.startswith(prefijo) or not nombre or "\\" in nombre or "/" in nombre or nombre in {".", ".."}:
        raise ValueError(f"destino de importación fuera del directorio privado: {destino}")
    carpeta = raiz / ".godot" / "imported"
    if (
        carpeta.is_symlink() or carpeta.parent.is_symlink()
        or not carpeta.resolve().is_relative_to(raiz.resolve())
    ):
        raise ValueError("el directorio privado no puede ser un enlace")
    return carpeta / nombre


def restauracion(datos: dict, entorno: Mapping[str, str]) -> str:
    """Qué dejó la caché: `exacta`, `parcial` (mismo prefijo, otro contenido) o `ninguna`.

    Sólo un prefijo propio se conserva: la clave restaurada llega de afuera, y una caché de otro
    motor, de otros importadores o de otra política dejaría importaciones que nadie auditó.
    """
    clave = entorno.get("CACHE_CLAVE_RESTAURADA", "")
    if not datos["cacheable"] or entorno.get("CACHE_RESULTADO") != "success" or not clave:
        return "ninguna"
    if clave == datos["key"] and entorno.get("CACHE_HIT") == "true":
        return "exacta"
    if datos["prefijo"] and clave.startswith(datos["prefijo"] + "-"):
        return "parcial"
    return "ninguna"


def huellas_de_imports(raiz: Path) -> dict[str, str]:
    """SHA-256 de cada archivo `.import` versionado en el checkout."""
    huellas: dict[str, str] = {}
    for nombre in archivos_versionados(raiz):
        if not nombre.endswith(".import"):
            continue
        ruta = raiz / nombre
        if not ruta.is_file() or ruta.is_symlink():
            continue
        with ruta.open("rb") as entrada:
            huellas[nombre] = hashlib.file_digest(entrada, "sha256").hexdigest()
    return huellas


def sellar_importaciones(raiz: Path) -> Path | None:
    """Guarda en `.godot/imported/` la huella de cada `.import` que produjo esta caché.

    Godot sólo registra `source_md5` y `dest_md5` en sus `.md5`, no los `[params]` del `.import`:
    sin este manifiesto, una restauración parcial reutiliza `.ctex` viejos aunque haya cambiado
    `process/size_limit` o `compress/mode`.
    """
    carpeta = destino_privado(raiz, "res://.godot/imported/comprobacion").parent
    if not carpeta.is_dir():
        return None
    manifiesto = carpeta / MANIFIESTO_IMPORTS
    manifiesto.write_text(
        json.dumps(huellas_de_imports(raiz), sort_keys=True, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )
    return manifiesto


def _leer_manifiesto(carpeta: Path) -> dict[str, str]:
    manifiesto = carpeta / MANIFIESTO_IMPORTS
    if not manifiesto.is_file() or manifiesto.is_symlink():
        return {}
    try:
        datos = json.loads(manifiesto.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    return datos if isinstance(datos, dict) else {}


def _purgar_destino(raiz: Path, destino: str, vistos: set[str]) -> list[str]:
    archivo = destino_privado(raiz, destino)
    carpeta = archivo.parent
    candidatos: list[Path] = [archivo, archivo.with_suffix(".md5")]
    coincidencia = _PREFIJO_HASH_IMPORT.match(archivo.name)
    if coincidencia and carpeta.is_dir():
        prefijo = coincidencia.group(1) + "."
        candidatos.extend(
            entrada for entrada in sorted(carpeta.iterdir())
            if entrada.name.startswith(prefijo)
        )
    eliminados: list[str] = []
    for actual in candidatos:
        relativa = actual.relative_to(raiz).as_posix()
        if relativa in vistos:
            continue
        if actual.exists() or actual.is_symlink():
            actual.unlink()
            vistos.add(relativa)
            eliminados.append(relativa)
    return eliminados


def preparar_verificacion(raiz: Path, conservar: bool, parcial: bool = False) -> list[str]:
    carpeta = destino_privado(raiz, "res://.godot/imported/comprobacion").parent
    if not conservar and carpeta.exists():
        shutil.rmtree(carpeta)
    eliminados: list[str] = []
    vistos: set[str] = set()
    for ruta in sorted((raiz / "assets" / "models").glob("*.glb.import")):
        script, destinos = configuracion_importacion(ruta)
        if script != IMPORTADOR_DE_CAJAS:
            continue
        for destino in destinos:
            eliminados.extend(_purgar_destino(raiz, destino, vistos))
    if conservar and parcial and carpeta.is_dir():
        guardadas = _leer_manifiesto(carpeta)
        for nombre, actual_sha in huellas_de_imports(raiz).items():
            if guardadas.get(nombre) == actual_sha:
                continue
            ruta = raiz / nombre
            _, destinos = configuracion_importacion(ruta)
            for destino in destinos:
                eliminados.extend(_purgar_destino(raiz, destino, vistos))
            origen = nombre.removesuffix(".import")
            prefijo_origen = f"{Path(origen).name}-{hashlib.md5(f'res://{origen}'.encode()).hexdigest()}."
            for entrada in sorted(carpeta.iterdir()):
                if not entrada.name.startswith(prefijo_origen):
                    continue
                relativa = entrada.relative_to(raiz).as_posix()
                if relativa in vistos:
                    continue
                entrada.unlink()
                vistos.add(relativa)
                eliminados.append(relativa)
    return eliminados


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Identidad por contenido y limpieza de la caché privada de importaciones."
    )
    parser.add_argument("operacion", choices=("identidad", "preparar", "sellar"))
    parser.add_argument("--raiz", type=Path, default=Path.cwd())
    args = parser.parse_args()
    raiz = args.raiz.resolve()
    if args.operacion == "sellar":
        sellar_importaciones(raiz)
        return 0
    reporte = raiz / "reports" / "cache-importaciones.json"
    reporte.parent.mkdir(parents=True, exist_ok=True)
    if args.operacion == "identidad":
        sistema = os.environ["RUNNER_OS"]
        release = Path("/etc/os-release")
        if release.exists():
            sistema += "-" + hashlib.sha256(release.read_bytes()).hexdigest()[:16]
        nativo = validar_motor(os.environ["GODOT_BIN"], raiz)
        resultado = identidad(raiz, sistema, os.environ["RUNNER_ARCH"], nativo)
        datos = asdict(resultado) | {"commit": os.environ.get("GITHUB_SHA", "")}
        with Path(os.environ["GITHUB_OUTPUT"]).open("a", encoding="utf-8") as salida:
            salida.write(
                f"key={resultado.key}\nprefijo={resultado.prefijo}\n"
                f"cacheable={str(resultado.cacheable).lower()}\n"
            )
        if not resultado.cacheable:
            print(f"::warning::Caché de importaciones apagada: {resultado.motivo}")
    else:
        datos = json.loads(reporte.read_text(encoding="utf-8"))
        cual = restauracion(datos, os.environ)
        datos |= {
            "hit": cual == "exacta", "restauracion": cual,
            "resultado_restore": os.environ.get("CACHE_RESULTADO", "skipped"),
            "purgados": preparar_verificacion(
                raiz, cual != "ninguna", parcial=(cual == "parcial")
            ),
        }
        resumen = os.environ.get("GITHUB_STEP_SUMMARY")
        if resumen:
            with Path(resumen).open("a", encoding="utf-8") as salida:
                salida.write(f"Caché de importaciones. Restauración: {cual}. Entradas: {datos['entradas']}.\n\n")
                salida.write(f"Clave `{datos['key']}`. {datos['motivo']}.\n")
    reporte.write_text(json.dumps(datos, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(datos, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
