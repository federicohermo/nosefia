"""Lo puro del despliegue: el par preset↔headers, el veredicto del export y el de la URL.

**Existe para que tenga tests**, por el mismo motivo que `verificacion.py`: mientras una regla
del despliegue vive adentro de un paso de YAML, la única forma de ejercerla es desplegar — y el
modo de falla que importa no se puede fabricar así.

## Los tres modos de falla que cierra, y por qué ninguno da rojo solo

1. **El par preset↔headers.** El `index.js` que genera Godot se apoya en `SharedArrayBuffer`
   —cuántas veces lo nombra está medido en `docs/infra/despliegue.md`— y aborta si el servidor
   no manda los dos headers de aislamiento: el deploy contesta 200, el HTML carga, y el juego
   no arranca. Apagar los hilos sin sacar los headers —o al revés— es un cambio de una línea, y
   las dos mitades del par viven en archivos distintos.
2. **El código de salida del export miente.** Medido: `--export-release "Web"` termina con
   `Program crashed with signal 11` y devuelve **0**. Un `$?` no distingue «exportó» de «murió
   a mitad», así que el veredicto es la lista de archivos y su tamaño.
3. **Publicar no es haber publicado.** Un archivo que contesta 404, o un `.wasm` sin su
   `Content-Type`, dejan la página cargando para siempre con el deploy en verde.

Nada de este archivo toca el disco ni la red: recibe texto, diccionarios y —para la URL— la
función que hace el pedido. Es lo que permite ejercer un 404 sin publicar nada.
"""

import re
from collections.abc import Callable
from dataclasses import dataclass, field

# ── El par preset↔headers ─────────────────────────────────────────────────────

#: Los dos headers que el aislamiento de origen cruzado pide, con el valor exacto que Godot
#: necesita. No alcanza con que el header esté: `Cross-Origin-Embedder-Policy: credentialless`
#: pasa el `crossOriginIsolated` de algunos navegadores y no de otros, y el modo de falla
#: sería el mismo de siempre — verde acá, negro en la pantalla de quien abre el link.
AISLAMIENTO: dict[str, str] = {
    "cross-origin-opener-policy": "same-origin",
    "cross-origin-embedder-policy": "require-corp",
}

#: El header del caché y la directiva que tiene que traer.
#:
#: **Ningún archivo que Godot exporta lleva hash en el nombre**: son siempre `index.wasm`,
#: `index.pck`, `index.js`. Un caché largo serviría la build anterior desde el navegador de
#: quien ya entró una vez — que en una cátedra es exactamente el docente que vuelve a mirar.
CACHE = "cache-control"
REVALIDACION = "must-revalidate"

#: La clave del preset que enciende los hilos, y la que dice dónde escribe.
HILOS = "variant/thread_support"
DESTINO = "export_path"

#: Los `source` de `vercel.json` que cubren **todas** las rutas.
#:
#: Es un conjunto cerrado y no un intento de decidir si un patrón cualquiera matchea todo:
#: eso, en el general, no se puede: y equivocarse hacia el «sí matchea» deja el gate en verde
#: sobre una regla que no cubre el `.wasm`. Las dos formas son las que documenta Vercel.
FUENTES_UNIVERSALES: frozenset[str] = frozenset({"/(.*)", "/:path*"})


def _secciones(cfg: str) -> dict[str, dict[str, str]]:
    """Un `.cfg` de Godot como `{sección: {clave: valor}}`, con los valores sin comillas.

    Es deliberadamente tolerante: las líneas que no son `clave=valor` —los
    `PackedStringArray()` que abren y cierran en varias líneas, los comentarios— se saltean en
    vez de romper. Lo que este parser tiene que poder contestar son tres claves escalares, y un
    parser estricto convertiría cualquier cosa que Godot agregue en el próximo release en un
    rojo que no es de nadie.
    """
    secciones: dict[str, dict[str, str]] = {}
    actual: dict[str, str] = {}
    for linea in cfg.splitlines():
        limpia = linea.strip()
        encabezado = re.fullmatch(r"\[([^\]]+)\]", limpia)
        if encabezado:
            actual = secciones.setdefault(encabezado.group(1), {})
            continue
        par = re.fullmatch(r'([A-Za-z0-9_/.]+)\s*=\s*"?([^"]*)"?', limpia)
        if par:
            actual[par.group(1)] = par.group(2)
    return secciones


