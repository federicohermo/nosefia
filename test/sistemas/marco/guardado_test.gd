## El guardado contra un archivo de verdad, en una carpeta temporal.
extends GdUnitTestSuite

const VERSION := "version"
const JORNADA := "jornada"
const APERCIBIMIENTOS := "apercibimientos"


func _guardado() -> Guardado:
	var guardado := Guardado.new()
	guardado.ruta = create_temp_dir("guardado").path_join("partida.guardado")
	guardado.borrar()
	return guardado


func _partida_en_la_tercera() -> Dictionary:
	return {
		VERSION: PartidaSerializada.VERSION,
		JORNADA: ReglasDeLaPartida.PRIMERA_JORNADA + 2,
		APERCIBIMIENTOS: Reglas.APERCIBIMIENTOS_POR_AVISO,
	}


func _escribir_crudo(ruta: String, texto: String) -> void:
	FileAccess.open(ruta, FileAccess.WRITE).store_string(texto)


func test_ida_y_vuelta_por_disco_con_los_tipos_intactos() -> void:  # AC-SAV-006
	var guardado := _guardado()
	assert_bool(guardado.escribir(_partida_en_la_tercera())).is_true()
	var cargado := guardado.cargar()
	assert_dict(cargado).is_equal(_partida_en_la_tercera())
	for clave: String in cargado:
		assert_int(typeof(cargado[clave])).is_equal(TYPE_INT)


func test_lo_que_falta_o_esta_mal_tipado_en_disco_vuelve_con_su_defecto() -> void:
	# AC-SAV-007 y AC-SAV-008, pasando por disco.
	var guardado := _guardado()
	guardado.escribir({APERCIBIMIENTOS: "dos"})
	var cargado := guardado.cargar()
	assert_int(cargado[JORNADA]).is_equal(ReglasDeLaPartida.PRIMERA_JORNADA)
	assert_int(cargado[APERCIBIMIENTOS]).is_equal(Legajo.new().apercibimientos())


func test_una_version_futura_no_carga_y_no_se_borra() -> void:  # AC-SAV-009
	var guardado := _guardado()
	var futura := _partida_en_la_tercera()
	futura[VERSION] = PartidaSerializada.VERSION + 1
	guardado.escribir(futura)
	assert_dict(guardado.cargar()).is_empty()
	assert_bool(guardado.hay_guardado()).is_false()
	assert_bool(FileAccess.file_exists(guardado.ruta)).is_true()


func test_un_guardado_sin_version_carga() -> void:  # AC-SAV-009
	var guardado := _guardado()
	var sin_version := _partida_en_la_tercera()
	sin_version.erase(VERSION)
	guardado.escribir(sin_version)
	assert_int(guardado.cargar()[JORNADA]).is_equal(ReglasDeLaPartida.PRIMERA_JORNADA + 2)


func test_sin_archivo_cargar_da_vacio() -> void:  # AC-SAV-010
	var guardado := _guardado()
	assert_dict(guardado.cargar()).is_empty()
	assert_bool(guardado.hay_guardado()).is_false()


func test_un_archivo_corrupto_da_vacio_y_se_borra() -> void:  # AC-SAV-011
	var guardado := _guardado()
	_escribir_crudo(guardado.ruta, "{ esto no es un guardado")
	assert_dict(guardado.cargar()).is_empty()
	assert_bool(FileAccess.file_exists(guardado.ruta)).is_false()


func test_un_archivo_que_no_es_un_diccionario_tambien_es_corrupto() -> void:  # AC-SAV-011
	var guardado := _guardado()
	_escribir_crudo(guardado.ruta, "3")
	assert_bool(guardado.hay_guardado()).is_false()
	assert_bool(FileAccess.file_exists(guardado.ruta)).is_false()


func test_borrar_saca_el_archivo() -> void:
	var guardado := _guardado()
	guardado.escribir(_partida_en_la_tercera())
	assert_bool(guardado.hay_guardado()).is_true()
	guardado.borrar()
	assert_bool(guardado.hay_guardado()).is_false()


func test_retomar_arranca_donde_quedo() -> void:  # AC-SAV-017
	var guardado := _guardado()
	var nueva := Partida.desde(guardado.cargar())
	assert_int(nueva.jornada()).is_equal(ReglasDeLaPartida.PRIMERA_JORNADA)
	assert_int(nueva.apercibimientos()).is_equal(0)
	guardado.escribir(_partida_en_la_tercera())
	var retomada := Partida.desde(guardado.cargar())
	assert_int(retomada.jornada()).is_equal(ReglasDeLaPartida.PRIMERA_JORNADA + 2)
	assert_int(retomada.apercibimientos()).is_equal(Reglas.APERCIBIMIENTOS_POR_AVISO)
