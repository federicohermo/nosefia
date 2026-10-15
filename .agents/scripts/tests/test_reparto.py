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
    MUEBLES_SIN_EXHIBICION,
    PRODUCTOS,
    SECTORES,
    SOLO_DEPOSITO,
    Tanda,
    es_cabecera,
    es_heladera,
    partes,
    sector_de,
    validar_reparto,
    validar_tandas,
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
CARAS_DE_LADO = ("A.oeste", "A.este", "B.oeste", "B.este", "N.sur", "S.sur")


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
    def test_los_sectores_siguen_el_esquema_y_no_reparten_por_marca(self):  # AC-STK-086
        esperados = {
            "A.oeste.2": ("MAROLINI", "ARVEJAS"),
            "A.oeste.1": ("UAKAS", "MARRANOS"),
            "A.este.2": ("MACUMBAS", "ZUCARACHAS"),
            "A.este.1": ("PEPITOS", "FROTLUPS"),
            "A.sur.1": ("MALBARDO",), "A.sur.0": ("AMARGADITO",),
            "A.norte.1": ("OAAAA",), "A.norte.0": ("TERMINATOR",),
            "B.este.2": ("OREMOS", "PETISAS"),
            "B.este.1": ("COSA_DE_MANI", "FEEL_RICKY_FORT"),
            "B.oeste.2": ("DONSATURADOS", "PRONGLES"),
            "B.oeste.1": ("CHISITOS", "LAYSNTT"),
            "B.sur.1": ("JORGILLO",), "B.sur.0": ("SALADIK",),
            "B.norte.1": ("BURBALOO",), "B.norte.0": ("FLINPUF",),
            "N.sur.2": ("ACTRONCITO", "DUREXTRA"),
            "N.sur.1": ("POETICO",),
        }
        for estante, productos in esperados.items():
            self.assertEqual(tuple(t.producto for t in ESTANTES[estante]), productos, estante)

    def test_duronga_no_tiene_tanda_y_el_mural_sobrante_no_inventa_exhibicion(self):
        # AC-STK-088, AC-STK-085: sigue en el catálogo, sin unidad ni referencia en el local.
        self.assertIn("DURONGA", {p.clave for p in PRODUCTOS})
        self.assertNotIn("DURONGA", {t.producto for ts in ESTANTES.values() for t in ts})
        self.assertFalse(any(e.startswith("S.") for e in ESTANTES))

    def test_las_heladeras_tienen_mitades_verticales_y_solo_esos_frios(self):  # AC-STK-087
        esperados = {"H1": ("FERNET_GOD", "CORACOLA"), "H2": ("MAYONCHIS", "CINDOLOR")}
        for mueble, (abajo, arriba) in esperados.items():
            for nivel in range(BANDEJAS_DE_HELADERA):
                self.assertEqual(
                    {t.producto for t in ESTANTES[f"{mueble}.sur.{nivel}"]},
                    {abajo if nivel < 2 else arriba},
                )

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
            self.assertEqual(principales[p.clave], 0 if p.clave in SOLO_DEPOSITO else 1, p.nombre)

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

    def test_un_estante_de_lado_lleva_dos_tandas_o_una_sola(self):  # AC-STK-051
        for estante, tandas in _de_lado().items():
            self.assertIn(len(tandas), (1, 2), f"{estante}: {len(tandas)}")

    def test_las_referencias_conservan_el_sector_de_su_principal(self):  # AC-STK-086
        validar_reparto(ESTANTES)
        vistos = set()
        for estante, tandas in ESTANTES.items():
            for columna, t in enumerate(tandas):
                self.assertIn(t.producto, SECTORES[sector_de(estante, columna)])
                vistos.add(t.producto)
        self.assertEqual(vistos, {p.clave for p in PRODUCTOS} - set(SOLO_DEPOSITO))

    def test_solo_el_producto_de_deposito_admite_cero_tandas(self):  # AC-STK-085
        cantidades = {p.clave: int(p.clave not in SOLO_DEPOSITO) for p in PRODUCTOS}
        validar_tandas(cantidades)
        for clave, cantidad in (("ACTRONCITO", 0), ("ACTRONCITO", 2), ("DURONGA", 1),
                                ("DESCONOCIDO", 1)):
            with self.subTest(clave=clave, cantidad=cantidad), self.assertRaises(ValueError):
                validar_tandas(cantidades | {clave: cantidad})

    def test_un_producto_ajeno_no_recibe_sector_por_defecto(self):  # AC-STK-085
        with self.assertRaises(ValueError):
            validar_reparto(ESTANTES | {"A.oeste.2": (Tanda("DESCONOCIDO"),)})
        with self.assertRaises(KeyError):
            sector_de("NO_EXISTE.sur.1", 0)

    def test_una_cabecera_lleva_al_menos_uno(self):
        for estante, tandas in ESTANTES.items():
            if es_cabecera(estante):
                self.assertGreaterEqual(len(tandas), 1, estante)

    def test_lo_de_cabecera_va_solo_en_cabecera(self):
        for estante, tandas in ESTANTES.items():
            for t in tandas:
                if t.producto in DE_CABECERA:
                    self.assertTrue(es_cabecera(estante), f"{t.producto} en {estante}")

    def test_lo_de_una_fila_se_conserva_en_el_sector_del_mapa(self):  # AC-STK-030
        self.assertEqual(
            set(DE_UNA_FILA),
            {"ACTRONCITO", "COSA_DE_MANI", "PRONGLES", "FLINPUF", "BURBALOO"},
        )
        for estante, tandas in ESTANTES.items():
            for t in tandas:
                if t.producto in DE_UNA_FILA and not t.fija:
                    self.assertIn(t.producto, SECTORES[sector_de(estante, tandas.index(t))])

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
                self.assertIn(f"{letra}.sur.{nivel}", ESTANTES)

    def test_ningun_estante_de_gondola_queda_vacio(self):
        for letra in MUEBLES:
            if letra in HELADERAS:
                continue
            if letra in MUEBLES_SIN_EXHIBICION:
                self.assertFalse(any(e.startswith(letra + ".") for e in ESTANTES))
                continue
            caras = ["sur"] if letra in ("N", "S") else ["oeste", "este", *CABECERAS]
            for cara in caras:
                niveles = (
                    NIVELES_DE_CABECERA if es_cabecera(f"{letra}.{cara}.0") else NIVELES_DE_LADO
                )
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
