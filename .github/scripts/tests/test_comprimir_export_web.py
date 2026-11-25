"""Tests de la precompresión Brotli del export web y su cableado en el despliegue."""

import json
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[1]
RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(SCRIPTS))

from comprimir_export_web import (  # noqa: E402
    OBJETIVOS,
    _descomprimir_bytes,
    comprimir_export,
    construir_vercel_con_brotli,
)


class PrecompresionBrotli(unittest.TestCase):
    def test_construir_vercel_conserva_headers_universales_y_agrega_rewrites(self):
        base = json.loads((RAIZ / "vercel.json").read_text(encoding="utf-8"))
        resultado = construir_vercel_con_brotli(base, OBJETIVOS)

        self.assertEqual(resultado["git"], {"deploymentEnabled": False})
        self.assertEqual(resultado["headers"][0]["source"], "/(.*)")
        self.assertEqual(
            resultado["rewrites"],
            [
                {"source": "/index.wasm", "destination": "/index.wasm.br"},
                {"source": "/index.pck", "destination": "/index.pck.br"},
            ],
        )

        por_source = {bloque["source"]: bloque["headers"] for bloque in resultado["headers"]}
        for ruta, tipo in (
            ("/index.wasm", "application/wasm"),
            ("/index.wasm.br", "application/wasm"),
            ("/index.pck", "application/octet-stream"),
            ("/index.pck.br", "application/octet-stream"),
        ):
            with self.subTest(ruta=ruta):
                cabeceras = {h["key"]: h["value"] for h in por_source[ruta]}
                self.assertEqual(cabeceras["Content-Type"], tipo)
                self.assertEqual(cabeceras["Content-Encoding"], "br")
                self.assertEqual(cabeceras["Vary"], "Accept-Encoding")

    def test_comprimir_export_genera_br_validos_elimina_crudos_y_escribe_vercel(self):
        with tempfile.TemporaryDirectory() as temporal:
            carpeta = Path(temporal)
            wasm_original = (b"\x00asm\x01\x00\x00\x00" + b"godot-wasm-payload" * 2048)
            pck_original = (b"GDPC" + b"recurso-repetido-del-almacen" * 4096)
            (carpeta / "index.html").write_text("<html></html>", encoding="utf-8")
            (carpeta / "index.wasm").write_bytes(wasm_original)
            (carpeta / "index.pck").write_bytes(pck_original)

            resumen = comprimir_export(carpeta, RAIZ / "vercel.json", calidad=4)

            self.assertFalse((carpeta / "index.wasm").exists())
            self.assertFalse((carpeta / "index.pck").exists())
            self.assertTrue((carpeta / "index.wasm.br").is_file())
            self.assertTrue((carpeta / "index.pck.br").is_file())
            self.assertEqual(_descomprimir_bytes((carpeta / "index.wasm.br").read_bytes()), wasm_original)
            self.assertEqual(_descomprimir_bytes((carpeta / "index.pck.br").read_bytes()), pck_original)
            self.assertLess(resumen["index.wasm"][1], resumen["index.wasm"][0])
            self.assertLess(resumen["index.pck"][1], resumen["index.pck"][0])

            vercel_generado = json.loads((carpeta / "vercel.json").read_text(encoding="utf-8"))
            self.assertEqual(len(vercel_generado["rewrites"]), 2)

    def test_desplegar_precomprime_despues_de_topes_y_antes_de_publicar(self):
        workflow = (RAIZ / ".github" / "workflows" / "desplegar.yml").read_text(encoding="utf-8")
        tope = workflow.index("python .github/scripts/tope_de_carga.py")
        compresion = workflow.index("python .github/scripts/comprimir_export_web.py")
        deploy = workflow.index("vercel deploy")
        self.assertLess(tope, compresion)
        self.assertLess(compresion, deploy)


if __name__ == "__main__":
    unittest.main()
