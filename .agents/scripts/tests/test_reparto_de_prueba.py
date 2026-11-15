import re
import unittest
from collections import Counter

from lib.repo import RAIZ
from lib.reparto import ESTANTES, PRODUCTOS, Tanda
from lib.reparto_de_prueba import (
    ESTANTES_DE_PRUEBA, REEMPLAZOS, bases_del_contenido, cara_de, cuantas_entran, derivar,
    paso_parejo, presentes, repartir_columnas, validar_identidades_de_prueba,
    validar_reemplazos, validar_reparto_de_prueba,
)


class RepartoDePrueba(unittest.TestCase):
    def test_cada_producto_presente_conserva_sus_tandas_del_mapa_completo(self):  # AC-STK-096
        for estante, tandas in ESTANTES.items():
            for columna, completa in enumerate(tandas):
                de_prueba = ESTANTES_DE_PRUEBA[estante][columna]
                with self.subTest(estante=estante, columna=columna):
                    if completa.producto in REEMPLAZOS:
                        self.assertEqual(de_prueba.producto, REEMPLAZOS[completa.producto])
                        self.assertTrue(de_prueba.fija)
                    else:
                        self.assertEqual(de_prueba, completa)

    def test_ningun_estante_queda_vacio_ni_lleva_un_ausente(self):  # AC-STK-096
        self.assertEqual(ESTANTES_DE_PRUEBA.keys(), ESTANTES.keys())
        for estante, tandas in ESTANTES_DE_PRUEBA.items():
            with self.subTest(estante=estante):
                self.assertEqual(len(tandas), len(ESTANTES[estante]))
                self.assertFalse({t.producto for t in tandas} & REEMPLAZOS.keys())

    def test_una_sola_principal_por_producto_presente(self):  # AC-STK-096
        principales = Counter(
            t.producto for tandas in ESTANTES_DE_PRUEBA.values() for t in tandas if not t.fija
        )
        self.assertEqual(principales, Counter({p: 1 for p in presentes()}))

    def test_cada_ausente_lo_reemplaza_un_presente_de_su_cara(self):  # AC-STK-096
        validar_reemplazos(ESTANTES)
        self.assertEqual(
            REEMPLAZOS.keys() | set(presentes()), {p.clave for p in PRODUCTOS}
        )
        caras = {}
        for estante, tandas in ESTANTES.items():
            for t in tandas:
                caras.setdefault(t.producto, set()).add(cara_de(estante))
        ausente, reemplazo = next(iter(REEMPLAZOS.items()))
        de_otra_cara = next(p for p in presentes() if not caras[p] & caras[ausente])
        mudado = {
            estante: tuple(
                Tanda(de_otra_cara if t.producto == reemplazo else t.producto, fija=t.fija)
                for t in tandas
            )
            for estante, tandas in ESTANTES.items()
        }
        with self.assertRaises(ValueError):
            validar_reemplazos(mudado)

    def test_el_mapa_no_modifica_el_perfil_completo(self):
        self.assertIsNot(ESTANTES_DE_PRUEBA, ESTANTES)
        self.assertEqual(derivar(ESTANTES), ESTANTES_DE_PRUEBA)
        self.assertTrue(
            any(t.producto in REEMPLAZOS for tandas in ESTANTES.values() for t in tandas)
        )

    def test_catalogo_y_mapa_tienen_las_mismas_identidades_en_orden(self):  # AC-STK-095
        texto = (RAIZ / "src/dominio/almacen/catalogo.gd").read_text(encoding="utf-8")
        bloque = re.search(r"const PRODUCTOS_DE_PRUEBA.*?=\s*\[(.*?)\]", texto, re.S)
        self.assertIsNotNone(bloque)
        ids = re.findall(r"Producto\.Id\.(\w+)", bloque.group(1))
        validar_identidades_de_prueba(ids)
        with self.assertRaises(ValueError):
            validar_identidades_de_prueba(ids[:-1])

    def test_rechaza_un_ausente_una_principal_perdida_y_dos_principales(self):  # AC-STK-096
        validar_reparto_de_prueba(ESTANTES_DE_PRUEBA)
        estante, tandas = next(
            (e, ts) for e, ts in ESTANTES_DE_PRUEBA.items() if any(not t.fija for t in ts)
        )
        principal = next(t for t in tandas if not t.fija)
        ausente = next(iter(REEMPLAZOS))
        con_ausente = dict(ESTANTES_DE_PRUEBA, **{estante: (Tanda(ausente, fija=True),)})
        sin_principal = dict(
            ESTANTES_DE_PRUEBA,
            **{estante: tuple(Tanda(t.producto, fija=True) for t in tandas)},
        )
        duplicada = dict(ESTANTES_DE_PRUEBA, **{"otro": (Tanda(principal.producto),)})
        for variante in (con_ausente, sin_principal, duplicada):
            with self.subTest(variante=variante[estante]), self.assertRaises(ValueError):
                validar_reparto_de_prueba(variante)

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


class RepartoDePuntaAPunta(unittest.TestCase):
    def test_entran_las_que_caben_con_su_paso_y_nunca_menos_de_una(self):
        self.assertEqual(cuantas_entran(1.0, 0.25, 0.25), 4)
        self.assertEqual(cuantas_entran(0.99, 0.25, 0.25), 3)
        self.assertEqual(cuantas_entran(0.1, 0.25, 0.25), 1)

    def test_el_paso_parejo_deja_la_primera_y_la_ultima_en_los_bordes(self):
        largo, ancho, cuantas = 2.0, 0.2, 7
        paso = paso_parejo(largo, ancho, cuantas, 0.25)
        self.assertAlmostEqual(ancho + paso * (cuantas - 1), largo)
        self.assertEqual(paso_parejo(largo, ancho, 1, 0.25), 0.25)

    def test_las_columnas_se_reparten_en_proporcion_y_no_se_pierde_ninguna(self):
        self.assertEqual(repartir_columnas(8, [4, 4]), [4, 4])
        self.assertEqual(repartir_columnas(7, [4, 3]), [4, 3])
        for columnas in range(1, 30):
            for frentes in ([3, 5], [7, 7], [1, 4, 2]):
                with self.subTest(columnas=columnas, frentes=frentes):
                    self.assertEqual(sum(repartir_columnas(columnas, frentes)), columnas)
