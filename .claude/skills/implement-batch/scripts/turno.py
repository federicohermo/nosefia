"""El turno de la máquina: una corrida pesada a la vez entre los carriles, por orden de llegada.

    python .claude/skills/implement-batch/scripts/turno.py <cola> <etiqueta> <log> -- <comando> [args...]

`<cola>` es una carpeta que comparten todos los carriles: cada worktree trae su copia de este
script, y lo único común es esa carpeta. Va en el scratch del lote, nunca adentro de un worktree.

Espera su lugar, corre el comando con la salida entera en `<log>`, imprime las últimas líneas y
sale con el código del comando.

## Por qué existe

Una suite que mide tiempos por cuadro falla bajo carga ajena, y una medición de GPU miente. En
el lote 282–285 dos verificaciones dieron rojo sólo por correr juntas.

## Por qué es una cola y no un cerrojo

La primera versión era un cerrojo que cada carril reintentaba. En el lote 317–322, del
2026-10-06, una prueba de 30 s esperó 55 minutos mientras otros carriles entraban antes, y los
carriles terminaron encadenando sus pasos adentro de un solo turno. Acá cada espera saca un
boleto con la hora, y pasa el boleto más viejo cuyo dueño sigue vivo.
"""

import ctypes
import json
import os
import subprocess
import sys
import time
from pathlib import Path


def el_que_pasa(boletos: list[str], vivos: set[str]) -> str | None:
    """El boleto más viejo cuyo dueño sigue vivo. El nombre empieza con la hora, y ordena."""
    for boleto in sorted(boletos):
        if boleto in vivos:
            return boleto
    return None


def vivo(pid: int) -> bool:
    if os.name != "nt":
        try:
            os.kill(pid, 0)
        except OSError:
            return False
        return True
    # En Windows `os.kill(pid, 0)` termina el proceso: se consulta con la API.
    manija = ctypes.windll.kernel32.OpenProcess(0x1000, False, pid)
    if not manija:
        return False
    codigo = ctypes.c_ulong()
    ctypes.windll.kernel32.GetExitCodeProcess(manija, ctypes.byref(codigo))
    ctypes.windll.kernel32.CloseHandle(manija)
    return codigo.value == 259


def _pid(boleto: str) -> int:
    return int(boleto.removesuffix(".json").split("-")[1])


def _primero(cola: Path) -> str | None:
    boletos = [p.name for p in cola.glob("*.json")]
    vivos = {b for b in boletos if vivo(_pid(b))}
    for huerfano in set(boletos) - vivos:
        (cola / huerfano).unlink(missing_ok=True)
    return el_que_pasa(boletos, vivos)


def esperar(cola: Path, etiqueta: str) -> Path:
    cola.mkdir(parents=True, exist_ok=True)
    boleto = cola / f"{time.time_ns():020d}-{os.getpid()}.json"
    boleto.write_text(json.dumps({"etiqueta": etiqueta}), encoding="utf-8")
    ultimo_aviso = 0.0
    while True:
        primero = _primero(cola)
        if primero == boleto.name:
            # Un boleto con hora anterior pudo escribirse después de la primera lectura.
            time.sleep(0.5)
            if _primero(cola) == boleto.name:
                return boleto
            continue
        if time.time() - ultimo_aviso > 60 and primero is not None:
            try:
                quien = json.loads((cola / primero).read_text(encoding="utf-8"))["etiqueta"]
            except (OSError, ValueError, KeyError):
                quien = primero
            print(f"[turno] espera: corre «{quien}»", flush=True)
            ultimo_aviso = time.time()
        time.sleep(2)


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    args = sys.argv[1:]
    if len(args) < 5 or args[3] != "--":
        print(
            "uso: python turno.py <cola> <etiqueta> <log> -- <comando> [args...]", file=sys.stderr
        )
        return 2
    cola, etiqueta, log, comando = Path(args[0]), args[1], Path(args[2]), args[4:]
    log.parent.mkdir(parents=True, exist_ok=True)
    llegada = time.time()
    boleto = esperar(cola, etiqueta)
    inicio = time.time()
    print(f"[turno] «{etiqueta}» corre tras {inicio - llegada:.0f} s de espera", flush=True)
    try:
        with log.open("wb") as salida:
            codigo = subprocess.run(comando, stdout=salida, stderr=subprocess.STDOUT).returncode
    finally:
        boleto.unlink(missing_ok=True)
    lineas = log.read_text(encoding="utf-8", errors="replace").splitlines()
    print("\n".join(lineas[-40:]))
    print(f"[turno] «{etiqueta}» salió con {codigo} en {time.time() - inicio:.0f} s; log: {log}")
    return codigo


if __name__ == "__main__":
    sys.exit(main())
