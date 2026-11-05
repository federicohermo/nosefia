extends GdUnitTestSuite

const JORNADA_5 := GeneradorDeTickets.JORNADA_SIN_LECTOR
const JORNADA_6 := JORNADA_5 + 1
const JORNADA_7 := JORNADA_6 + 1
const CUARTA := JORNADA_5 - 1
const E := ReflexionDeCierre.Etapa

const TEXTO_DE_LA_HIPOTESIS := (
	"ADVERTENCIA: Este camino aún no está listo. Si lo elegís, no te van a aparecer más pistas y tu "
	+ "investigación va a quedar incompleta. Recomendamos elegir las otras pistas o reiniciar la "
	+ "jornada si no las encontraste."
)


func _caso() -> CasoDeInvestigacion:
	return CasoDeInvestigacion.de_la_partida()


func _identidades(opciones: Array[Hipotesis]) -> Array[String]:
	var identidades: Array[String] = []
	for opcion: Hipotesis in opciones:
		identidades.append(opcion.identidad)
	return identidades


## La partida que llegó a la sexta por la 5A: la 4 y la 5 elegidas, con sus pistas.
func _por_el_camino_de_la_5a() -> Expediente:
	var expediente := Expediente.new(_caso())
	expediente.registrar("2A")
	expediente.elegir(CUARTA, "2A")
	expediente.registrar("5A")
	expediente.elegir(JORNADA_5, "5A")
	return expediente


func _empezada(expediente: Expediente) -> ReflexionDeCierre:
	var reflexion := ReflexionDeCierre.para(JORNADA_6, expediente)
	reflexion.empezar()
	return reflexion


func test_6a_es_una_pista_de_chat_de_la_jornada_6_con_la_foto_de_hernan() -> void:  # AC-INV-199
	var caso := _caso()
	var pista := caso.pista_de("6A")
	assert_object(pista).is_not_null()
	if pista == null:
		return
	assert_int(pista.jornada).is_equal(JORNADA_6)
	assert_int(pista.canal).is_equal(Pista.Canal.CHAT)
	assert_str(pista.texto).is_not_empty()
	assert_object(pista.foto).is_not_null()
	assert_object(pista.foto).is_same(Conversacion.de(Conversacion.Interlocutor.PROVEEDOR).imagen)
	for otra: String in ["2A", "2B", "5A", "5B", "6B", "6C"]:
		assert_bool(pista.foto != caso.pista_de(otra).foto).is_true()
		assert_bool(pista.origen != caso.pista_de(otra).origen).is_true()


func test_la_hipotesis_6a_avisa_que_no_sigue_y_la_5a_abre_su_camino() -> void:  # AC-INV-199
	var caso := _caso()
	var opciones := caso.hipotesis_para(JORNADA_6, PackedStringArray(["6A"]))
	assert_array(_identidades(opciones)).is_equal(["6A"])
	if not opciones.is_empty():
		assert_str(opciones[0].titulo).is_equal("EL PROVEEDOR")
		assert_str(opciones[0].texto).is_equal(TEXTO_DE_LA_HIPOTESIS)
		assert_array(Array(opciones[0].exigencias)).is_equal(["6A"])
		assert_array(Array(opciones[0].camino)).is_empty()
	assert_array(Array(caso.opcion(JORNADA_5, "5A").camino)).is_equal(["6A", "6B"])
	assert_array(Array(caso.opcion(JORNADA_5, "5B").camino)).is_equal(["6C", "6D"])
	assert_array(Array(caso.opcion(JORNADA_6, "6B").camino)).is_equal(["7B"])
	assert_array(Array(caso.opcion(JORNADA_6, "6C").camino)).is_equal(["7C"])


func test_6a_esta_activa_solo_por_el_camino_de_la_5a() -> void:  # AC-INV-200
	var caso := _caso()
	var con_6a: Array[Array] = [
		[{CUARTA: "2A", JORNADA_5: "5A"}, {}], [{CUARTA: "2A"}, {JORNADA_6: "5A"}]
	]
	for escenario: Array in con_6a:
		(
			assert_array(Array(caso.pistas_activas(JORNADA_6, escenario[0], escenario[1])))
			. override_failure_message("elecciones %s, sorteos %s" % escenario)
			. contains(["6A"])
		)
	var sin_6a: Array[Array] = [
		[{CUARTA: "2A", JORNADA_5: "5B"}, {}],
		[{CUARTA: "2B"}, {}],
		[{CUARTA: "2A", JORNADA_5: "5P"}, {}],
		[{CUARTA: "2A"}, {}],
		[{}, {}],
		[{CUARTA: "2A"}, {JORNADA_6: "5B"}],
	]
	for escenario: Array in sin_6a:
		(
			assert_array(Array(caso.pistas_activas(JORNADA_6, escenario[0], escenario[1])))
			. override_failure_message("elecciones %s, sorteos %s" % escenario)
			. not_contains(["6A"])
		)


