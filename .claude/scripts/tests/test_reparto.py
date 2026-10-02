"""Los tests de `lib/reparto.py`: que el reparto de la góndola cumpla las reglas antes de llegar
al `.blend`.

El reparto se itera con el usuario mirando capturas, y cada vuelta es una línea que se mueve de
un estante a otro. Una regla rota ahí —un producto que se repone en dos lugares, una tanda fija
a la altura de la mano— no la ve ningún test del juego hasta después de acomodar, exportar y medir:
acá se ve antes de correr nada.
"""

import re
import unittest
from collections import Counter

from lib.reparto import (
    CABECERAS,
    DE_CABECERA,
    DE_UNA_FILA,
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

#: Cuántas bandejas tiene cada heladera. Medido sobre el mismo `.blend`.
BANDEJAS_DE_HELADERA = 4

#: Las caras de lado del local: las dos de cada góndola del medio y la única de las de pared.
CARAS_DE_LADO = ("A.oeste", "A.este", "B.oeste", "B.este", "N.este", "S.este")


def _es_de_reposicion(estante: str) -> bool:
    """Si el estante está a la altura de la mano: en una cara de lado, los que no son ni el de
    arriba ni el zócalo; en una cabecera, los que no son el de arriba."""
    _, _, nivel = partes(estante)
    if es_cabecera(estante):
        return nivel < NIVELES_DE_CABECERA - 1
    return 0 < nivel < NIVELES_DE_LADO - 1


def _de_gondola() -> dict:
    return {e: tandas for e, tandas in ESTANTES.items() if not es_heladera(e)}


def _de_lado() -> dict:
    return {e: tandas for e, tandas in _de_gondola().items() if not es_cabecera(e)}


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

    def test_se_repone_solo_a_la_altura_de_la_mano(self):  # AC-STK-028
        for estante, tandas in _de_gondola().items():
            for t in tandas:
                self.assertEqual(
                    not t.fija, _es_de_reposicion(estante), f"{t.producto} en {estante}"
                )

    def test_un_estante_de_lado_lleva_dos_tandas_o_una_sola_con_casilleros(self):  # AC-STK-051
        for estante, tandas in _de_lado().items():
            entero = len(tandas) == 1 and not tandas[0].fija
            self.assertTrue(len(tandas) == 2 or entero, f"{estante}: {len(tandas)}")

    def test_cada_cara_de_lado_tiene_un_solo_estante_entero(self):
        # Los lugares a la altura de la mano son más que los productos: lo que sobra no se llena
        # con tandas fijas, sino con un estante entero de un solo producto por cara.
        enteros = [e for e, tandas in _de_lado().items() if len(tandas) == 1]
        caras = sorted(".".join(e.split(".")[:2]) for e in enteros)
        self.assertEqual(caras, sorted(CARAS_DE_LADO))

    def test_ningun_producto_va_justo_encima_de_si_mismo(self):
        for estante, tandas in _de_gondola().items():
            mueble, cara, nivel = partes(estante)
            arriba = ESTANTES.get(f"{mueble}.{cara}.{nivel + 1}", ())
            repetidos = {t.producto for t in tandas} & {t.producto for t in arriba}
            self.assertEqual(repetidos, set(), f"sobre {estante}")

    def test_una_cabecera_lleva_al_menos_uno(self):
        for estante, tandas in ESTANTES.items():
            if es_cabecera(estante):
                self.assertGreaterEqual(len(tandas), 1, estante)

    def test_lo_de_cabecera_va_solo_en_cabecera(self):
        for estante, tandas in ESTANTES.items():
            for t in tandas:
                if t.producto in DE_CABECERA:
                    self.assertTrue(es_cabecera(estante), f"{t.producto} en {estante}")

    def test_lo_de_una_fila_va_una_sola_vez_y_en_una_cara_de_lado(self):  # AC-STK-030
        self.assertEqual(
            set(DE_UNA_FILA),
            {"ACTRONCITO", "COSA_DE_MANI", "PRONGLES", "FLINPUF", "BURBALOO"},
        )
        for estante, tandas in ESTANTES.items():
            for t in tandas:
                if t.producto in DE_UNA_FILA and not t.fija:
                    self.assertTrue(estante in _de_lado(), f"{t.producto} en {estante}")

    def test_la_heladera_repone_lo_frio_una_sola_vez_y_repite_solo_lo_frio(self):
        en_heladera = [
            t for estante, tandas in ESTANTES.items() if es_heladera(estante) for t in tandas
        ]
        con_casilleros = sorted(t.producto for t in en_heladera if not t.fija)
        self.assertEqual(con_casilleros, sorted(FRIOS))
        for t in en_heladera:
            self.assertIn(t.producto, FRIOS)
        for estante, tandas in ESTANTES.items():
            for t in tandas:
                if t.producto in FRIOS:
                    self.assertTrue(es_heladera(estante), f"{t.producto} en {estante}")

    def test_ninguna_bandeja_de_heladera_queda_vacia(self):
        # Decidido por el usuario el 2026-09-29: las bandejas que sobran se llenan con repetidos
        # fijos de lo frío, como los estantes de góndola que no se completan sin repetir.
        for letra in HELADERAS:
            for nivel in range(BANDEJAS_DE_HELADERA):
                self.assertIn(f"{letra}.este.{nivel}", ESTANTES)

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
