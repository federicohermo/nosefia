"""Lo que el servidor MCP contesta. Funciones puras sobre el árbol del repo.

## Por qué no hay un índice en disco

El `inventario-index` de las referencias compila un índice a `.index/` y cada respuesta declara
el commit con el que se generó, porque un índice envejece: un archivo nuevo es invisible y un
símbolo renombrado conserva el nombre viejo hasta regenerar.

**Acá no hace falta y por eso no está.** `src/` son 96 `.gd` y 18 `.tscn`: leer el árbol entero
cuesta milisegundos, así que cada respuesta mira el disco de ahora. Se pierde el paso
`pnpm index` que hay que acordarse de correr, y con él se pierde el modo de falla entero —una
respuesta vieja que parece fresca—.

## Y no reimplementa el índice de clases

Lo importa de `lib/capas.py`, que es el mismo que usa `gate_de_capas.py`. Una herramienta que
contesta distinto que el gate se deja de mirar el mismo día: ya pasó con `estructura.py`, que en
su primera versión dibujaba tres flechas que el gate pone en rojo.
"""

from __future__ import annotations

import json
import re
import sys
from collections import defaultdict
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(RAIZ / ".claude" / "scripts"))

from lib.archivos import escenas_tscn, scripts_gd  # noqa: E402
from lib.capas import (  # noqa: E402
    _sin_comentarios_ni_strings,
    capa_de,
    indice_de_class_names,
)
from lib.repo import CAPAS, CAPAS_CON_TEST_OBLIGATORIO, CARPETAS_POR_CAPA, TESTS  # noqa: E402
from lib.specs import ids_citados, specs_del_repo  # noqa: E402
from lib.tdd import SUFIJO_DE_TEST, ruta_de_test  # noqa: E402
from lib.tdd import violaciones as violaciones_de_tdd  # noqa: E402

#: Los símbolos que un `.gd` declara, y con qué los declara.
DECLARACIONES = (
    ("class_name", re.compile(r"^class_name\s+([A-Za-z_]\w*)", re.MULTILINE)),
    ("func", re.compile(r"^(?:static\s+)?func\s+([a-z_]\w*)", re.MULTILINE)),
    ("const", re.compile(r"^const\s+([A-Z_][A-Z0-9_]*)", re.MULTILINE)),
    ("enum", re.compile(r"^enum\s+([A-Za-z_]\w*)", re.MULTILINE)),
    ("signal", re.compile(r"^signal\s+([a-z_]\w*)", re.MULTILINE)),
    ("var", re.compile(r"^(?:@export\s+)?var\s+([a-z_]\w*)", re.MULTILINE)),
)

#: Un `ext_resource` de un `.tscn`: de ahí salen los scripts y las escenas que instancia.
_EXT_RESOURCE = re.compile(r'\[ext_resource type="(\w+)"[^\]]*path="(res://[^"]+)"')
_NODE = re.compile(r'\[node name="([^"]+)"(?:\s+type="(\w+)")?[^\]]*\]')
_NODE_PATHS = re.compile(r'node_paths=PackedStringArray\(([^)]*)\)')
_EXPORT = re.compile(r"^@export\s+var\s+(\w+)\s*:\s*([\w.]+)", re.MULTILINE)


def _fuentes() -> dict[str, str]:
    return scripts_gd(RAIZ, "src")


def _tests() -> dict[str, str]:
    return scripts_gd(RAIZ, TESTS)


def _escenas() -> dict[str, str]:
    """Las escenas con su contenido.

    **`escenas_tscn()` devuelve las rutas con el texto vacío, y eso es deliberado**: el gate sólo
    contesta con ellas el nombre de la carpeta, y su encabezado declara que el contenido no viaja
    para que nadie se lo pase a `violaciones()` —adentro de un `.tscn` de `escenas/` referenciar
    hacia abajo es correcto—. Acá el contenido sí hace falta, así que se lee de nuevo sin tocar
    ese contrato: la lista de rutas sigue saliendo de la misma función, con su filtro de
    ignorados.
    """
    return {
        ruta: (RAIZ / ruta).read_text(encoding="utf-8", errors="replace")
        for ruta in escenas_tscn(RAIZ, "src")
    }


