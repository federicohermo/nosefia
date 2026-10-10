"""El gate de la coherencia: **ninguna herramienta informativa contesta distinto que su gate.**

Este repo tiene dos clases de programa sobre el mismo código. Los **gates** dan un veredicto y su
rojo es el producto. Las **herramientas** —`estructura.py`, el servidor MCP— sólo informan, para
que explorar cueste una consulta en vez de diez.

**Cuando las dos miran lo mismo y contestan distinto, la que pierde es la herramienta**: se deja
de mirar el mismo día, y con ella se pierde el ahorro que justificaba escribirla. Ya pasó dos
veces en una tarde:

- `estructura.py` dibujó tres flechas de `dominio/` a `sistemas/` —que el gate de capas pone en
  rojo— sobre un repo con el nodo `capas` en verde: contaba nombres escritos en comentarios.
- El `sin_test` del MCP listó los `.gd` de `ui/` y `escenas/` como faltos de test espejo, que es
  justo lo que `gate_de_tests.py` **no** pide: habría empujado a escribir los tests de humo que
  la regla de presentación prohíbe.

La forma de cerrarlo no es comparar salidas: es que **la herramienta llame a la misma función del
gate, con los mismos argumentos**. Estos casos lo verifican de punta a punta, y son lo que hay que
copiar cuando entre la herramienta siguiente.
"""

import sys
import unittest

from lib.capas import violaciones as violaciones_de_capas
from lib.repo import CAPAS, CAPAS_CON_TEST_OBLIGATORIO, CARPETAS_POR_CAPA, RAIZ, TESTS
from lib.specs import ids_citados, specs_del_repo
from lib.tdd import violaciones as violaciones_de_tdd

sys.path.insert(0, str(RAIZ / "mcp-server"))
sys.path.insert(0, str(RAIZ / ".claude" / "scripts"))

import estructura  # noqa: E402
import herramientas  # noqa: E402


class ElMcpNoContradiceAlGateDeTests(unittest.TestCase):
    def test_lista_exactamente_los_espejos_que_el_gate_reclama(self):
        fuentes, tests = herramientas._fuentes(), herramientas._tests()
        del_gate = {
            ruta
            for ruta, motivo in violaciones_de_tdd(
                fuentes, tests, CAPAS_CON_TEST_OBLIGATORIO, TESTS
            )
            if "falta" in motivo
        }
        salida = herramientas.sin_test().split("## Criterios")[0]
        de_la_herramienta = {
            linea.split(" → ")[0].removeprefix("- ").strip()
            for linea in salida.splitlines()
            if linea.startswith("- ") and " → " in linea
        }
        self.assertEqual(de_la_herramienta, del_gate)

    def test_no_reclama_test_a_las_capas_que_no_lo_llevan(self):
        seccion = herramientas.sin_test().split("## Criterios")[0]
        for capa in (c for c, _ in CAPAS if c not in CAPAS_CON_TEST_OBLIGATORIO):
            self.assertNotIn(f"{capa}/", seccion, f"`{capa}/` no lleva test obligatorio")


    def test_tests_de_dice_lo_mismo_que_el_gate_sobre_cada_espejo(self):
        # La otra punta de `sin_test`: preguntado archivo por archivo, tiene que contestar
        # «FALTA» exactamente donde el gate lo reclama, y nunca donde no.
        fuentes, suites = herramientas._fuentes(), herramientas._tests()
        del_gate = {
            ruta
            for ruta, motivo in violaciones_de_tdd(
                fuentes, suites, CAPAS_CON_TEST_OBLIGATORIO, TESTS
            )
            if "falta" in motivo
        }
        for ruta in fuentes:
            with self.subTest(ruta=ruta):
                self.assertEqual("FALTA" in herramientas.tests_de(ruta), ruta in del_gate)


