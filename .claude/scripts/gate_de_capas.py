"""El gate de la dirección de dependencia entre las capas de `src/`.

Lo que decide vive en `lib/capas.py` —y ahí están los tests—; acá está el disco y el código
de salida.

Uso:
    python .claude/scripts/gate_de_capas.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from lib.consola import configurar  # noqa: E402

configurar()

from lib.archivos import scripts_gd  # noqa: E402
from lib.capas import violaciones  # noqa: E402
from lib.repo import CAPAS, RAIZ  # noqa: E402


def main() -> None:
    archivos = scripts_gd(RAIZ, "src")
    hallazgos = violaciones(archivos, CAPAS)

    if not hallazgos:
        print(f"capas: {len(archivos)} scripts, ninguno referencia hacia arriba.")
        sys.exit(0)

    for ruta, linea, origen, destino, referencia in hallazgos:
        print(f"{ruta}:{linea}  {origen} → {destino}  ({referencia})")

    permitido = "\n".join(
        f"  {capa}/ puede referenciar: " + (", ".join(f"{p}/" for p in puede) or "nada")
        for capa, puede in CAPAS
    )
    print(
        f"\n{len(hallazgos)} {'referencia' if len(hallazgos) == 1 else 'referencias'} "
        "en contra de la dirección declarada.\n"
        f"{permitido}\n"
        "La salida no es agregar una excepción: es mover la decisión hacia abajo —al dominio, "
        "que no conoce a nadie— o pasar el dato por parámetro en vez de ir a buscarlo."
    )
    sys.exit(1)


if __name__ == "__main__":
    main()
