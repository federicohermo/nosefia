"""Los tests de `lib/specs.py`, que es lo puro del registro de specs."""

import json
import unittest

from lib.specs import (
    aterrizo,
    agrupar_prs_por_spec,
    archivo_de_comentario,
    carpeta_existente,
    derivar_mapa,
    deuda_del_censo,
    en_vuelo,
    escribir_mapa,
    estado_de,
    leer_mapa,
    origen_de,
    traducir,
    url_de_issue,
)


def entrada(**cambios):
    base = {
        "issue": 7,
        "carpeta": "001-la-ventanilla",
        "fecha": "2026-08-28",
        "estado": "Propuesto",
        "titulo": "Spec 001 — La ventanilla",
    }
    base.update(cambios)
    return base


class LeerMapa(unittest.TestCase):
    def test_un_mapa_vacio_es_valido(self):
        # Un repo recién arrancado tiene cero specs, y eso NO es un registro roto. Es la
        # desviación consciente respecto del harness original, donde un mapa vacío grita
        # porque allá siempre hubo specs y un `{}` sólo podía venir de un parseo que se rompió.
        self.assertEqual(leer_mapa("{}"), {})

    def test_rechaza_lo_que_no_es_json(self):
        with self.assertRaises(ValueError):
            leer_mapa("{ esto no es json")

    def test_rechaza_una_lista(self):
        with self.assertRaises(ValueError):
            leer_mapa("[]")

    def test_rechaza_una_entrada_sin_campo(self):
        sin_titulo = {"001": {k: v for k, v in entrada().items() if k != "titulo"}}
        with self.assertRaises(ValueError) as e:
            leer_mapa(json.dumps(sin_titulo))
        self.assertIn("titulo", str(e.exception))

    def test_rechaza_un_issue_que_no_es_numero(self):
        with self.assertRaises(ValueError):
            leer_mapa(json.dumps({"001": entrada(issue="7")}))

    def test_rechaza_un_issue_booleano(self):
        # `bool` es subclase de `int` en Python: sin la guarda explícita, `issue: true` pasa
        # la validación de tipo y después no encuentra ningún issue.
        with self.assertRaises(ValueError):
            leer_mapa(json.dumps({"001": entrada(issue=True)}))

    def test_acepta_un_origen_bien_formado(self):
        mapa = leer_mapa(json.dumps({"001": entrada(origen=[12, 15])}))
        self.assertEqual(mapa["001"]["origen"], [12, 15])

    def test_rechaza_un_origen_vacio(self):
        # «No tiene origen» ya se dice omitiendo el campo. Dos formas de decir lo mismo es la
        # puerta de que un día se lea una y no la otra.
        with self.assertRaises(ValueError):
            leer_mapa(json.dumps({"001": entrada(origen=[])}))

    def test_rechaza_un_origen_que_no_es_lista(self):
        with self.assertRaises(ValueError):
            leer_mapa(json.dumps({"001": entrada(origen=12)}))

    def test_rechaza_un_origen_con_un_string(self):
        with self.assertRaises(ValueError):
            leer_mapa(json.dumps({"001": entrada(origen=["12"])}))

    def test_rechaza_un_origen_con_cero(self):
        with self.assertRaises(ValueError):
            leer_mapa(json.dumps({"001": entrada(origen=[0])}))


class EscribirMapa(unittest.TestCase):
    def test_una_entrada_por_linea_ordenadas(self):
        texto = escribir_mapa({"010": entrada(issue=2), "002": entrada(issue=1)})
        lineas = texto.strip().splitlines()
        self.assertEqual(lineas[0], "{")
        self.assertTrue(lineas[1].startswith('  "002":'))
        self.assertTrue(lineas[2].startswith('  "010":'))
        self.assertEqual(lineas[-1], "}")

    def test_lo_que_escribe_se_puede_volver_a_leer(self):
        original = {"001": entrada(origen=[3])}
        self.assertEqual(leer_mapa(escribir_mapa(original)), original)

    def test_no_escapa_los_acentos(self):
        # Un título con acentos escapado a `í` deja el registro ilegible en el diff, que
        # es justo donde se lo mira.
        texto = escribir_mapa({"001": entrada(titulo="La ventanilla está cerrada")})
        self.assertIn("está", texto)


