"""Que la tabla de zonas de reposición del juego siga al reparto de la góndola.

Qué zona cubre cada producto lo declara `zonas_de_reposicion.gd`, y en qué mueble está su tanda
principal lo declaran `reparto.py` y `reparto_de_prueba.py`. Mover un producto de estante en el
reparto lo mueve de zona sin que ningún test del juego se entere: acá se ve antes de acomodar.
"""

import re
import unittest

from lib.repo import RAIZ
from lib.reparto import ESTANTES
from lib.reparto_de_prueba import CARAS

#: La tabla de BR-STK-052: qué mueble cubre cada zona. Una cara de isla se nombra `<isla>.<cara>`.
ZONA_DE_LA_CARA = {
    "H1.sur": 1, "H2.sur": 1, "A.norte": 1,
    "N.sur": 2, "B.norte": 2,
    "A.oeste": 3,
    "A.este": 4, "B.oeste": 4,
    "B.este": 5,
    "A.sur": 6,
    "B.sur": 7,
}

_FUENTE = (RAIZ / "src/dominio/almacen/zonas_de_reposicion.gd").read_text(encoding="utf-8")


def _tabla(nombre):
    """`zona -> {productos}` de la constante `nombre` del script."""
    cuerpo = re.search(rf"^const {nombre}: Dictionary\[int, Array\] = \{{\n(.*?)\n\}}", _FUENTE,
                       re.M | re.S)[1]
    tabla = {}
    for zona, lista in re.findall(r"^\t(\d+):\s*\[(.*?)\]", cuerpo, re.M | re.S):
        tabla[int(zona)] = set(re.findall(r"Producto\.Id\.([A-Z_]+)", lista))
    return tabla


def _por_zona(zona_de_cada_producto):
    tabla = {}
    for producto, zona in zona_de_cada_producto.items():
        tabla.setdefault(zona, set()).add(producto)
    return tabla


class TestZonasDeReposicion(unittest.TestCase):
    def test_la_zona_de_cada_producto_sigue_a_su_tanda_principal_en_el_local_completo(self):
        esperado = {}
        for estante, tandas in ESTANTES.items():
            mueble, cara, _ = estante.split(".")
            for tanda in tandas:
                if not tanda.fija:
                    esperado[tanda.producto] = ZONA_DE_LA_CARA[f"{mueble}.{cara}"]
        self.assertEqual(_tabla("COMPLETA"), _por_zona(esperado))

    def test_la_zona_de_cada_producto_sigue_a_su_cara_en_el_local_de_prueba(self):
        esperado = {
            producto: ZONA_DE_LA_CARA[cara]
            for cara, productos in CARAS.items()
            for producto in productos
        }
        self.assertEqual(_tabla("DE_PRUEBA"), _por_zona(esperado))

    def test_ningun_producto_esta_en_dos_zonas(self):
        for nombre in ("COMPLETA", "DE_PRUEBA"):
            todos = [p for productos in _tabla(nombre).values() for p in productos]
            self.assertEqual(len(todos), len(set(todos)), nombre)


if __name__ == "__main__":
    unittest.main()
