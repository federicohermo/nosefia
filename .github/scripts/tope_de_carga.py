"""Frenar un PR que suma programas de shader a la carga web o agranda el motor.

    python .github/scripts/tope_de_carga.py .github/performance/topes-de-carga.json \\
        con-paralelo.json sin-paralelo.json export/web/index.wasm

Los dos JSON los escribe `medir_la_carga.mjs`: uno con el enlace en paralelo y otro con
`--sin-enlace-en-paralelo`, que recorre el camino de Firefox. Cada corrida se compara sola
contra su tope: una mediana taparía una corrida mala.

Devuelve 0 si todo queda en su tope o por debajo, 1 si algo lo supera y 2 si los datos no
alcanzan para decidir. Los topes no cambian solos: subir uno es una decisión del PR.
"""

import json
import sys
from pathlib import Path

TOPES = Path(__file__).resolve().parents[1] / "performance" / "topes-de-carga.json"
CLAVES = ("programas_con_paralelo", "programas_sin_paralelo", "wasm_bytes")
CORRIDAS = 3
EXTENSION = "KHR_parallel_shader_compile"


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


def _corridas(medicion, ruta, sin_enlace):
    try:
        corridas = medicion["corridas"]
        declarado = medicion["condiciones"]["sinEnlaceEnParalelo"]
    except (KeyError, TypeError) as error:
        raise DatosIncompletos(f"{ruta} no trae corridas y condiciones") from error
    if declarado is not sin_enlace:
        raise DatosIncompletos(f"{ruta} no es la medición {_camino(sin_enlace)}")
    if not isinstance(corridas, list) or len(corridas) < CORRIDAS:
        raise DatosIncompletos(f"{ruta} trae menos de {CORRIDAS} corridas")
    try:
        return [
            (_entero(c["programas"], "programas"), c["enlace_en_paralelo"]) for c in corridas
        ]
    except (KeyError, TypeError) as error:
        raise DatosIncompletos(f"{ruta} tiene una corrida incompleta") from error


def _camino(sin_enlace):
    return "sin enlace en paralelo" if sin_enlace else "con enlace en paralelo"


def revisar(topes, corridas_con, corridas_sin, wasm_bytes):
    """Los excesos, uno por línea. Vacía si todo queda en su tope."""
    excesos = []
    for sin_enlace, corridas, tope in (
        (False, corridas_con, topes["programas_con_paralelo"]),
        (True, corridas_sin, topes["programas_sin_paralelo"]),
    ):
        camino = _camino(sin_enlace)
        for numero, (programas, vio_la_extension) in enumerate(corridas, 1):
            if vio_la_extension is sin_enlace:
                excesos.append(
                    f"corrida {numero} {camino}: la página "
                    f"{'vio' if vio_la_extension else 'no vio'} {EXTENSION}"
                )
            if programas == 0:
                excesos.append(f"corrida {numero} {camino}: 0 programas, no se contó la carga")
            elif programas > tope:
                excesos.append(f"corrida {numero} {camino}: {programas} programas, tope {tope}")
    if wasm_bytes > topes["wasm_bytes"]:
        excesos.append(f"index.wasm: {wasm_bytes} bytes, tope {topes['wasm_bytes']}")
    return excesos


def main(argv):
    if len(argv) != 4:
        print(__doc__, file=sys.stderr)
        return 2
    ruta_topes, ruta_con, ruta_sin, ruta_wasm = argv
    try:
        topes = _leer(ruta_topes)
        if not isinstance(topes, dict) or set(topes) != set(CLAVES):
            raise DatosIncompletos(f"{ruta_topes} tiene que declarar {', '.join(CLAVES)}")
        topes = {clave: _entero(topes[clave], clave) for clave in CLAVES}
        con = _corridas(_leer(ruta_con), ruta_con, sin_enlace=False)
        sin = _corridas(_leer(ruta_sin), ruta_sin, sin_enlace=True)
        try:
            wasm_bytes = Path(ruta_wasm).stat().st_size
        except OSError as error:
            raise DatosIncompletos(f"no está {ruta_wasm}: {error}") from error
    except DatosIncompletos as error:
        print(f"tope de carga: datos incompletos: {error}", file=sys.stderr)
        return 2

    for corridas, clave, sin_enlace in (
        (con, "programas_con_paralelo", False),
        (sin, "programas_sin_paralelo", True),
    ):
        conteos = [programas for programas, _ in corridas]
        print(f"programas {_camino(sin_enlace)}: {conteos} (tope {topes[clave]})")
    print(f"index.wasm: {wasm_bytes} bytes (tope {topes['wasm_bytes']})")
    excesos = revisar(topes, con, sin, wasm_bytes)
    for exceso in excesos:
        print(f"::error::{exceso}")
    return 1 if excesos else 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    sys.exit(main(sys.argv[1:]))
