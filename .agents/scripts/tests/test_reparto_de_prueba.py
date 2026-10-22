import re
import unittest
from collections import Counter

from lib.repo import RAIZ
from lib.reparto import ESTANTES, PRODUCTOS, Tanda
from lib import reparto_de_prueba
from lib.gondola import Envase, HUECO_MINIMO, MARGEN
from lib.reparto_de_prueba import (
    ESTANTES_DE_PRUEBA, bandas_del_nivel, bases_del_contenido,
    validar_identidades_de_prueba,
    validar_reparto_de_prueba,
)


_REGLAS = (RAIZ / "src/dominio/almacen/reglas_del_estante.gd").read_text(encoding="utf-8")


def _regla(nombre):
    return float(re.search(rf"^const {nombre} := ([0-9.]+)$", _REGLAS, re.M)[1])


MINIMO = _regla("SEPARACION_MINIMA_DE_EXHIBICION")
AIRE_CENTRAL = _regla("AIRE_MINIMO_ENTRE_TANDAS")
AIRE_ENTRE_CARAS = _regla("AIRE_MINIMO_ENTRE_CARAS")


def _distribuir(largo, envases, cuentas, huecos, extremos=None):
    return reparto_de_prueba.centros_con_referencia(
        largo, envases, cuentas, huecos, extremos, minimo=MINIMO, aire_central=AIRE_CENTRAL
    )


