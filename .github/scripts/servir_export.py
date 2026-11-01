"""Servir un export web local con los headers que pone Vercel.

    python .github/scripts/servir_export.py export/web 8060

Sin `Cross-Origin-Opener-Policy` y `Cross-Origin-Embedder-Policy` el navegador no aísla la
página, `SharedArrayBuffer` no existe y el motor con hilos no arranca. Los headers se leen de
`vercel.json`: servir otros sería medir un juego distinto del publicado.

**Y se aplican por ruta, como en Vercel.** Las reglas con `source` universal valen para todo, y
una regla con la ruta de un archivo vale sólo para ése. El `Content-Encoding` del `.pck` es una
de esas: aplicarlo a todo rompería el `.wasm`, el `.js` y el `.html`, que viajan sin comprimir.

Si el `.pck` de la carpeta no está comprimido, el header se cae y se avisa: es el modo de falla
de medir un export recién salido de Godot creyendo que se mide el que se publica.
"""

import functools
import json
import re
import sys
import urllib.parse
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]

#: Las `source` de `vercel.json` que cubren todas las rutas, tal como las documenta Vercel.
UNIVERSALES = frozenset({"/(.*)", "/:path*"})


def reglas_de_vercel() -> list[dict]:
    return json.loads((RAIZ / "vercel.json").read_text(encoding="utf-8"))["headers"]


def headers_para(reglas: list[dict], ruta: str) -> list[tuple[str, str]]:
    """Los headers que Vercel mandaría para esa ruta, en el orden en que los lee el navegador."""
    return [
        (header["key"], header["value"])
        for regla in reglas
        if regla.get("source") in UNIVERSALES or regla.get("source") == ruta
        for header in regla["headers"]
    ]


def tamano_declarado(carpeta: Path, nombre: str) -> int | None:
    """El tamaño que el `index.html` de esa carpeta declara para un archivo, o `None`.

    Es el total de la barra de carga y, acá, el discriminador de si el archivo está comprimido:
    el comprimido **siempre** pesa menos que el total que declara su propio paquete.
    """
    html = carpeta / "index.html"
    if not html.is_file():
        return None
    encontrado = re.search(
        r'"fileSizes"\s*:\s*(\{[^}]*\})', html.read_text(encoding="utf-8", errors="replace")
    )
    if not encontrado:
        return None
    try:
        tamanos = json.loads(encontrado.group(1))
    except json.JSONDecodeError:
        return None
    valor = tamanos.get(nombre)
    return valor if isinstance(valor, int) else None


class ConHeaders(SimpleHTTPRequestHandler):
    extensions_map = {**SimpleHTTPRequestHandler.extensions_map, ".wasm": "application/wasm"}
    reglas: list[dict] = []
    headers_extra: list[tuple[str, str]] = []

    def send_head(self):  # noqa: D102, ANN201
        ruta = urllib.parse.urlsplit(self.path).path
        self.headers_extra = headers_para(self.reglas, ruta)
        archivo = Path(self.translate_path(ruta))
        if archivo.is_file():
            self.headers_extra = [
                (clave, valor)
                for clave, valor in self.headers_extra
                if not (
                    clave.lower() == "content-encoding"
                    and not self._comprimido(archivo, valor)
                )
            ]
        return super().send_head()

    def _comprimido(self, archivo: Path, codificacion: str) -> bool:
        """Si el archivo en el disco pesa menos que el total que declara su `index.html`.

        Un `Content-Encoding` sobre un cuerpo que no lo está deja el juego en negro, y en local
        el síntoma es un error de descompresión que no nombra al export.
        """
        declarado = tamano_declarado(archivo.parent, archivo.name)
        if declarado is None:
            # Sin `fileSizes` no hay con qué comparar: se confía en quien armó la carpeta.
            return True
        if archivo.stat().st_size < declarado:
            return True
        print(
            f"`{archivo.name}` no está comprimido y `vercel.json` declara "
            f"`Content-Encoding: {codificacion}`: se sirve sin el header. Correr "
            "`node .github/scripts/comprimir_pck.mjs` antes de medir.",
            file=sys.stderr,
            flush=True,
        )
        return False

    def end_headers(self) -> None:
        for clave, valor in self.headers_extra:
            self.send_header(clave, valor)
        super().end_headers()

    def log_message(self, format: str, *args: object) -> None:
        pass


class Servidor(ThreadingHTTPServer):
    """Un puerto ocupado falla al abrir, también en Windows.

    Ahí `SO_REUSEADDR` deja que dos procesos escuchen el mismo puerto. El segundo arrancaba sin
    avisar, y el navegador medía el export del primero.
    """

    allow_reuse_address = sys.platform != "win32"


def main() -> None:
    if len(sys.argv) != 3:
        print("uso: python .github/scripts/servir_export.py <carpeta> <puerto>", file=sys.stderr)
        sys.exit(2)
    carpeta = Path(sys.argv[1]).resolve()
    if not (carpeta / "index.html").is_file():
        print(f"`{carpeta}` no tiene `index.html`.", file=sys.stderr)
        sys.exit(1)
    ConHeaders.reglas = reglas_de_vercel()
    manejador = functools.partial(ConHeaders, directory=str(carpeta))
    servidor = Servidor(("127.0.0.1", int(sys.argv[2])), manejador)
    print(f"sirviendo {carpeta} en http://localhost:{sys.argv[2]}", flush=True)
    servidor.serve_forever()


if __name__ == "__main__":
    main()
