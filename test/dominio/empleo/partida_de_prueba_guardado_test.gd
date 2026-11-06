## El guardado que arma la partida de prueba: qué restaura `Partida.desde()` de cada camino.
extends GdUnitTestSuite

const DOCUMENTO := "res://docs/infra/despliegue.md"
const FUENTE := "res://src/dominio/empleo/partida_de_prueba.gd"

var _caso: CasoDeInvestigacion


func before_test() -> void:
	_caso = CasoDeInvestigacion.de_la_partida()


func _partida_del(busqueda: String) -> Partida:
	var prueba := PartidaDePrueba.desde_busqueda(busqueda)
	assert_object(prueba).is_not_null()
	return Partida.desde(prueba.guardado(_caso))


func _todas_las_hipotesis() -> Array[Hipotesis]:
	var todas: Array[Hipotesis] = []
	for jornada: HipotesisDeLaJornada in _caso.hipotesis:
		todas.append_array(jornada.opciones)
		for aparte: Hipotesis in [jornada.predeterminada, jornada.con_antecedentes]:
			if aparte != null and not todas.has(aparte):
				todas.append(aparte)
	return todas


# --- El guardado ---


func test_el_guardado_deja_la_partida_en_la_jornada_pedida() -> void:
	var prueba := PartidaDePrueba.desde_busqueda("?jornada=6")
	var datos := prueba.guardado(_caso)
	assert_bool(PartidaSerializada.legible(datos)).is_true()
	assert_int(Partida.desde(datos).jornada()).is_equal(6)


func test_sin_camino_la_partida_abre_sin_elecciones() -> void:
	var partida := _partida_del("?jornada=6")
	assert_dict(partida.expediente.elecciones()).is_empty()
	assert_array(partida.expediente.identidades()).is_empty()


func test_el_camino_restaura_la_eleccion_de_cada_jornada_anterior() -> void:
	var partida := _partida_del("?jornada=6&camino=6C")
	assert_str(partida.expediente.eleccion(4)).is_equal("2A")
	assert_str(partida.expediente.eleccion(5)).is_equal("5B")
	assert_str(partida.expediente.eleccion(6)).is_empty()


func test_las_pistas_activas_de_la_jornada_son_las_del_camino_elegido() -> void:
	var partida := _partida_del("?jornada=6&camino=6C")
	var abiertas := _caso.opcion(5, "5B").camino
	var esperadas := PackedStringArray()
	for pista: Pista in _caso.pistas:
		if pista.jornada == 6 and abiertas.has(pista.identidad):
			esperadas.append(pista.identidad)
	assert_array(esperadas).is_not_empty()
	assert_array(partida.expediente.pistas_activas(6)).contains_exactly_in_any_order(esperadas)


func test_el_expediente_trae_cada_pista_que_exigen_las_hipotesis_elegidas() -> void:
	var partida := _partida_del("?jornada=6&camino=6C")
	var exigidas := PackedStringArray()
	for hipotesis: Hipotesis in PartidaDePrueba.cadena(_caso, "6C"):
		if hipotesis.jornada < 6:
			exigidas.append_array(hipotesis.exigencias)
	assert_array(exigidas).is_not_empty()
	assert_array(partida.expediente.identidades()).contains_exactly_in_any_order(exigidas)


func test_un_camino_que_llega_a_una_jornada_posterior_elige_tambien_la_ultima() -> void:
	var partida := _partida_del("?jornada=7&camino=6C")
	assert_str(partida.expediente.eleccion(4)).is_equal("2A")
	assert_str(partida.expediente.eleccion(5)).is_equal("5B")
	assert_str(partida.expediente.eleccion(6)).is_equal("6C")
	assert_bool(partida.expediente.identidades().has("6C")).is_true()


func test_se_cortan_las_hipotesis_de_la_jornada_pedida_y_de_las_siguientes() -> void:
	var partida := _partida_del("?jornada=4&camino=6C")
	assert_dict(partida.expediente.elecciones()).is_empty()
	assert_array(partida.expediente.identidades()).is_empty()


func test_un_camino_que_no_es_del_caso_abre_sin_elecciones() -> void:
	var partida := _partida_del("?jornada=6&camino=9Z")
	assert_int(partida.jornada()).is_equal(6)
	assert_dict(partida.expediente.elecciones()).is_empty()


func test_la_hipotesis_sin_pistas_no_deja_elecciones_en_las_jornadas_previas() -> void:
	var partida := _partida_del("?jornada=6&camino=6P")
	assert_dict(partida.expediente.elecciones()).is_empty()


# --- Lo que el repo y el documento dicen del camino ---


func test_la_tabla_de_caminos_del_documento_lista_cada_hipotesis_con_su_cadena() -> void:
	var texto := FileAccess.get_file_as_string(DOCUMENTO)
	var plano := " ".join(texto.split("\n"))
	assert_str(texto).is_not_empty()
	for hipotesis: Hipotesis in _todas_las_hipotesis():
		var cadena := PackedStringArray()
		for eslabon: Hipotesis in PartidaDePrueba.cadena(_caso, hipotesis.identidad):
			cadena.append("`%s`" % eslabon.identidad)
		var fila := "| `%s` | %s |" % [hipotesis.identidad, " → ".join(cadena)]
		assert_bool(plano.contains(fila)).override_failure_message(fila).is_true()


func test_la_lectura_de_la_url_no_usa_regex() -> void:
	assert_bool(FileAccess.get_file_as_string(FUENTE).contains("RegEx")).is_false()
