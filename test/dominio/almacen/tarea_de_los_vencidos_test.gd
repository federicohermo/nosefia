## La cuenta de los vencidos tirados al contenedor: cada uno una sola vez, y sólo los vencidos.
extends GdUnitTestSuite

const JORNADA := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 2


func _cindolor(vencida: bool) -> UnidadDeProducto:
	return UnidadDeProducto.new(Catalogo.de(Producto.Id.CINDOLOR), vencida)


func _desechar_vencidos(tarea: TareaDeLosVencidos, cuantos: int) -> void:
	for _vuelta in cuantos:
		assert_bool(tarea.desechar(_cindolor(true))).is_true()


func test_la_jornada_de_los_vencidos_pide_los_cinco() -> void:  # AC-SHF-059
	assert_int(TareaDeLosVencidos.de_la_jornada(JORNADA).total()).is_equal(
		ReglasDelEstante.CINDOLOR_VENCIDOS
	)


func test_con_menos_de_cinco_no_se_cumple_y_con_el_quinto_si() -> void:  # AC-SHF-059
	var tarea := TareaDeLosVencidos.de_la_jornada(JORNADA)
	for desechados in range(1, ReglasDelEstante.CINDOLOR_VENCIDOS):
		_desechar_vencidos(tarea, 1)
		assert_int(tarea.desechados()).is_equal(desechados)
		assert_bool(tarea.completada()).is_false()
	_desechar_vencidos(tarea, 1)
	assert_bool(tarea.completada()).is_true()


func test_un_vencido_de_mas_no_se_cuenta_dos_veces() -> void:  # AC-SHF-059
	var tarea := TareaDeLosVencidos.de_la_jornada(JORNADA)
	_desechar_vencidos(tarea, ReglasDelEstante.CINDOLOR_VENCIDOS)
	assert_bool(tarea.desechar(_cindolor(true))).is_false()
	assert_int(tarea.desechados()).is_equal(ReglasDelEstante.CINDOLOR_VENCIDOS)
	assert_bool(tarea.completada()).is_true()


func test_un_cindolor_sano_no_suple_a_un_vencido() -> void:  # AC-SHF-060
	var tarea := TareaDeLosVencidos.de_la_jornada(JORNADA)
	_desechar_vencidos(tarea, ReglasDelEstante.CINDOLOR_VENCIDOS - 1)
	assert_bool(tarea.desechar(_cindolor(false))).is_false()
	assert_bool(tarea.desechar(ObjetoDelAlmacen.new())).is_false()
	assert_bool(tarea.desechar(null)).is_false()
	assert_bool(tarea.completada()).is_false()


func test_tirar_de_mas_no_impide_cumplir() -> void:  # AC-SHF-060
	var tarea := TareaDeLosVencidos.de_la_jornada(JORNADA)
	tarea.desechar(_cindolor(false))
	_desechar_vencidos(tarea, ReglasDelEstante.CINDOLOR_VENCIDOS)
	assert_bool(tarea.completada()).is_true()


func test_las_demas_jornadas_no_piden_vencidos() -> void:  # AC-SHF-059
	for numero in ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA:
		var jornada := ReglasDeLaPartida.PRIMERA_JORNADA + numero
		if jornada == JORNADA:
			continue
		var tarea := TareaDeLosVencidos.de_la_jornada(jornada)
		assert_int(tarea.total()).is_zero()
		assert_bool(tarea.desechar(_cindolor(true))).is_false()
		assert_bool(tarea.completada()).is_false()
