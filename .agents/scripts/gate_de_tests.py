"""El gate de la disciplina de tests: el espejo, la aserción, y que el test corra.

Lo que decide vive en `lib/tdd.py` —y ahí están los tests, y también la explicación de qué
reemplaza y qué NO cubre—; acá está el disco y el código de salida.

Uso:
    python .claude/scripts/gate_de_tests.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from lib.consola import configurar  # noqa: E402

configurar()

from lib.archivos import scripts_gd  # noqa: E402
from lib.repo import CAPAS_CON_TEST_OBLIGATORIO, RAIZ, TESTS  # noqa: E402
from lib.tdd import violaciones  # noqa: E402


def main() -> None:
    scripts = scripts_gd(RAIZ, "src")
    tests = scripts_gd(RAIZ, TESTS)
    hallazgos = violaciones(scripts, tests, CAPAS_CON_TEST_OBLIGATORIO, TESTS)

    if not hallazgos:
        capas = ", ".join(f"{c}/" for c in CAPAS_CON_TEST_OBLIGATORIO)
        print(
            f"tdd: {len(scripts)} scripts y {len(tests)} archivos de test. "
            f"Todo lo de {capas} tiene test, y ningún test está apagado ni sin aserción."
        )
        sys.exit(0)

    for ruta, problema in hallazgos:
        print(f"{ruta}  {problema}")

    print(
        f"\n{len(hallazgos)} {'hallazgo' if len(hallazgos) == 1 else 'hallazgos'}. "
        "El test se escribe ANTES: en rojo, contra la firma que "
        "todavía no existe.\nLo que no se puede ejercer sin levantar una escena no va en "
        "`dominio/` ni en `sistemas/` — va en `ui/` o en `escenas/`, que son cáscara y no "
        "deciden nada."
    )
    sys.exit(1)


if __name__ == "__main__":
    main()