def _simbolos_de(texto: str) -> list[tuple[str, str]]:
    """Cada símbolo declarado, con su clase. Sobre el texto limpio: un `func` nombrado en un
    comentario no es una declaración."""
    limpio = _sin_comentarios_ni_strings(texto)
    encontrados: list[tuple[str, str]] = []
    for clase, patron in DECLARACIONES:
        for nombre in patron.findall(limpio):
            encontrados.append((clase, nombre))
    return encontrados


def _menciones(
    nombre: str, archivos: dict[str, str], limpiar: bool = True
) -> list[tuple[str, int]]:
    """Dónde se nombra un identificador, como palabra.

    El borde de palabra no es cosmético: sin él `Tarea` matchea adentro de `TareaDeAtender`.

    **`limpiar` decide si un comentario cuenta, y las dos respuestas son correctas según qué se
    pregunte.** Para «quién usa este símbolo» un comentario no es un uso, así que se limpia. Para
    «qué test cita este criterio» la cita **vive en un comentario** —`# AC-EMP-004` al final de la
    línea—, así que limpiar la haría invisible: el primer humo de este servidor contestó «ningún
    test lo cita» sobre un criterio citado.
    """
    patron = re.compile(rf"(?<![\w]){re.escape(nombre)}(?![\w])")
    salida: list[tuple[str, int]] = []
    for ruta, texto in sorted(archivos.items()):
        cuerpo = _sin_comentarios_ni_strings(texto) if limpiar else texto
        for numero, linea in enumerate(cuerpo.splitlines(), 1):
            if patron.search(linea):
                salida.append((ruta, numero))
    return salida


# --------------------------------------------------------------------------------------- tools


def mapa_del_sistema() -> str:
    """La primera consulta: qué capas hay, qué carpeta admite cada una y qué capacidades existen."""
    archivos = _fuentes()
    indice = indice_de_class_names(archivos, CAPAS)
    lineas = ["# Mapa del sistema", ""]
    for capa, puede in CAPAS:
        suyos = [r for r in archivos if capa_de(r, CAPAS) == capa]
        clases = sorted(c for c, d in indice.items() if d == capa)
        lineas.append(f"## {capa}/  — {len(suyos)} scripts, {len(clases)} `class_name`")
        lineas.append(f"- puede referenciar: {', '.join(puede) or '(ninguna)'}")
        lineas.append(f"- carpetas que admite: {', '.join(sorted(CARPETAS_POR_CAPA[capa]))}")
        lineas.append("")
    lineas.append("## Capacidades — el contrato de cada una está en `specs/`")
    lineas.append("")
    for spec in specs_del_repo():
        lineas.append(
            f"- **{spec.nombre}** (`{spec.codigo}`, {spec.estado}): "
            f"{len(spec.reglas)} reglas, {len(spec.criterios)} criterios"
        )
    lineas.append("")
    lineas.append("Las reglas de cada capa se cargan solas al tocar sus archivos.")
    return "\n".join(lineas)


def buscar_simbolo(texto: str, clase: str = "") -> str:
    """Un símbolo por parte de su nombre, sin distinguir mayúsculas."""
    aguja = texto.lower()
    hallazgos: list[str] = []
    for ruta, contenido in sorted({**_fuentes(), **_tests()}.items()):
        for tipo, nombre in _simbolos_de(contenido):
            if clase and tipo != clase:
                continue
            if aguja in nombre.lower():
                hallazgos.append(f"- `{nombre}` ({tipo}) — {ruta}")
    if not hallazgos:
        return f"Ningún símbolo contiene «{texto}». Para texto que no es un símbolo, va `rg`."
    if len(hallazgos) > 60:
        return (
            f"{len(hallazgos)} coincidencias con «{texto}»: demasiadas para servir. "
            "Acotá el texto, o filtrá por clase con `clase`."
        )
    return "\n".join(hallazgos)


