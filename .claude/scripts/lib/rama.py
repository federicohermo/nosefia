"""Qué spec nombra la rama, qué archivos toca, y cómo leer los archivos de ese spec.

**Lo comparten dos gates** —el de los criterios y el de las rutas del plan— y por eso vive
acá: dos copias que se separen dan dos herramientas que no coinciden en de qué spec es una
rama, y la que se equivoca es siempre la que nadie mira.

La parte de I/O —git, `gh`— está separada de la parte pura a propósito: lo que decide si una
ruta declarada se violó no necesita ni red ni repo, y por eso se puede sondear.
"""

from __future__ import annotations

import functools
import json
import os
import subprocess

from lib.repo import RAIZ, RAMA_DE_INTEGRACION, REPO
from lib.specs import RAMA_DE_SPEC, archivo_de_comentario, leer_mapa

SPECS = RAIZ / "specs"


def rama_actual() -> str | None:
    """El nombre de la rama, con el caso del PR de la Action resuelto primero.

    **En un `pull_request` de GitHub Actions, `HEAD` no es la rama**: es el merge de prueba, y
    `git rev-parse --abbrev-ref HEAD` contesta `HEAD` pelado. Sin `GITHUB_HEAD_REF`, los gates
    que dependen de esto se saltearían siempre y justo en el único lugar donde tienen que
    correr.
    """
    del_entorno = os.environ.get("GITHUB_HEAD_REF")
    if del_entorno:
        return del_entorno
    try:
        salida = subprocess.run(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            cwd=RAIZ, capture_output=True, text=True, timeout=10, check=True,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    return salida.stdout.strip()


@functools.lru_cache(maxsize=1)
def spec_de_la_rama() -> str | None:
    """El `NNN` que nombra la rama, o `None`.

    El patrón deja el prefijo abierto —`feature/`, pero también `fix/` o `chore/`— y vive en
    `lib/specs.py` porque lo comparten el derivador del mapa y estos gates.
    """
    rama = rama_actual()
    if rama is None:
        return None
    m = RAMA_DE_SPEC.match(rama)
    return m.group(1) if m else None


def archivo_del_spec(numero: str, nombre: str) -> tuple[str, str] | None:
    """Un archivo del spec y de dónde salió, o `None` si no se pudo leer.

    **El disco primero y la red después**, y no al revés: el árbol local puede tener ediciones
    que todavía no se publicaron, y son las que el PR está implementando. Preguntarle a GitHub
    primero haría que el gate juzgara una versión anterior del spec.

    El `spec.md` vive en el body del issue y todo lo demás en un comentario, que es la misma
    partición que hace `publicar_spec.py`.
    """
    for carpeta in sorted(SPECS.glob(f"{numero}-*")):
        archivo = carpeta / nombre
        if archivo.is_file():
            return archivo.read_text(encoding="utf-8"), f"{carpeta.name}/{nombre}"

    try:
        mapa = leer_mapa((SPECS / "mapa.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    fila = mapa.get(numero)
    if fila is None:
        return None

    # `subprocess` pelado y no el `gh` de `lib/`: ése muere con un mensaje cuando no hay `gh`
    # ni sesión, y acá eso no es un error sino un salteo que se declara.
    try:
        salida = subprocess.run(
            ["gh", "issue", "view", str(fila["issue"]), "--repo", REPO,
             "--json", "body,comments"],
            capture_output=True, text=True, encoding="utf-8", timeout=60,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if salida.returncode != 0:
        return None
    datos = json.loads(salida.stdout)
    origen = f"el issue #{fila['issue']}"
    if nombre == "spec.md":
        return datos["body"], origen
    for comentario in datos["comments"]:
        par = archivo_de_comentario(comentario["body"])
        if par and par[0] == nombre:
            return par[1], origen
    return None


def archivos_de_la_rama() -> list[str] | None:
    """Los archivos que la rama cambia respecto de su base, o `None` si no se pudo medir.

    La base sale de `GITHUB_BASE_REF` cuando la Action la da y de la rama de integración si
    no. Los tres puntos son a propósito: comparar contra el **merge-base** y no contra la
    punta de la base, o cada commit que aterriza en `staging` aparecería como cambio de esta
    rama.
    """
    base = os.environ.get("GITHUB_BASE_REF") or RAMA_DE_INTEGRACION
    try:
        salida = subprocess.run(
            ["git", "diff", "--name-only", f"origin/{base}...HEAD"],
            cwd=RAIZ, capture_output=True, text=True, timeout=30,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if salida.returncode != 0:
        return None
    return [l.strip() for l in salida.stdout.splitlines() if l.strip()]


def archivo_en_la_base(ruta: str) -> str | None:
    """El contenido que un archivo tiene en la base de la rama, o `None` si no se pudo leer.

    El `None` no distingue «no se pudo preguntar» de «no existía allá», y es a propósito: los
    dos terminan en el mismo salteo declarado, y separarlos daría dos mensajes para un gate que
    igual no puede mirar.
    """
    base = os.environ.get("GITHUB_BASE_REF") or RAMA_DE_INTEGRACION
    try:
        salida = subprocess.run(
            ["git", "show", f"origin/{base}:{ruta}"],
            cwd=RAIZ, capture_output=True, text=True, encoding="utf-8", timeout=30,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    return salida.stdout if salida.returncode == 0 else None


def viola(declarada: str, tocado: str) -> bool:
    """Si el archivo `tocado` cae adentro de la ruta `declarada`.

    Tres formas, porque son las tres que los specs usan y están medidas:

    - **Termina en `/`** —`src/`, `ui/`— es un prefijo de directorio.
    - **Tiene barra** —`src/dominio/reglas.gd`— es la ruta exacta.
    - **No tiene barra** —`reglas.gd`, `almacen.tscn`— es el nombre del archivo, en cualquier
      carpeta. Es la forma que usan el 006, el 008, el 016, el 017 y el 033, y leerla como
      ruta exacta las volvería inofensivas sin decirlo.

    **Lo que separa un directorio de un nombre es la extensión, no la barra**, y la barra que
    falta era un apagado silencioso: `src` leído como nombre de archivo no matchea nada —no
    hay archivo que se llame `src`— así que la restricción quedaba escrita en el plan y no
    protegía nada. La forma canónica sigue siendo con barra; ésta es la que se escribe sola.
    """
    tocado = tocado.replace("\\", "/")
    declarada = declarada.replace("\\", "/")
    if not declarada.endswith("/") and "." not in declarada.rsplit("/", 1)[-1]:
        declarada += "/"
    if declarada.endswith("/"):
        return tocado.startswith(declarada)
    if "/" in declarada:
        return tocado == declarada
    return tocado.rsplit("/", 1)[-1] == declarada


def rutas_violadas(rutas: list[str], archivos: list[str]) -> list[tuple[str, str]]:
    """Los pares `(archivo tocado, ruta declarada)` que el plan prohibía, sin repetir.

    **Por par y no por archivo**, que es lo que hace accionable el rojo: decir «`reglas.gd` lo
    prohíbe `src/`» manda a la línea del plan que hay que discutir.
    """
    return [(a, r) for a in archivos for r in rutas if viola(r, a)]
