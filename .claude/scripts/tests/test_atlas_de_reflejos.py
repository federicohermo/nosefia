"""El atlas de reflejos de la web alcanza para todas las sondas del local.

Con más sondas que espacios, GLES3 no le da lugar a la que sobra: su reemplazo por la menos usada
compara contra cero y nunca elige ninguna. Esa sonda deja `atlas_index < 0` y el motor escribe el
error en la consola dos veces por cuadro. No hay otro síntoma: el juego sigue andando.
"""

import re
import unittest

from lib.repo import RAIZ

ESCENA = RAIZ / "src" / "escenas" / "puestos" / "ambiente_del_almacen.tscn"
AJUSTE = re.compile(r"^reflections/reflection_atlas/reflection_count\.web=(\d+)$", re.MULTILINE)


class AtlasDeReflejos(unittest.TestCase):
    def test_la_web_tiene_un_espacio_por_cada_sonda_del_local(self):
        sondas = ESCENA.read_text(encoding="utf-8").count('type="ReflectionProbe"')
        ajuste = AJUSTE.search((RAIZ / "project.godot").read_text(encoding="utf-8"))
        self.assertIsNotNone(ajuste, "project.godot ya no limita el atlas de la web")
        self.assertGreaterEqual(int(ajuste.group(1)), sondas)


if __name__ == "__main__":
    unittest.main()
