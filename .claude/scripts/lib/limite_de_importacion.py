"""El límite de lado con que Godot importa cada textura que extrae del `.glb`.

Godot extrae al lado del `.glb` cada imagen que cambió y le crea su `.import` con
`process/size_limit=0`, que para él es «sin límite». Hasta ahora alguien lo corregía a mano en un
commit aparte (`f44d521c`), y un `.import` regenerado lo devolvía a 0. Acá sale de una sola
cuenta: el paso de `exportar_modelo.py` que corre después de reimportar le pone a cada textura sin
límite el de su grupo, que es el que vigila `test_texturas_del_modelo.py`.

Nada de acá toca el disco: son cuentas sobre el texto de un `.import`, y por eso se prueban sin
Godot.
"""

from __future__ import annotations

import re
from collections.abc import Collection

from lib import atlas
from lib.blender import LADO_TOPE

_LIMITE = re.compile(r"^process/size_limit=(\d+)\s*$", re.MULTILINE)


def es_una_textura(texto: str) -> bool:
    """Si el `.import` es de una textura y no de un modelo, un audio u otra cosa."""
    return 'importer="texture"' in texto


def limite_declarado(texto: str) -> int | None:
    """El `process/size_limit` de un `.import`, o `None` si no lo declara."""
    encontrado = _LIMITE.search(texto)
    return None if encontrado is None else int(encontrado.group(1))


def limite_de(nombre: str, atlas_del_modelo: Collection[str]) -> int:
    """El lado más grande que puede tener una textura del modelo, por su nombre sin extensión.

    Un atlas junta muchas etiquetas, cada una con el lado de su grupo, y su tope es el de
    `lib.atlas`: achicarlo a `LADO_TOPE` achicaría cada etiqueta que lleva adentro.
    """
    return atlas.TOPE if nombre in atlas_del_modelo else LADO_TOPE


def con_el_limite(texto: str, limite: int) -> str:
    """El `.import` con `process/size_limit` en `limite` si no tenía ninguno, o lo tenía en 0.

    Uno que ya declara un límite se devuelve igual: lo decidió alguien y no se pisa.
    """
    actual = limite_declarado(texto)
    if actual is None:
        raise ValueError("el .import no declara process/size_limit: no es el de una textura")
    if actual != 0:
        return texto
    return _LIMITE.sub(f"process/size_limit={limite}", texto, count=1)
