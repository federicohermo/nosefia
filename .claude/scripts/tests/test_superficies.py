"""Las recetas de superficies: dónde caen sus archivos y qué le hace la variación al color.

Lo que depende de la geometría del modelo no se prueba acá. Lo que sí: que cada archivo caiga en
el grupo de tamaño que le toca, y, con Blender, que la variación no cambie el tono medio y que el
ruido empalme de un borde al opuesto, porque un piso se repite.
"""

import os
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path

from lib import blender as lib_blender
from lib import superficies
from lib.blender import resolver
from lib.repo import RAIZ

SCRIPTS = RAIZ / ".claude" / "scripts"


class LasRecetas(unittest.TestCase):
    def test_cada_material_tiene_una_sola_receta(self):
        nombres = [r.material for r in superficies.RECETAS]
        self.assertEqual(len(nombres), len(set(nombres)))

    def test_ningun_archivo_de_salida_se_repite(self):
        rutas = [superficies.ruta_del_color(r) for r in superficies.RECETAS]
        rutas += [superficies.ruta_de_la_rugosidad(r) for r in superficies.RECETAS]
        self.assertEqual(len(rutas), len(set(rutas)))

    def test_la_rugosidad_viaja_en_el_grupo_chico_y_el_color_no(self):
        for receta in superficies.RECETAS:
            rugosidad = superficies.ruta_de_la_rugosidad(receta).relative_to(
                lib_blender.FUENTES
            )
            color = superficies.ruta_del_color(receta).relative_to(lib_blender.FUENTES)
            self.assertEqual(lib_blender.grupo_de(rugosidad.as_posix()), lib_blender.SUPERFICIE)
            self.assertNotEqual(lib_blender.grupo_de(color.as_posix()), lib_blender.SUPERFICIE)

    def test_el_nombre_de_archivo_no_lleva_simbolos(self):
        self.assertEqual(superficies.espacio_de_nombre("GONDOLA | Chapa pintada"), "gondola_chapa_pintada")
        self.assertEqual(superficies.espacio_de_nombre("Material.019"), "material_019")

    def test_cada_receta_tiene_valores_dentro_de_lo_posible(self):
        for receta in superficies.RECETAS:
            claro, oscuro, variacion = receta.rugosidad
            for valor in (claro, oscuro):
                self.assertTrue(0.0 < valor <= 1.0, receta.material)
            self.assertGreaterEqual(variacion, 0.0)
            self.assertTrue(0.0 <= receta.mancha < 0.5 and 0.0 <= receta.grano < 0.5)
            self.assertGreaterEqual(receta.manchas_por_lado, 1)
            if receta.polvo > 0.0:
                self.assertTrue(receta.aire, "el polvo se hornea desde la malla")


def _blender() -> str:
    ejecutable, _ = resolver(dict(os.environ))
    if ejecutable is None:
        raise unittest.SkipTest(
            "no corre: falta Blender, así que no se probó la variación del color ni el ruido "
            "periódico. Se declara con BLENDER_BIN."
        )
    return ejecutable


PRUEBA = textwrap.dedent(
    """
    import sys
    import numpy as np
    sys.path.insert(0, r"{scripts}")
    from blender import mejorar_superficies as ms
    from lib import superficies

    ruido = ms._ruido(64, 64, 4, 1)
    assert abs(float(ruido.std()) - 1.0) < 0.05, "el ruido no tiene desvío 1"
    salto_interno = np.abs(np.diff(ruido, axis=1)).mean()
    salto_del_borde = np.abs(ruido[:, 0] - ruido[:, -1]).mean()
    assert salto_del_borde < 2.5 * salto_interno, "el ruido no empalma con su borde opuesto"

    azar = np.random.default_rng(3)
    original = np.clip(azar.normal(0.5, 0.1, (64, 64, 3)), 0, 1).astype(np.float32)
    original[:8, :8] = 0.0
    receta = superficies.RECETAS[0]
    nuevo = ms._devolver_la_media(ms._variar(original, receta, 5), original)
    resto = ms._luminancia(original) > ms.NEGRO
    diferencia = np.abs(nuevo[resto].mean(axis=0) - original[resto].mean(axis=0)).max()
    assert diferencia < 0.003, f"la media se movió {{diferencia}}"
    assert float(nuevo[resto].std()) > float(original[resto].std()) * 0.95
    assert np.all(nuevo[:8, :8] == 0.0), "el negro dejó de ser negro"
    print("LISTO")
    """
)


class LaVariacionEnBlender(unittest.TestCase):
    def test_la_variacion_conserva_el_tono_y_el_ruido_empalma(self):
        ejecutable = _blender()
        with tempfile.TemporaryDirectory() as carpeta:
            guion = Path(carpeta) / "prueba.py"
            guion.write_text(PRUEBA.format(scripts=str(SCRIPTS)), encoding="utf-8")
            resultado = subprocess.run(
                [ejecutable, "--factory-startup", "--background", "--python-exit-code", "1",
                 "--python", str(guion)],
                capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=300,
            )
        self.assertEqual(resultado.returncode, 0, resultado.stdout + resultado.stderr)
        self.assertIn("LISTO", resultado.stdout)


if __name__ == "__main__":
    unittest.main()
