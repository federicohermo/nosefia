"""El gate de las capas de `src/`: qué es cada una y a quién puede referenciar.

Son **tres** chequeos y un solo gate a propósito —la dirección de las dependencias, los nombres
de subcarpeta y la pureza del dominio—: los tres contestan la misma pregunta, «¿esta capa es lo
que dice ser?», y un séptimo nodo en `verificar.py` obligaría a leer dos reportes para una sola
respuesta.

Lo que decide vive en `lib/capas.py` —y ahí están los tests—; acá está el disco y el código
de salida.

Uso:
    python .claude/scripts/gate_de_capas.py [raíz]

La raíz es opcional y por defecto es la del repo. Existe para que el test pueda fabricar el rojo
en un árbol temporal: ensuciar `src/` de verdad pondría en rojo a los otros nodos que
`verificar.py` corre **en paralelo** con éste, por un archivo que el test está por borrar.
"""

import os
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from lib.consola import configurar  # noqa: E402

configurar()

from lib.archivos import escenas_tscn, scripts_gd  # noqa: E402
from lib.capas import carpetas_no_declaradas, impurezas, violaciones  # noqa: E402
from lib.repo import CAPAS, CARPETAS_POR_CAPA, RAIZ  # noqa: E402


def _carpetas(archivos: dict[str, str]) -> tuple[int, str]:
    """Los archivos en una subcarpeta que su capa no declara: cuántos son y qué se imprime."""
    sueltos = carpetas_no_declaradas(archivos, CAPAS, CARPETAS_POR_CAPA)
    if not sueltos:
        return 0, ""

    admitido = "\n".join(
        f"  {capa}/ admite: " + ", ".join(f"{c}/" for c in sorted(CARPETAS_POR_CAPA[capa]))
        for capa, _ in CAPAS
        if capa in CARPETAS_POR_CAPA
    )
    lineas = [
        f"{ruta}  {capa}/ no declara la subcarpeta «{carpeta}/»"
        for ruta, capa, carpeta in sueltos
    ]
    lineas.append(
        f"\n{len(sueltos)} {'archivo' if len(sueltos) == 1 else 'archivos'} "
        "en una subcarpeta que su capa no declara.\n"
        f"{admitido}\n"
        "La carpeta dice qué se rompe si tocás lo que hay adentro, y el criterio de cada capa "
        "está en su `.claude/rules/`. La raíz de una capa es válida a propósito: es donde van "
        "los que cruzan dos carpetas. Lo que este gate NO verifica es que un archivo esté en la "
        "carpeta correcta — eso es semántica y lo mira la revisión."
    )
    return len(sueltos), "\n".join(lineas)


def _pureza(archivos: dict[str, str]) -> tuple[int, str]:
    """Los usos de motor en la capa pura: cuántos son y qué se imprime.

    Se reporta bajo su propio encabezado y no junto a las violaciones de dirección porque son
    defectos distintos y se arreglan distinto: una dirección equivocada se mueve de lugar, una
    impureza se reescribe pasando por parámetro lo que se estaba yendo a buscar.
    """
    hallazgos = impurezas(archivos, CAPAS)
    if not hallazgos:
        return 0, ""

    lineas = [f"{ruta}:{linea}  usa el motor  ({patron})" for ruta, linea, patron in hallazgos]
    lineas.append(
        f"\n{len(hallazgos)} {'uso' if len(hallazgos) == 1 else 'usos'} del motor en la capa que "
        "tiene que poder ejercerse sin levantar una escena.\n"
        "  sólo se puede extender: RefCounted, Resource, o un `class_name` del propio dominio\n"
        "La salida no es agregar el nombre a la lista: es que el `Node` viva en `sistemas/` y le "
        "pase al dominio lo que el motor da —un `delta`, un evento, un archivo— como parámetro. "
        "Un dominio que va a buscarlo necesita un frame para probarse, y ahí se acaba el TDD."
    )
    return len(hallazgos), "\n".join(lineas)


def _direccion(archivos: dict[str, str]) -> tuple[int, str]:
    """Las referencias que van en contra de la dirección declarada: cuántas y qué se imprime."""
    hallazgos = violaciones(archivos, CAPAS)
    if not hallazgos:
        return 0, ""

    permitido = "\n".join(
        f"  {capa}/ puede referenciar: " + (", ".join(f"{p}/" for p in puede) or "nada")
        for capa, puede in CAPAS
    )
    lineas = [
        f"{ruta}:{linea}  {origen} → {destino}  ({referencia})"
        for ruta, linea, origen, destino, referencia in hallazgos
    ]
    lineas.append(
        f"\n{len(hallazgos)} {'referencia' if len(hallazgos) == 1 else 'referencias'} "
        "en contra de la dirección declarada.\n"
        f"{permitido}\n"
        "La salida no es agregar una excepción: es mover la decisión hacia abajo —al dominio, "
        "que no conoce a nadie— o pasar el dato por parámetro en vez de ir a buscarlo."
    )
    return len(hallazgos), "\n".join(lineas)


def main(raiz: Path = RAIZ) -> None:
    archivos = scripts_gd(raiz, "src")
    # El chequeo de carpetas mira **también** las escenas, y los otros dos no: `escenas/` es
    # la capa donde casi todo es `.tscn`, así que un gate que sólo caminara `.gd` la dejaría sin
    # verificar justo donde vive la distinción entre `puestos/` y `objetos/`.
    clasificables = {**archivos, **escenas_tscn(raiz, "src")}

    bloques = (_carpetas(clasificables), _pureza(archivos), _direccion(archivos))
    if any(cuantos for cuantos, _ in bloques):
        print("\n\n".join(texto for _, texto in bloques if texto))
        sys.exit(1)

    print(
        f"capas: {len(archivos)} scripts, ninguno referencia hacia arriba y ninguno del dominio "
        f"usa el motor; {len(clasificables)} archivos, ninguno en una subcarpeta sin declarar."
    )
    sys.exit(0)


if __name__ == "__main__":
    main(Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else RAIZ)
