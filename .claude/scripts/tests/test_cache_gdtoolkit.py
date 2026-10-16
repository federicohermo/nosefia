"""Lint y formato deben poder arrancar juntos con una caché inexistente."""

import os
import subprocess
import sys
import tempfile
import threading
import types
import unittest
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from unittest import mock

import verificar


class CacheFriaDeGdtoolkit(unittest.TestCase):
    def test_lint_y_formato_no_compiten_por_crear_la_cache(self):
        with tempfile.TemporaryDirectory() as temporal:
            raiz = Path(temporal)
            cache = raiz / "gdtoolkit" / "4.5.0"
            barrera = threading.Barrier(2)
            modulo = types.ModuleType("gdtoolkit.parser.parser")
            modulo.get_cache_directory = lambda: str(raiz)

            def herramienta(comando, **opciones):
                try:
                    # gdtoolkit 4.5.0 consulta y crea sin exist_ok; la barrera ejerce
                    # ambos procesos después de la consulta y antes de la creación.
                    if not cache.exists():
                        barrera.wait(timeout=3)
                        os.makedirs(cache)
                    return subprocess.CompletedProcess(comando, 0, "", "")
                except OSError as error:
                    return subprocess.CompletedProcess(comando, 1, "", str(error))

            with (
                mock.patch.dict(sys.modules, {modulo.__name__: modulo}),
                mock.patch("importlib.metadata.version", return_value="4.5.0"),
                mock.patch.object(verificar.subprocess, "run", side_effect=herramienta),
                ThreadPoolExecutor(max_workers=2) as pool,
            ):
                resultados = list(
                    pool.map(lambda nombre: verificar._correr(nombre, [nombre]),
                             ("gdlint", "gdformat"))
                )
            self.assertEqual([resultado.codigo for resultado in resultados], [0, 0])
            self.assertTrue(cache.is_dir())

    def test_un_error_de_la_herramienta_conserva_su_codigo_y_salida_sin_reintento(self):
        with (
            mock.patch.object(verificar, "_preparar_cache_gdtoolkit"),
            mock.patch.object(verificar.subprocess, "run", return_value=
                              subprocess.CompletedProcess(["gdlint"], 3, "", "fallo real"))
            as proceso,
        ):
            resultado = verificar._correr("lint", ["gdlint"])
        self.assertEqual(resultado.codigo, 3)
        self.assertEqual(resultado.salida, "fallo real")
        proceso.assert_called_once()


if __name__ == "__main__":
    unittest.main()
