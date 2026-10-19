import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time

import preparar_godot_nativo as nativo


def probar(carpeta: Path, repeticiones: int, reportes: Path) -> dict:
    motor = nativo.validar(carpeta, nativo.RAIZ)
    reportes.mkdir(parents=True, exist_ok=True)
    resultado = {
        "motor": motor["receta_sha256"], "archivos": motor["archivos"], "procesos": [],
    }
    with tempfile.TemporaryDirectory(prefix="nosefia-classdb-", dir=reportes) as temporal:
        proyecto = Path(temporal).resolve()
        (proyecto / "project.godot").write_text(
            'config_version=5\n[application]\nconfig/name="ClassDB concurrente"\n',
            encoding="utf-8",
        )
        shutil.copyfile(
            Path(__file__).parent / "tests/fixtures/classdb_concurrente.gd",
            proyecto / "probe.gd",
        )
        entorno = dict(os.environ)
        entorno["APPDATA" if sys.platform == "win32" else "XDG_DATA_HOME"] = str(
            proyecto / "datos"
        )
        for indice in range(repeticiones):
            archivo = reportes / f"classdb-{indice}.log"
            inicio = time.monotonic()
            with archivo.open("w", encoding="utf-8") as salida:
                proceso = subprocess.Popen(
                    [motor["binario"], "--headless", "--path", str(proyecto),
                     "--script", "res://probe.gd"],
                    stdout=salida, stderr=subprocess.STDOUT, cwd=proyecto, env=entorno,
                )
                agotado = False
                try:
                    codigo = proceso.wait(timeout=30)
                except subprocess.TimeoutExpired:
                    agotado = True
                    if sys.platform == "win32":
                        subprocess.run(
                            ["taskkill", "/PID", str(proceso.pid), "/T", "/F"],
                            check=False, capture_output=True,
                        )
                    else:
                        proceso.kill()
                    codigo = proceso.wait(timeout=10)
            texto = archivo.read_text(encoding="utf-8", errors="replace")
            clases = re.search(r"\[CLASSDB-PROBE\] threads=16 classes=(\d+)", texto)
            consultas = re.search(r"\[CLASSDB-PROBE\] complete calls=(\d+)", texto)
            completo = (
                clases is not None and consultas is not None
                and int(clases[1]) >= 16 and int(consultas[1]) == 16 * int(clases[1])
            )
            correcto = (
                codigo == 0 and not agotado and completo
                and "SCRIPT ERROR:" not in texto and "ERROR:" not in texto
            )
            resultado["procesos"].append({
                "codigo": codigo, "timeout": agotado, "completo": completo,
                "correcto": correcto, "segundos": time.monotonic() - inicio,
            })
            (reportes / "classdb.json").write_text(
                json.dumps(resultado, indent=2) + "\n", encoding="utf-8"
            )
            if not correcto:
                raise ValueError(f"falló la reproducción concurrente de ClassDB: {archivo}")
    return resultado


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser()
    parser.add_argument("--destino", type=Path)
    parser.add_argument("--repeticiones", type=int, default=8)
    parser.add_argument("--reportes", type=Path, default=Path("reports/motor-nativo"))
    opciones = parser.parse_args()
    if not 1 <= opciones.repeticiones <= 32:
        parser.error("repeticiones debe estar entre 1 y 32")
    carpeta = opciones.destino or nativo.RAIZ / "build/godot-native" / nativo.plataforma_actual()
    try:
        resultado = probar(carpeta, opciones.repeticiones, opciones.reportes)
    except (ValueError, OSError, KeyError, subprocess.SubprocessError) as error:
        print(f"Falló la prueba del motor nativo. {error}", file=sys.stderr)
        return 1
    print(json.dumps(resultado))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