class ElMcpNoContradiceAlGateDeSpecs(unittest.TestCase):
    def test_los_criterios_sin_cita_son_los_mismos_que_ve_el_gate(self):
        citados = ids_citados((RAIZ / TESTS, RAIZ / ".claude" / "scripts" / "tests"))
        del_gate = {
            criterio
            for spec in specs_del_repo()
            for criterio in spec.criterios
            if criterio not in citados
        }
        salida = herramientas.sin_test()
        for criterio in del_gate:
            self.assertIn(criterio, salida, "el gate lo ve sin cita y la herramienta no lo lista")
        # Y la otra dirección: no puede listar uno que sí está citado.
        for spec in specs_del_repo():
            for criterio in spec.criterios:
                if criterio in citados:
                    self.assertNotIn(
                        criterio,
                        salida.split("## Criterios")[-1],
                        "lo lista como sin cita y está citado",
                    )

    def test_la_cita_de_un_criterio_la_ven_los_dos_lectores(self):
        # La cita vive en un **comentario** —`# AC-EMP-004` al final de la línea—, así que quien
        # la busque sobre el texto limpio no la encuentra y contesta que nadie la cita. Le pasó
        # al servidor MCP en su primer humo.
        archivos = {"x_test.gd": "func test_algo() -> void:  # AC-EMP-004\n"}
        self.assertEqual(
            herramientas._menciones("AC-EMP-004", archivos, limpiar=False), [("x_test.gd", 1)]
        )
        for spec in specs_del_repo():
            if spec.estado != "ratified":
                continue
            citados = ids_citados((RAIZ / TESTS, RAIZ / ".claude" / "scripts" / "tests"))
            for criterio in spec.criterios:
                with self.subTest(criterio=criterio):
                    self.assertIn(criterio, citados, "un `ratified` con un criterio sin cita")
                    self.assertIn("Lo citan", herramientas.criterio(criterio))


class ElMapaNoContradiceAlGateDeCapas(unittest.TestCase):
    def test_ninguna_flecha_del_grafo_va_contra_la_direccion(self):
        archivos = estructura._fuentes()
        if not archivos:
            self.skipTest("no hay `.gd` en `src/`")
        permitidas = {capa: set(puede) for capa, puede in CAPAS}
        for origen, destino in estructura._referencias_entre_capas(archivos):
            self.assertIn(destino, permitidas[origen], f"el mapa dibuja {origen} → {destino}")
        self.assertEqual(violaciones_de_capas(archivos, CAPAS), [])

    def test_las_carpetas_que_el_mcp_publica_son_las_que_el_gate_declara(self):
        salida = herramientas.mapa_del_sistema()
        for capa, carpetas in CARPETAS_POR_CAPA.items():
            for carpeta in carpetas:
                self.assertIn(carpeta, salida, f"`{capa}/{carpeta}` no aparece en el mapa")


class LosContratosQueDevuelvenVacio(unittest.TestCase):
    def test_escenas_tscn_sigue_devolviendo_el_texto_vacio(self):
        # **Es deliberado y está documentado**: el gate de capas sólo contesta con ellas el
        # nombre de la carpeta, y devolver el contenido invitaría a pasárselas a `violaciones()`,
        # que es justo lo que `capas.py` declara que no hace.
        #
        # Este caso fija el contrato para que quien necesite el contenido tenga que verlo y
        # releer los archivos, en vez de recibir cadenas vacías y creer que las escenas no dicen
        # nada. Al servidor MCP le pasó: contestó «0 nodos» sobre una escena de 29.
        from lib.archivos import escenas_tscn

        escenas = escenas_tscn(RAIZ, "src")
        if not escenas:
            self.skipTest("no hay `.tscn` en `src/`")
        self.assertTrue(all(texto == "" for texto in escenas.values()))

    def test_y_el_mcp_las_relee_en_vez_de_creerles(self):
        escenas = herramientas._escenas()
        if not escenas:
            self.skipTest("no hay `.tscn` en `src/`")
        self.assertTrue(any(texto.strip() for texto in escenas.values()))


if __name__ == "__main__":
    unittest.main()
