## Qué hace el guardado al cerrar una jornada, decidido sin tocar disco.
extends GdUnitTestSuite

const POLITICA := "res://src/dominio/empleo/politica_de_guardado.gd"


func _cerrar_grave(partida: Partida) -> void:
	partida.abrir_la_jornada()
	partida.cerrar_la_jornada(0)


func test_las_acciones_son_escribir_y_borrar_y_ninguna_mas() -> void:  # AC-SAV-004
	assert_array(PoliticaDeGuardado.Accion.keys()).is_equal(["ESCRIBIR", "BORRAR"])
	var en_curso := Partida.nueva()
	assert_int(PoliticaDeGuardado.accion(en_curso)).is_equal(PoliticaDeGuardado.Accion.ESCRIBIR)
	var despedido := Partida.desde({"jornada": ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA})
	_cerrar_grave(despedido)
	_cerrar_grave(despedido)
	assert_bool(despedido.terminada()).is_true()
	assert_int(PoliticaDeGuardado.accion(despedido)).is_equal(PoliticaDeGuardado.Accion.BORRAR)


func test_los_datos_llevan_la_jornada_y_los_medios_de_la_partida() -> void:
	var partida := Partida.nueva()
	_cerrar_grave(partida)
	var datos := PoliticaDeGuardado.datos(partida)
	var retomada := Partida.desde(datos)
	assert_int(retomada.jornada()).is_equal(partida.jornada())
	assert_int(retomada.medios()).is_equal(partida.medios())
	assert_int(datos[PartidaSerializada.CLAVE_DE_VERSION]).is_equal(PartidaSerializada.VERSION)


func test_los_datos_llevan_las_cuentas_y_las_devoluciones() -> void:  # AC-SAV-024
	var partida := Partida.desde({"jornada": ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA})
	partida.abrir_la_jornada()
	partida.anotar_llamado(Partida.Llamado.PAPEL_EN_EL_INODORO)
	partida.cerrar_la_jornada(0)
	var datos := PoliticaDeGuardado.datos(partida)
	assert_dict(datos["fallas"]).contains_key_value("REPONER", 1)
	assert_dict(datos["llamados"]).contains_key_value("PAPEL_EN_EL_INODORO", 1)
	assert_int(datos["noches_sin_sumar"]).is_zero()
	assert_array(Partida.desde(datos).mensajes_del_jefe()).is_equal(partida.mensajes_del_jefe())
	assert_array(datos["devoluciones"]).is_not_empty()


func test_la_politica_es_pura() -> void:
	var texto := FileAccess.get_file_as_string(POLITICA)
	assert_str(texto).contains("extends RefCounted")
	for patron: String in ["FileAccess", "get_tree(", "_process(", "await"]:
		assert_str(texto).not_contains(patron)
