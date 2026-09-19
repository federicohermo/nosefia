"""Que un `@export` de tipo `Node` llegue resuelto, y no en `null`.

Es la única falla conocida acá que **carga la escena sin un solo error, deja los siete nodos en
verde, y mata el juego en el primer cuadro** con un mensaje que no nombra ni al `.tscn` ni al
`@export`: `Invalid call. Nonexistent function 'x' in base 'Nil'`.

La causa: el motor guarda el valor de un `@export var x: Node` como un `NodePath`, y **sólo lo
resuelve si el nodo declara además la lista `node_paths`**. El editor de Godot la escribe sola;
una escena editada a mano, no. El `@export` llega en `null` y nada avisa hasta que alguien lo
llama.

Este módulo decide; no toca el disco. Lo ejerce el harness.
"""

from __future__ import annotations

import re

#: Un `[node …]` de un `.tscn`, con su línea entera: de ahí salen el nombre y el `node_paths`.
_NODO = re.compile(r"^\[node\s+name=\"([^\"]+)\"(.*)\]$", re.MULTILINE)
#: La lista que hace que el motor resuelva los `NodePath` de ese nodo.
_NODE_PATHS = re.compile(r"node_paths=PackedStringArray\(([^)]*)\)")
#: Una propiedad que vale un `NodePath`, suelto o adentro de un arreglo.
_ASIGNA_NODEPATH = re.compile(r"^(\w+)\s*=\s*\[?\s*NodePath\(", re.MULTILINE)
#: Un `@export` cuyo tipo es un `Node`, que es el caso que el motor guarda como `NodePath`.
_EXPORT = re.compile(r"^@export\s+var\s+(\w+)\s*:\s*(?:Array\[)?([\w.]+)", re.MULTILINE)
#: El script que cuelga de un `[node]`, por el `id` del `ext_resource` que lo declara.
_EXT_SCRIPT = re.compile(r"\[ext_resource type=\"Script\"[^\]]*path=\"([^\"]+)\"[^\]]*id=\"([^\"]+)\"")
_SCRIPT_DEL_NODO = re.compile(r"^script\s*=\s*ExtResource\(\"([^\"]+)\"\)", re.MULTILINE)


def _bloques(texto: str) -> list[tuple[str, str, str]]:
    """Cada `[node]` con su encabezado y el cuerpo que le sigue hasta el corchete siguiente."""
    salida = []
    encontrados = list(_NODO.finditer(texto))
    for i, m in enumerate(encontrados):
        fin = encontrados[i + 1].start() if i + 1 < len(encontrados) else len(texto)
        salida.append((m.group(1), m.group(2), texto[m.end() : fin]))
    return salida


def exports_sin_declarar(
    escenas: dict[str, str], fuentes: dict[str, str]
) -> list[tuple[str, str, str]]:
    """Los `(escena, nodo, propiedad)` que el motor va a dejar en `null`.

    Se reporta una propiedad **sólo si la escena le asigna un `NodePath`**: una que no se
    asigna se resuelve por código y no tiene por qué estar en la lista. Queda afuera el
    `@export` declarado `NodePath`, que guarda la ruta como valor y no necesita resolverse.
    """
    hallazgos = []
    for ruta, texto in escenas.items():
        por_id = {i: p for p, i in _EXT_SCRIPT.findall(texto)}
        for nombre, encabezado, cuerpo in _bloques(texto):
            script = _SCRIPT_DEL_NODO.search(cuerpo)
            if script is None:
                continue
            fuente = fuentes.get(por_id.get(script.group(1), "").removeprefix("res://"))
            if fuente is None:
                continue
            # **La regla es por lo que NO es.** El tipo de un `@export` de escena es casi
            # siempre un `class_name` propio —`Hud`, `RelojDelTurno`—, así que mirar si el
            # nombre parece de Godot no sirve. Lo que sí se sabe: un `@export` declarado
            # `NodePath` guarda la ruta **como valor** y no necesita resolverse. Todo lo demás
            # que reciba un `NodePath` es una referencia, y sin la lista llega en `null`.
            de_nodo = {
                var
                for var, tipo in _EXPORT.findall(fuente)
                if tipo != "NodePath"
            }
            declaradas = set()
            lista = _NODE_PATHS.search(encabezado)
            if lista:
                declaradas = {n.strip().strip('"') for n in lista.group(1).split(",") if n.strip()}
            for propiedad in _ASIGNA_NODEPATH.findall(cuerpo):
                if propiedad in de_nodo and propiedad not in declaradas:
                    hallazgos.append((ruta, nombre, propiedad))
    return sorted(hallazgos)
