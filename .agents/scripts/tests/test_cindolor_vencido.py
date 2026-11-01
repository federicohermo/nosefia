"""La variante conserva geometría y opciones del material, incluso si cambia el arte."""

import os
import subprocess
import unittest

from lib.godot import resolver
from lib.repo import RAIZ


class CindolorVencido(unittest.TestCase):
    def test_la_variante_conserva_la_estructura_y_detecta_una_alteracion(self):
        motor, _ = resolver(dict(os.environ))
        self.assertIsNotNone(motor, "la comprobación estructural necesita Godot")
        resultado = subprocess.run(
            [motor, "--headless", "--path", str(RAIZ), "--script",
             "assets/models/generar_cindolor_vencido.gd", "--", "--comprobar"],
            capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=120,
        )
        self.assertEqual(resultado.returncode, 0, resultado.stdout + resultado.stderr)
        self.assertIn("estructura y testigos: OK", resultado.stdout)
