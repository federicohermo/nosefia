## El texto común de las hojas y de su lectura encuadrada.
extends GdUnitTestSuite


func test_las_obligatorias_se_presentan_en_el_orden_de_la_ficha() -> void:  # AC-PLY-069
	var nota := NotaPegada.tareas_a_realizar(
		Apertura.obligatorias(ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA)
	)
	assert_str(nota.titulo()).is_equal("TAREAS A REALIZAR")
	assert_bool(nota.numerada()).is_true()
	(
		assert_array(nota.renglones())
		. contains_exactly(
			[
				"Atención al cliente",
				"Registro de productos vendidos",
				"Limpieza",
				"Reposición",
				"Ordenar cajas en el depósito",
			]
		)
	)


func test_dos_obligatorias_dan_dos_renglones_en_su_orden() -> void:  # AC-PLY-069
	var nota := NotaPegada.tareas_a_realizar(
		[Tarea.new(Tarea.Tipo.SACAR_LA_BASURA), Tarea.new(Tarea.Tipo.LIMPIAR)]
	)
	assert_array(nota.renglones()).contains_exactly(["Limpieza", "Tirar la basura"])


func test_sin_obligatorias_hay_titulo_y_ningun_renglon() -> void:  # AC-PLY-069
	var nota := NotaPegada.tareas_a_realizar([])
	assert_str(nota.titulo()).is_equal("TAREAS A REALIZAR")
	assert_array(nota.renglones()).is_empty()
	assert_bool(nota.numerada()).is_true()


func test_cada_tipo_de_tarea_declarado_tiene_nombre() -> void:  # AC-PLY-069
	# Si la jornada declara otro tipo y falta su nombre, este caso sale rojo por aserción.
	for tipo: Tarea.Tipo in Tarea.Tipo.values():
		var nota := NotaPegada.tareas_a_realizar([Tarea.new(tipo)])
		(
			assert_int(nota.renglones().size())
			. override_failure_message("Falta el nombre de la tarea %s" % tipo)
			. is_equal(1)
		)
		if not nota.renglones().is_empty():
			assert_str(nota.renglones()[0]).is_not_empty()


# AC-PLY-068, AC-PLY-070
func test_mantener_ordenado_dice_las_tres_indicaciones_de_la_ficha() -> void:
	var nota := NotaPegada.de(NotaPegada.Id.LOCAL_ORDENADO)
	assert_str(nota.titulo()).is_equal("MANTENER EL LOCAL ORDENADO")
	assert_bool(nota.numerada()).is_false()
	(
		assert_array(nota.renglones())
		. contains_exactly(
			[
				"No dejar productos tirados.",
				"Dejar las cajas en el depósito.",
				"Dejar los elementos de limpieza en el cuartito.",
			]
		)
	)


func test_las_hojas_del_bano_no_generan_una_transcripcion() -> void:  # AC-PLY-068, AC-PLY-070
	for id: NotaPegada.Id in [
		NotaPegada.Id.JABONES_Y_MANCHAS,
		NotaPegada.Id.INSTRUCCIONES_DE_LIMPIEZA,
		NotaPegada.Id.NO_TIRAR_PAPEL
	]:
		var nota := NotaPegada.de(id)
		assert_str(nota.titulo()).is_not_empty()
		assert_array(nota.renglones()).is_empty()
		assert_bool(nota.numerada()).is_false()


func test_cambiar_la_lectura_no_cambia_el_dato_compartido() -> void:  # AC-PLY-068, AC-PLY-070
	var nota := NotaPegada.de(NotaPegada.Id.LOCAL_ORDENADO)
	var lectura := nota.renglones()
	lectura.clear()
	assert_int(nota.renglones().size()).is_equal(3)


func test_la_jornada_sin_particular_enumera_solo_las_fijas() -> void:  # AC-PLY-080
	var sin_particular := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 4
	var filas := NotaPegada.tareas_a_realizar(Apertura.obligatorias(sin_particular)).renglones()
	assert_array(filas).contains_exactly(
		["Atención al cliente", "Registro de productos vendidos", "Limpieza", "Reposición"]
	)


func test_la_tarea_cumplida_marca_su_renglon_y_al_descumplirse_lo_pierde() -> void:  # AC-PLY-165
	var limpiar := Tarea.new(Tarea.Tipo.LIMPIAR)
	var basura := Tarea.new(Tarea.Tipo.SACAR_LA_BASURA)
	# La lista llega en un orden y los renglones salen en el de la ficha.
	var obligatorias: Array[Tarea] = [basura, limpiar]
	var sin_cumplir := NotaPegada.tareas_a_realizar(obligatorias)
	assert_bool(sin_cumplir.cumplida(0)).is_false()
	assert_bool(sin_cumplir.cumplida(1)).is_false()
	limpiar.completar()
	var con_limpieza := NotaPegada.tareas_a_realizar(obligatorias)
	assert_bool(con_limpieza.cumplida(0)).is_true()
	assert_bool(con_limpieza.cumplida(1)).is_false()
	assert_array(con_limpieza.renglones()).contains_exactly(sin_cumplir.renglones())
	limpiar.descompletar()
	assert_bool(NotaPegada.tareas_a_realizar(obligatorias).cumplida(0)).is_false()


func test_la_jornada_que_abre_con_una_tarea_cumplida_arranca_cumplida() -> void:  # AC-PLY-165
	var obligatorias := Apertura.obligatorias(ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA)
	obligatorias[2].completar()
	var nota := NotaPegada.tareas_a_realizar(obligatorias)
	for fila in nota.renglones().size():
		assert_bool(nota.cumplida(fila)).is_equal(fila == 2)


func test_las_hojas_sin_tareas_no_arrancan_cumplidas() -> void:  # AC-PLY-165
	for id: NotaPegada.Id in NotaPegada.Id.values():
		var nota := NotaPegada.de(id)
		for fila in nota.renglones().size():
			assert_bool(nota.cumplida(fila)).is_false()