def quien_usa(simbolo: str) -> str:
    """Quién nombra un símbolo, con las tres respuestas distinguidas.

    En Godot un `class_name` se nombra **sin escribir una sola ruta**, así que esto es lo que
    ningún análisis de imports contesta.
    """
    fuentes, tests = _fuentes(), _tests()
    todos = {**fuentes, **tests}
    declara = [r for r, t in sorted(todos.items()) if any(n == simbolo for _, n in _simbolos_de(t))]
    usos = [(r, n) for r, n in _menciones(simbolo, todos) if r not in declara]

    if not declara and not usos:
        return f"`{simbolo}` no existe en `src/` ni en `{TESTS}/`. Revisá cómo se escribe."
    lineas = []
    if declara:
        lineas.append(f"Declarado en: {', '.join(declara)}")
    if not usos:
        lineas.append(
            "**Ningún archivo lo nombra.** Puede ser código muerto, o algo que sólo se usa "
            "desde un `.tscn` por `@export` — eso lo contesta `contexto_de_escena`."
        )
        return "\n".join(lineas)
    cuantos = len({r for r, _ in usos})
    lineas.append(f"Lo nombran {cuantos} archivo{'s' if cuantos > 1 else ''}:")
    lineas += [f"- {r}:{n}" for r, n in usos]
    return "\n".join(lineas)


def contexto_de_archivo(ruta: str) -> str:
    """Qué declara un `.gd`, a quién nombra, quién lo nombra y dónde está su test espejo."""
    archivos = {**_fuentes(), **_tests()}
    if ruta not in archivos:
        return f"No hay `{ruta}`. Las rutas son relativas a la raíz, con `/`."
    texto = archivos[ruta]
    capa = capa_de(ruta, CAPAS)
    indice = indice_de_class_names(_fuentes(), CAPAS)
    limpio = _sin_comentarios_ni_strings(texto)

    propios = _simbolos_de(texto)
    nombra = sorted(
        c
        for c in indice
        if c not in {n for _, n in propios}
        and re.search(rf"(?<![\w]){re.escape(c)}(?![\w])", limpio)
    )
    clases_propias = [n for t, n in propios if t == "class_name"]
    lo_nombran = sorted(
        {r for c in clases_propias for r, _ in _menciones(c, archivos) if r != ruta}
    )

    lineas = [f"# {ruta}", ""]
    if capa:
        lineas.append(f"Capa: `{capa}`")
    espejo = ruta_de_test(ruta, tuple(c for c, _ in CAPAS), TESTS) if capa else None
    if espejo:
        estado = "existe" if espejo in archivos else "**FALTA**"
        lineas.append(f"Test espejo: `{espejo}` — {estado}")
    lineas.append("")
    lineas.append("## Declara")
    lineas += [f"- `{n}` ({t})" for t, n in propios] or ["- (nada)"]
    lineas.append("")
    lineas.append("## Nombra")
    lineas += [f"- `{c}` ({indice[c]})" for c in nombra] or ["- (a nadie)"]
    lineas.append("")
    lineas.append("## Lo nombran")
    lineas += [f"- {r}" for r in lo_nombran] or ["- (nadie)"]
    return "\n".join(lineas)


def impacto_de_tocar(ruta: str) -> str:
    """Qué se mueve si tocás este archivo: quién lo nombra, qué escenas lo cuelgan, qué capacidad."""
    fuentes = _fuentes()
    if ruta not in fuentes:
        return f"No hay `{ruta}` en `src/`."
    clases = [n for t, n in _simbolos_de(fuentes[ruta]) if t == "class_name"]
    todos = {**fuentes, **_tests()}
    consumidores = sorted({r for c in clases for r, _ in _menciones(c, todos) if r != ruta})
    escenas = sorted(r for r, t in _escenas().items() if ruta in t)

    por_capa: dict[str, int] = defaultdict(int)
    for r in consumidores:
        por_capa[capa_de(r, CAPAS) or TESTS] += 1

    lineas = [f"# Impacto de tocar `{ruta}`", ""]
    lineas.append(f"Declara: {', '.join(f'`{c}`' for c in clases) or '(ningún class_name)'}")
    lineas.append("")
    lineas.append(f"## Lo nombran {len(consumidores)} archivos")
    lineas += [f"- {r} ({por_capa and capa_de(r, CAPAS) or TESTS})" for r in consumidores] or [
        "- (nadie)"
    ]
    lineas.append("")
    lineas.append("## Escenas que lo cuelgan")
    lineas += [f"- {r}" for r in escenas] or ["- (ninguna)"]
    if escenas:
        lineas.append("")
        lineas.append(
            "**Una escena no se mergea.** Dos issues que tocan la misma se ordenan, no se "
            "paralelizan."
        )
    return "\n".join(lineas)


