"""Servidor local del paquete Web threaded original; no transforma sus archivos."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import sys

class Paquete(SimpleHTTPRequestHandler):
    extensions_map={**SimpleHTTPRequestHandler.extensions_map,'.wasm':'application/wasm','.pck':'application/octet-stream'}

    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy','same-origin')
        self.send_header('Cross-Origin-Embedder-Policy','require-corp')
        self.send_header('Cache-Control','no-store')
        super().end_headers()

directory=Path(sys.argv[2]).resolve()
if not (directory/'index.html').is_file(): raise SystemExit('Falta index.html del paquete real')
server=ThreadingHTTPServer(('127.0.0.1',int(sys.argv[1])),partial(Paquete,directory=str(directory)))
print(f'SERVIDOR431_LISTO http://127.0.0.1:{server.server_port}/index.html desde {directory}',flush=True)
server.serve_forever()