class RepartoDePrueba(unittest.TestCase):
    def test_el_retiro_frontal_no_comprime_el_ancho_transversal_de_la_cabecera(self):  # AC-STK-100
        envase = Envase(10 * HUECO_MINIMO, 10 * MARGEN, 20 * MARGEN)
        cuenta, hueco = 7, 2 * HUECO_MINIMO
        ancho = cuenta * envase.ancho + (cuenta - 1) * hueco
        largo = ancho + 2 * MARGEN
        inicio, fin = reparto_de_prueba.tramo_con_referencia(
            largo, MARGEN, ancho, 10 * MARGEN, cabecera=True
        )
        fila = _distribuir(
            fin - inicio, [envase], [cuenta], [hueco]
        )[0]
        self.assertEqual(len(fila), cuenta)
        self.assertGreaterEqual(inicio + fila[0] - envase.ancho / 2, MARGEN)
        self.assertLessEqual(inicio + fila[-1] + envase.ancho / 2, largo - MARGEN + 1e-9)
        for a, b in zip(fila, fila[1:]):
            self.assertAlmostEqual(b - a - envase.ancho, hueco)

    def test_el_lateral_reserva_aire_detras_de_ambas_cabeceras(self):  # AC-STK-100
        largo = 200 * HUECO_MINIMO
        retiros = (10 * MARGEN, 12 * MARGEN)
        separaciones = (3 * HUECO_MINIMO, 4 * HUECO_MINIMO)
        inicio, fin = reparto_de_prueba.tramo_con_referencia(
            largo, MARGEN, largo - 2 * MARGEN, 8 * MARGEN,
            retiros, separaciones,
        )
        # La banda original ya incluye un margen delante y otro detrás de la tanda.
        self.assertGreaterEqual(inicio - (retiros[0] - 2 * MARGEN), separaciones[0])
        self.assertGreaterEqual(largo - fin - (retiros[1] - 2 * MARGEN), separaciones[1])

    def test_rechaza_el_tramo_que_solo_cabe_borrando_el_aire(self):  # AC-STK-104
        envase = Envase(20 * MINIMO, MARGEN, MARGEN)
        cuenta = 4
        exacto = cuenta * envase.ancho + (cuenta - 1) * MINIMO
        fila = _distribuir(exacto, [envase], [cuenta], [MINIMO])[0]
        self.assertEqual(len(fila), cuenta)
        for a, b in zip(fila, fila[1:]):
            self.assertAlmostEqual(b - a - envase.ancho, MINIMO)
        with self.assertRaises(ValueError):
            _distribuir(exacto - MINIMO, [envase], [cuenta], [MINIMO])

    def test_el_minimo_exacto_incluye_el_aire_de_caras_y_de_la_union(self):  # AC-STK-104
        envases = [Envase(20 * MINIMO, MARGEN, MARGEN)] * 2
        cuentas = [3, 2]
        longitud = sum(c * e.ancho + (c - 1) * MINIMO for c, e in zip(cuentas, envases))
        longitud += 2 * AIRE_ENTRE_CARAS + AIRE_CENTRAL
        filas = _distribuir(longitud, envases, cuentas, [MINIMO] * 2, (AIRE_ENTRE_CARAS,) * 2)
        self.assertEqual([len(f) for f in filas], cuentas)
        union = filas[1][0] - filas[0][-1] - envases[0].ancho / 2 - envases[1].ancho / 2
        self.assertAlmostEqual(union, AIRE_CENTRAL)
        self.assertAlmostEqual(filas[0][0] - envases[0].ancho / 2, AIRE_ENTRE_CARAS)
        with self.assertRaises(ValueError):
            _distribuir(longitud - MINIMO, envases, cuentas, [MINIMO] * 2, (AIRE_ENTRE_CARAS,) * 2)

    def test_el_aire_extra_de_las_puntas_no_roba_el_ritmo_y_deja_la_mitad_abierta(self):  # AC-STK-101
        envases = [Envase(10 * HUECO_MINIMO, MARGEN, MARGEN)] * 2
        cuentas = [4, 2]
        huecos = [2 * HUECO_MINIMO] * 2
        extremos = (AIRE_ENTRE_CARAS, AIRE_ENTRE_CARAS)
        mitad = 4 * envases[0].ancho + 3 * huecos[0] + sum(extremos)
        filas = _distribuir(2 * mitad, envases, cuentas, huecos, extremos)
        for e, c, h, fila in zip(envases, cuentas, huecos, filas):
            self.assertEqual(len(fila), c)
            for a, b in zip(fila, fila[1:]):
                self.assertAlmostEqual(b - a - e.ancho, h)
        union = filas[1][0] - envases[1].ancho / 2 - filas[0][-1] - envases[0].ancho / 2
        self.assertGreaterEqual(union, AIRE_CENTRAL - 1e-9)

    def test_cada_tanda_conserva_el_ritmo_de_su_envase_y_el_sobrante_queda_en_los_bordes(self):  # AC-STK-100
        envases = [Envase(20 * HUECO_MINIMO, 4 * MARGEN, 10 * MARGEN),
                   Envase(30 * HUECO_MINIMO, 4 * MARGEN, 10 * MARGEN)]
        cuentas = [3, 2]
        huecos = [HUECO_MINIMO * 1.5, HUECO_MINIMO * 3.5]
        largo = sum(e.ancho * c + h * (c - 1)
                    for e, c, h in zip(envases, cuentas, huecos)) + 8 * MARGEN + 2 * AIRE_CENTRAL
        filas = _distribuir(largo, envases, cuentas, huecos)
        mitad = largo / len(envases)
        for indice, (envase, cuenta, hueco, fila) in enumerate(
            zip(envases, cuentas, huecos, filas)
        ):
            self.assertEqual(len(fila), cuenta)
            for a, b in zip(fila, fila[1:]):
                self.assertAlmostEqual(b - a - envase.ancho, hueco)
            izquierda = fila[0] - envase.ancho / 2
            derecha = fila[-1] + envase.ancho / 2
            self.assertGreaterEqual(izquierda, indice * mitad)
            self.assertLessEqual(derecha, (indice + 1) * mitad)
            self.assertAlmostEqual(izquierda - indice * mitad, (indice + 1) * mitad - derecha)

    def test_el_sobrante_de_una_mitad_evita_comprimir_el_ritmo_de_la_otra(self):  # AC-STK-100
        envases = [Envase(0.2, 0.1, 0.3), Envase(0.1, 0.1, 0.2)]
        cuentas = [3, 2]
        huecos = [4 * HUECO_MINIMO, 2 * HUECO_MINIMO]
        parte = 3 * envases[0].ancho + 2 * HUECO_MINIMO + AIRE_CENTRAL
        filas = _distribuir(2 * parte, envases, cuentas, huecos)
        for fila, envase, cuenta in zip(filas, envases, cuentas):
            self.assertEqual(len(fila), cuenta)
            for a, b in zip(fila, fila[1:]):
                self.assertGreaterEqual(b - a - envase.ancho, 0)
        self.assertAlmostEqual(filas[0][1] - filas[0][0] - envases[0].ancho, huecos[0])
        self.assertAlmostEqual(filas[0][2] - filas[0][1] - envases[0].ancho, huecos[0])
        self.assertAlmostEqual(filas[1][1] - filas[1][0] - envases[1].ancho, huecos[1])

    def test_rechaza_un_cupo_que_no_cabe_aun_sin_separacion(self):  # AC-STK-100
        envase = Envase(0.2, 0.1, 0.3)
        with self.assertRaises(ValueError):
            _distribuir(
                3 * envase.ancho - MARGEN, [envase], [3], [HUECO_MINIMO]
            )

    def test_retroceden_todos_los_laterales_de_las_islas_y_ninguna_cabecera(self):
        retiros = reparto_de_prueba.RETIROS_POR_ESTANTE_DE_PRUEBA
        laterales = {clave for clave in ESTANTES_DE_PRUEBA
                     if clave.split(".")[0] in ("A", "B")
                     and clave.split(".")[1] in ("este", "oeste")}
        self.assertEqual(set(retiros), laterales)
        self.assertTrue(all(retiro > 0 for retiro in retiros.values()))

    def test_cada_uno_de_los_cuatro_niveles_repite_el_mapa(self):  # AC-STK-096
        caras = {
            "A.oeste": ("ARVECOR", "MAROLINI"),
            "A.este": ("TERMINATOR", "ZUCARACHAS"),
            "A.norte": ("FERNET_GOD",), "A.sur": ("MALBARDO",),
            "B.este": ("PEPITO", "PETISAS"),
            "B.oeste": ("PROGRES", "DON_SATURADOS"),
            "B.norte": ("JORGILLO",), "B.sur": ("POETICO",),
            "N.sur": ("ACTRONCITO", "DURONGA"),
            "H1.sur": ("PURA_COLA",), "H2.sur": ("MAYONCHIS",),
        }
        self.assertEqual(len(ESTANTES_DE_PRUEBA), 44)
        for cara, productos in caras.items():
            for nivel in range(4):
                with self.subTest(cara=cara, nivel=nivel):
                    reales = tuple(t.producto for t in ESTANTES_DE_PRUEBA[f"{cara}.{nivel}"])
                    self.assertEqual(reales, productos)

    def test_una_principal_y_tres_repeticiones_por_producto(self):  # AC-STK-096
        principales = Counter(t.producto for ts in ESTANTES_DE_PRUEBA.values()
                              for t in ts if not t.fija)
        fijas = Counter(t.producto for ts in ESTANTES_DE_PRUEBA.values()
                        for t in ts if t.fija)
        self.assertEqual(len(principales), 16)
        self.assertEqual(set(principales.values()), {1})
        self.assertEqual(fijas, Counter({p: 3 for p in principales}))

    def test_el_mapa_no_modifica_el_perfil_completo(self):
        self.assertIsNot(ESTANTES_DE_PRUEBA, ESTANTES)
        self.assertEqual(tuple(t.producto for t in ESTANTES["B.sur.1"]), ("FLIM_POF",))

    def test_catalogo_y_mapa_tienen_las_mismas_identidades_en_orden(self):  # AC-STK-095
        texto = (RAIZ / "src/dominio/almacen/catalogo.gd").read_text(encoding="utf-8")
        bloque = re.search(r"const PRODUCTOS_DE_PRUEBA.*?=\s*\[(.*?)\]", texto, re.S)
        self.assertIsNotNone(bloque)
        ids = re.findall(r"Producto\.Id\.(\w+)", bloque.group(1))
        validar_identidades_de_prueba(ids)
        with self.assertRaises(ValueError):
            validar_identidades_de_prueba(ids[:-1])

    def test_rechaza_un_ausente_un_nivel_perdido_y_dos_principales(self):  # AC-STK-096
        validar_reparto_de_prueba(ESTANTES_DE_PRUEBA)
        perdido = dict(ESTANTES_DE_PRUEBA)
        del perdido["B.sur.0"]
        ajeno = dict(ESTANTES_DE_PRUEBA, **{"B.sur.0": (Tanda("BURBALOO", fija=True),)})
        duplicado = dict(ESTANTES_DE_PRUEBA, **{"B.sur.2": (Tanda("POETICO"),)})
        fuera_de_alcance = dict(ESTANTES_DE_PRUEBA, **{
            "B.sur.1": (Tanda("POETICO", fija=True),), "B.sur.0": (Tanda("POETICO"),)
        })
        for variante in (perdido, ajeno, duplicado, fuera_de_alcance):
            with self.subTest(variante=variante.keys()), self.assertRaises(ValueError):
                validar_reparto_de_prueba(variante)

    def test_las_cuatro_bandas_cubren_el_soporte_sin_superponerse(self):
        bandas = bandas_del_nivel(-1, 1, -3, 3, 0.4, 0.3)
        self.assertEqual(set(bandas), {"norte", "sur", "oeste", "este"})
        self.assertEqual(bandas["norte"].y0, 2.6)
        self.assertEqual(bandas["sur"].y1, -2.7)
        area = sum((b.x1 - b.x0) * (b.y1 - b.y0) for b in bandas.values())
        self.assertAlmostEqual(area, 12)
        for cara, a in bandas.items():
            for otra, b in bandas.items():
                if cara != otra:
                    self.assertFalse(min(a.x1, b.x1) > max(a.x0, b.x0)
                                     and min(a.y1, b.y1) > max(a.y0, b.y0))

    def test_un_soporte_insuficiente_no_publica_bandas(self):
        with self.assertRaises(ValueError):
            bandas_del_nivel(-1, 1, 0, 1, 0.6, 0.6)

    def test_las_bases_horneadas_se_indexan_por_identidad_y_conservan_sus_filas(self):
        texto = "\n".join(
            f'[node name="Nombre{indice}" type="MeshInstance3D" parent="."]\n'
            'transform = Transform3D(1, 2, 3, 0, 1, 4, 5, 6, 0, 9, 8, 7)\n'
            f'metadata/producto_id = {indice}\n'
            for indice in range(len(PRODUCTOS))
        )
        bases = bases_del_contenido(texto)
        self.assertEqual(set(bases), {p.clave for p in PRODUCTOS})
        self.assertEqual(bases["ACTRONCITO"], ((1, 2, 3), (0, 1, 4), (5, 6, 0)))

    def test_una_base_faltante_o_identidad_duplicada_no_normaliza_las_guias(self):
        ruta = RAIZ / "src/escenas/puestos/contenido_del_estante.tscn"
        texto = ruta.read_text(encoding="utf-8")
        self.assertEqual(len(bases_del_contenido(texto)), len(PRODUCTOS))
        for variante in (texto.replace("metadata/producto_id = 0", "metadata/producto_id = 1"),
                         texto.replace("metadata/producto_id = 0", "metadata/otro = 0")):
            with self.assertRaises(ValueError):
                bases_del_contenido(variante)