def contexto_de_escena(ruta: str) -> str:
    """Qué declara un `.tscn`: sus nodos, sus scripts, sus `@export` y su `node_paths`.

    Es lo que ningún `grep` contesta bien, y donde viven los cuatro modos de falla que cargan la
    escena **sin un solo error** y matan el juego en el primer cuadro.
    """
    escenas = _escenas()
    if ruta not in escenas:
        return f"No hay `{ruta}`. Las escenas de este repo están en `src/escenas/` y `src/ui/`."
    texto = escenas[ruta]

    recursos = _EXT_RESOURCE.findall(texto)
    scripts = [p for t, p in recursos if t == "Script"]
    instancia = [p for t, p in recursos if t == "PackedScene"]
    nodos = _NODE.findall(texto)
    rutas_de_nodo = [
        n.strip().strip('"') for m in _NODE_PATHS.findall(texto) for n in m.split(",") if n.strip()
    ]

    lineas = [f"# {ruta}", ""]
    lineas.append(f"Nodos declarados: {len(nodos)}")
    lineas.append("")
    lineas.append("## Scripts que cuelga")
    lineas += [f"- {p}" for p in scripts] or ["- (ninguno)"]
    lineas.append("")
    lineas.append("## Escenas que instancia")
    lineas += [f"- {p}" for p in instancia] or ["- (ninguna)"]
    lineas.append("")
    lineas.append("## `node_paths` declarados")
    lineas += [f"- `{n}`" for n in rutas_de_nodo] or ["- (ninguno)"]

    # El cruce que importa: un `@export` de tipo Node sin su entrada en `node_paths` queda en
    # `null`, la escena carga sin un solo error, y el juego muere en el primer cuadro.
    faltantes: list[str] = []
    for p in scripts:
        local = p.removeprefix("res://")
        fuente = _fuentes().get(local)
        if fuente is None:
            continue
        for nombre, tipo in _EXPORT.findall(fuente):
            if tipo[0].isupper() and nombre not in rutas_de_nodo and tipo != "PackedScene":
                faltantes.append(f"`{nombre}: {tipo}` en {local}")
    if faltantes:
        lineas.append("")
        lineas.append("## Candidatos a quedar en `null`")
        lineas += [f"- {f}" for f in faltantes]
        lineas.append("")
        lineas.append(
            "Un `@export` de tipo `Node` necesita su nombre en `node_paths`. Sin él la escena "
            "carga **sin un solo error** y el juego muere en el primer cuadro. No todos son un "
            "bug: un `@export` que se asigna por código no va en la lista."
        )
    return "\n".join(lineas)


def quien_instancia(ruta: str) -> str:
    """Qué escenas instancian a ésta. Decide si dos issues se pueden paralelizar."""
    escenas = _escenas()
    if ruta not in escenas:
        return f"No hay `{ruta}`."
    padres = sorted(r for r, t in escenas.items() if r != ruta and ruta in t)
    if not padres:
        return f"Ninguna escena instancia a `{ruta}`: es una raíz, o entra por código."
    return "\n".join(
        [f"`{ruta}` la instancian {len(padres)} escenas:"]
        + [f"- {r}" for r in padres]
        + [
            "",
            "**Un `.tscn` no se mergea**: un merge de tres vías da una escena corrupta, no un "
            "conflicto. Dos issues que tocan cualquiera de éstas se ordenan.",
        ]
    )


