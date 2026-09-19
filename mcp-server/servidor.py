"""El servidor MCP de este repo: `nosefia-index`.

    python mcp-server/servidor.py        # lo levanta Claude Code por `.mcp.json`, no a mano

Expone el código como herramientas para gastar menos consultas explorando: dónde está un
símbolo, quién lo usa, qué se mueve si lo tocás, qué declara una escena y qué criterio no tiene
test.

## Por qué está escrito a mano y sin dependencias

El servidor de las referencias es TypeScript con el SDK oficial y su propio `package.json`. Acá
la regla del harness es **sin una sola dependencia**: `python archivo.py` alcanza en un clone
recién hecho.

MCP sobre stdio es JSON-RPC 2.0 con un objeto por línea. Implementar `initialize`, `tools/list`
y `tools/call` son ochenta líneas de biblioteca estándar, y a cambio no hay `install` que correr
por worktree, ni un `dist/` compilado que se puede separar de su fuente.

## Las dos reglas del stdio

1. **Nada que no sea un mensaje va a `stdout`.** Un `print` de depuración rompe el protocolo, y
   el síntoma es un servidor que «no conecta». Lo que haya que decir va a `stderr`.
2. **Un error de una herramienta se contesta, no se propaga.** Un `raise` mata el servidor y se
   lleva la sesión; el error vuelve como texto, que es lo que el agente puede leer y corregir.
"""

import json
import sys
import traceback
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import herramientas  # noqa: E402

VERSION_DEL_PROTOCOLO = "2025-06-18"
NOMBRE = "nosefia-index"

#: Cada herramienta con su esquema. El orden es el de utilidad: `mapa_del_sistema` primero
#: porque es la consulta con la que conviene empezar cualquier tarea.
TOOLS: list[dict] = [
    {
        "name": "mapa_del_sistema",
        "description": (
            "La primera consulta de cualquier tarea. Las cuatro capas de `src/`, qué puede "
            "referenciar cada una, qué subcarpetas admite, y las capacidades con su contrato y "
            "su estado."
        ),
        "inputSchema": {"type": "object", "properties": {}},
        "fn": lambda a: herramientas.mapa_del_sistema(),
    },
    {
        "name": "buscar_simbolo",
        "description": (
            "Busca un `class_name`, función, constante, señal o enum por parte de su nombre, sin "
            "distinguir mayúsculas. Para texto que NO es un símbolo —un mensaje, una ruta— va `rg`."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "texto": {"type": "string", "description": "Parte del nombre, ej: 'consecuencia'."},
                "clase": {
                    "type": "string",
                    "enum": ["class_name", "func", "const", "enum", "signal", "var"],
                    "description": "Filtro opcional por qué clase de símbolo es.",
                },
            },
            "required": ["texto"],
        },
        "fn": lambda a: herramientas.buscar_simbolo(a["texto"], a.get("clase", "")),
    },
    {
        "name": "quien_usa",
        "description": (
            "Quién nombra un símbolo, con archivo y línea. Pide el nombre EXACTO. En Godot un "
            "`class_name` se nombra sin escribir una ruta, así que esto es lo que ningún análisis "
            "de imports contesta. Distingue tres casos: tiene usos, existe sin usos, o no existe."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {"simbolo": {"type": "string", "description": "Nombre exacto."}},
            "required": ["simbolo"],
        },
        "fn": lambda a: herramientas.quien_usa(a["simbolo"]),
    },
    {
        "name": "contexto_de_archivo",
        "description": (
            "Qué declara un `.gd`, a quién nombra, quién lo nombra y si tiene su test espejo. La "
            "ruta va relativa a la raíz, con `/`."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {"ruta": {"type": "string", "description": "ej: src/dominio/reglas.gd"}},
            "required": ["ruta"],
        },
        "fn": lambda a: herramientas.contexto_de_archivo(a["ruta"]),
    },
    {
        "name": "impacto_de_tocar",
        "description": (
            "Qué se mueve si tocás un `.gd`: quién lo nombra, de qué capa es cada uno, y qué "
            "escenas lo cuelgan. Las escenas importan porque un `.tscn` no se mergea."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {"ruta": {"type": "string"}},
            "required": ["ruta"],
        },
        "fn": lambda a: herramientas.impacto_de_tocar(a["ruta"]),
    },
    {
        "name": "contexto_de_escena",
        "description": (
            "Qué declara un `.tscn`: sus nodos, los scripts que cuelga, las escenas que "
            "instancia, su `node_paths`, y qué `@export` de tipo `Node` puede quedar en `null`. "
            "Ese caso carga la escena sin un solo error y mata el juego en el primer cuadro."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {"ruta": {"type": "string", "description": "ej: src/escenas/almacen.tscn"}},
            "required": ["ruta"],
        },
        "fn": lambda a: herramientas.contexto_de_escena(a["ruta"]),
    },
    {
        "name": "quien_instancia",
        "description": (
            "Qué escenas instancian a una escena. Es lo que decide si dos issues se pueden "
            "paralelizar: un merge de tres vías sobre un `.tscn` da una escena corrupta."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {"ruta": {"type": "string"}},
            "required": ["ruta"],
        },
        "fn": lambda a: herramientas.quien_instancia(a["ruta"]),
    },
    {
        "name": "criterio",
        "description": (
            "Un criterio de aceptación por su ID `AC-<COD>-###`: su texto, la regla que verifica, "
            "y qué test lo cita. Sin cita, sobre un spec `ratified`, el nodo `specs` da rojo."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {"id": {"type": "string", "description": "ej: AC-EMP-004"}},
            "required": ["id"],
        },
        "fn": lambda a: herramientas.criterio(a["id"]),
    },
    {
        "name": "donde_vive_el_numero",
        "description": (
            "Dónde está declarada una constante de balance y quién la lee. El número exacto sale "
            "del dominio y nunca de un documento: esto lo hace barato de verificar."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "nombre": {"type": "string", "description": "ej: APERCIBIMIENTOS, COSTO, DURACION"}
            },
            "required": ["nombre"],
        },
        "fn": lambda a: herramientas.donde_vive_el_numero(a["nombre"]),
    },
    {
        "name": "sin_test",
        "description": (
            "Qué `.gd` de `dominio/` y `sistemas/` no tiene test espejo, y qué criterio no tiene "
            "ningún test que lo cite. Lista, no juzga: el veredicto es de los gates."
        ),
        "inputSchema": {"type": "object", "properties": {}},
        "fn": lambda a: herramientas.sin_test(),
    },
]

