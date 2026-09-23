"""Leer los specs de capacidad: su forma, sus IDs y qué test los nombra.

Un spec es `specs/<capability>/<capability>.md`, con frontmatter y dos familias de IDs
tipados: `BR-<COD>-###` para las reglas y `AC-<COD>-###` para los criterios.

**Por qué se parsea a mano y sin YAML.** El harness no tiene dependencias fuera de la
biblioteca estándar y gdtoolkit, y agregar una para leer cinco campos escalares pondría un
`pip install` entre un repo recién clonado y el primer `verificar.py`. El frontmatter de un
spec es plano a propósito: si algún día deja de serlo, el que cambia es el formato.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path

from lib.repo import RAIZ

SPECS = RAIZ / "specs"

#: Los directorios de `specs/` que no son capacidades. Empiezan con `_` por eso mismo.
NO_ES_CAPACIDAD = ("_",)

#: Los tres estados de un spec, en orden de ciclo de vida.
#:
#: `draft` es «escrito, con criterios que todavía ningún test nombra». `ratified` es la
#: afirmación fuerte y la que el gate cobra: **todos** sus criterios tienen test. `superseded`
#: es un spec que otro reemplazó, y se queda en el árbol porque es lo que explica por qué el
#: código tiene la forma que tiene.
ESTADOS: tuple[str, ...] = ("draft", "ratified", "superseded")

#: Los archivos del régimen viejo. Un spec era tres archivos y un mapa; ahora es un contrato y
#: un issue, y estos nombres vueltos a aparecer son el régimen viejo volviendo por la ventana.
PROHIBIDOS = ("spec.md", "research.md", "plan.md", "tasks.md")

_FRONTMATTER = re.compile(r"\A---\r?\n(.*?)\r?\n---\r?\n", re.DOTALL)
_CAMPO = re.compile(r"^([a-z_]+):\s*(.*?)\s*$")

#: El código de tres letras mayúsculas que identifica a la capacidad adentro de cada ID.
_CAPABILITY_ID = re.compile(r"^CAP-([A-Z]{3})$")

#: Un encabezado de regla o de criterio: `### BR-CHK-001 — nombre`.
_ENCABEZADO = re.compile(r"^###\s+((?:BR|AC)-[A-Z]{3}-\d{3})\b(.*)$", re.MULTILINE)

#: Las reglas que un criterio dice verificar: `*(verifica BR-CHK-001, BR-CHK-002)*`.
_VERIFICA = re.compile(r"BR-[A-Z]{3}-\d{3}")


@dataclass
class Spec:
    ruta: Path
    codigo: str = ""
    estado: str = ""
    reglas: list[str] = field(default_factory=list)
    criterios: dict[str, list[str]] = field(default_factory=dict)
    #: Lo que está mal de su forma. Viaja **adentro** del spec y no como un segundo valor de
    #: retorno: el gate lo junta de nueve archivos, y un spec ilegible tiene que aparecer en el
    #: reporte al lado de los demás en vez de llevarse puesta la corrida.
    problemas: list[str] = field(default_factory=list)

    @property
    def nombre(self) -> str:
        return self.ruta.parent.name


def _frontmatter(texto: str) -> dict[str, str]:
    bloque = _FRONTMATTER.match(texto)
    if bloque is None:
        return {}
    campos: dict[str, str] = {}
    for linea in bloque.group(1).splitlines():
        # El comentario de la plantilla explica el ciclo de vida al lado del valor, así que
        # cortarlo es parte de leer el campo y no una tolerancia de más.
        campo = _CAMPO.match(linea.split("#", 1)[0])
        if campo is not None:
            campos[campo.group(1)] = campo.group(2)
    return campos


def leer_spec(ruta: Path, texto: str) -> Spec:
    """El spec, con lo que está mal de su forma adentro."""
    spec = Spec(ruta)
    problemas = spec.problemas
    campos = _frontmatter(texto)
    if not campos:
        problemas.append(f"{_relativa(ruta)}: no tiene frontmatter")
        return spec

    identidad = _CAPABILITY_ID.match(campos.get("capability_id", ""))
    if identidad is None:
        problemas.append(
            f"{_relativa(ruta)}: `capability_id` tiene que ser `CAP-XXX` con tres mayúsculas, "
            f"y dice `{campos.get('capability_id', '')}`"
        )
    else:
        spec.codigo = identidad.group(1)

    spec.estado = campos.get("status", "")
    if spec.estado not in ESTADOS:
        problemas.append(
            f"{_relativa(ruta)}: `status` es uno de {', '.join(ESTADOS)}, y dice "
            f"`{spec.estado}`"
        )

    for encabezado in _ENCABEZADO.finditer(texto):
        identificador = encabezado.group(1)
        if "retirad" in encabezado.group(2).lower():
            problemas.append(
                f"{_relativa(ruta)}: `{identificador}` está retirado. Retirar es borrar: sale "
                "entero, con su test, y el número queda como hueco"
            )
        if spec.codigo and not identificador.startswith(("BR-" + spec.codigo, "AC-" + spec.codigo)):
            problemas.append(
                f"{_relativa(ruta)}: `{identificador}` no lleva el código de la capacidad "
                f"(`{spec.codigo}`)"
            )
        if identificador.startswith("BR-"):
            destino: list = spec.reglas
            if identificador in spec.reglas:
                problemas.append(f"{_relativa(ruta)}: `{identificador}` está dos veces")
            destino.append(identificador)
            continue
        if identificador in spec.criterios:
            problemas.append(f"{_relativa(ruta)}: `{identificador}` está dos veces")
        spec.criterios[identificador] = _VERIFICA.findall(encabezado.group(2))

    return spec


def specs_del_repo() -> list[Spec]:
    """Un spec por capacidad. Los de forma rota entran igual: quien los juzga es el gate."""
    encontrados: list[Spec] = []
    for carpeta in sorted(p for p in SPECS.glob("*") if p.is_dir()):
        if carpeta.name.startswith(NO_ES_CAPACIDAD):
            continue
        archivo = carpeta / f"{carpeta.name}.md"
        if not archivo.is_file():
            continue
        encontrados.append(leer_spec(archivo, archivo.read_text(encoding="utf-8")))
    return encontrados


def ids_citados(arboles: tuple[Path, ...]) -> set[str]:
    """Los `AC-XXX-###` que algún archivo de test nombra, en cualquier posición de la línea.

    Son dos árboles porque este repo tiene dos suites: gdUnit4 sobre el juego y `unittest`
    sobre el harness. Un criterio puede caer entero de cualquiera de los dos lados.
    """
    citados: set[str] = set()
    patron = re.compile(r"AC-[A-Z]{3}-\d{3}")
    for arbol in arboles:
        if not arbol.is_dir():
            continue
        for archivo in arbol.rglob("*"):
            if archivo.is_file() and archivo.suffix in (".gd", ".py"):
                citados |= set(patron.findall(archivo.read_text(encoding="utf-8", errors="replace")))
    return citados


def _relativa(ruta: Path) -> str:
    """La ruta como se lee en un mensaje. Una de afuera del repo se imprime entera en vez de
    romper: los tests arman specs en un temporal, y un `ValueError` ahí no dice nada."""
    try:
        return ruta.relative_to(RAIZ).as_posix()
    except ValueError:
        return ruta.as_posix()
