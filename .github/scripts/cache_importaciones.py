import argparse
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


IMPORTADORES = {
    "assets/models/importar_modelo.gd": "0da71c1d2052f41124553e8187c1646b7a50206ea69643284ec75b036337310e",
    "assets/models/importar_caja.gd": "f09d6fd85dec24b9544948637bbc12cbef8e8904ff362fa3aecc517fe2a24755",
}
CAJAS = {"caja_registradora", "lector_de_productos", "ticket_impreso"}
MATERIAL = "src/escenas/puestos/vidrio_del_local.tres"
EXCLUIDOS = {".github", ".claude", ".agents", "docs", "reports", "specs", "tools"}


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
    for nombre, esperado in IMPORTADORES.items():
        ruta = raiz / nombre
        if ruta.is_symlink() or not ruta.is_file() or hashlib.sha256(
            ruta.read_text(encoding="utf-8").encode("utf-8")
        ).hexdigest() != esperado:
            motivo = f"importador sin auditar: {nombre}"
            break
    else:
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
                if script.endswith("importar_caja.gd") and nombre not in {
                    f"assets/models/{caja}.glb.import" for caja in CAJAS
                }:
                    motivo = f"salidas de importador sin auditar: {nombre}"
                    break
                if script.endswith("importar_caja.gd"):
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
    for valor in ("importaciones-v2", sistema, arquitectura, motor, receta, binario, artefacto):
        datos = valor.encode("utf-8")
        huella.update(len(datos).to_bytes(8, "big") + datos)
    politica = Path(__file__).read_bytes()
    huella.update(hashlib.sha256(politica).digest())
    for nombre in seleccion:
        archivo = raiz / nombre
        ruta = nombre.encode("utf-8")
        huella.update(len(ruta).to_bytes(8, "big") + ruta)
        huella.update(archivo.stat().st_size.to_bytes(8, "big"))
        with archivo.open("rb") as entrada:
            huella.update(hashlib.file_digest(entrada, "sha256").digest())
    return IdentidadImportacion(
        f"godot-importaciones-v2-{huella.hexdigest()}", not motivo,
        motivo or "importadores auditados y recursos cubiertos", len(seleccion),
        motor, sistema, arquitectura, receta, binario, artefacto,
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


def preparar_verificacion(raiz: Path, exacta: bool) -> list[str]:
    carpeta = destino_privado(raiz, "res://.godot/imported/comprobacion").parent
    if not exacta and carpeta.exists():
        shutil.rmtree(carpeta)
    eliminados = []
    for caja in sorted(CAJAS):
        ruta = raiz / "assets" / "models" / f"{caja}.glb.import"
        if not ruta.exists():
            continue
        script, destinos = configuracion_importacion(ruta)
        if script != "assets/models/importar_caja.gd":
            continue
        for destino in destinos:
            archivo = destino_privado(raiz, destino)
            for actual in (archivo, archivo.with_suffix(".md5")):
                if actual.exists() or actual.is_symlink():
                    actual.unlink()
                    eliminados.append(actual.relative_to(raiz).as_posix())
    return eliminados


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Identidad por contenido y limpieza de la caché privada de importaciones."
    )
    parser.add_argument("operacion", choices=("identidad", "preparar"))
    parser.add_argument("--raiz", type=Path, default=Path.cwd())
    args = parser.parse_args()
    raiz = args.raiz.resolve()
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
            salida.write(f"key={resultado.key}\ncacheable={str(resultado.cacheable).lower()}\n")
    else:
        datos = json.loads(reporte.read_text(encoding="utf-8"))
        exacta = (
            datos["cacheable"] and os.environ.get("CACHE_HIT") == "true"
            and os.environ.get("CACHE_RESULTADO") == "success"
            and os.environ.get("CACHE_CLAVE_RESTAURADA") == datos["key"]
        )
        datos |= {
            "hit": bool(exacta), "resultado_restore": os.environ.get("CACHE_RESULTADO", "skipped"),
            "purgados": preparar_verificacion(raiz, exacta),
        }
        resumen = os.environ.get("GITHUB_STEP_SUMMARY")
        if resumen:
            with Path(resumen).open("a", encoding="utf-8") as salida:
                salida.write(f"Caché de importaciones. Hit exacto: {exacta}. Entradas: {datos['entradas']}.\n\n")
                salida.write(f"Clave `{datos['key']}`. {datos['motivo']}.\n")
    reporte.write_text(json.dumps(datos, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(datos, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
