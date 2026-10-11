"""El conteo crudo sin volver a correr: las suites del último reporte contra los `*_test.gd`.

    python .claude/skills/implement-batch/scripts/conteo.py

Se corre desde la raíz del worktree, justo después de `verificar.py`. Sale con 1 si difieren:
una suite no corrió.

`verificar.py` no imprime el `Executed test suites: (N/N)`, y sacarlo de la salida cruda pide
otra corrida entera del motor. El `results.xml` que deja gdUnit4 ya lo tiene.
"""

import re
import sys
from pathlib import Path


def suites_corridas(xml: str) -> int:
    return len(re.findall(r"<testsuite ", xml))


def ultimo_reporte(reportes: Path) -> Path | None:
    con_resultado = [r for r in reportes.glob("report_*") if (r / "results.xml").is_file()]
    if not con_resultado:
        return None
    return max(con_resultado, key=lambda r: int(r.name.removeprefix("report_")))


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    reporte = ultimo_reporte(Path("reports"))
    if reporte is None:
        print("No hay `reports/report_N/results.xml`: correr antes `verificar.py`.")
        return 1
    xml = (reporte / "results.xml").read_text(encoding="utf-8", errors="replace")
    corridas = suites_corridas(xml)
    archivos = len(list(Path("test").rglob("*_test.gd")))
    print(f"{reporte.as_posix()}: {corridas} suites corridas, {archivos} archivos `*_test.gd`")
    return 0 if corridas == archivos else 1


if __name__ == "__main__":
    sys.exit(main())
