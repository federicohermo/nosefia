"""Servir un export web local con los headers que pone Vercel.

    python .github/scripts/servir_export.py export/web 8060

Sin `Cross-Origin-Opener-Policy` y `Cross-Origin-Embedder-Policy` el navegador no aísla la
página, `SharedArrayBuffer` no existe y el motor con hilos no arranca. Los headers se leen de
`vercel.json`: servir otros sería medir un juego distinto del publicado.
"""

import functools
import json
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]


def headers_de_vercel() -> list[tuple[str, str]]:
    config = json.loads((RAIZ / "vercel.json").read_text(encoding="utf-8"))
    return [(h["key"], h["value"]) for bloque in config["headers"] for h in bloque["headers"]]


class ConHeaders(SimpleHTTPRequestHandler):
    extensions_map = {
        **SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".pck": "application/octet-stream",
    }
    headers_extra: list[tuple[str, str]] = []
    _sirviendo_brotli: bool = False

    def translate_path(self, path: str) -> str:
        ruta = Path(super().translate_path(path))
        self._sirviendo_brotli = False
        if not ruta.is_file() and ruta.with_name(ruta.name + ".br").is_file():
            self._sirviendo_brotli = True
            return str(ruta.with_name(ruta.name + ".br"))
        return str(ruta)

    def guess_type(self, path: str) -> str:
        if path.endswith(".br"):
            return super().guess_type(path[:-3])
        return super().guess_type(path)

    def end_headers(self) -> None:
        if self._sirviendo_brotli:
            self.send_header("Content-Encoding", "br")
            self.send_header("Vary", "Accept-Encoding")
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
    ConHeaders.headers_extra = headers_de_vercel()
    manejador = functools.partial(ConHeaders, directory=str(carpeta))
    servidor = Servidor(("127.0.0.1", int(sys.argv[2])), manejador)
    print(f"sirviendo {carpeta} en http://localhost:{sys.argv[2]}", flush=True)
    servidor.serve_forever()


if __name__ == "__main__":
    main()