def criterio(identificador: str) -> str:
    """Un `AC-<COD>-###`: su texto, la regla que verifica y qué test lo cita."""
    for spec in specs_del_repo():
        if identificador not in spec.criterios:
            continue
        texto = spec.ruta.read_text(encoding="utf-8")
        bloque = re.search(
            rf"^### {re.escape(identificador)}[^\n]*\n(.*?)(?=^### |\Z)",
            texto,
            re.MULTILINE | re.DOTALL,
        )
        citas = [
            f"{r}:{n}"
            for r, n in _menciones(
                identificador, {**_tests(), **_tests_del_harness()}, limpiar=False
            )
        ]
        lineas = [
            f"# {identificador} — capacidad `{spec.nombre}` ({spec.estado})",
            "",
            (bloque.group(1).strip() if bloque else "(sin texto)"),
            "",
            f"Verifica: {', '.join(f'`{r}`' for r in spec.criterios[identificador]) or '(ninguna)'}",
            "",
        ]
        if citas:
            lineas.append("Lo citan:")
            lineas += [f"- {c}" for c in citas]
        else:
            lineas.append(
                "**Ningún test lo cita.** Sobre un spec `ratified` eso es rojo en el nodo `specs`."
            )
        return "\n".join(lineas)
    return f"No hay un criterio `{identificador}`. Los IDs son `AC-<COD>-###`."


def _tests_del_harness() -> dict[str, str]:
    base = RAIZ / ".claude" / "scripts" / "tests"
    if not base.is_dir():
        return {}
    return {
        p.relative_to(RAIZ).as_posix(): p.read_text(encoding="utf-8", errors="replace")
        for p in base.rglob("*.py")
    }


def donde_vive_el_numero(nombre: str) -> str:
    """Dónde está declarada una constante de balance, y quién la lee.

    El número exacto sale del dominio y nunca de un documento: esto es lo que lo hace barato de
    verificar antes de escribirlo.
    """
    fuentes = _fuentes()
    declaraciones = []
    for ruta, texto in sorted(fuentes.items()):
        for linea in _sin_comentarios_ni_strings(texto).splitlines():
            m = re.match(rf"^const\s+({re.escape(nombre)}\w*)\s*:?=?\s*(.*)$", linea.strip())
            if m:
                declaraciones.append((ruta, m.group(1), m.group(2).lstrip(":= ").strip()))
    if not declaraciones:
        return f"Ninguna constante de `src/` empieza con «{nombre}»."
    lineas = []
    for ruta, const, valor in declaraciones:
        lectores = sorted({r for r, _ in _menciones(const, fuentes) if r != ruta})
        lineas.append(f"- `{const}` = `{valor}` — {ruta}")
        lineas.append(f"  la leen: {', '.join(lectores) or '(nadie más)'}")
    return "\n".join(lineas)


def sin_test() -> str:
    """Qué `.gd` no tiene espejo y qué criterio no tiene cita. El trabajo pendiente, derivado."""
    fuentes, tests = _fuentes(), _tests()
    # **Se le pregunta al gate, con sus mismos argumentos.** No es economía: una herramienta que
    # contesta distinto que el gate se deja de mirar el mismo día. La primera versión recorría
    # las cuatro capas y listaba `ui/` y `escenas/` como faltas de test, que es justo lo que el
    # gate NO pide — y habría empujado a los tests de humo que la regla de presentación prohíbe.
    faltan = [
        f"- {ruta} → {motivo}"
        for ruta, motivo in violaciones_de_tdd(fuentes, tests, CAPAS_CON_TEST_OBLIGATORIO, TESTS)
        if "falta" in motivo
    ]

    citados = ids_citados((RAIZ / TESTS, RAIZ / ".claude" / "scripts" / "tests"))
    lineas = ["# Lo que falta", "", "## Scripts sin test espejo"]
    lineas += faltan or ["- (ninguno)"]
    lineas.append("")
    lineas.append("## Criterios que ningún test cita")
    hubo = False
    for spec in specs_del_repo():
        sin = sorted(c for c in spec.criterios if c not in citados)
        if sin:
            hubo = True
            lineas.append(f"- **{spec.nombre}** ({spec.estado}): {', '.join(sin)}")
    if not hubo:
        lineas.append("- (ninguno)")
    lineas.append("")
    lineas.append("El veredicto lo dan `gate_de_tests.py` y `gate_de_specs.py`. Esto sólo lista.")
    return "\n".join(lineas)