class Estados(unittest.TestCase):
    def test_propuesto_esta_en_vuelo(self):
        self.assertTrue(en_vuelo("Propuesto"))

    def test_los_tres_cerrados_no(self):
        for estado in ("Implementado", "Descartado", "Superado"):
            self.assertFalse(en_vuelo(estado), estado)

    def test_un_estado_desconocido_cuenta_como_en_vuelo(self):
        # Lo que no se entiende no cierra nada. Que además sea ilegal lo grita el gate.
        self.assertTrue(en_vuelo("En curso"))

    def test_estado_de_un_spec_que_no_esta_es_none(self):
        # `None` no es un estado terminal: un spec recién escrito todavía no está en el mapa,
        # y confundir las dos cosas cierra su issue apenas nace.
        self.assertIsNone(estado_de({}, "001"))


class ArchivoDeComentario(unittest.TestCase):
    def test_reconstruye_nombre_y_contenido(self):
        self.assertEqual(
            archivo_de_comentario("## `research.md`\n\nLo que se midió."),
            ("research.md", "Lo que se midió."),
        )

    def test_un_comentario_sin_encabezado_no_es_un_archivo(self):
        # Es la única forma de distinguir un archivo de una discusión del issue.
        self.assertIsNone(archivo_de_comentario("Ojo con esto, lo probamos y no anduvo."))

    def test_conserva_la_linea_en_blanco_del_archivo(self):
        # El separador consume UNA línea en blanco, no todas: un archivo que arranca vacío
        # tiene que volver del issue arrancando vacío.
        nombre, contenido = archivo_de_comentario("## `plan.md`\n\n\nArranca con una vacía.")
        self.assertEqual(contenido, "\nArranca con una vacía.")

    def test_tolera_crlf(self):
        # La API devuelve CRLF. Sin el `\r` explícito queda un retorno de carro colgado.
        nombre, contenido = archivo_de_comentario("## `tasks.md`\r\n\r\n- [ ] T001")
        self.assertEqual(nombre, "tasks.md")
        self.assertEqual(contenido, "- [ ] T001")

    def test_el_archivo_del_regimen_nuevo_vuelve_del_issue(self):
        # `estrategia.md` reemplaza a `plan.md` y `tasks.md` del 030 en adelante. Entra por el
        # mismo alfabeto que los demás y no hay ninguna lista de nombres que ampliar: si la
        # hubiera, este archivo se subiría al issue y no volvería nunca — y `specs/` es caché,
        # así que «no volver» es perderse.
        self.assertEqual(
            archivo_de_comentario("## `estrategia.md`\n\nEl orden obligado."),
            ("estrategia.md", "El orden obligado."),
        )

    def test_no_acepta_un_nombre_fuera_del_alfabeto(self):
        self.assertIsNone(archivo_de_comentario("## `Research.md`\n\ntexto"))


class Traducir(unittest.TestCase):
    def setUp(self):
        self.mapa = {"005": entrada(issue=42, carpeta="005-el-inventario")}

    def test_traduce_la_forma_relativa(self):
        self.assertEqual(
            traducir("ver ./005-el-inventario/spec.md", self.mapa, "u/r"),
            f"ver {url_de_issue('u/r', 42)}",
        )

    def test_traduce_la_forma_desde_afuera(self):
        self.assertEqual(
            traducir("ver specs/005-el-inventario/plan.md", self.mapa, "u/r"),
            f"ver {url_de_issue('u/r', 42)}",
        )

    def test_deja_como_esta_lo_que_no_esta_en_el_mapa(self):
        texto = "ver ./009-otro/spec.md"
        self.assertEqual(traducir(texto, self.mapa, "u/r"), texto)

    def test_acepta_cualquier_md_publicable(self):
        # Si acá entraran menos nombres que los que se publican, un enlace a un `baseline.md`
        # se subiría verbatim: una ruta relativa a un directorio ignorado, o sea un enlace
        # muerto.
        self.assertIn("issues/42", traducir("./005-el-inventario/baseline.md", self.mapa, "u/r"))


