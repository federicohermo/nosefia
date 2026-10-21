import re
import unittest
from collections import Counter

from lib.repo import RAIZ
from lib.reparto import ESTANTES, PRODUCTOS, Tanda
from lib.reparto_de_prueba import (
    ESTANTES_DE_PRUEBA, bandas_del_nivel, bases_del_contenido,
    validar_identidades_de_prueba,
    validar_reparto_de_prueba,
)


class RepartoDePrueba(unittest.TestCase):
    def test_cada_uno_de_los_cuatro_niveles_repite_el_mapa(self):  # AC-STK-096
        caras = {
            "A.oeste": ("ARVECOR", "MAROLINI"),
            "A.este": ("TERMINATOR", "ZUCARACHAS"),
            "A.norte": ("FERNET_GOD",), "A.sur": ("MALBARDO",),
            "B.este": ("PEPITO", "PETISAS"),
            "B.oeste": ("PROGRES", "DON_SATURADOS"),
            "B.norte": ("JORGILLO",), "B.sur": ("POETICO",),
            "N.sur": ("ACTRONCITO", "DUREXTRA"),
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

