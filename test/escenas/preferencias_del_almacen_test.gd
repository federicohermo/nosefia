## Las preferencias en el almacén: la sensibilidad guardada vale al entrar, y la que se cambia
## desde la pausa vale desde el primer giro después de reanudar.
extends GdUnitTestSuite

const ESCENA_DEL_ALMACEN := "res://src/escenas/almacen.tscn"
const C := Preferencias.Campo
const MOVIMIENTO := Vector2(100.0, 0.0)


func after_test() -> void:
	get_tree().paused = false
	var ajuste: AjusteDePreferencias = auto_free(AjusteDePreferencias.new())
	add_child(ajuste)
	ajuste.aplicar(Preferencias.new())


func _almacen() -> Node3D:
	var almacen: Node3D = auto_free(load(ESCENA_DEL_ALMACEN).instantiate())
	add_child(almacen)
	await get_tree().process_frame
	return almacen


## Cuánto gira la vista con un mismo movimiento del mouse, desde la vista derecha.
func _giro(almacen: Node3D) -> float:
	var mirada: Mirada = almacen.get("_jugador").get("_mirada")
	mirada.orientar(0.0)
	mirada.girar(MOVIMIENTO)
	var giro := absf(mirada.yaw())
	mirada.orientar(0.0)
	return giro


func _esc() -> InputEventAction:
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	return esc


func test_la_sensibilidad_guardada_vale_al_empezar_otra_partida() -> void:  # AC-CFG-013
	var de_fabrica := MOVIMIENTO.x * ReglasDelJugador.SENSIBILIDAD_DEL_MOUSE
	var guardadas := Preferencias.new()
	guardadas.poner(C.SENSIBILIDAD, 2.0)
	assert_bool(ArchivoDePreferencias.new().escribir(guardadas)).is_true()
	var almacen: Node3D = await _almacen()
	assert_float(_giro(almacen)).is_equal_approx(de_fabrica * 2.0, 1e-5)
	var examen: Examen = almacen.get("_jugador").get("examen")
	assert_float(examen.sensibilidad).is_equal_approx(
		ReglasDelJugador.SENSIBILIDAD_DEL_MOUSE * 2.0, 1e-9
	)


func test_sin_preferencias_la_vista_gira_como_de_fabrica() -> void:  # AC-CFG-006
	var almacen: Node3D = await _almacen()
	assert_float(_giro(almacen)).is_equal_approx(
		MOVIMIENTO.x * ReglasDelJugador.SENSIBILIDAD_DEL_MOUSE, 1e-5
	)


func test_la_sensibilidad_cambiada_en_la_pausa_vale_al_reanudar() -> void:  # AC-CFG-009, AC-CFG-010
	var almacen: Node3D = await _almacen()
	var de_fabrica := _giro(almacen)
	var pausa: ControlDePausa = almacen.get_node("Interfaz/ControlDePausa")
	var menu: MenuDePausa = almacen.get_node("Interfaz/MenuDePausa")
	pausa._input(_esc())
	assert_bool(get_tree().paused).is_true()
	(menu.get_node("Fondo/Panel/Opciones/Configuraciones") as Button).pressed.emit()
	var pantalla := menu.configuraciones()
	assert_bool(pantalla.visible).is_true()
	# Encima del fondo de la pausa, o el fondo se come los clics.
	assert_int(pantalla.layer).is_greater(menu.layer)
	assert_bool(get_tree().paused).is_true()
	assert_int(Input.mouse_mode).is_not_equal(Input.MOUSE_MODE_CAPTURED)
	var fila: HBoxContainer = pantalla.filas()[Preferencias.CAMPOS.find(C.SENSIBILIDAD)]
	for _vez: int in range(4):
		(fila.get_child(3) as Button).pressed.emit()
	assert_float(ArchivoDePreferencias.new().cargar().valor(C.SENSIBILIDAD)).is_equal_approx(
		2.0, 1e-6
	)
	# El primer Esc cierra configuraciones y deja la pausa; el segundo reanuda.
	pausa._input(_esc())
	assert_bool(pantalla.visible).is_false()
	assert_bool(menu.visible).is_true()
	assert_bool(get_tree().paused).is_true()
	assert_bool((menu.get_node("Fondo/Panel/Opciones/Reanudar") as Button).has_focus()).is_true()
	pausa._input(_esc())
	assert_bool(get_tree().paused).is_false()
	assert_float(_giro(almacen)).is_equal_approx(de_fabrica * 2.0, 1e-5)


func test_el_brillo_guardado_aclara_la_interfaz_del_almacen() -> void:  # AC-CFG-007
	var guardadas := Preferencias.new()
	guardadas.poner(C.BRILLO, 150.0)
	ArchivoDePreferencias.new().escribir(guardadas)
	var almacen: Node3D = await _almacen()
	var tema: Theme = load("res://assets/ui/manada/tema.tres")
	var con_tema := 0
	for control: Control in almacen.find_children("*", "Control", true, false):
		if control.theme == tema:
			con_tema += 1
			assert_float(control.modulate.r).is_equal_approx(1.5, 1e-5)
	assert_int(con_tema).is_greater(0)
