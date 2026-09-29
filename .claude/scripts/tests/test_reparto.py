"""Los tests de `lib/reparto.py`: que el reparto de la góndola cumpla las reglas antes de llegar
al `.blend`.

El reparto se itera con el usuario mirando capturas, y cada vuelta es una línea que se mueve de
un estante a otro. Una regla rota ahí —un producto que se repone en dos lugares, un estante de
lado con uno solo— no la ve ningún test del juego hasta después de acomodar, exportar y medir:
acá se ve antes de correr nada.
"""

import re
import unittest
from collections import Counter

from lib.reparto import (
    CABECERAS,
    DE_CABECERA,
    DEL_ZOCALO,
    ESTANTES,
    FRIOS,
    HELADERAS,
    MUEBLES,
    PRODUCTOS,
    es_cabecera,
    es_heladera,
    partes,
)
from lib.repo import RAIZ

CATALOGO = RAIZ / "src/dominio/almacen/catalogo.gd"

#: Cuántos estantes tiene cada cara de góndola, contando el zócalo. Medido sobre el `.blend` del
#: 2026-09-29: las caras de lado tienen zócalo y tres chapas, y las cabeceras zócalo y dos.
NIVELES_DE_LADO = 4
NIVELES_DE_CABECERA = 3


def _filas_del_catalogo() -> list[tuple[str, str]]:
    """Las filas de `FILAS` del catálogo del juego, en su orden: la clave del enum y el nombre."""
    texto = CATALOGO.read_text(encoding="utf-8")
    bloque = texto.split("const FILAS := {", 1)[1].split("\n}", 1)[0]
    return re.findall(r'Producto\.Id\.(\w+): \["([^"]+)"', bloque)


class ElReparto(unittest.TestCase):
    def test_los_productos_son_los_del_catalogo_y_en_su_orden(self):
        filas = _filas_del_catalogo()
        # Sin esto el test pasaría sobre un catálogo que no se pudo leer.
        self.assertGreater(len(filas), 0)
        self.assertEqual([(p.clave, p.nombre) for p in PRODUCTOS], filas)

    def test_cada_producto_se_repone_en_una_sola_tanda(self):  # AC-STK-028
        principales = Counter(
            t.producto for tandas in ESTANTES.values() for t in tandas if not t.fija
        )
        for p in PRODUCTOS:
            self.assertEqual(principales[p.clave], 1, p.nombre)

    def test_lo_que_se_repite_es_un_producto_del_catalogo(self):
        claves = {p.clave for p in PRODUCTOS}
        for estante, tandas in ESTANTES.items():
            for t in tandas:
                self.assertIn(t.producto, claves, estante)

    def test_un_estante_no_repite_un_producto(self):
        for estante, tandas in ESTANTES.items():
            productos = [t.producto for t in tandas]
            self.assertEqual(len(productos), len(set(productos)), estante)

    def test_un_estante_de_lado_lleva_entre_dos_y_cuatro_productos(self):
        for estante, tandas in ESTANTES.items():
            if es_cabecera(estante) or es_heladera(estante):
                continue
            self.assertTrue(2 <= len(tandas) <= 4, f"{estante}: {len(tandas)}")

    def test_una_cabecera_lleva_al_menos_uno(self):
        for estante, tandas in ESTANTES.items():
            if es_cabecera(estante):
                self.assertGreaterEqual(len(tandas), 1, estante)

    def test_lo_de_cabecera_va_solo_en_cabecera(self):
        for estante, tandas in ESTANTES.items():
            for t in tandas:
                if t.producto in DE_CABECERA:
                    self.assertTrue(es_cabecera(estante), f"{t.producto} en {estante}")

    def test_lo_que_no_entra_en_dos_filas_arriba_va_en_el_zocalo(self):
        for estante, tandas in ESTANTES.items():
            _, _, nivel = partes(estante)
            for t in tandas:
                if t.producto in DEL_ZOCALO:
                    self.assertEqual(nivel, 0, f"{t.producto} en {estante}")

    def test_la_heladera_lleva_lo_frio_una_sola_vez_y_nada_mas(self):
        en_heladera = [
            t for estante, tandas in ESTANTES.items() if es_heladera(estante) for t in tandas
        ]
        self.assertEqual(sorted(t.producto for t in en_heladera), sorted(FRIOS))
        self.assertTrue(all(not t.fija for t in en_heladera))
        for estante, tandas in ESTANTES.items():
            for t in tandas:
                if t.producto in FRIOS:
                    self.assertTrue(es_heladera(estante), f"{t.producto} en {estante}")

    def test_ningun_estante_de_gondola_queda_vacio(self):
        for letra in MUEBLES:
            if letra in HELADERAS:
                continue
            caras = ["este"] if letra in ("N", "S") else ["oeste", "este", *CABECERAS]
            for cara in caras:
                niveles = NIVELES_DE_CABECERA if cara in CABECERAS else NIVELES_DE_LADO
                for nivel in range(niveles):
                    self.assertIn(f"{letra}.{cara}.{nivel}", ESTANTES)

    def test_cada_estante_nombra_un_mueble_y_una_cara_que_existen(self):
        for estante in ESTANTES:
            mueble, cara, nivel = partes(estante)
            self.assertIn(mueble, MUEBLES)
            self.assertIn(cara, ("norte", "sur", "este", "oeste"))
            self.assertGreaterEqual(nivel, 0)


if __name__ == "__main__":
    unittest.main()
