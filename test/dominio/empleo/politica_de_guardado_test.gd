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
	var despedido := Partida.nueva()
	_cerrar_grave(despedido)
	_cerrar_grave(despedido)
	assert_bool(despedido.terminada()).is_true()
	assert_int(PoliticaDeGuardado.accion(despedido)).is_equal(PoliticaDeGuardado.Accion.BORRAR)


func test_los_datos_llevan_la_jornada_y_los_apercibimientos_de_la_partida() -> void:
	var partida := Partida.nueva()
	_cerrar_grave(partida)
	var datos := PoliticaDeGuardado.datos(partida)
	var retomada := Partida.desde(datos)
	assert_int(retomada.jornada()).is_equal(partida.jornada())
	assert_int(retomada.apercibimientos()).is_equal(partida.apercibimientos())
	assert_int(datos[PartidaSerializada.CLAVE_DE_VERSION]).is_equal(PartidaSerializada.VERSION)


func test_la_politica_es_pura() -> void:
	var texto := FileAccess.get_file_as_string(POLITICA)
	assert_str(texto).contains("extends RefCounted")
	for patron: String in ["FileAccess", "get_tree(", "_process(", "await"]:
		assert_str(texto).not_contains(patron)
