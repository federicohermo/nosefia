"""El tono del cuerpo de las góndolas: el factor por canal y lo que hace con una imagen.

Lo que depende del modelo no se prueba acá. Lo que sí: que el factor lleve la media al tono, y,
con Blender, que el detalle de la imagen conserve su proporción.
"""

import os
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path

from lib import gondolas
from lib.blender import resolver
from lib.repo import RAIZ


class ElFactor(unittest.TestCase):
    def test_multiplicar_cada_canal_por_su_factor_da_el_tono(self):
        medias = (0.08, 0.09, 0.05)
        llegada = tuple(m * f for m, f in zip(medias, gondolas.factores(medias)))
        for canal, esperado in zip(llegada, gondolas.TONO):
            self.assertAlmostEqual(canal, esperado)

    def test_una_imagen_que_ya_tiene_el_tono_no_cambia(self):
        for factor in gondolas.factores(gondolas.TONO):
            self.assertAlmostEqual(factor, 1.0)

    def test_una_imagen_negra_no_divide_por_cero(self):
        for factor in gondolas.factores((0.0, 0.0, 0.0)):
            self.assertTrue(factor > 0 and factor < float("inf"))

    def test_ninguna_textura_se_repite_ni_comparte_archivo(self):
        self.assertEqual(len(gondolas.TEXTURAS), len(set(gondolas.TEXTURAS)))
        rutas = [gondolas.ruta_de_la_textura(n) for n in gondolas.TEXTURAS]
        self.assertEqual(len(rutas), len(set(rutas)))


class ElColorLineal(unittest.TestCase):
    def test_a_lineal_conserva_los_extremos_y_oscurece_el_medio(self):
        self.assertAlmostEqual(gondolas.a_lineal(0.0), 0.0)
        self.assertAlmostEqual(gondolas.a_lineal(1.0), 1.0)
        self.assertLess(gondolas.a_lineal(0.5), 0.5)

    def test_la_paleta_no_mezcla_el_rojo_ni_el_azul_con_los_grises(self):
        self.assertNotIn(gondolas.PIXEL_ROJO, gondolas.PIXELES_GRISES)
        self.assertNotIn(4, gondolas.PIXELES_GRISES)

    def test_el_rojo_es_rojo_y_mas_claro_que_el_de_antes(self):
        rojo, verde, azul = gondolas.ROJO
        self.assertTrue(rojo > 2 * verde and rojo > 2 * azul)
        self.assertGreater(rojo, 0.808)


PRUEBA = textwrap.dedent(
    """
    import sys
    import numpy as np
    sys.path.insert(0, r"{scripts}")
    from blender import aclarar_gondolas as ag
    from lib import gondolas

    azar = np.random.default_rng(2)
    original = np.ones((32, 32, 4), dtype=np.float32)
    original[..., :3] = np.clip(azar.normal(0.08, 0.006, (32, 32, 3)), 0.01, 0.2)
    nuevo = ag.aclarar(original)
    for canal, esperado in enumerate(gondolas.TONO):
        assert abs(float(nuevo[..., canal].mean()) - esperado) < 0.002, f"canal {{canal}} no llegó al tono"
    correlacion = np.corrcoef(original[..., 0].ravel(), nuevo[..., 0].ravel())[0, 1]
    assert correlacion > 0.999, "el detalle perdió su proporción"
    assert float(nuevo[..., :3].max()) <= 1.0
    assert np.all(nuevo[..., 3] == 1.0), "el alfa cambió"
    print("LISTO")
    """
)


class ConBlender(unittest.TestCase):
    def test_aclarar_lleva_la_media_al_tono_y_conserva_el_detalle(self):
        ejecutable, _ = resolver(dict(os.environ))
        if ejecutable is None:
            raise unittest.SkipTest(
                "no corre: falta Blender, así que no se probó el aclarado de una imagen. Se "
                "declara con BLENDER_BIN."
            )
        scripts = RAIZ / ".claude" / "scripts"
        with tempfile.TemporaryDirectory() as carpeta:
            guion = Path(carpeta) / "prueba.py"
            guion.write_text(PRUEBA.format(scripts=str(scripts)), encoding="utf-8")
            resultado = subprocess.run(
                [ejecutable, "--factory-startup", "--background", "--python-exit-code", "1",
                 "--python", str(guion)],
                capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=300,
            )
        self.assertEqual(resultado.returncode, 0, resultado.stdout + resultado.stderr)
        self.assertIn("LISTO", resultado.stdout)


if __name__ == "__main__":
    unittest.main()
