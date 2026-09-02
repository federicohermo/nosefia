"""La dirección de dependencia entre las capas de `src/`, verificada en vez de escrita.

En el repo del que sale este harness, esta regla la verifica el linter por ruta
(`import-x/no-restricted-paths`). En GDScript no hay un linter que lo haga: `gdlint` mira
estilo y nombres, no de dónde viene una referencia. Así que la regla o se verifica acá o es
prosa — y una regla de arquitectura escrita en prosa dura hasta el primer apuro.

## Las dos formas en que un script de Godot referencia a otro

Y las dos hay que mirar, porque tapar una sola deja la puerta al lado abierta:

1. **Por ruta** — `preload("res://src/ui/hud.gd")`, `load(...)`, `extends "res://…"`. Es la
   forma explícita y la fácil de ver.
2. **Por `class_name`** — un script que declara `class_name Ventanilla` queda registrado
   **globalmente** en el proyecto, y desde cualquier otro archivo se lo nombra sin escribir
   una sola ruta. Es la puerta que ningún análisis de imports encuentra, y en Godot es la
   forma **normal** de escribir código: por eso el gate construye el índice
   `class_name → archivo` y después busca esos identificadores como palabras.

## Por qué se limpian comentarios y strings antes de buscar identificadores

Un `class_name` nombrado en un comentario —«esto lo va a usar `Ventanilla`»— o adentro de un
string no es una dependencia. Sin la limpieza, el gate reporta violaciones que no existen, y
un gate con falsos positivos se apaga: la única salida que le queda a quien lo sufre es
sacarlo del `verify`.

Lo que el chequeo de **dirección** NO mira, dicho para que no se lea como cobertura —el de
nombres de carpeta, más abajo en este archivo, sí ve las escenas, porque le alcanza la ruta—:

- **Las escenas (`.tscn`)**, que también referencian scripts. Un `.tscn` de `escenas/` puede
  apuntar a lo que quiera hacia abajo y eso es correcto por definición; el caso peligroso
  —una escena de `dominio/`— no puede existir, porque `dominio/` no tiene escenas.
- **Los autoloads**, que son globales por construcción: viven en `project.godot` y cualquiera
  los ve. Es una decisión de arquitectura que se toma al agregarlos, no una referencia que se
  escriba escondida en un archivo.
"""

import re

#: `preload("res://…")` y `load("res://…")`, la referencia por ruta.
_REFERENCIA_POR_RUTA = re.compile(r"""(?:preload|load)\s*\(\s*["'](res://[^"']+)["']""")

#: `extends "res://…"`, que es una referencia por ruta que no pasa por `preload`.
_EXTENDS_POR_RUTA = re.compile(r"""^\s*extends\s+["'](res://[^"']+)["']""", re.MULTILINE)

#: `class_name Ventanilla` — lo que registra un script en el índice global del proyecto.
_DECLARA_CLASS_NAME = re.compile(r"^\s*class_name\s+([A-Za-z_]\w*)", re.MULTILINE)

#: Los strings de GDScript, en sus cuatro formas. Se reemplazan por espacios y no se borran
#: para que los números de línea no se corran.
_STRINGS = re.compile(r'"""[\s\S]*?"""|\'\'\'[\s\S]*?\'\'\'|"(?:[^"\\\n]|\\.)*"|\'(?:[^\'\\\n]|\\.)*\'')

#: Un comentario de GDScript: `#` hasta el fin de línea. `##` (documentación) entra igual.
_COMENTARIOS = re.compile(r"#[^\n]*")


def _sin_comentarios_ni_strings(texto: str) -> str:
    """El código con los strings y los comentarios reemplazados por espacios.

    Espacios y no vacío: así cada carácter conserva su posición y el número de línea de un
    hallazgo sigue siendo el del archivo real.
    """

    def a_espacios(m: re.Match[str]) -> str:
        return re.sub(r"[^\n]", " ", m.group(0))

    return _COMENTARIOS.sub(a_espacios, _STRINGS.sub(a_espacios, texto))


def _linea_de(texto: str, posicion: int) -> int:
    return texto.count("\n", 0, posicion) + 1


def capa_de(ruta: str, capas: tuple[tuple[str, tuple[str, ...]], ...]) -> str | None:
    """A qué capa pertenece una ruta del repo, o `None` si no está en ninguna.

    La ruta se compara normalizada a barras: en Windows el walk devuelve `src\\dominio\\x.gd`
    y las capas se declaran con barras. Sin normalizar, en Windows **ninguna** ruta cae en
    ninguna capa y el gate pasa siempre, en verde.
    """
    normalizada = ruta.replace("\\", "/")
    for nombre, _ in capas:
        if normalizada.startswith(f"{nombre}/"):
            return nombre
    return None


