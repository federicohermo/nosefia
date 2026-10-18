"""Los tests de `lib/reparto.py`: que el reparto de la góndola cumpla las reglas antes de llegar
al `.blend`.

El reparto se itera con el usuario mirando capturas, y cada vuelta es una línea que se mueve de
un estante a otro. Una regla rota ahí —un producto con dos principales, una tanda fija
a la altura de la mano— no la ve ningún test del juego hasta después de acomodar, exportar y medir:
acá se ve antes de correr nada.
"""

import re
import unittest
from collections import Counter
from unittest.mock import patch

from lib.reparto import (
    CABECERAS,
    DE_CABECERA,
    DE_UNA_FILA,
    ESTANTES,
    FRIOS,
    HELADERAS,
    MUEBLES,
    PRODUCTOS,
    SECTORES,
    SOLO_DEPOSITO,
    Tanda,
    cara_de_isla,
    es_cabecera,
    es_heladera,
    partes,
    sector_de,
    validar_reparto,
    validar_tandas,
)
from lib.repo import RAIZ

CATALOGO = RAIZ / "src/dominio/almacen/catalogo.gd"

#: Las cuatro chapas originales: zócalo y superior fijos, los dos niveles centrales reponibles.
NIVELES_DE_LADO = 4
NIVELES_DE_CABECERA = 4

#: Cuántas bandejas tiene cada heladera. Medido sobre el mismo `.blend`.
BANDEJAS_DE_HELADERA = 4

#: Las caras de lado del local: las dos de cada góndola del medio y la única de las de pared.
CARAS_DE_LADO = ("A.oeste", "A.este", "B.oeste", "B.este", "N.sur")