_POR_NOMBRE = {t["name"]: t for t in TOOLS}


def _publicas() -> list[dict]:
    """Las tools como las ve el cliente: sin el `fn`, que es cableado nuestro."""
    return [{k: v for k, v in t.items() if k != "fn"} for t in TOOLS]


def ejecutar(nombre: str, argumentos: dict) -> tuple[str, bool]:
    """Corre una herramienta y devuelve su texto y si fue error.

    **Un fallo se contesta, no se propaga.** Un `raise` acá mata el servidor y se lleva la
    sesión; devuelto como texto, el agente lo lee y corrige la llamada.
    """
    tool = _POR_NOMBRE.get(nombre)
    if tool is None:
        return f"No existe la herramienta `{nombre}`. Las que hay: {', '.join(_POR_NOMBRE)}.", True
    try:
        return tool["fn"](argumentos or {}), False
    except Exception:
        return f"La herramienta `{nombre}` falló:\n{traceback.format_exc()}", True


def responder(peticion: dict) -> dict | None:
    """La respuesta a un mensaje, o `None` si es una notificación —que no lleva respuesta—."""
    metodo = peticion.get("method")
    identificador = peticion.get("id")

    if metodo == "initialize":
        resultado = {
            "protocolVersion": VERSION_DEL_PROTOCOLO,
            "capabilities": {"tools": {}},
            "serverInfo": {"name": NOMBRE, "version": "1.0.0"},
        }
    elif metodo == "tools/list":
        resultado = {"tools": _publicas()}
    elif metodo == "tools/call":
        parametros = peticion.get("params") or {}
        texto, fallo = ejecutar(parametros.get("name", ""), parametros.get("arguments") or {})
        resultado = {"content": [{"type": "text", "text": texto}], "isError": fallo}
    elif metodo == "ping":
        resultado = {}
    elif identificador is None:
        # Una notificación —`notifications/initialized`, por ejemplo— no se contesta.
        return None
    else:
        return {
            "jsonrpc": "2.0",
            "id": identificador,
            "error": {"code": -32601, "message": f"método desconocido: {metodo}"},
        }

    if identificador is None:
        return None
    return {"jsonrpc": "2.0", "id": identificador, "result": resultado}


def main() -> int:
    # **El protocolo es UTF-8, y en Windows el default no lo es.** Sin esto, la primera
    # respuesta con un acento sale en cp1252 y el cliente la descarta con un error de decodificación
    # que no nombra ni al encoding ni a este archivo: se lee como «el servidor no conecta». Es la
    # misma trampa que `lib/consola.py` cierra para los scripts, acá sobre el canal del protocolo.
    sys.stdin.reconfigure(encoding="utf-8")
    sys.stdout.reconfigure(encoding="utf-8", newline="\n")

    for linea in sys.stdin:
        linea = linea.strip()
        if not linea:
            continue
        try:
            peticion = json.loads(linea)
        except json.JSONDecodeError as error:
            print(f"mensaje ilegible: {error}", file=sys.stderr)
            continue
        respuesta = responder(peticion)
        if respuesta is not None:
            # `stdout` es sólo del protocolo: cualquier otra cosa acá lo rompe.
            sys.stdout.write(json.dumps(respuesta, ensure_ascii=False) + "\n")
            sys.stdout.flush()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
