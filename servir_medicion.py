from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from functools import partial


class Handler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        super().end_headers()


ThreadingHTTPServer(('127.0.0.1', 8765), partial(Handler, directory='build/medicion/web')).serve_forever()