def preset_web(cfg: str) -> dict[str, str] | None:
    """El preset de plataforma `Web`, con sus opciones plegadas adentro, o `None`.

    Godot parte cada preset en dos secciones —`[preset.N]` y `[preset.N.options]`— y el par
    que este módulo verifica vive con una pata en cada una: `export_path` arriba,
    `variant/thread_support` abajo. Devolverlas plegadas es lo que deja que quien pregunta no
    tenga que saber eso.
    """
    secciones = _secciones(cfg)
    for nombre, campos in secciones.items():
        if re.fullmatch(r"preset\.\d+", nombre) and campos.get("platform") == "Web":
            return {**campos, **secciones.get(f"{nombre}.options", {})}
    return None


def pide_hilos(cfg: str) -> bool:
    """Si el preset `Web` exporta con hilos, que es la mitad del par que vive en el `.cfg`."""
    preset = preset_web(cfg)
    return bool(preset) and preset.get(HILOS) == "true"


def headers_universales(vercel: dict) -> dict[str, str]:
    """Los headers que `vercel.json` manda para **todas** las rutas, en minúscula.

    Las claves se bajan a minúscula porque HTTP no distingue mayúsculas y `vercel.json` las
    escribe capitalizadas: comparar el string tal cual haría que `cache-control` y
    `Cache-Control` fueran headers distintos, y el gate diría que falta el que está.
    """
    declarados: dict[str, str] = {}
    for regla in vercel.get("headers", []):
        if regla.get("source") not in FUENTES_UNIVERSALES:
            continue
        for header in regla.get("headers", []):
            clave = str(header.get("key", "")).strip().lower()
            if clave:
                declarados[clave] = str(header.get("value", ""))
    return declarados


def desajustes_del_par(cfg: str, vercel: dict) -> list[str]:
    """Qué tiene desatado el par preset↔headers. Vacío es que está atado.

    Mira las **dos** direcciones a propósito. Que falten los headers con los hilos encendidos
    es la falla obvia; que sobren con los hilos apagados no rompe el juego pero deja el par
    desatado igual, y el próximo que lea el `vercel.json` va a creer que la web usa hilos.
    Un gate que sólo mira una dirección deja que la otra mitad se apague sola.
    """
    problemas: list[str] = []
    preset = preset_web(cfg)
    if preset is None:
        return [
            "`export_presets.cfg` no declara ningún preset de plataforma `Web`: sin él no hay "
            "nada que exportar y el despliegue publicaría el directorio vacío."
        ]
    if not preset.get(DESTINO):
        problemas.append(
            f"el preset `Web` no declara `{DESTINO}`: Godot exporta a donde le digan por línea "
            "de comandos, así que sin esto el destino lo decide quien corra el comando."
        )

    declarados = headers_universales(vercel)
    for header, valor in AISLAMIENTO.items():
        presente = declarados.get(header, "").strip() == valor
        if pide_hilos(cfg) and not presente:
            problemas.append(
                f"el preset `Web` pide hilos (`{HILOS}=true`) y `vercel.json` no manda "
                f"`{header}: {valor}` para todas las rutas: el deploy contesta 200, el HTML "
                "carga y el juego aborta sin arrancar."
            )
        if not pide_hilos(cfg) and presente:
            problemas.append(
                f"`vercel.json` manda `{header}: {valor}` pero el preset `Web` no pide hilos "
                f"(`{HILOS}` no es `true`): el aislamiento sin hilos no compra nada y deja "
                "escrito que la web los usa."
            )

    if REVALIDACION not in declarados.get(CACHE, ""):
        problemas.append(
            f"`vercel.json` no manda `{CACHE}` con `{REVALIDACION}` para todas las rutas: "
            "ningún archivo que Godot exporta lleva hash en el nombre, así que un caché largo "
            "sirve la build anterior a quien ya entró una vez."
        )
    return problemas


# ── El veredicto del export ───────────────────────────────────────────────────

#: Los tres archivos sin los cuales no hay juego. Los otros seis que Godot escribe —el splash,
#: los dos worklets de audio, los iconos— degradan la página; sin éstos no hay página.
OBLIGATORIOS: tuple[str, ...] = ("index.html", "index.wasm", "index.pck")

#: El piso del `.wasm` y el techo del directorio, en bytes.
#:
#: **Ninguno de los dos depende de la versión del motor**: medido con 4.4.1, el `.wasm` son
#: 6,4 MB comprimidos —o sea bastante más de 10 sin comprimir— y el directorio entero queda
#: muy por debajo de 90 MB. No existen para afinar nada: existen para distinguir un export
#: completo de uno que murió a mitad, que es lo único que el código de salida no dice.
PISO_DEL_WASM = 10 * 1024 * 1024
TECHO_DEL_DIRECTORIO = 90 * 1024 * 1024