def indice_de_class_names(
    archivos: dict[str, str], capas: tuple[tuple[str, tuple[str, ...]], ...]
) -> dict[str, str]:
    """`class_name` → la capa que lo declara.

    Sólo se indexan los que declara `src/`: un `class_name` de `addons/` o de un test no es
    una capa y no participa de la regla.
    """
    indice: dict[str, str] = {}
    for ruta, texto in archivos.items():
        capa = capa_de(ruta, capas)
        if capa is None:
            continue
        for m in _DECLARA_CLASS_NAME.finditer(texto):
            indice[m.group(1)] = capa
    return indice


def carpetas_no_declaradas(
    archivos: dict[str, str],
    capas: tuple[tuple[str, tuple[str, ...]], ...],
    carpetas_por_capa: dict[str, frozenset[str]],
) -> list[tuple[str, str, str]]:
    """Los archivos que están en una subcarpeta que su capa no declara.

    Devuelve `(ruta, capa, carpeta)` ordenado, con la ruta normalizada a barras como hace
    `capa_de()`. La carpeta viaja en el hallazgo porque sin ella el reporte del gate no la puede
    nombrar, y quien lo sufre no sabe qué renombrar.

    Dos decisiones que el nombre de la función no dice:

    - **La raíz de una capa es válida.** `reglas.gd` cruza `jornada/` y `empleo/`, `hud.gd` está
      siempre en pantalla: los que cruzan no caben en ninguna carpeta, y forzarlos a una sería
      exactamente la carpeta que repite lo que el nombre del archivo ya dice.
    - **Se mira el camino entero, no el primer segmento.** Un archivo en
      `ui/diegetica/pantallas/` es un hallazgo aunque `diegetica` esté declarada: si sólo se
      mirara el primero, la puerta de atrás se reabre un nivel más adentro.

    Lo que esto **no** contesta es si un archivo está en la carpeta *correcta*. Eso es semántica,
    ninguna herramienta lo puede decidir, y lo mira la revisión.
    """
    hallazgos: list[tuple[str, str, str]] = []
    for ruta in archivos:
        normalizada = ruta.replace("\\", "/")
        capa = capa_de(normalizada, capas)
        if capa is None:
            continue
        resto = normalizada[len(capa) + 1 :]
        carpeta, sep, _ = resto.rpartition("/")
        if not sep or carpeta in carpetas_por_capa.get(capa, frozenset()):
            continue
        hallazgos.append((normalizada, capa, carpeta))
    return sorted(hallazgos)


def violaciones(
    archivos: dict[str, str], capas: tuple[tuple[str, tuple[str, ...]], ...]
) -> list[tuple[str, int, str, str, str]]:
    """Las referencias que van en contra de la dirección declarada.

    Devuelve `(archivo, línea, capa_origen, capa_destino, referencia)`.

    `archivos` es `ruta relativa al repo` → contenido. Recibirlo así y no leer el disco es lo
    que hace que esto tenga tests: los casos que importan —una referencia adentro de un
    comentario, un `class_name` que se llama igual que una variable— se escriben a mano en
    cuatro líneas y no piden un repo de mentira en el disco.
    """
    permitidas = dict(capas)
    indice = indice_de_class_names(archivos, capas)
    hallazgos: list[tuple[str, int, str, str, str]] = []

    for ruta in sorted(archivos):
        texto = archivos[ruta]
        origen = capa_de(ruta, capas)
        if origen is None:
            continue

        def reportar(destino: str, referencia: str, posicion: int, texto=texto, ruta=ruta,
                     origen=origen) -> None:
            if destino == origen or destino in permitidas[origen]:
                return
            hallazgos.append((ruta, _linea_de(texto, posicion), origen, destino, referencia))

        # 1. Por ruta. Se busca sobre el texto CRUDO porque la referencia vive adentro de un
        #    string, que es justo lo que el limpiador de abajo borra.
        for patron in (_REFERENCIA_POR_RUTA, _EXTENDS_POR_RUTA):
            for m in patron.finditer(texto):
                recurso = m.group(1).removeprefix("res://")
                destino = capa_de(recurso, capas)
                if destino is not None:
                    reportar(destino, m.group(1), m.start())

        # 2. Por `class_name`, sobre el código limpio.
        limpio = _sin_comentarios_ni_strings(texto)
        propios = {m.group(1) for m in _DECLARA_CLASS_NAME.finditer(texto)}
        for nombre, destino in indice.items():
            # Un script no se referencia a sí mismo por nombrar su propio `class_name`.
            if nombre in propios:
                continue
            for m in re.finditer(rf"\b{re.escape(nombre)}\b", limpio):
                reportar(destino, nombre, m.start())

    return sorted(hallazgos)