# ------------------------------------------------------------------------------- tests y assets


def _casos_de(texto: str) -> list[tuple[str, str]]:
    """Cada `func test_…` de una suite, con la cita de criterio que lleva al final, si tiene."""
    casos: list[tuple[str, str]] = []
    for linea in texto.splitlines():
        if not linea.startswith("func test"):
            continue
        nombre = linea[len("func ") :].split("(")[0]
        cita = re.search(r"#\s*((?:AC-[A-Z]{3}-\d{3})(?:,\s*AC-[A-Z]{3}-\d{3})*)", linea)
        casos.append((nombre, cita.group(1) if cita else ""))
    return casos


def contexto_de_test(ruta: str) -> str:
    """Qué prueba una suite: sus casos, qué criterios cita y a qué script espeja."""
    tests = _tests()
    if ruta not in tests:
        return f"No hay `{ruta}`. Las suites viven en `{TESTS}/` y terminan en `{SUFIJO_DE_TEST}`."
    texto = tests[ruta]
    casos = _casos_de(texto)
    indice = indice_de_class_names(_fuentes(), CAPAS)
    limpio = _sin_comentarios_ni_strings(texto)
    ejerce = sorted(c for c in indice if re.search(rf"(?<![\w]){re.escape(c)}(?![\w])", limpio))

    # El espejo al revés: de `test/dominio/x_test.gd` sale `src/dominio/x.gd`.
    espejado = None
    if ruta.startswith(f"{TESTS}/") and ruta.endswith(SUFIJO_DE_TEST):
        resto = ruta[len(TESTS) + 1 : -len(SUFIJO_DE_TEST)]
        candidato = f"src/{resto}.gd"
        espejado = candidato if candidato in _fuentes() else f"{candidato} — **no existe**"

    citados = sorted({c for _, cita in casos for c in cita.split(", ") if c})
    lineas = [f"# {ruta}", ""]
    if espejado:
        lineas.append(f"Espeja a: `{espejado}`")
    lineas.append(f"Casos: {len(casos)}")
    lineas.append("")
    lineas.append("## Criterios que cita")
    lineas += [f"- `{c}`" for c in citados] or [
        "- (ninguno) — un criterio que ningún test nombra no está aceptado"
    ]
    lineas.append("")
    lineas.append("## Ejerce")
    lineas += [f"- `{c}` ({indice[c]})" for c in ejerce] or ["- (ninguna clase de `src/`)"]
    lineas.append("")
    lineas.append("## Casos")
    lineas += [f"- `{n}`" + (f"  → {c}" if c else "") for n, c in casos]
    return "\n".join(lineas)


def tests_de(ruta: str) -> str:
    """Qué suites prueban un script: su espejo, y las que nombran alguna de sus clases."""
    fuentes = _fuentes()
    if ruta not in fuentes:
        return f"No hay `{ruta}` en `src/`."
    tests = _tests()
    espejo = ruta_de_test(ruta, CAPAS_CON_TEST_OBLIGATORIO, TESTS)
    clases = [n for t, n in _simbolos_de(fuentes[ruta]) if t == "class_name"]
    indirectos = sorted({r for c in clases for r, _ in _menciones(c, tests)} - {espejo})

    lineas = [f"# Qué prueba a `{ruta}`", ""]
    if espejo is None:
        lineas.append(
            "Su capa **no lleva test obligatorio**: ahí probar pide el `scene_runner`, y exigirlo "
            "empuja a tests de humo que pasan sin ejercer nada."
        )
    elif espejo in tests:
        lineas.append(f"Espejo: `{espejo}`")
    else:
        lineas.append(f"Espejo: `{espejo}` — **FALTA**, y el nodo `tdd` lo cobra.")
    lineas.append("")
    lineas.append("## Otras suites que lo nombran")
    lineas += [f"- {r}" for r in indirectos] or ["- (ninguna)"]
    return "\n".join(lineas)