_MB = 1024 * 1024


def veredicto_del_export(archivos: dict[str, int]) -> list[str]:
    """Qué le falta al directorio exportado para ser una web jugable. Vacío es que está.

    `archivos` va `{nombre: bytes}`. **El código de salida del export no entra acá**, y no es
    un olvido: está medido que devuelve 0 después de un `Program crashed with signal 11`.
    """
    problemas: list[str] = []
    for obligatorio in OBLIGATORIOS:
        if obligatorio not in archivos:
            problemas.append(
                f"el export no dejó `{obligatorio}`. El código de salida de Godot no lo dice: "
                "está medido que devuelve 0 después de crashear."
            )

    wasm = archivos.get("index.wasm")
    if wasm is not None and wasm < PISO_DEL_WASM:
        problemas.append(
            f"`index.wasm` pesa {wasm / _MB:.1f} MB y el piso son {PISO_DEL_WASM / _MB:.0f}: "
            "un binario de Godot no baja de ahí, así que esto es un archivo truncado."
        )

    total = sum(archivos.values())
    if total > TECHO_DEL_DIRECTORIO:
        problemas.append(
            f"el directorio exportado pesa {total / _MB:.1f} MB y el techo son "
            f"{TECHO_DEL_DIRECTORIO / _MB:.0f}: algo se está publicando que no es el juego."
        )
    return problemas


# ── El veredicto de la publicación ────────────────────────────────────────────

#: Los archivos que se le piden a la URL publicada. Son los tres obligatorios más el `index.js`,
#: que es el que nombra `SharedArrayBuffer` y el que aborta si los headers no están.
PUBLICADOS: tuple[str, ...] = ("index.html", "index.js", "index.wasm", "index.pck")

#: El `Content-Type` sin el cual el navegador no compila el `.wasm` en streaming. Servido como
#: `application/octet-stream` la página carga igual y el juego no arranca nunca.
TIPO_DEL_WASM = "application/wasm"


@dataclass
class Respuesta:
    """Lo mínimo que el veredicto mira de una respuesta HTTP.

    No es la respuesta de `urllib`: es lo que hace falta para decidir, y por eso se puede
    fabricar en un test. Es lo que permite ejercer un 404 y un header faltante sin publicar
    nada ni tener red.
    """

    estado: int
    headers: dict[str, str] = field(default_factory=dict)

    def header(self, clave: str) -> str:
        """El valor de un header, sin importar cómo lo haya capitalizado el servidor."""
        clave = clave.lower()
        for nombre, valor in self.headers.items():
            if nombre.lower() == clave:
                return valor.strip()
        return ""


def problemas_de_la_publicacion(url: str, pedir: Callable[[str], Respuesta]) -> list[str]:
    """Qué tiene rota la URL publicada. Vacío es que se juega.

    `pedir` se inyecta por el mismo motivo que el lector del registro en `godot.py`: el modo de
    falla que importa —un 404, un header que se cayó— no lo puede fabricar una máquina que
    tiene la URL sana, y esperar a que se rompa en producción es no tener el test.
    """
    problemas: list[str] = []
    base = url.rstrip("/")
    for archivo in PUBLICADOS:
        respuesta = pedir(f"{base}/{archivo}")
        if respuesta.estado != 200:
            problemas.append(
                f"`{archivo}` contestó {respuesta.estado}: la publicación está incompleta y la "
                "página se queda cargando para siempre."
            )
            continue
        for header, valor in AISLAMIENTO.items():
            if respuesta.header(header) != valor:
                problemas.append(
                    f"`{archivo}` no trae `{header}: {valor}`. Sin los dos headers el "
                    "`SharedArrayBuffer` no existe y el juego aborta al arrancar."
                )
        if REVALIDACION not in respuesta.header(CACHE):
            problemas.append(
                f"`{archivo}` no trae `{CACHE}` con `{REVALIDACION}`: como ningún archivo "
                "exportado lleva hash, se sirve la build anterior."
            )
        if archivo.endswith(".wasm") and TIPO_DEL_WASM not in respuesta.header("content-type"):
            problemas.append(
                f"`{archivo}` se sirve como `{respuesta.header('content-type') or 'nada'}` y no "
                f"como `{TIPO_DEL_WASM}`: el navegador no lo compila en streaming."
            )
    return problemas
