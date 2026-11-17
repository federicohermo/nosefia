"""El paso que achica el atlas de la noche del corte: promedia cada bloque de 2x2 de su capa.

`blender/reducir_mapa_de_luz.py` usa numpy, que la CI del harness no instala: ahí los casos se
saltean **diciendo qué no miraron**. Un salteo no es un verde. Corren en la máquina que lo tiene.
La parte que habla con Blender (leer y guardar el EXR) no se prueba acá: la ejerce el horneado.
"""

from __future__ import annotations

import sys
import unittest

try:
    import numpy as np
except ImportError:  # pragma: no cover - la CI del harness no tiene numpy
    np = None

from lib.repo import RAIZ

sys.path.insert(0, str(RAIZ / ".claude" / "scripts" / "blender"))

if np is not None:
    import reducir_mapa_de_luz as reductor

CAPAS = 4
LADO = 8
LADO_FINAL = LADO // 2


def _atlas(lado: int) -> "np.ndarray":
    """Un atlas de cuatro capas apiladas, con un valor distinto en cada capa y cada texel."""
    capas = [np.full((lado, lado, 3), 10.0 * capa, dtype=np.float32) for capa in range(CAPAS)]
    atlas = np.concatenate(capas, axis=0)
    atlas += np.arange(atlas.size, dtype=np.float32).reshape(atlas.shape) * 0.01
    return atlas


@unittest.skipIf(
    np is None,
    "no corre: falta numpy, así que no se miró cómo se reduce el atlas. "
    "Corre en la máquina que lo tiene.",
)
class ReduccionDelAtlas(unittest.TestCase):
    def test_cada_capa_queda_con_la_mitad_de_lado(self) -> None:
        reducido = reductor.reducir(_atlas(LADO), LADO_FINAL)
        self.assertEqual(reducido.shape, (CAPAS * LADO_FINAL, LADO_FINAL, 3))

    def test_cada_texel_es_el_promedio_de_su_bloque_de_dos_por_dos(self) -> None:
        atlas = _atlas(LADO)
        reducido = reductor.reducir(atlas, LADO_FINAL)
        bloque = atlas[2:4, 6:8]
        esperado = bloque.reshape(-1, 3).mean(axis=0)
        np.testing.assert_allclose(reducido[1, 3], esperado, rtol=1e-6)

    def test_una_capa_no_mezcla_su_luz_con_la_de_otra(self) -> None:
        atlas = _atlas(LADO)
        reducido = reductor.reducir(atlas, LADO_FINAL)
        for capa in range(CAPAS):
            propia = reducido[capa * LADO_FINAL : (capa + 1) * LADO_FINAL]
            original = atlas[capa * LADO : (capa + 1) * LADO]
            self.assertLessEqual(float(propia.max()), float(original.max()))
            self.assertGreaterEqual(float(propia.min()), float(original.min()))

    def test_un_atlas_que_ya_tiene_el_lado_pedido_no_cambia(self) -> None:
        atlas = _atlas(LADO_FINAL)
        np.testing.assert_array_equal(reductor.reducir(atlas, LADO_FINAL), atlas)

    def test_un_lado_que_no_es_el_pedido_ni_el_doble_frena_y_lo_dice(self) -> None:
        atlas = _atlas(LADO * 2)
        with self.assertRaises(SystemExit) as error:
            reductor.reducir(atlas, LADO_FINAL)
        self.assertIn(str(LADO * 2), str(error.exception))

    def test_un_atlas_que_no_es_de_cuatro_capas_frena(self) -> None:
        atlas = _atlas(LADO)[: 3 * LADO]
        with self.assertRaises(SystemExit):
            reductor.reducir(atlas, LADO_FINAL)


if __name__ == "__main__":
    unittest.main()