#: Los assets que Godot no importa. Llevan un `.gdignore` arriba, así que nadie los referencia
#: **por definición**: preguntar si están huérfanos no tiene sentido.
FUENTE_DE_ARTE = "assets/source/"


def _uid_de(ruta: str) -> str:
    """El `uid://` que el `.import` de un asset declara, o vacío."""
    importe = RAIZ / (ruta + ".import")
    if not importe.is_file():
        return ""
    texto = importe.read_text(encoding="utf-8", errors="replace")
    encontrado = re.search(r'uid="(uid://[a-z0-9]+)"', texto)
    return encontrado.group(1) if encontrado else ""


def _binarios_del_repo() -> dict[str, bytes]:
    """Los archivos donde una referencia puede estar **adentro de un binario**: `.res` y `.glb`."""
    salida: dict[str, bytes] = {}
    for base in (RAIZ / "assets", RAIZ / "src"):
        if not base.is_dir():
            continue
        for p in base.rglob("*"):
            if p.suffix.lower() in (".res", ".glb") and p.is_file():
                salida[p.relative_to(RAIZ).as_posix()] = p.read_bytes()
    return salida


def _texto_del_repo() -> dict[str, str]:
    """Todo lo que puede nombrar un asset en texto: scripts, escenas, recursos y `project.godot`."""
    junto: dict[str, str] = {**_fuentes(), **_tests(), **_escenas()}
    # El harness cuenta: el `.blend` no lo abre el juego, lo abre `exportar_modelo.py`. Sin este
    # árbol, el archivo de origen del modelo aparecía como que no lo referencia nadie.
    for patron in ("*.tres", "project.godot", ".claude/scripts/**/*.py"):
        for p in RAIZ.glob(patron) if "/" in patron else RAIZ.rglob(patron):
            partes = p.relative_to(RAIZ).parts
            if ".godot" in partes or "addons" in partes:
                continue
            junto[p.relative_to(RAIZ).as_posix()] = p.read_text(encoding="utf-8", errors="replace")
    return junto