def _es_de_reposicion(estante: str) -> bool:
    """Los niveles centrales son principales; zócalo y superior son fijos, también en cabeceras."""
    _, _, nivel = partes(estante)
    if es_cabecera(estante):
        return 0 < nivel < NIVELES_DE_CABECERA - 1
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
    def test_las_chapas_inclinadas_son_cabeceras_aunque_acorten_su_fondo(self):
        # AC-STK-085: centros/normales medidos en el modelo; la chapa alta queda a 1,883 m.
        for distancia in (1.883, 1.95, 2.10):
            self.assertEqual(cara_de_isla((0, -0.247, 0.969), (0, distancia, 1.788)), "norte")
            self.assertEqual(cara_de_isla((0, 0.247, 0.969), (0, -distancia, 1.788)), "sur")
        self.assertEqual(cara_de_isla((0, 0, 1), (-0.45, 0, 1.3)), "oeste")
        self.assertEqual(cara_de_isla((0, 0, 1), (0.45, 0, 1.3)), "este")

    def test_los_sectores_siguen_el_esquema_y_no_reparten_por_marca(self):  # AC-STK-086
        esperados = {
            "A.oeste.2": ("MARRANOS", "ARVECOR"),
            "A.oeste.1": ("UAKALAS", "MAROLINI"),
            "A.este.2": ("MACUMBAS", "PEPITO"),
            "A.este.1": ("ZUCARACHAS", "FROT_LUPS"),
            "A.sur.2": ("MALBARDO",), "A.sur.1": ("AMARGADITO",),
            "A.norte.2": ("TERMINATOR",), "A.norte.1": ("FERNET_GOD",),
            "B.este.2": ("DON_SATURADOS", "PETISAS"),
            "B.este.1": ("OREMOS", "FEEL_RICKY_FORT"),
            "B.oeste.2": ("SALADICK", "PROGRES"),
            "B.oeste.1": ("CHISITOS", "LAYSNNT"),
            "B.sur.2": ("COSA_DE_MANI",), "B.sur.1": ("FLIM_POF",),
            "B.norte.2": ("JORGILLO",), "B.norte.1": ("BURBALOO",),
            "N.sur.2": ("DURONGA", "DUREXTRA"),
            "N.sur.1": ("POETICO", "ACTRONCITO"),
        }
        for estante, productos in esperados.items():
            self.assertEqual(tuple(t.producto for t in ESTANTES[estante]), productos, estante)

    def test_dos_estantes_seguidos_llevan_los_mismos_productos(self):  # AC-STK-092
        for clave in ESTANTES:
            mueble, cara, nivel = partes(clave)
            pareja = f"{mueble}.{cara}.{nivel ^ 1}"
            with self.subTest(estante=clave):
                self.assertEqual(
                    [t.producto for t in ESTANTES[clave]], [t.producto for t in ESTANTES[pareja]]
                )

    def test_duronga_comparte_no_comestibles_sin_inventar_muebles_ni_niveles(self):
        # AC-STK-088, AC-STK-085: destino provisional inferior derecho del mapa.
        self.assertIn("DURONGA", {p.clave for p in PRODUCTOS})
        tandas_de_duronga = [
            (estante, tanda)
            for estante, tandas in ESTANTES.items()
            for tanda in tandas
            if tanda.producto == "DURONGA"
        ]
        self.assertEqual(len(tandas_de_duronga), 2)
        for estante, tanda in tandas_de_duronga:
            mueble, cara, nivel = partes(estante)
            self.assertEqual((mueble, cara), ("N", "sur"))
            self.assertIn(nivel, range(NIVELES_DE_LADO))
            self.assertEqual(tanda.cantidad_de_filas, 2)
        self.assertFalse(any(e.startswith("S.") for e in ESTANTES))
        self.assertNotIn("S", MUEBLES)
        for mueble in ("A", "B"):
            for cara in CABECERAS:
                for nivel in range(4):
                    tandas = ESTANTES[f"{mueble}.{cara}.{nivel}"]
                    self.assertTrue(all(t.fija == (nivel in (0, 3)) for t in tandas))

    def test_oaaaa_fernet_y_amargadito_llevan_dos_filas_en_todas_sus_tandas(self):  # AC-STK-030
        for clave in ("H1.sur.0", "H1.sur.1", "A.norte.0", "A.norte.1", "A.sur.0", "A.sur.1"):
            with self.subTest(estante=clave):
                tanda, = ESTANTES[clave]
                self.assertEqual(tanda.cantidad_de_filas, 2)

    def test_solo_una_tanda_fija_puede_declarar_su_cantidad_de_filas(self):
        self.assertEqual(Tanda("FERNET_GOD", fija=True, filas=1).cantidad_de_filas, 1)
        for fija, filas in ((False, 1), (False, 2), (True, 0), (True, 3)):
            with self.subTest(fija=fija, filas=filas), self.assertRaises(ValueError):
                Tanda("FERNET_GOD", fija=fija, filas=filas)

    def test_las_heladeras_tienen_mitades_verticales_y_solo_esos_frios(self):  # AC-STK-087
        esperados = {"H1": ("OAAAA", "PURA_COLA"), "H2": ("MAYONCHIS", "CINDOLOR")}
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

    def test_cada_producto_tiene_una_sola_tanda_principal(self):  # AC-STK-028
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

    def test_los_faltantes_abren_solo_en_niveles_principales(self):  # AC-STK-028
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
        self.assertEqual(vistos, {p.clave for p in PRODUCTOS})

    def test_solo_una_declaracion_explicita_admite_cero_tandas(self):  # AC-STK-085
        self.assertEqual(SOLO_DEPOSITO, ())
        cantidades = {p.clave: 1 for p in PRODUCTOS}
        validar_tandas(cantidades)
        for clave, cantidad in (("ACTRONCITO", 0), ("ACTRONCITO", 2), ("DURONGA", 0),
                                ("DESCONOCIDO", 1)):
            with self.subTest(clave=clave, cantidad=cantidad), self.assertRaises(ValueError):
                validar_tandas(cantidades | {clave: cantidad})
        # Capacidad futura, no el reparto vigente: una declaración explícita admite el vacío.
        with patch("lib.reparto.SOLO_DEPOSITO", ("DURONGA",)):
            validar_tandas(cantidades | {"DURONGA": 0})
            with self.assertRaises(ValueError):
                validar_tandas(cantidades)

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
            {"COSA_DE_MANI", "FLIM_POF", "BURBALOO", "MARRANOS", "POETICO"},
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
            caras = ["sur"] if letra == "N" else ["oeste", "este", *CABECERAS]
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


class DecisionDeFilas(unittest.TestCase):
    def test_actroncito_y_progres_conservan_dos_filas_en_todas_sus_tandas(self):  # AC-STK-030
        for producto in ("ACTRONCITO", "PROGRES"):
            for fija in (False, True):
                with self.subTest(producto=producto, fija=fija):
                    self.assertEqual(Tanda(producto, fija=fija).cantidad_de_filas, 2)

    def test_los_cinco_del_arte_tienen_una_fila_principal_y_fija(self):  # AC-STK-030
        for producto in ("COSA_DE_MANI", "FLIM_POF", "BURBALOO", "MARRANOS", "POETICO"):
            for fija in (False, True):
                with self.subTest(producto=producto, fija=fija):
                    self.assertEqual(Tanda(producto, fija=fija).cantidad_de_filas, 1)

    def test_una_fija_no_puede_eludir_la_excepcion_global_de_una_fila(self):  # AC-STK-030
        for producto in ("COSA_DE_MANI", "FLIM_POF", "BURBALOO", "MARRANOS", "POETICO"):
            with self.subTest(producto=producto), self.assertRaises(ValueError):
                Tanda(producto, fija=True, filas=2)


if __name__ == "__main__":
    unittest.main()
