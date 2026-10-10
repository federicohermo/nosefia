"""El mapa del sistema, derivado del código.

    python .claude/scripts/estructura.py            # las capas, sus carpetas y sus clases
    python .claude/scripts/estructura.py --clases   # además, cada `class_name` con su archivo
    python .claude/scripts/estructura.py --mermaid  # el grafo de referencias, para pegar

## Por qué esto es un script y no un documento

Este repo tenía un `docs/architecture/directory-structure.md` con el árbol dibujado a mano y un
`overview.md` con las capas explicadas otra vez. Los dos decían lo que `ls` contesta, y los dos
envejecían solos: **una lista escrita a mano caduca en el commit siguiente, y nadie se entera**.

Lo que no se puede averiguar mirando —el criterio de cada carpeta, la dirección de dependencia,
la pureza del dominio— vive en `lib/repo.py`, que es de donde este script lo lee, y en las reglas
de `.claude/rules/`, que se cargan solas al tocar cada árbol. Acá no hay ninguna lista escrita.

## Qué muestra, y qué no

Muestra el **grafo de referencias entre capas**, que es lo que en Godot no se puede leer de los
imports: un `class_name` queda registrado globalmente, así que un archivo nombra a otro sin
escribir una sola ruta. El índice sale de `lib/capas.py`, el mismo que usa el gate.

No muestra los autoloads —son globales por construcción y no dejan referencia— ni lo que una
escena cablea por `@export`. Las dos cosas las mira la revisión.
"""

import os
import re
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from lib.consola import configurar  # noqa: E402

configurar()

from lib.archivos import scripts_gd  # noqa: E402
from lib.capas import (  # noqa: E402
    _sin_comentarios_ni_strings,
    capa_de,
    indice_de_class_names,
    violaciones,
)
from lib.repo import CAPAS, CARPETAS_POR_CAPA, RAIZ  # noqa: E402
from lib.specs import specs_del_repo  # noqa: E402


def _fuentes() -> dict[str, str]:
    """Cada `.gd` de `src/`, por su ruta relativa."""
    return scripts_gd(RAIZ, "src")


def _por_carpeta(rutas: list[str]) -> dict[str, list[str]]:
    """Los scripts de una capa, agrupados por su subcarpeta. La raíz de la capa es `·`."""
    agrupados: dict[str, list[str]] = defaultdict(list)
    for ruta in rutas:
        partes = ruta.split("/")
        agrupados["·" if len(partes) == 3 else partes[2]].append(ruta)
    return agrupados


def _referencias_entre_capas(archivos: dict[str, str]) -> dict[tuple[str, str], int]:
    """Cuántas veces una capa nombra a otra por `class_name`.

    **Limpia el texto igual que el gate y busca el identificador como palabra**, y las dos cosas
    importan. Sin limpiar, un `class_name` nombrado en un comentario cuenta como referencia: la
    primera versión de esto reportó tres de `dominio/` a `sistemas/` —que el gate pone en rojo—
    sobre un repo con el nodo `capas` en verde. Una herramienta que contradice al gate se deja
    de mirar el mismo día.

    Sin el borde de palabra, un nombre que es prefijo de otro se cuenta dos veces.
    """
    indice = indice_de_class_names(archivos, CAPAS)
    cuenta: dict[tuple[str, str], int] = defaultdict(int)
    for ruta, texto in archivos.items():
        origen = capa_de(ruta, CAPAS)
        if origen is None:
            continue
        limpio = _sin_comentarios_ni_strings(texto)
        for clase, destino in indice.items():
            if destino == origen:
                continue
            if re.search(rf"(?<![\w]){re.escape(clase)}(?![\w])", limpio):
                cuenta[(origen, destino)] += 1
    return cuenta


def _capas_con_archivos(archivos: dict[str, str]) -> list[tuple[str, list[str]]]:
    orden = []
    for capa, _ in CAPAS:
        suyos = sorted(r for r in archivos if capa_de(r, CAPAS) == capa)
        orden.append((capa, suyos))
    return orden


def imprimir_arbol(archivos: dict[str, str], con_clases: bool) -> None:
    indice = indice_de_class_names(archivos, CAPAS)
    por_archivo: dict[str, list[str]] = defaultdict(list)
    for clase, _ in indice.items():
        for ruta, texto in archivos.items():
            if f"class_name {clase}" in texto:
                por_archivo[ruta].append(clase)

    for capa, suyos in _capas_con_archivos(archivos):
        declaradas = sorted(CARPETAS_POR_CAPA.get(capa, frozenset()))
        print(f"\n{capa}/  —  {len(suyos)} scripts")
        print(f"  carpetas que admite: {', '.join(declaradas) or '(ninguna)'}")
        for carpeta, rutas in sorted(_por_carpeta(suyos).items()):
            # La carpeta que el gate no declara se marca acá y se cobra allá: este script
            # informa, y el veredicto es de `gate_de_capas.py`.
            fuera = "" if carpeta == "·" or carpeta in declaradas else "  ← NO DECLARADA"
            print(f"  {carpeta}/  ({len(rutas)}){fuera}")
            if not con_clases:
                continue
            for ruta in rutas:
                for clase in sorted(por_archivo.get(ruta, [])):
                    print(f"      {clase:<28} {ruta}")


def imprimir_grafo(archivos: dict[str, str], mermaid: bool) -> None:
    cuenta = _referencias_entre_capas(archivos)
    print("\nReferencias entre capas —la flecha va de quien nombra a quien es nombrado—:")
    if mermaid:
        print("\n```mermaid\nflowchart RL")
        for capa, _ in CAPAS:
            print(f'  {capa.split("/")[1]}["{capa}/"]')
        for (origen, destino), veces in sorted(cuenta.items()):
            print(f'  {origen.split("/")[1]} -- "{veces}" --> {destino.split("/")[1]}')
        print("```")
        return
    if not cuenta:
        print("  (ninguna todavía)")
        return
    for (origen, destino), veces in sorted(cuenta.items()):
        print(f"  {origen:<14} → {destino:<14} {veces}")


def imprimir_capacidades() -> None:
    specs = specs_del_repo()
    if not specs:
        return
    print("\nCapacidades —el contrato de cada una, en `specs/`—:")
    for spec in specs:
        print(
            f"  {spec.nombre:<20} {spec.codigo:<4} {spec.estado:<10} "
            f"{len(spec.reglas):>2} reglas · {len(spec.criterios):>2} criterios"
        )


def main() -> int:
    archivos = _fuentes()
    if not archivos:
        print("no hay un solo `.gd` en `src/` todavía: nada que mapear.")
        return 0

    imprimir_arbol(archivos, "--clases" in sys.argv)
    imprimir_grafo(archivos, "--mermaid" in sys.argv)
    imprimir_capacidades()

    # El veredicto no es de este script: lo da `gate_de_capas.py`. Acá se nombra para que quien
    # vea una flecha rara sepa quién la cobra.
    contra_mano = violaciones(archivos, CAPAS)
    if contra_mano:
        print(f"\n{len(contra_mano)} referencias van contra la dirección. Las cobra el nodo `capas`.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
