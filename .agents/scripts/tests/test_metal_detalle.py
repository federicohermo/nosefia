"""La pintura de los metales sale de la geometría y no depende del azar.

`blender/metal_detalle.py` usa numpy, que la CI del harness no instala: ahí los casos se saltean
**diciendo qué no miraron**. Un salteo no es un verde. Corren en la máquina que tiene numpy.
"""

import sys
import unittest
from pathlib import Path

try:
    import numpy as np
except ImportError:  # pragma: no cover - la CI del harness no tiene numpy
    np = None

from lib.repo import RAIZ

sys.path.insert(0, str(RAIZ / ".claude" / "scripts" / "blender"))

if np is not None:
    import metal_detalle as metal

LADO = 256
DENSIDAD = 160.0


def _caja(centro_x: float, ancho: float, alto: float) -> tuple[np.ndarray, list[list[int]]]:
    x0, x1, y0, y1, z0, z1 = centro_x - ancho / 2, centro_x + ancho / 2, 0.0, ancho, 0.1, 0.1 + alto
    vertices = np.array(
        [[x0, y0, z0], [x1, y0, z0], [x1, y1, z0], [x0, y1, z0],
         [x0, y0, z1], [x1, y0, z1], [x1, y1, z1], [x0, y1, z1]],
        dtype=float,
    )
    caras = [[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]
    return vertices, caras


def _receta() -> "metal.Receta":
    return metal.Receta(color=(0.74, 0.78, 0.78), rugosidad=0.3, metal=0.75, suelo=0.1, semilla=3)


@unittest.skipIf(
    np is None,
    "no corre: falta numpy, así que no se miró la pintura de los metales. "
    "Corre en la máquina que lo tiene.",
)
class PinturaDeLosMetales(unittest.TestCase):
    def _islas(self):
        vertices, caras = _caja(0.0, 0.13, 0.6)
        islas, sin_area = metal.armar_islas(vertices, caras)
        for isla in islas:
            isla.receta = _receta()
        return islas, sin_area

    def test_una_caja_da_una_isla_por_cara(self) -> None:
        islas, sin_area = self._islas()
        self.assertEqual(len(islas), 6)
        self.assertEqual(sin_area, [])

    def test_una_cara_sin_area_no_lleva_isla(self) -> None:
        vertices = np.array([[0, 0, 0], [1, 0, 0], [2, 0, 0]], dtype=float)
        islas, sin_area = metal.armar_islas(vertices, [[0, 1, 2]])
        self.assertEqual(islas, [])
        self.assertEqual(sin_area, [0])

    def test_las_islas_no_se_pisan_y_caen_adentro_del_atlas(self) -> None:
        islas, _ = self._islas()
        densidad = metal.elegir_densidad(islas, LADO, DENSIDAD, reservado=16)
        ocupado = np.zeros((LADO, LADO), dtype=int)
        for isla in islas:
            ancho, alto = metal._medidas(isla, densidad)
            if isla.girada:
                ancho, alto = alto, ancho
            ocupado[isla.y : isla.y + alto, isla.x : isla.x + ancho] += 1
        self.assertEqual(int(ocupado.max()), 1)
        self.assertEqual(int(ocupado[:16].sum()), 0)

    def test_la_uv_de_cada_vertice_cae_adentro_de_su_isla(self) -> None:
        vertices, caras = _caja(0.0, 0.13, 0.6)
        islas, _ = metal.armar_islas(vertices, caras)
        densidad = metal.elegir_densidad(islas, LADO, DENSIDAD, reservado=16)
        for isla in islas:
            for cara in isla.caras:
                for vertice in caras[cara]:
                    u, v = metal.uv_de(isla, vertices[vertice], densidad, LADO)
                    self.assertTrue(0.0 <= u <= 1.0 and 0.0 <= v <= 1.0)

    def test_el_atlas_conserva_el_tono_medio_y_sale_igual_dos_veces(self) -> None:
        islas, _ = self._islas()
        densidad = metal.elegir_densidad(islas, LADO, DENSIDAD, reservado=16)
        receta = _receta()
        color, orm = metal.armar_atlas(islas, [receta], LADO, densidad)
        otra, _ = metal.armar_atlas(islas, [receta], LADO, densidad)
        self.assertEqual(metal.png_de(color), metal.png_de(otra))
        self.assertGreaterEqual(float(orm[..., 1].min()), 0.05)
        self.assertLessEqual(float(orm[..., 2].max()), 1.0)
        pintado = np.zeros((LADO, LADO), dtype=bool)
        for isla in islas:
            ancho, alto = metal._medidas(isla, densidad)
            if isla.girada:
                ancho, alto = alto, ancho
            pintado[isla.y : isla.y + alto, isla.x : isla.x + ancho] = True
        media = color[pintado].mean(axis=0)
        for canal, esperado in enumerate(receta.color):
            self.assertAlmostEqual(float(media[canal]), esperado, delta=0.02)

    def test_el_detalle_varia_el_color(self) -> None:
        islas, _ = self._islas()
        densidad = metal.elegir_densidad(islas, LADO, DENSIDAD, reservado=16)
        color, _ = metal.armar_atlas(islas, [_receta()], LADO, densidad)
        isla = islas[0]
        ancho, alto = metal._medidas(isla, densidad)
        trozo = color[isla.y : isla.y + alto, isla.x : isla.x + ancho]
        self.assertGreater(float(trozo.std()), 0.01)

    def test_islas_que_no_entran_se_avisan(self) -> None:
        islas, _ = self._islas()
        with self.assertRaises(ValueError):
            metal.elegir_densidad(islas, 8, 400.0)


if __name__ == "__main__":
    unittest.main()
