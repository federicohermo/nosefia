extends GdUnitTestSuite


func _probar_cierre(nombre: String, desde_popup: bool = false) -> Array[Input.MouseMode]:
	var local: Node3D = auto_free(load("res://src/escenas/almacen.tscn").instantiate())
	local.set("_partida", Partida.desde({"jornada": ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA}))
	add_child(local)
	local.get_node("Interfaz/PersianaDeLaNoche").terminar()
	(local.get("_reloj") as Node).set_process(false)
	var jugador: Node3D = local.get("_jugador")
	jugador.set_physics_process(false)
	jugador.set("_en_web", true)
	var modo: Array[Input.MouseMode] = [Input.MOUSE_MODE_VISIBLE]
	var escrituras: Array[Input.MouseMode] = []
	jugador.set("_leer_cursor", func() -> Input.MouseMode: return modo[0])
	jugador.set(
		"_escribir_cursor",
		func(valor: Input.MouseMode) -> void:
			modo[0] = valor
			escrituras.append(valor)
	)
	var puesto: Node = local.get_node(nombre)
	if nombre.ends_with("NotasDelAlmacen"):
		puesto.call("_abrir", puesto.get("notas")[0])
	elif nombre.ends_with("Ventanilla"):
		(local.get("_reloj") as RelojDelTurno).avanzar(480.0)
		puesto.get_node("Comprador/Objetivo").call("accionar")
	else:
		puesto.call("abrir")
	assert_bool(jugador.call("suspendido")).is_true()
	assert_array(escrituras).is_empty()
	var derecho := InputEventMouseButton.new()
	derecho.button_index = MOUSE_BUTTON_RIGHT
	derecho.pressed = true
	if nombre.ends_with("Ventanilla"):
		derecho.button_index = MOUSE_BUTTON_LEFT
	if desde_popup:
		var programa: ProgramaDeTickets = puesto.get("programa")
		var selector: OptionButton = programa.selectores[0]
		programa.call("_en_el_popup", derecho, selector.get_popup())
	else:
		puesto.call("_input", derecho)
	assert_bool(jugador.call("suspendido")).is_false()
	for cuadro: int in 3:
		jugador.call("_aplicar_el_modo_del_cursor")
	return escrituras


func test_salir_de_ventanilla_recaptura_con_el_mismo_clic() -> void:  # AC-PLY-056
	assert_array(_probar_cierre("Estructura/Ventanilla")).is_equal([Input.MOUSE_MODE_CAPTURED])


func test_salir_de_computadora_recaptura_con_el_mismo_clic() -> void:  # AC-PLY-056
	assert_array(_probar_cierre("Estructura/base compu/StaticBody3D")).is_equal(
		[Input.MOUSE_MODE_CAPTURED]
	)


func test_salir_de_nota_recaptura_con_el_mismo_clic() -> void:  # AC-PLY-071
	assert_array(_probar_cierre("Estructura/NotasDelAlmacen")).is_equal([Input.MOUSE_MODE_CAPTURED])


func test_salir_de_caja_recaptura_con_el_mismo_clic() -> void:  # AC-PLY-072
	assert_array(_probar_cierre("Estructura/cajaregistradora/StaticBody3D")).is_equal(
		[Input.MOUSE_MODE_CAPTURED]
	)


func test_salir_del_popup_de_caja_recaptura_con_el_mismo_clic() -> void:  # AC-PLY-072
	assert_array(_probar_cierre("Estructura/cajaregistradora/StaticBody3D", true)).is_equal(
		[Input.MOUSE_MODE_CAPTURED]
	)