def _imagenes_de_un_glb(datos: bytes) -> set[str]:
    """Los nombres de las texturas que un `.glb` lleva **embebidas**, sacados de su chunk JSON.

    Es la cuarta forma de referenciar un asset acá, y la única que no deja rastro en texto: la
    textura no está en disco al lado del modelo, está adentro del binario, y al importar Godot
    la extrae a `<stem del .glb>_<name>.<ext>`. Por eso un `.png` de `assets/models/` puede no
    aparecer en ningún `res://`, en ningún `uid://` y tampoco como cadena adentro del `.glb`, y
    ser aun así parte del modelo.

    **Esto no es teoría: costó treinta texturas borradas.** Se las midió como huérfanas con las
    otras tres formas, se las borró, y la reimportación cayó con `Failed loading resource`.
    """
    if datos[:4] != b"glTF" or len(datos) < 20:
        return set()
    largo = int.from_bytes(datos[12:16], "little")
    if datos[16:20] != b"JSON" or 20 + largo > len(datos):
        return set()
    try:
        cabecera = json.loads(datos[20 : 20 + largo].decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        return set()
    return {i["name"] for i in cabecera.get("images", []) if i.get("name")}


def _nombre_embebido(stem: str, stem_del_glb: str) -> set[str]:
    """Los nombres de imagen del `.glb` que pueden haber producido este archivo al importar.

    Godot extrae cada imagen embebida a `<stem del .glb>_<name>`, y **cuando dos comparten el
    `name` le agrega el índice de la imagen**: de un solo `jorgillo` salen `…_jorgillo_17` y
    `…_jorgillo_22`. Por eso hay dos candidatos y no uno — el nombre pelado y el nombre sin ese
    sufijo numérico.
    """
    sin_prefijo = stem.removeprefix(stem_del_glb + "_")
    return {sin_prefijo, re.sub(r"_\d+$", "", sin_prefijo)}


def _referencias_a(
    ruta: str, texto: dict[str, str] | None = None, crudos: dict[str, bytes] | None = None
) -> dict[str, list[str]]:
    """Quién referencia un asset, **por las tres formas que existen en este repo**.

    Las tres no son teoría: cada una esconde una referencia que una búsqueda por ruta no ve, y
    mezclarlas ya produjo un borrado equivocado de treinta texturas.

    `texto` y `crudos` se pasan cuando hay que preguntar por muchos assets seguidos: releer
    el `.glb` de 40 MB una vez por archivo convierte medio segundo de barrido en minutos.
    """
    nombre = Path(ruta).name
    texto = _texto_del_repo() if texto is None else texto
    uid = _uid_de(ruta)
    crudos = _binarios_del_repo() if crudos is None else crudos
    aguja = nombre.encode("utf-8")
    return {
        "por su ruta": sorted(r for r, t in texto.items() if ruta in t),
        "por `uid://`": sorted(r for r, t in texto.items() if uid and uid in t),
        "adentro de un binario": sorted(r for r, d in crudos.items() if r != ruta and aguja in d),
        "embebido en un `.glb`": sorted(
            r
            for r, d in crudos.items()
            if r.lower().endswith(".glb")
            and _nombre_embebido(Path(ruta).stem, Path(r).stem) & _imagenes_de_un_glb(d)
        ),
    }


def contexto_de_asset(ruta: str) -> str:
    """Dónde está un asset y quién lo referencia, por cada una de las formas que existen."""
    archivo = RAIZ / ruta
    if not archivo.is_file():
        return f"No hay `{ruta}`."
    if ruta.startswith(FUENTE_DE_ARTE):
        return (
            f"`{ruta}` está bajo `{FUENTE_DE_ARTE}`: es arte de origen y **Godot no lo importa** "
            "—hay un `.gdignore` arriba—. Que nadie lo referencie es lo correcto."
        )

    formas = _referencias_a(ruta)
    total = sum(len(v) for v in formas.values())
    lineas = [
        f"# {ruta}",
        "",
        f"{archivo.stat().st_size} bytes · uid: `{_uid_de(ruta) or 'sin .import'}`",
        "",
    ]
    for forma, quienes in formas.items():
        lineas.append(f"## {forma}")
        lineas += [f"- {r}" for r in quienes] or ["- (nadie)"]
        lineas.append("")
    if total == 0:
        lineas.append(
            "**Nadie lo referencia por ninguna de las cuatro formas, y eso no prueba que sobre.** "
            "Antes de borrar va una corrida de `--import`: el rojo que deja un asset que hacía "
            "falta aparece ahí y en ningún otro lado."
        )
    return "\n".join(lineas)


def assets_sin_referencia() -> str:
    """Los assets que ninguna forma de referencia alcanza. Es una sospecha, no un veredicto."""
    base = RAIZ / "assets"
    if not base.is_dir():
        return "No hay `assets/`."
    texto, crudos = _texto_del_repo(), _binarios_del_repo()
    sospechosos = []
    for p in sorted(base.rglob("*")):
        ruta = p.relative_to(RAIZ).as_posix()
        if not p.is_file() or ruta.startswith(FUENTE_DE_ARTE):
            continue
        if p.suffix in (".import", ".gdignore") or p.name == ".gitkeep":
            continue
        if sum(len(v) for v in _referencias_a(ruta, texto, crudos).values()) == 0:
            sospechosos.append(ruta)
    return "\n".join(
        ["# Assets que ninguna referencia alcanza", ""]
        + ([f"- {r}" for r in sospechosos] or ["- (ninguno)"])
        + [
            "",
            "**Es una sospecha y no un veredicto.** Las cuatro formas cubren lo que este repo "
            "usa hoy; la quinta que aparezca no está acá. Antes de borrar va "
            "`contexto_de_asset`, y después una corrida de `--import`, que es donde sale el "
            "rojo si el asset hacía falta.",
        ]
    )
