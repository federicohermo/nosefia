"""Frenar un despliegue que suma programas de shader a la carga web o agranda el motor.

    python .github/scripts/tope_de_carga.py .github/performance/topes-de-carga.json \\
        carga.json export/web/index.wasm

`carga.json` lo escribe `medir_la_carga.mjs --sin-ventana --software`. El conteo por software
difiere del que da una GPU, así que el tope sale de una medición por software. Cada corrida se
compara sola contra el tope: una mediana taparía una corrida mala.

Devuelve 0 si todo queda en su tope o por debajo, 1 si algo lo supera y 2 si los datos no
alcanzan para decidir. Los topes no cambian solos: subir uno es una decisión del PR.
"""

import json
import sys
from pathlib import Path

TOPES = Path(__file__).resolve().parents[1] / "performance" / "topes-de-carga.json"
CLAVES = ("programas", "wasm_bytes")


class DatosIncompletos(Exception):
    pass


def _leer(ruta):
    try:
        return json.loads(Path(ruta).read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        raise DatosIncompletos(f"no se pudo leer {ruta}: {error}") from error


def _entero(valor, que):
    if isinstance(valor, bool) or not isinstance(valor, int):
        raise DatosIncompletos(f"{que} no es un entero: {valor!r}")
    return valor


def _conteos(medicion, ruta):
    try:
        conteos = [_entero(corrida["programas"], "programas") for corrida in medicion["corridas"]]
    except (KeyError, TypeError) as error:
        raise DatosIncompletos(f"{ruta} tiene una corrida incompleta") from error
    if not conteos:
        raise DatosIncompletos(f"{ruta} no trae corridas")
    return conteos


def revisar(topes, conteos, wasm_bytes):
    """Los excesos, uno por línea. Vacía si todo queda en su tope."""
    excesos = []
    for numero, programas in enumerate(conteos, 1):
        if programas == 0:
            excesos.append(f"corrida {numero}: 0 programas, no se contó la carga")
        elif programas > topes["programas"]:
            excesos.append(f"corrida {numero}: {programas} programas, tope {topes['programas']}")
    if wasm_bytes > topes["wasm_bytes"]:
        excesos.append(f"index.wasm: {wasm_bytes} bytes, tope {topes['wasm_bytes']}")
    return excesos


def main(argv):
    if len(argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    ruta_topes, ruta_carga, ruta_wasm = argv
    try:
        topes = _leer(ruta_topes)
        if not isinstance(topes, dict) or set(topes) != set(CLAVES):
            raise DatosIncompletos(f"{ruta_topes} tiene que declarar {', '.join(CLAVES)}")
        topes = {clave: _entero(topes[clave], clave) for clave in CLAVES}
        conteos = _conteos(_leer(ruta_carga), ruta_carga)
        try:
            wasm_bytes = Path(ruta_wasm).stat().st_size
        except OSError as error:
            raise DatosIncompletos(f"no está {ruta_wasm}: {error}") from error
    except DatosIncompletos as error:
        print(f"tope de carga: datos incompletos: {error}", file=sys.stderr)
        return 2

    print(f"programas: {conteos} (tope {topes['programas']})")
    print(f"index.wasm: {wasm_bytes} bytes (tope {topes['wasm_bytes']})")
    excesos = revisar(topes, conteos, wasm_bytes)
    for exceso in excesos:
        print(f"::error::{exceso}")
    return 1 if excesos else 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    sys.exit(main(sys.argv[1:]))