class CarpetaExistente(unittest.TestCase):
    def test_empareja_por_numero_y_no_por_nombre(self):
        # Una caché vieja con otro nombre tiene que reconocerse como el mismo spec: tratarla
        # como ausente crearía una SEGUNDA carpeta para el mismo `NNN`.
        self.assertEqual(carpeta_existente(["005-nombre-viejo"], "005"), "005-nombre-viejo")

    def test_devuelve_none_si_no_esta(self):
        self.assertIsNone(carpeta_existente(["004-otra"], "005"))


class OrigenDe(unittest.TestCase):
    def test_lee_los_numeros_del_encabezado(self):
        spec = "# Spec 007\n\n**Origen:** #12, #15\n\n## Problema\n"
        self.assertEqual(origen_de(spec), [12, 15])

    def test_sin_la_linea_devuelve_none(self):
        self.assertIsNone(origen_de("# Spec 007\n\n## Problema\n"))

    def test_no_mira_mas_alla_del_encabezado(self):
        # Un `#127` suelto en la prosa no es un origen: si lo fuera, un spec que cita un issue
        # como contexto quedaría declarando que lo salda.
        spec = "# Spec 007\n\n## Problema\n\n**Origen:** #12\n"
        self.assertIsNone(origen_de(spec))

    def test_grita_si_la_linea_no_nombra_ningun_issue(self):
        # Devolver `[]` lo convertiría en un spec sin vínculo, en silencio.
        with self.assertRaises(ValueError):
            origen_de("# Spec 007\n\n**Origen:** el issue del inventario\n\n## Problema\n")


