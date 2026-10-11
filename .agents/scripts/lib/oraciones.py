"""El largo de las oraciones de la prosa de un `.md`.

La directriz de lenguaje pone un techo de palabras por oración, y un número fijo no se cobra en
una revisión: se cobra acá. Este módulo parte un `.md` en oraciones y cuenta las palabras de
cada una. El techo no vive acá: lo pasa quien llama.

Lo que no es prosa se saltea: el frontmatter, los bloques de código, las tablas y los títulos.
El código entre comillas invertidas cuenta como una palabra: `gate_de_capas.py` es un nombre. Un
enlace cuenta por su texto, nunca por su URL.

Una oración que sigue en la línea siguiente cuenta entera: los docs van cortados a 100
columnas, y contar por línea no mediría nada. Un ítem de lista es una oración aparte del texto
que lo introduce.

Una abreviatura con punto, como «p. ej.», no corta la oración. Un punto seguido de minúscula
tampoco: en español, una oración nueva arranca con mayúscula.
"""

import re
from collections.abc import Callable
from dataclasses import dataclass

#: Las abreviaturas con punto que no terminan una oración aunque las siga una mayúscula. «etc.»
#: no está: seguido de mayúscula, sí la termina.
ABREVIATURAS = ("p. ej.", "e. g.", "vs.", "Sr.", "Sra.", "N.º")

_CERCO = re.compile(r"^\s*(```|~~~)")
_TITULO = re.compile(r"^\s*#{1,6}\s")
_TABLA = re.compile(r"^\s*\|")
_ITEM = re.compile(r"^\s*(?:[-*+]|\d+[.)])\s+")
_CODIGO = re.compile(r"`+[^`]*`+")
_ENLACE = re.compile(r"!?\[([^\]]*)\]\([^)]*\)")
_ENFASIS = re.compile(r"\*+")
#: El fin de una oración: un signo de cierre, lo que lo cierra —comillas, paréntesis— y un blanco
#: seguido de algo que no es minúscula.
_FIN = re.compile(r"(?<=[.!?…])[»”\")\]]*\s+(?=[^\sa-záéíóúüñ])")
_PALABRA = re.compile(r"\w")
#: Lo que reemplaza al código en línea. No lleva punto, así que no corta ninguna oración.
_MARCA = "CODIGO"


@dataclass(frozen=True)
class Oracion:
    linea: int
    palabras: int
    texto: str


def _bloques(texto: str) -> list[tuple[int, str]]:
    """Los párrafos y los ítems de prosa, unidos con `\\n`, con la línea donde arranca cada uno."""
    lineas = texto.splitlines()
    inicio = 0
    if lineas and lineas[0].strip() == "---":
        cierre = next((i for i in range(1, len(lineas)) if lineas[i].strip() == "---"), None)
        if cierre is not None:
            inicio = cierre + 1

    bloques: list[tuple[int, list[str]]] = []
    actual: list[tuple[int, list[str]]] = []
    en_codigo = False
    for i in range(inicio, len(lineas)):
        linea = lineas[i]
        if _CERCO.match(linea):
            actual.clear()
            en_codigo = not en_codigo
            continue
        if en_codigo or not linea.strip() or _TITULO.match(linea) or _TABLA.match(linea):
            actual.clear()
            continue
        item = _ITEM.match(linea)
        if item or not actual:
            bloque = (i + 1, [linea[item.end() :] if item else linea])
            bloques.append(bloque)
            actual[:] = [bloque]
        else:
            actual[0][1].append(linea)
    return [(n, "\n".join(parte.strip() for parte in partes)) for n, partes in bloques]


def _conservando_saltos(reemplazo: str) -> Callable[[re.Match[str]], str]:
    """Un reemplazo que conserva los saltos de línea, para no perder la línea de cada oración."""
    return lambda m: reemplazo.format(*m.groups()) + "\n" * m.group(0).count("\n")


def _limpio(bloque: str) -> str:
    bloque = _CODIGO.sub(_conservando_saltos(_MARCA), bloque)
    bloque = _ENLACE.sub(_conservando_saltos("{0}"), bloque)
    bloque = _ENFASIS.sub("", bloque)
    for abreviatura in ABREVIATURAS:
        bloque = bloque.replace(abreviatura, abreviatura.replace(".", "").replace(" ", ""))
    return bloque


def contar_palabras(oracion: str) -> int:
    return sum(1 for token in oracion.split() if _PALABRA.search(token))


def oraciones(texto: str) -> list[Oracion]:
    """Las oraciones de prosa de un `.md`, cada una con la línea donde arranca."""
    resultado: list[Oracion] = []
    for primera, bloque in _bloques(texto):
        limpio = _limpio(bloque)
        desde = 0
        cortes = [m.end() for m in _FIN.finditer(limpio)] + [len(limpio)]
        for hasta in cortes:
            parte = limpio[desde:hasta]
            if parte.strip():
                linea = primera + limpio[: desde + len(parte) - len(parte.lstrip())].count("\n")
                resultado.append(Oracion(linea, contar_palabras(parte), " ".join(parte.split())))
            desde = hasta
    return resultado


def largas(texto: str, techo: int) -> list[Oracion]:
    """Las oraciones que pasan de `techo` palabras."""
    return [o for o in oraciones(texto) if o.palabras > techo]
