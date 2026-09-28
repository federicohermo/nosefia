## El sobre del guardado, saneado sin tocar disco.
extends GdUnitTestSuite

const JORNADA := "jornada"
const APERCIBIMIENTOS := "apercibimientos"
const VERSION := "version"


func _completo() -> Dictionary:
	return {
		VERSION: PartidaSerializada.VERSION,
		JORNADA: ReglasDeLaPartida.PRIMERA_JORNADA + 2,
		APERCIBIMIENTOS: Reglas.APERCIBIMIENTOS_POR_AVISO,
	}


func test_cada_campo_tiene_su_clave() -> void:
	assert_str(PartidaSerializada.clave(PartidaSerializada.Campo.JORNADA)).is_equal(JORNADA)
	assert_str(PartidaSerializada.clave(PartidaSerializada.Campo.APERCIBIMIENTOS)).is_equal(
		APERCIBIMIENTOS
	)


func test_un_guardado_completo_vuelve_igual() -> void:  # AC-SAV-006
	var saneado := PartidaSerializada.sanear(_completo())
	assert_dict(saneado).is_equal(_completo())
	for clave: String in saneado:
		assert_int(typeof(saneado[clave])).is_equal(typeof(_completo()[clave]))


func test_el_campo_que_falta_vuelve_con_su_defecto() -> void:  # AC-SAV-007
	var saneado := PartidaSerializada.sanear({})
	assert_dict(saneado).contains_keys([VERSION, JORNADA, APERCIBIMIENTOS])
	assert_int(saneado[JORNADA]).is_equal(ReglasDeLaPartida.PRIMERA_JORNADA)
	assert_int(saneado[APERCIBIMIENTOS]).is_equal(Legajo.new().apercibimientos())
	var sin_jornada := _completo()
	sin_jornada.erase(JORNADA)
	saneado = PartidaSerializada.sanear(sin_jornada)
	assert_int(saneado[JORNADA]).is_equal(ReglasDeLaPartida.PRIMERA_JORNADA)
	assert_int(saneado[APERCIBIMIENTOS]).is_equal(Reglas.APERCIBIMIENTOS_POR_AVISO)


func test_el_tipo_equivocado_vuelve_con_su_defecto() -> void:  # AC-SAV-008
	var mal_tipado := _completo()
	mal_tipado[JORNADA] = "3"
	mal_tipado[APERCIBIMIENTOS] = 2.5
	var saneado := PartidaSerializada.sanear(mal_tipado)
	assert_int(saneado[JORNADA]).is_equal(ReglasDeLaPartida.PRIMERA_JORNADA)
	assert_int(typeof(saneado[JORNADA])).is_equal(TYPE_INT)
	assert_int(saneado[APERCIBIMIENTOS]).is_equal(Legajo.new().apercibimientos())
	assert_int(typeof(saneado[APERCIBIMIENTOS])).is_equal(TYPE_INT)


func test_la_actual_una_anterior_y_sin_version_son_legibles() -> void:  # AC-SAV-009
	var anterior := _completo()
	anterior[VERSION] = PartidaSerializada.VERSION - 1
	var sin_version := _completo()
	sin_version.erase(VERSION)
	var posterior := _completo()
	posterior[VERSION] = PartidaSerializada.VERSION + 1
	assert_bool(PartidaSerializada.legible(_completo())).is_true()
	assert_bool(PartidaSerializada.legible(anterior)).is_true()
	assert_bool(PartidaSerializada.legible(sin_version)).is_true()
	assert_bool(PartidaSerializada.legible(posterior)).is_false()
