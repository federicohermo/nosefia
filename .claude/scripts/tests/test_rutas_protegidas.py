"""Los tests de `lib/rutas_protegidas.py`, o sea de qué cuenta como «adentro de `src/`».

El caso que justifica el módulo entero —dos discos de Windows— se ejerce con `ntpath`, así
que da lo mismo en las tres plataformas y también en el `ubuntu-latest` de la CI, donde no
hay dos discos que fabricar.
"""

import ntpath
import posixpath
import unittest

from lib.rutas_protegidas import esta_protegida

PROTEGIDAS = ["src", "docs"]


class EnPosix(unittest.TestCase):
    def protegida(self, ruta):
        return esta_protegida(posixpath, "/repo", PROTEGIDAS, ruta)

    def test_un_archivo_adentro(self):
        self.assertTrue(self.protegida("src/dominio/turno.gd"))

    def test_un_archivo_afuera(self):
        self.assertFalse(self.protegida("addons/gdUnit4/plugin.gd"))

    def test_la_carpeta_protegida_misma_cuenta_como_adentro(self):
        # Con `Bash` en el matcher del hook, el payload puede ser `rm -rf src`: el borrado que
        # más importa por la única puerta que quedaría abierta.
        self.assertTrue(self.protegida("src"))

    def test_normaliza_los_puntos_suspensivos(self):
        # Comparar el string dejaría pasar esta forma, que apunta adentro.
        self.assertTrue(self.protegida("test/../src/dominio/turno.gd"))

    def test_una_ruta_que_sale_no_esta_protegida(self):
        self.assertFalse(self.protegida("../otro-repo/src/x.gd"))

    def test_una_hermana_que_empieza_con_puntos_no_se_confunde(self):
        # `..notas` empieza con `..` y no sale de ningún lado: el prefijo pelado la dejaría
        # pasar creyendo que está afuera.
        self.assertTrue(self.protegida("src/..notas/x.gd"))

    def test_una_carpeta_con_el_mismo_prefijo_no_cuenta(self):
        # `srcs/` no es `src/`.
        self.assertFalse(self.protegida("srcs/x.gd"))

    def test_una_ruta_absoluta_adentro(self):
        self.assertTrue(self.protegida("/repo/src/dominio/turno.gd"))


class EnWindows(unittest.TestCase):
    def protegida(self, ruta):
        return esta_protegida(ntpath, r"D:\repo", PROTEGIDAS, ruta)

    def test_un_archivo_adentro_con_barras_invertidas(self):
        self.assertTrue(self.protegida(r"src\dominio\turno.gd"))

    def test_otro_disco_no_esta_protegido(self):
        # ÉSTE es el caso que justifica el módulo. En Python `relpath` entre dos discos lanza
        # `ValueError`; sin atajarlo y decidir qué significa, el gate se cae con un traceback
        # en cada edición del scratchpad —que vive en `C:` mientras el repo vive en `D:`— y
        # se termina desactivando.
        self.assertFalse(self.protegida(r"C:\Users\fede\AppData\Local\Temp\nota.txt"))

    def test_el_otro_disco_tampoco_aunque_se_llame_igual(self):
        self.assertFalse(self.protegida(r"C:\repo\src\dominio\turno.gd"))


if __name__ == "__main__":
    unittest.main()
