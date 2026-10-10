## El texto común de las hojas y de su lectura encuadrada.
extends GdUnitTestSuite


func test_las_obligatorias_se_presentan_en_el_orden_de_la_ficha() -> void:  # AC-PLY-069
	var nota := NotaPegada.tareas_a_realizar(Apertura.obligatorias())
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
				"Sacar la basura",
			]
		)
	)


func test_dos_obligatorias_dan_dos_renglones_en_su_orden() -> void:  # AC-PLY-069
	var nota := NotaPegada.tareas_a_realizar(
		[Tarea.new(Tarea.Tipo.SACAR_LA_BASURA), Tarea.new(Tarea.Tipo.CAJA)]
	)
	assert_array(nota.renglones()).contains_exactly(["Atención al cliente", "Sacar la basura"])


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
				"Dejar los elementos de limpieza en el baño.",
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
