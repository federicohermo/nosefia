"""Mediciones aisladas del harness de CI sin cambiar su comando de convergencia."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
import time
import xml.etree.ElementTree as ET


TIPOS_SNAPSHOT = ("completo", "importaciones")


def guardar(ruta: Path, datos: dict) -> None:
    ruta.parent.mkdir(parents=True, exist_ok=True)
    ruta.write_text(json.dumps(datos, indent=2) + "\n", encoding="utf-8")


def captura(*comando: str) -> str:
    return subprocess.check_output(comando, text=True).strip()


def cantidad(texto: str) -> int:
    valor = int(texto)
    if not 1 <= valor <= 256:
        raise argparse.ArgumentTypeError("particiones debe estar entre 1 y 256")
    return valor


def identidad() -> dict:
    memoria = {}
    cpu = platform.processor()
    if Path("/proc/cpuinfo").exists():
        cpu = next((
            linea.split(":", 1)[1].strip()
            for linea in Path("/proc/cpuinfo").read_text().splitlines()
            if linea.startswith("model name")
        ), cpu)
    if Path("/proc/meminfo").exists():
        memoria = dict(
            linea.split(":", 1) for linea in Path("/proc/meminfo").read_text().splitlines()
        )
    return {
        "commit": captura("git", "rev-parse", "HEAD"),
        "arbol_juego": {
            nombre: captura("git", "rev-parse", f"HEAD:{nombre}")
            for nombre in ("src", "test", "assets")
        },
        "workspace": str(Path.cwd()),
        "python": sys.version,
        "plataforma": platform.platform(),
        "cpu": cpu,
        "cpus": os.cpu_count(),
        "load": os.getloadavg() if hasattr(os, "getloadavg") else None,
        "memoria": {k: memoria.get(k, "").strip() for k in ("MemTotal", "MemAvailable")},
        "runner": os.environ.get("RUNNER_NAME"),
        "imagen_os": os.environ.get("ImageOS"),
        "imagen_version": os.environ.get("ImageVersion"),
        "run_id": os.environ.get("GITHUB_RUN_ID"),
        "run_attempt": os.environ.get("GITHUB_RUN_ATTEMPT"),
        "inicio_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
    }


def ejecutar_medido(comando: list[str], log: Path | None = None) -> dict:
    import resource

    antes = resource.getrusage(resource.RUSAGE_CHILDREN)
    inicio = time.monotonic()
    inicio_utc = dt.datetime.now(dt.timezone.utc).isoformat()
    if log is None:
        codigo = subprocess.call(comando)
    else:
        log.parent.mkdir(parents=True, exist_ok=True)
        with log.open("w", encoding="utf-8") as archivo:
            with subprocess.Popen(
                comando, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                text=True, encoding="utf-8", errors="replace", bufsize=1,
            ) as proceso:
                for linea in proceso.stdout:
                    print(linea, end="", flush=True)
                    archivo.write(linea)
                codigo = proceso.wait()
    despues = resource.getrusage(resource.RUSAGE_CHILDREN)
    return {
        "comando": comando,
        "inicio_utc": inicio_utc,
        "wall_s": time.monotonic() - inicio,
        "cpu_user_s": despues.ru_utime - antes.ru_utime,
        "cpu_system_s": despues.ru_stime - antes.ru_stime,
        "maxrss_kib": despues.ru_maxrss,
        "codigo": codigo,
    }


def godot(argumentos: list[str]) -> int:
    dato = ejecutar_medido([os.environ["CI_GODOT_REAL"], *argumentos])
    dato["fase"] = "import" if "--import" in argumentos else "tests"
    with Path(os.environ["CI_GODOT_METRICAS"]).open("a", encoding="utf-8") as archivo:
        archivo.write(json.dumps(dato) + "\n")
    return dato["codigo"]


def preparar(tipo: str = "completo") -> int:
    datos = identidad()
    datos["import_frio"] = ejecutar_medido(
        [os.environ["GODOT_BIN"], "--headless", "--path", str(Path.cwd()), "--import", "--quit"],
        Path("reports/medicion-ci/import-frio.log"),
    )
    guardar(Path("reports/medicion-ci/preparacion.json"), datos)
    guardar(Path(".ci-tools/snapshot.json"), {
        "tipo": tipo,
        "workspace": str(Path.cwd()), "python": sys.version,
        "commit": datos["commit"], "arbol_juego": datos["arbol_juego"],
        "godot_version": captura(os.environ["GODOT_BIN"], "--version"),
        "sistema": platform.system(), "arquitectura": platform.machine(),
    })
    return datos["import_frio"]["codigo"]


def nombres_snapshot(tipo: str) -> bytes:
    if tipo == "completo":
        return subprocess.check_output(["git", "ls-files", "-z"]) + b".git\0.godot\0.ci-tools\0"
    rutas = [Path(".godot/imported"), Path(".ci-tools/snapshot.json")]
    rutas.extend(sorted(Path(".godot/editor").glob("filesystem_cache*")))
    rutas.extend(
        ruta for ruta in (
            Path(".godot/global_script_class_cache.cfg"), Path(".godot/uid_cache.bin"),
        ) if ruta.exists()
    )
    return b"".join(os.fsencode(ruta.as_posix()) + b"\0" for ruta in rutas)


def empaquetar(destino: Path, tipo: str = "completo") -> int:
    destino = destino.resolve()
    if destino.is_relative_to(Path.cwd().resolve()):
        raise ValueError("el snapshot debe escribirse fuera del workspace")
    manifest = json.loads(Path(".ci-tools/snapshot.json").read_text(encoding="utf-8"))
    if manifest["tipo"] != tipo:
        raise ValueError("el tipo de snapshot no coincide con la preparación")
    nombres = nombres_snapshot(tipo)
    inicio = time.monotonic()
    subprocess.run(
        ["tar", "--zstd", "-cf", str(destino), "--null", "-T", "-"],
        input=nombres, check=True,
    )
    ruta = Path("reports/medicion-ci/preparacion.json")
    datos = json.loads(ruta.read_text(encoding="utf-8"))
    datos["empaquetado"] = {"wall_s": time.monotonic() - inicio, "bytes": destino.stat().st_size}
    guardar(ruta, datos)
    return 0


def validar_snapshot(tipo: str = "completo") -> int:
    datos = json.loads(Path(".ci-tools/snapshot.json").read_text(encoding="utf-8"))
    if datos["tipo"] != tipo:
        raise ValueError("el tipo de snapshot no coincide con el esperado")
    if datos["workspace"] != str(Path.cwd()):
        raise ValueError("el snapshot requiere el mismo workspace del preparador")
    if tipo == "completo" and datos["python"] != sys.version:
        raise ValueError("el venv requiere el mismo Python del preparador")
    if datos["sistema"] != platform.system() or datos["arquitectura"] != platform.machine():
        raise ValueError("el snapshot requiere el mismo sistema y arquitectura del preparador")
    if tipo == "completo":
        motores = list(Path(".ci-tools/godot").glob("Godot_v*"))
        if len(motores) != 1:
            raise ValueError("el snapshot requiere un único motor")
        motor = str(motores[0].resolve())
    else:
        motor = os.environ["GODOT_BIN"]
    if captura(motor, "--version") != datos["godot_version"]:
        raise ValueError("el motor no coincide con la versión del preparador")
    if datos["commit"] != captura("git", "rev-parse", "HEAD"):
        raise ValueError("el snapshot no coincide con el commit empaquetado")
    esperado = os.environ.get("CI_COMMIT_ESPERADO")
    if esperado and datos["commit"] != esperado:
        raise ValueError("el snapshot no coincide con el commit objetivo externo")
    for nombre, arbol in datos["arbol_juego"].items():
        if arbol != captura("git", "rev-parse", f"HEAD:{nombre}"):
            raise ValueError(f"el árbol {nombre} no coincide con el snapshot")
    return 0


def comprobar_trabajo(datos: dict) -> None:
    invocaciones = datos["godot"]
    if sorted(dato["fase"] for dato in invocaciones) != ["import", "tests"]:
        raise ValueError("se requiere una importación y una ejecución real de tests")
    if any(dato["codigo"] != 0 for dato in invocaciones):
        raise ValueError("una invocación de Godot falló")
    if any(dato["wall_s"] <= 0 for dato in invocaciones):
        raise ValueError("hay métricas sin trabajo")
    if not datos["suites"] or datos["suites_verificadas"] != len(datos["suites"]):
        raise ValueError("cobertura incompleta de suites")
    if datos["casos"] <= 0:
        raise ValueError("la partición no ejecutó casos")


def verificar(indice: int, total: int, modo: str, etiqueta: str) -> int:
    if not 0 <= indice < total:
        raise ValueError("índice de partición fuera de rango")
    sys.path.insert(0, str(Path(".claude/scripts").resolve()))
    from lib.archivos import scripts_gd
    from lib.particiones_de_tests import ParticionTests, comprobar_reporte, seleccionar_suites

    destino = Path("reports/medicion-ci")
    destino.mkdir(parents=True, exist_ok=True)
    metricas = destino / "godot.jsonl"
    metricas.write_text("", encoding="utf-8")
    datos = identidad() | {
        "indice": indice, "particiones": total, "preparacion": modo, "etiqueta": etiqueta,
        "programacion": os.environ.get("PROGRAMACION", "serial"),
        "suites": seleccionar_suites(
            [r for r in scripts_gd(Path.cwd(), "test") if r.endswith("_test.gd")],
            ParticionTests(indice, total),
        ),
        "godot": [], "suites_verificadas": 0, "casos": 0,
    }
    codigo = 1
    try:
        real = os.environ["GODOT_BIN"]
        datos["godot_version"] = captura(real, "--version")
        datos["gdtoolkit_version"] = captura(
            sys.executable, "-c",
            "import importlib.metadata; print(importlib.metadata.version('gdtoolkit'))",
        )
        wrapper = Path(os.environ.get("RUNNER_TEMP", ".ci-tools")) / "godot-medido"
        wrapper.parent.mkdir(parents=True, exist_ok=True)
        wrapper.write_text(
            '#!/bin/sh\nexec "$CI_BENCH_PYTHON" "$CI_BENCH_SCRIPT" godot "$@"\n',
            encoding="utf-8",
        )
        wrapper.chmod(0o755)
        os.environ.update({
            "CI_GODOT_REAL": real,
            "CI_GODOT_METRICAS": str(metricas.resolve()),
            "CI_BENCH_PYTHON": sys.executable,
            "CI_BENCH_SCRIPT": str(Path(__file__).resolve()),
            "GODOT_BIN": str(wrapper.resolve()),
        })
        datos["verificacion"] = ejecutar_medido(
            [
                sys.executable, ".claude/scripts/verificar.py",
                "--particion-tests", f"{indice}/{total}",
            ],
            destino / "verificar.log",
        )
        codigo = datos["verificacion"]["codigo"]
        datos["godot"] = [json.loads(linea) for linea in metricas.read_text().splitlines()]
        reportes = list(Path("reports").glob(f"particion-{indice}-de-{total}-*/**/results.xml"))
        if len(reportes) != 1:
            raise ValueError(f"se esperaba un único JUnit nuevo, se encontraron {len(reportes)}")
        xml = reportes[0].read_text(encoding="utf-8")
        datos["suites_verificadas"] = len(comprobar_reporte(datos["suites"], xml))
        datos["casos"] = len(ET.fromstring(xml).findall(".//testcase"))
        comprobar_trabajo(datos)
    except Exception as error:
        datos["error"] = str(error)
        print(f"::error::{error}", file=sys.stderr)
        codigo = codigo or 1
    finally:
        datos["codigo"] = codigo
        guardar(destino / "worker.json", datos)
    return codigo


def main(argumentos: list[str] | None = None) -> int:
    argumentos = sys.argv[1:] if argumentos is None else argumentos
    if argumentos and argumentos[0] == "godot":
        return godot(argumentos[1:])
    parser = argparse.ArgumentParser(description=__doc__)
    comandos = parser.add_subparsers(dest="comando", required=True)
    matriz = comandos.add_parser("matriz")
    matriz.add_argument("particiones", type=cantidad)
    preparacion = comandos.add_parser("preparar")
    preparacion.add_argument("--tipo", choices=TIPOS_SNAPSHOT, default="completo")
    paquete = comandos.add_parser("empaquetar")
    paquete.add_argument("destino", type=Path)
    paquete.add_argument("--tipo", choices=TIPOS_SNAPSHOT, default="completo")
    validacion = comandos.add_parser("validar-snapshot")
    validacion.add_argument("--tipo", choices=TIPOS_SNAPSHOT, default="completo")
    worker = comandos.add_parser("verificar")
    worker.add_argument("indice", type=int)
    worker.add_argument("particiones", type=cantidad)
    worker.add_argument("preparacion", choices=("independiente", "compartida", "importaciones"))
    worker.add_argument("etiqueta")
    opciones = parser.parse_args(argumentos)
    if opciones.comando == "matriz":
        print(json.dumps({"indice": list(range(opciones.particiones))}))
        return 0
    if opciones.comando == "preparar":
        return preparar(opciones.tipo)
    if opciones.comando == "empaquetar":
        return empaquetar(opciones.destino, opciones.tipo)
    if opciones.comando == "validar-snapshot":
        return validar_snapshot(opciones.tipo)
    return verificar(
        opciones.indice, opciones.particiones, opciones.preparacion, opciones.etiqueta
    )


if __name__ == "__main__":
    raise SystemExit(main())