func test_pedir_6a_por_el_chat_la_registra_una_vez_con_su_foto_y_su_texto() -> void:  # AC-INV-201
	var expediente := _por_el_camino_de_la_5a()
	var antes := expediente.mensajes_de_notas().size()
	var nuevas: Array[Pista] = []
	expediente.pista_nueva.connect(func(pista: Pista) -> void: nuevas.append(pista))
	var origen := _caso().pista_de("6A").origen
	var ajenos: Array[Array] = [
		[origen, Pista.Canal.CHAT, JORNADA_5],
		[origen, Pista.Canal.LEVANTAR, JORNADA_6],
		[origen, Pista.Canal.COMPRADOR, JORNADA_6],
	]
	for ajeno: Array in ajenos:
		assert_int(expediente.registrar_por_canal(ajeno[0], ajeno[1], ajeno[2])).is_equal(
			Expediente.Resultado.DESCONOCIDA
		)
	assert_array(Array(expediente.identidades())).not_contains(["6A"])
	assert_int(expediente.registrar_por_canal(origen, Pista.Canal.CHAT, JORNADA_6)).is_equal(
		Expediente.Resultado.ANOTADA
	)
	assert_int(expediente.registrar_por_canal(origen, Pista.Canal.CHAT, JORNADA_6)).is_equal(
		Expediente.Resultado.REPETIDA
	)
	assert_int(nuevas.size()).is_equal(1)
	var notas := expediente.mensajes_de_notas()
	assert_int(notas.size()).is_equal(antes + 2)
	if notas.size() == antes + 2:
		assert_object(notas[antes].foto).is_not_null()
		assert_str(notas[antes].texto).is_empty()
		assert_str(notas[antes + 1].texto).is_equal(_caso().pista_de("6A").texto)
		assert_int(notas[antes + 1].jornada).is_equal(JORNADA_6)


func test_6a_no_se_anota_por_el_camino_de_la_5b() -> void:  # AC-INV-201
	var expediente := Expediente.new(_caso())
	expediente.registrar("2A")
	expediente.elegir(CUARTA, "2A")
	expediente.registrar("5B")
	expediente.elegir(JORNADA_5, "5B")
	var antes := expediente.mensajes_de_notas().size()
	var origen := _caso().pista_de("6A").origen
	assert_int(expediente.registrar_por_canal(origen, Pista.Canal.CHAT, JORNADA_6)).is_equal(
		Expediente.Resultado.DESCONOCIDA
	)
	assert_array(Array(expediente.identidades())).not_contains(["6A"])
	assert_int(expediente.mensajes_de_notas().size()).is_equal(antes)


func test_con_la_6a_la_sexta_ofrece_su_hipotesis() -> void:  # AC-INV-202
	var expediente := _por_el_camino_de_la_5a()
	assert_int(expediente.registrar("6A")).is_equal(Expediente.Resultado.ANOTADA)
	var reflexion := _empezada(expediente)
	assert_str(reflexion.encabezado()).is_equal(ReflexionDeCierre.ENCABEZADOS[JORNADA_6])
	assert_array(_identidades(reflexion.opciones())).is_equal(["6A"])
	for ajena: String in ["6P", "6L", "6C"]:
		assert_int(reflexion.elegir(ajena)).is_equal(ReflexionDeCierre.Eleccion.NO_DISPONIBLE)
	assert_str(expediente.eleccion(JORNADA_6)).is_empty()


func test_con_la_6a_y_la_6b_la_sexta_ofrece_las_dos_en_ese_orden() -> void:  # AC-INV-202
	var expediente := _por_el_camino_de_la_5a()
	expediente.registrar("6B")
	expediente.registrar("6A")
	assert_array(_identidades(_empezada(expediente).opciones())).is_equal(["6A", "6B"])


func test_sin_la_6a_no_se_puede_elegir() -> void:  # AC-INV-202
	var reflexion := _empezada(_por_el_camino_de_la_5a())
	assert_int(reflexion.elegir("6A")).is_equal(ReflexionDeCierre.Eleccion.NO_DISPONIBLE)


func test_elegir_la_6a_anota_una_vez_y_deja_la_septima_sin_pistas() -> void:  # AC-INV-202
	var expediente := _por_el_camino_de_la_5a()
	expediente.registrar("6A")
	var reflexion := _empezada(expediente)
	var notas := expediente.mensajes_de_notas().size()
	assert_int(reflexion.elegir("6A")).is_equal(ReflexionDeCierre.Eleccion.ACEPTADA)
	assert_str(expediente.eleccion(JORNADA_6)).is_equal("6A")
	assert_int(expediente.mensajes_de_notas().size()).is_equal(notas + 1)
	assert_int(reflexion.elegir("6A")).is_equal(ReflexionDeCierre.Eleccion.REPETIDA)
	assert_int(expediente.mensajes_de_notas().size()).is_equal(notas + 1)
	assert_bool(reflexion.avanzar(ReflexionDeCierre.ESPERA_ANTES_DE_LA_NOCHE)).is_true()
	assert_int(reflexion.etapa()).is_equal(E.TERMINADA)
	assert_array(Array(expediente.pistas_activas(JORNADA_7))).is_empty()
