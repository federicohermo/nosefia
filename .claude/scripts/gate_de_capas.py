"""El gate de las capas de `src/`: su dirección de dependencia y sus nombres de subcarpeta.

Son dos chequeos y **un solo gate a propósito**: los dos contestan la misma pregunta —«¿esta
capa es lo que dice ser?»— y un séptimo nodo en `verificar.py` obligaría a leer dos reportes
para la misma respuesta.

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
from lib.capas import carpetas_no_declaradas, violaciones  # noqa: E402
from lib.repo import CAPAS, CARPETAS_POR_CAPA, RAIZ  # noqa: E402


def _reportar_carpetas(archivos: dict[str, str]) -> int:
    """Los archivos en una subcarpeta que su capa no declara. Devuelve cuántos son."""
    sueltos = carpetas_no_declaradas(archivos, CAPAS, CARPETAS_POR_CAPA)
    if not sueltos:
        return 0

    for ruta, capa, carpeta in sueltos:
        print(f"{ruta}  {capa}/ no declara la subcarpeta «{carpeta}/»")

    admitido = "\n".join(
        f"  {capa}/ admite: " + ", ".join(f"{c}/" for c in sorted(CARPETAS_POR_CAPA[capa]))
        for capa, _ in CAPAS
        if capa in CARPETAS_POR_CAPA
    )
    print(
        f"\n{len(sueltos)} {'archivo' if len(sueltos) == 1 else 'archivos'} "
        "en una subcarpeta que su capa no declara.\n"
        f"{admitido}\n"
        "La carpeta dice qué se rompe si tocás lo que hay adentro, y el criterio de cada capa "
        "está en su `.claude/rules/`. La raíz de una capa es válida a propósito: es donde van "
        "los que cruzan dos carpetas. Lo que este gate NO verifica es que un archivo esté en la "
        "carpeta correcta — eso es semántica y lo mira la revisión."
    )
    return len(sueltos)


def main() -> None:
    archivos = scripts_gd(RAIZ, "src")
    hallazgos = violaciones(archivos, CAPAS)
    sueltos = _reportar_carpetas(archivos)

    if not hallazgos:
        if sueltos:
            sys.exit(1)
        print(
            f"capas: {len(archivos)} scripts, ninguno referencia hacia arriba "
            "y ninguno en una subcarpeta sin declarar."
        )
        sys.exit(0)

    if sueltos:
        print()

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
