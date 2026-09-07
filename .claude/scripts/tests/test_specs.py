"""Los tests de `lib/specs.py`, que es lo puro del registro de specs."""

import json
import unittest

from lib.specs import (
    aterrizo,
    cercado_sin_cerrar,
    encabezados_con_linea,
    encabezados_del_plan,
    palabras,
    partir_spec,
    seleccionar_carpetas,
    rutas_intocables,
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

    def test_un_archivo_que_no_es_canonico_vuelve_del_issue(self):
        # El alfabeto no es una lista de nombres conocidos, y ésa es la propiedad: un spec
        # puede agregar un `baseline.md` con una medición previa. Si hubiera una lista, ese
        # archivo se subiría al issue y no volvería nunca — y `specs/` es caché, así que «no
        # volver» es perderse.
        self.assertEqual(
            archivo_de_comentario("## `baseline.md`\n\nLo que medía antes."),
            ("baseline.md", "Lo que medía antes."),
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

    def test_una_cita_con_linea_no_se_traduce(self):
        # Sin esto la traducción **destruye la medición**: matcheaba hasta el `.md` y dejaba el
        # rango pegado a la URL —`…/issues/42:59-60`—, que no lleva a ninguna parte. Y como
        # `hidratar_specs.py` escribe al disco lo que el issue tiene, la URL rota volvía y
        # pisaba la ruta original. Medido el 2026-09-06: ocho citas perdidas así, en el 007 y
        # el 013. Un issue no tiene número de línea, así que la cita se deja verbatim.
        for cita in ("specs/005-el-inventario/research.md:59-60", "./005-el-inventario/spec.md:7"):
            with self.subTest(cita=cita):
                self.assertEqual(traducir(f"ver {cita}", self.mapa, "u/r"), f"ver {cita}")


class CarpetaExistente(unittest.TestCase):
    def test_empareja_por_numero_y_no_por_nombre(self):
        # Una caché vieja con otro nombre tiene que reconocerse como el mismo spec: tratarla
        # como ausente crearía una SEGUNDA carpeta para el mismo `NNN`.
        self.assertEqual(carpeta_existente(["005-nombre-viejo"], "005"), "005-nombre-viejo")

    def test_devuelve_none_si_no_esta(self):
        self.assertIsNone(carpeta_existente(["004-otra"], "005"))


class SeleccionarCarpetas(unittest.TestCase):
    """La selección de `publicar_spec.py`, ejercida sin red ni disco.  # 030-AC6

    Las carpetas entran como una lista de strings y salen como otra: no hay `Path`, no hay
    `gh` y no hay `iterdir`. Es lo que hace que los cuatro casos de abajo se puedan escribir.
    """

    CARPETAS = ["028-uno", "029-dos", "030-tres"]

    def test_sin_ids_devuelve_todas(self):  # 030-AC2
        # El default no cambia: sin `NNN` la lista sale entera y en el mismo orden, que es lo
        # que necesitan el alta y cualquier reconciliación.
        self.assertEqual(seleccionar_carpetas(self.CARPETAS, []), self.CARPETAS)

    def test_un_id_deja_solo_su_carpeta(self):  # 030-AC1
        self.assertEqual(seleccionar_carpetas(self.CARPETAS, ["029"]), ["029-dos"])

    def test_varios_ids_dejan_esas_y_ninguna_mas(self):  # 030-AC3
        self.assertEqual(
            seleccionar_carpetas(self.CARPETAS, ["030", "028"]), ["028-uno", "030-tres"]
        )

    def test_un_id_sin_carpeta_grita_y_lo_nombra(self):  # 030-AC4
        # Y grita aunque venga acompañado de uno válido: media corrida deja el mapa y los
        # issues discrepando.
        with self.assertRaises(ValueError) as caso:
            seleccionar_carpetas(self.CARPETAS, ["029", "031"])
        self.assertIn("031", str(caso.exception))
        self.assertNotIn("029", str(caso.exception))

    def test_empareja_por_numero_y_no_por_nombre(self):  # 030-AC1
        # Una caché hidratada antes de un cambio de título tiene otro nombre y el mismo `NNN`:
        # emparejar por nombre completo la trataría como ausente y cortaría una corrida buena.
        self.assertEqual(seleccionar_carpetas(["005-nombre-viejo"], ["005"]), ["005-nombre-viejo"])


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


class ElAndamioDeLaPlantillaNoEsContenido(unittest.TestCase):
    """Un `<!-- -->` es instrucción para quien escribe el spec, no texto del spec.

    Las tres reglas son la misma: lo que el autor va a borrar no puede gastar techo ni
    declarar prohibiciones. Sin esto `specs/plantilla/` es inusable — medido el 2026-09-06:
    su `plan.md` daba 386 palabras contra un techo de 250 sin haber escrito nada propio, y su
    `### Rutas` declaraba intocables `src/`, `reglas.gd` y `tasks.md` desde la prosa que
    explica el rubro.
    """

    def test_un_comentario_no_gasta_techo(self):
        self.assertEqual(palabras("uno dos <!-- tres cuatro cinco --> seis"), 3)

    def test_un_comentario_de_varias_lineas_tampoco(self):
        self.assertEqual(palabras("uno\n<!-- dos\n     tres -->\ncuatro"), 2)

    def test_una_ruta_citada_adentro_de_un_comentario_no_se_prohibe(self):
        # El párrafo que explica el rubro cita rutas para ilustrarlo, y el de la plantilla
        # cita hasta la que dice que NO va. Contarlas deja al spec prohibiendo `src/` antes
        # de escribir una línea propia.
        plan = "## Qué NO se toca\n\n### Rutas\n\n<!-- por ejemplo `src/` -->\n- `reglas.gd`\n"
        self.assertEqual(rutas_intocables(plan), ["reglas.gd"])

    def test_un_encabezado_comentado_no_es_una_seccion_del_plan(self):
        plan = "# Plan\n\n<!-- ## Orden obligado va acá -->\n\n## Criterio de terminado\n"
        self.assertEqual(encabezados_del_plan(plan), ["## Criterio de terminado"])


class ElRubroDeRutasSeReconocePorLaLineaEntera(unittest.TestCase):
    def test_un_encabezado_mas_hondo_no_es_el_rubro(self):
        # Se buscaba por substring, y `#### Rutas` contiene `### Rutas`: un rubro de otro
        # nivel se leía como éste y sus citas pasaban a ser prohibiciones.
        self.assertEqual(rutas_intocables("#### Rutas\n\n- `src/`\n"), [])

    def test_el_rubro_de_verdad_si(self):
        self.assertEqual(rutas_intocables("### Rutas\n\n- `src/`\n"), ["src/"])

    def test_el_rubro_como_ultima_linea_no_rompe(self):
        # Sin `\n` detrás —fin de archivo— la búsqueda por substring no lo encontraba y el
        # gate se salteaba callado.
        self.assertEqual(rutas_intocables("## Qué NO se toca\n\n### Rutas"), [])


class UnCercadoSinCerrarSeVe(unittest.TestCase):
    """El modo de falla más silencioso de este parser, y por eso tiene su propio rojo.

    Un bloque cercado que nunca cierra deja a `sin_cercados()` borrando **todo lo que sigue**,
    así que un `### Rutas` escrito después de un ``` huérfano devuelve cero rutas y el gate se
    saltea con cara de haber mirado. Medido el 2026-09-06: `sin_cercados("a\\n```\\nb\\nc\\n")`
    devuelve `"a"`.
    """

    def test_un_bloque_que_cierra_no_es_hallazgo(self):
        self.assertFalse(cercado_sin_cerrar("texto\n```py\nx = 1\n```\nmás texto\n"))

    def test_un_bloque_que_no_cierra_si(self):
        self.assertTrue(cercado_sin_cerrar("texto\n```py\nx = 1\n"))

    def test_las_dos_cercas_cuentan(self):
        self.assertTrue(cercado_sin_cerrar("~~~\nx\n"))
        self.assertFalse(cercado_sin_cerrar("~~~\nx\n~~~\n"))

    def test_un_texto_sin_cercas_no_es_hallazgo(self):
        self.assertFalse(cercado_sin_cerrar("# T\n\nprosa y `código` en línea\n"))


class LosEncabezadosCercadosSonEjemplos(unittest.TestCase):
    def test_un_encabezado_cercado_no_es_una_seccion(self):
        # Un `research.md` que muestra un `## Pendientes` para explicar que está prohibido
        # quedaba acusado de tenerlo. El barrido del plan ya salteaba los cercados; el de las
        # secciones que aplazan, no.
        texto = "# R\n\nasí se ve una prohibida:\n\n```markdown\n## Pendientes\n```\n"
        self.assertEqual(encabezados_con_linea(texto), [(1, "R")])

    def test_la_linea_es_la_del_archivo(self):
        # El rojo la nombra: `spec.md:41` se abre, «hay una sección que aplaza» hay que ir a
        # buscarla.
        self.assertEqual(encabezados_con_linea("a\n\n## Dos\n"), [(3, "Dos")])


class UnEncabezadoCercadoNoParteElSpec(unittest.TestCase):
    def test_el_bloque_de_criterios_sale_del_encabezado_real(self):
        # Un `spec.md` que muestra el formato de un spec adentro de un bloque cercado se
        # partía por el encabezado del EJEMPLO: la prosa se quedaba con los criterios reales
        # y el bloque salía vacío, así que su techo dejaba de morder y `acs_de()` devolvía
        # cero criterios sobre un spec que los tiene. Es el mismo agujero que
        # `sin_cercados()` ya cierra para el `plan.md`.
        texto = (
            "# T\n\nprosa\n\n```markdown\n## Criterios de aceptación\n```\n\n"
            "## Criterios de aceptación\n\n- **AC1** — x\n"
        )
        prosa, criterios = partir_spec(texto)
        self.assertIn("```", prosa)
        self.assertNotIn("```", criterios)
        self.assertIn("AC1", criterios)


if __name__ == "__main__":
    unittest.main()
