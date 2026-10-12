## Esc sobre la placa del cierre: la pausa se abre encima, la placa no responde mientras tanto,
## y al reanudar vuelve la misma placa con el turno detenido. Volver al menú desde esa pausa
## conserva el guardado que dejó el cierre.
extends GdUnitTestSuite

const ESCENA_DEL_ALMACEN := "res://src/escenas/almacen.tscn"
const SEGUNDOS_REALES_DE_UN_TURNO := (
	Reglas.DURACION_DEL_TURNO / Ritmo.SEGUNDOS_DE_TURNO_POR_SEGUNDO_REAL
)


func after_test() -> void:
	get_tree().paused = false


func _almacen_cerrado() -> Node3D:
	var almacen: Node3D = auto_free(load(ESCENA_DEL_ALMACEN).instantiate())
	add_child(almacen)
	await get_tree().process_frame
	(almacen.get_node("Servicios/RelojDelTurno") as RelojDelTurno).avanzar(
		SEGUNDOS_REALES_DE_UN_TURNO
	)
	await get_tree().process_frame
	return almacen


func _esc() -> InputEventAction:
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	return esc


func test_esc_sobre_la_placa_pausa_encima_y_otro_esc_deja_la_misma_placa() -> void:  # AC-SAV-018
	var almacen: Node3D = await _almacen_cerrado()
	var placa: PantallaDeCierre = almacen.get_node("Interfaz/PantallaDeCierre")
	var pausa: ControlDePausa = almacen.get_node("Interfaz/ControlDePausa")
	var menu: MenuDePausa = almacen.get_node("Interfaz/MenuDePausa")
	var reloj: RelojDelTurno = almacen.get_node("Servicios/RelojDelTurno")
	var ciclo: CicloDeJornadas = almacen.get_node("Servicios/CicloDeJornadas")
	var continuar: Button = placa.get_node("Fondo/Panel/Continuar")
	assert_bool(placa.visible).is_true()
	var saludo := (placa.get_node("Fondo/Panel/Saludo") as Label).text
	pausa._input(_esc())
	assert_bool(get_tree().paused).is_true()
	assert_bool(menu.visible).is_true()
	assert_int(menu.layer).is_greater(placa.layer)
	assert_bool(placa.visible).is_true()
	# Mientras la pausa está, la placa no responde: ni el foco ni el proceso le quedan.
	assert_bool(continuar.has_focus()).is_false()
	assert_bool(continuar.can_process()).is_false()
	pausa._input(_esc())
	await get_tree().process_frame
	assert_bool(get_tree().paused).is_false()
	assert_bool(placa.visible).is_true()
	assert_str((placa.get_node("Fondo/Panel/Saludo") as Label).text).is_equal(saludo)
	assert_bool(continuar.visible).is_true()
	assert_bool(continuar.has_focus()).is_true()
	assert_bool(reloj.corriendo()).is_false()
	assert_int(ciclo.partida().jornada()).is_equal(ReglasDeLaPartida.PRIMERA_JORNADA + 1)


func test_volver_al_menu_desde_la_pausa_sobre_la_placa_conserva_el_guardado() -> void:  # AC-SAV-020
	var almacen: Node3D = await _almacen_cerrado()
	var menus := [0]
	almacen.set("_ir_al_menu", func() -> void: menus[0] += 1)
	var guardado_del_cierre := FileAccess.get_file_as_string(Guardado.ruta_por_defecto)
	assert_str(guardado_del_cierre).is_not_empty()
	var pausa: ControlDePausa = almacen.get_node("Interfaz/ControlDePausa")
	var menu: MenuDePausa = almacen.get_node("Interfaz/MenuDePausa")
	var reloj: RelojDelTurno = almacen.get_node("Servicios/RelojDelTurno")
	pausa._input(_esc())
	var volver: Button = menu.get_node("Fondo/Panel/Opciones/VolverAlMenu")
	volver.pressed.emit()
	volver.pressed.emit()
	assert_bool(get_tree().paused).is_false()
	assert_int(menus[0]).is_equal(1)
	assert_bool(reloj.corriendo()).is_false()
	assert_str(FileAccess.get_file_as_string(Guardado.ruta_por_defecto)).is_equal(
		guardado_del_cierre
	)
	var retomada := Guardado.new().cargar()
	assert_int(retomada[PartidaSerializada.clave(PartidaSerializada.Campo.JORNADA)]).is_equal(
		ReglasDeLaPartida.PRIMERA_JORNADA + 1
	)