class DerivarElMapa(unittest.TestCase):
    def test_un_pr_mergeado_lo_pone_en_implementado(self):
        mapa = {"001": entrada()}
        prs = [{"number": 3, "headRefName": "feature/001-la-ventanilla", "state": "MERGED"}]
        derivado, correcciones = derivar_mapa(mapa, {}, agrupar_prs_por_spec(prs))
        self.assertEqual(derivado["001"]["estado"], "Implementado")
        self.assertEqual(correcciones, [("001", "estado", "Propuesto", "Implementado")])

    def test_un_pr_cerrado_sin_mergear_no_lo_mueve(self):
        # El error queda del lado barato: un PR abandonado deja el spec en `Propuesto`, que es
        # lo que era. Contarlo sería escribir `Implementado` sobre trabajo que no aterrizó, y
        # eso pone en rojo todos los PR siguientes.
        mapa = {"001": entrada()}
        prs = [{"number": 3, "headRefName": "feature/001-la-ventanilla", "state": "CLOSED"}]
        derivado, correcciones = derivar_mapa(mapa, {}, agrupar_prs_por_spec(prs))
        self.assertEqual(derivado["001"]["estado"], "Propuesto")
        self.assertEqual(correcciones, [])

    def test_un_implementado_sin_pr_vuelve_a_propuesto(self):
        # La mentira al revés, que es la que hace que el gate no se pueda satisfacer adentro
        # del PR que lo justifica.
        mapa = {"001": entrada(estado="Implementado")}
        derivado, _ = derivar_mapa(mapa, {}, {})
        self.assertEqual(derivado["001"]["estado"], "Propuesto")

    def test_no_toca_los_estados_que_no_mueve_un_merge(self):
        for estado in ("Descartado", "Superado"):
            mapa = {"001": entrada(estado=estado)}
            prs = [{"number": 3, "headRefName": "feature/001-x", "state": "MERGED"}]
            derivado, _ = derivar_mapa(mapa, {}, agrupar_prs_por_spec(prs))
            self.assertEqual(derivado["001"]["estado"], estado)

    def test_copia_el_titulo_del_issue(self):
        mapa = {"001": entrada(titulo="viejo")}
        issues = {7: {"number": 7, "state": "OPEN", "title": "nuevo"}}
        derivado, correcciones = derivar_mapa(mapa, issues, {})
        self.assertEqual(derivado["001"]["titulo"], "nuevo")
        self.assertIn(("001", "titulo", "viejo", "nuevo"), correcciones)

    def test_un_issue_que_no_esta_deja_el_titulo_como_estaba(self):
        # «No lo pude leer» no es «se llama vacío».
        mapa = {"001": entrada(titulo="el que había")}
        derivado, correcciones = derivar_mapa(mapa, {}, {})
        self.assertEqual(derivado["001"]["titulo"], "el que había")
        self.assertEqual(correcciones, [])

    def test_conserva_el_origen(self):
        # Lo que la derivación no nombra, no lo pierde.
        mapa = {"001": entrada(origen=[3])}
        derivado, _ = derivar_mapa(mapa, {}, {})
        self.assertEqual(derivado["001"]["origen"], [3])

    def test_no_inventa_entradas_para_ramas_que_no_estan_en_el_mapa(self):
        prs = [{"number": 3, "headRefName": "feature/099-inventada", "state": "MERGED"}]
        derivado, _ = derivar_mapa({}, {}, agrupar_prs_por_spec(prs))
        self.assertEqual(derivado, {})

    def test_el_orden_de_los_campos_no_cambia(self):
        # Un diff de una línea, no una línea reordenada: es lo que hace revisable el commit
        # que la Action hace sola.
        mapa = {"001": entrada()}
        derivado, _ = derivar_mapa(mapa, {}, {})
        self.assertEqual(list(derivado["001"]), list(mapa["001"]))


class AgruparYAterrizar(unittest.TestCase):
    def test_agrupa_por_el_nnn_de_la_rama(self):
        prs = [
            {"number": 1, "headRefName": "feature/001-a", "state": "MERGED"},
            {"number": 2, "headRefName": "fix/001-b", "state": "MERGED"},
            {"number": 3, "headRefName": "sin-spec", "state": "MERGED"},
        ]
        agrupados = agrupar_prs_por_spec(prs)
        self.assertEqual(len(agrupados["001"]), 2)
        self.assertNotIn("", agrupados)

    def test_acepta_prefijos_que_no_son_feature(self):
        # Un spec puede aterrizar por una rama `fix/`, y un patrón que sólo aceptara
        # `feature/` lo perdería sin decirlo.
        self.assertTrue(aterrizo(agrupar_prs_por_spec(
            [{"number": 1, "headRefName": "chore/012-x", "state": "MERGED"}]
        )["012"]))

    def test_sin_prs_no_aterrizo(self):
        self.assertFalse(aterrizo(None))
        self.assertFalse(aterrizo([]))


class CensoDeDeuda(unittest.TestCase):
    def test_saca_los_issues_que_son_de_un_spec(self):
        issues = [{"number": 7}, {"number": 9}]
        self.assertEqual(deuda_del_censo(issues, {"001": entrada(issue=7)}), [{"number": 9}])

    def test_un_issue_declarado_como_origen_ya_tiene_duenio(self):
        # Sin esta mitad, el censo seguiría mostrando lo que un spec acaba de reclamar.
        issues = [{"number": 9}]
        self.assertEqual(deuda_del_censo(issues, {"001": entrada(issue=7, origen=[9])}), [])


if __name__ == "__main__":
    unittest.main()
