## La pantalla de controles: un renglón por acción, y elegir una ranura y apretar una tecla o un
## botón del mouse se la asigna.
extends GdUnitTestSuite

const ESCENA := "res://src/ui/interrupciones/pantalla_de_controles.tscn"
const TECLA := AsignacionDeControles.TipoDeEntrada.TECLA
const BOTON := AsignacionDeControles.TipoDeEntrada.BOTON_DEL_MOUSE

var _avisos: Array[AsignacionDeControles] = []
var _cierres: int = 0


func before_test() -> void:
	_avisos = []
	_cierres = 0


## El `InputMap` es de todo el proceso: cada caso lo deja como en `project.godot`.
func after_test() -> void:
	_aplicar_al_motor(AsignacionDeControles.new())


func _aplicar_al_motor(asignacion: AsignacionDeControles) -> void:
	var ajuste: AjusteDePreferencias = auto_free(AjusteDePreferencias.new())
	add_child(ajuste)
	var preferencias := Preferencias.new()
	preferencias.poner_controles(asignacion)
	ajuste.aplicar(preferencias)


func _pantalla() -> PantallaDeControles:
	var pantalla: PantallaDeControles = auto_free(load(ESCENA).instantiate())
	add_child(pantalla)
	pantalla.preparar(AsignacionDeControles.new())
	pantalla.controles_cambiados.connect(func(a: AsignacionDeControles) -> void: _avisos.append(a))
	pantalla.cerrada.connect(func() -> void: _cierres += 1)
	pantalla.abrir()
	return pantalla


func _tecla(codigo: int) -> InputEventKey:
	var evento := InputEventKey.new()
	evento.physical_keycode = codigo as Key
	evento.pressed = true
	return evento


func _clic(boton: int) -> InputEventMouseButton:
	var evento := InputEventMouseButton.new()
	evento.button_index = boton as MouseButton
	evento.pressed = true
	return evento


func _entrada(asignacion: AsignacionDeControles, accion: StringName, ranura: int) -> Vector2i:
	var entrada := asignacion.entrada(accion, ranura)
	return Vector2i(entrada["tipo"], entrada["codigo"])


## Los renglones de TECLADO Y MOUSE, en orden: las acciones con Visión después de Derecha.
func _nombres_de_los_renglones() -> Array[String]:
	var nombres: Array[String] = []
	for accion: StringName in AsignacionDeControles.ACCIONES:
		nombres.append(AsignacionDeControles.nombre_de_la_accion(accion))
		if accion == AsignacionDeControles.DERECHA:
			nombres.append(PantallaDeControles.TEXTO_DE_VISION)
	return nombres


func _boton_del_joystick(indice: int) -> InputEventJoypadButton:
	var evento := InputEventJoypadButton.new()
	evento.button_index = indice as JoyButton
	evento.pressed = true
	return evento


func test_muestra_un_renglon_por_accion_con_sus_teclas() -> void:  # AC-CFG-015, AC-CFG-016
	var pantalla := _pantalla()
	var nombres: Array[String] = []
	var botones: int = 0
	for fila: HBoxContainer in pantalla.filas():
		nombres.append((fila.get_child(0) as Label).text)
		botones += fila.find_children("*", "Button", true, false).size()
	assert_array(nombres).is_equal(_nombres_de_los_renglones())
	# Cada acción tiene una celda principal y una secundaria, y lo fijo no tiene ninguna.
	assert_int(botones).is_equal(AsignacionDeControles.ACCIONES.size() * 2)
	assert_str(pantalla.texto_de(AsignacionDeControles.EXAMINAR, 0)).is_equal(
		PantallaDeControles.nombre_de_la_entrada(TECLA, KEY_E)
	)
	assert_str(pantalla.texto_de(AsignacionDeControles.AGARRAR, 0)).is_equal(
		PantallaDeControles.nombre_de_la_entrada(BOTON, MOUSE_BUTTON_LEFT)
	)
	assert_str(pantalla.texto_de(AsignacionDeControles.AGARRAR, 0)).is_not_equal(
		pantalla.texto_de(AsignacionDeControles.INTERACTUAR, 0)
	)
	for entrada: Dictionary in AsignacionDeControles.new().entradas():
		assert_object(pantalla.glifo_de(entrada["accion"], entrada["ranura"])).is_not_null()


func test_movimiento_se_reasigna_desde_sus_cuatro_renglones() -> void:  # AC-CFG-016, AC-CFG-019
	var pantalla := _pantalla()
	var renglones := pantalla.filas()
	for direccion: StringName in AsignacionDeControles.DIRECCIONES:
		var indice := AsignacionDeControles.ACCIONES.find(direccion)
		for ranura: int in AsignacionDeControles.ranuras_de(direccion):
			(
				assert_bool(renglones[indice].is_ancestor_of(pantalla.boton_de(direccion, ranura)))
				. is_true()
			)
	pantalla.boton_de(AsignacionDeControles.ADELANTE, 1).pressed.emit()
	assert_bool(pantalla.atender(_tecla(KEY_H))).is_true()
	assert_int(_avisos.size()).is_equal(1)
	assert_vector(_entrada(_avisos[0], AsignacionDeControles.ADELANTE, 1)).is_equal(
		Vector2i(TECLA, KEY_H)
	)
	assert_vector(_entrada(_avisos[0], AsignacionDeControles.ADELANTE, 0)).is_equal(
		_entrada(AsignacionDeControles.new(), AsignacionDeControles.ADELANTE, 0)
	)


func test_apretar_el_renglon_espera_la_entrada() -> void:  # AC-CFG-017
	var pantalla := _pantalla()
	assert_bool(pantalla.capturando()).is_false()
	pantalla.boton_de(AsignacionDeControles.EXAMINAR, 0).pressed.emit()
	assert_bool(pantalla.capturando()).is_true()
	assert_str(pantalla.texto_de(AsignacionDeControles.EXAMINAR, 0)).is_equal(
		PantallaDeControles.TEXTO_DE_ESPERA
	)


func test_elegir_una_accion_y_apretar_una_tecla_la_asigna_y_avisa_una_vez() -> void:  # AC-CFG-017
	var pantalla := _pantalla()
	pantalla.elegir(AsignacionDeControles.EXAMINAR, 0)
	assert_bool(pantalla.atender(_tecla(KEY_F))).is_true()
	assert_bool(pantalla.capturando()).is_false()
	assert_int(_avisos.size()).is_equal(1)
	assert_vector(_entrada(_avisos[0], AsignacionDeControles.EXAMINAR, 0)).is_equal(
		Vector2i(TECLA, KEY_F)
	)
	assert_str(pantalla.texto_de(AsignacionDeControles.EXAMINAR, 0)).is_equal(
		PantallaDeControles.nombre_de_la_entrada(TECLA, KEY_F)
	)


func test_apretar_un_boton_del_mouse_se_lo_asigna_a_otra_accion() -> void:  # AC-CFG-017, AC-CFG-018
	var pantalla := _pantalla()
	pantalla.elegir(AsignacionDeControles.INTERACTUAR, 0)
	assert_bool(pantalla.atender(_clic(MOUSE_BUTTON_LEFT))).is_true()
	assert_int(_avisos.size()).is_equal(1)
	assert_vector(_entrada(_avisos[0], AsignacionDeControles.INTERACTUAR, 0)).is_equal(
		Vector2i(BOTON, MOUSE_BUTTON_LEFT)
	)
	assert_vector(_entrada(_avisos[0], AsignacionDeControles.AGARRAR, 0)).is_equal(
		Vector2i(BOTON, MOUSE_BUTTON_RIGHT)
	)
	assert_str(pantalla.texto_de(AsignacionDeControles.AGARRAR, 0)).is_equal(
		PantallaDeControles.nombre_de_la_entrada(BOTON, MOUSE_BUTTON_RIGHT)
	)


func test_la_rueda_y_el_movimiento_del_mouse_no_son_entradas() -> void:  # AC-CFG-017
	var pantalla := _pantalla()
	pantalla.elegir(AsignacionDeControles.EXAMINAR, 0)
	assert_bool(pantalla.atender(InputEventMouseMotion.new())).is_false()
	assert_bool(pantalla.atender(_clic(MOUSE_BUTTON_WHEEL_UP))).is_true()
	assert_bool(pantalla.capturando()).is_true()
	assert_array(_avisos).is_empty()


func test_la_tecla_de_pausa_cancela_la_espera_sin_cambiar_nada() -> void:  # AC-CFG-017
	var pantalla := _pantalla()
	pantalla.elegir(AsignacionDeControles.EXAMINAR, 0)
	assert_bool(pantalla.atender(_tecla(KEY_ESCAPE))).is_true()
	assert_bool(pantalla.capturando()).is_false()
	assert_array(_avisos).is_empty()
	assert_str(pantalla.texto_de(AsignacionDeControles.EXAMINAR, 0)).is_equal(
		PantallaDeControles.nombre_de_la_entrada(TECLA, KEY_E)
	)
	assert_bool(pantalla.visible).is_true()


func test_retroceder_cancela_la_espera_y_despues_cierra() -> void:  # AC-CFG-015
	var pantalla := _pantalla()
	pantalla.elegir(AsignacionDeControles.EXAMINAR, 0)
	pantalla.retroceder()
	assert_bool(pantalla.capturando()).is_false()
	assert_bool(pantalla.visible).is_true()
	assert_int(_cierres).is_equal(0)
	pantalla.retroceder()
	assert_bool(pantalla.visible).is_false()
	assert_int(_cierres).is_equal(1)


func test_apretar_la_entrada_que_ya_tiene_no_avisa() -> void:  # AC-CFG-018
	var pantalla := _pantalla()
	pantalla.elegir(AsignacionDeControles.EXAMINAR, 0)
	assert_bool(pantalla.atender(_tecla(KEY_E))).is_true()
	assert_bool(pantalla.capturando()).is_false()
	assert_array(_avisos).is_empty()


func test_sin_esperar_nada_no_se_come_ninguna_tecla() -> void:  # AC-CFG-017
	var pantalla := _pantalla()
	assert_bool(pantalla.atender(_tecla(KEY_F))).is_false()
	assert_bool(pantalla.atender(_clic(MOUSE_BUTTON_LEFT))).is_false()
	assert_array(_avisos).is_empty()


func test_con_pausa_en_otra_tecla_esc_se_asigna_a_otra_accion() -> void:  # AC-CFG-017
	var pantalla := _pantalla()
	pantalla.elegir(AsignacionDeControles.PAUSA, 0)
	pantalla.atender(_tecla(KEY_P))
	_aplicar_al_motor(_avisos.back())
	pantalla.elegir(AsignacionDeControles.EXAMINAR, 0)
	assert_bool(pantalla.atender(_tecla(KEY_ESCAPE))).is_true()
	assert_vector(_entrada(_avisos.back(), AsignacionDeControles.EXAMINAR, 0)).is_equal(
		Vector2i(TECLA, KEY_ESCAPE)
	)
	assert_vector(_entrada(_avisos.back(), AsignacionDeControles.PAUSA, 0)).is_equal(
		Vector2i(TECLA, KEY_P)
	)


func test_en_la_web_esc_no_se_asigna_a_otra_accion_y_sigue_esperando() -> void:  # AC-CFG-017
	var pantalla := _pantalla()
	pantalla.en_la_web = true
	pantalla.elegir(AsignacionDeControles.PAUSA, 0)
	pantalla.atender(_tecla(KEY_P))
	_aplicar_al_motor(_avisos.back())
	pantalla.elegir(AsignacionDeControles.EXAMINAR, 0)
	assert_bool(pantalla.atender(_tecla(KEY_ESCAPE))).is_true()
	assert_bool(pantalla.capturando()).is_true()
	assert_int(_avisos.size()).is_equal(1)
	assert_vector(_entrada(_avisos[0], AsignacionDeControles.EXAMINAR, 0)).is_equal(
		Vector2i(TECLA, KEY_E)
	)


func test_corre_tambien_con_el_arbol_en_pausa() -> void:
	assert_int(_pantalla().process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)


func test_la_pantalla_usa_el_tema_y_no_declara_estilos() -> void:
	var texto := FileAccess.get_file_as_string(ESCENA)
	assert_str(texto).contains("res://assets/ui/manada/tema.tres")
	assert_str(texto).not_contains("theme_override_")


func test_muestra_el_esquema_del_joystick_con_un_boton_por_accion() -> void:  # AC-CFG-026
	var pantalla := _pantalla()
	var esperados: Dictionary[StringName, int] = {
		AsignacionDeControles.AGARRAR: JOY_BUTTON_A,
		AsignacionDeControles.INTERACTUAR: JOY_BUTTON_RIGHT_SHOULDER,
		AsignacionDeControles.AGACHARSE: JOY_BUTTON_LEFT_SHOULDER,
		AsignacionDeControles.CELULAR: JOY_BUTTON_B,
		AsignacionDeControles.EXAMINAR: JOY_BUTTON_X,
	}
	for accion: StringName in esperados:
		var texto := pantalla.texto_de(accion, AsignacionDeControles.RANURA_DEL_JOYSTICK)
		assert_str(texto).is_equal(
			PantallaDeControles.nombre_de_la_entrada(
				AsignacionDeControles.TipoDeEntrada.BOTON_DEL_JOYSTICK, esperados[accion]
			)
		)
	var nombres: Array[String] = []
	for accion: StringName in esperados:
		nombres.append(pantalla.texto_de(accion, AsignacionDeControles.RANURA_DEL_JOYSTICK))
	assert_int(nombres.size()).is_equal(esperados.size())
	assert_bool(nombres.has("")).is_false()


func test_un_boton_del_joystick_se_asigna_a_la_ranura_y_avisa() -> void:  # AC-CFG-026
	var pantalla := _pantalla()
	var ranura := AsignacionDeControles.RANURA_DEL_JOYSTICK
	pantalla.elegir(AsignacionDeControles.EXAMINAR, ranura)
	assert_str(pantalla.texto_de(AsignacionDeControles.EXAMINAR, ranura)).is_equal(
		PantallaDeControles.TEXTO_DE_ESPERA_DEL_JOYSTICK
	)
	assert_bool(pantalla.atender(_boton_del_joystick(JOY_BUTTON_Y))).is_true()
	assert_bool(pantalla.capturando()).is_false()
	assert_int(_avisos.size()).is_equal(1)
	var asignacion: AsignacionDeControles = _avisos[0]
	assert_vector(_entrada(asignacion, AsignacionDeControles.EXAMINAR, ranura)).is_equal(
		Vector2i(AsignacionDeControles.TipoDeEntrada.BOTON_DEL_JOYSTICK, JOY_BUTTON_Y)
	)
	assert_vector(_entrada(asignacion, AsignacionDeControles.EXAMINAR, 0)).is_equal(
		Vector2i(TECLA, KEY_E)
	)


func test_una_tecla_no_entra_al_boton_y_start_cancela_la_espera() -> void:  # AC-CFG-026
	var pantalla := _pantalla()
	var ranura := AsignacionDeControles.RANURA_DEL_JOYSTICK
	pantalla.elegir(AsignacionDeControles.EXAMINAR, ranura)
	assert_bool(pantalla.atender(_tecla(KEY_F))).is_true()
	assert_bool(pantalla.atender(_clic(MOUSE_BUTTON_MIDDLE))).is_true()
	assert_bool(pantalla.capturando()).is_true()
	assert_array(_avisos).is_empty()
	assert_bool(pantalla.atender(_boton_del_joystick(JOY_BUTTON_START))).is_true()
	assert_bool(pantalla.capturando()).is_false()
	assert_array(_avisos).is_empty()
	pantalla.elegir(AsignacionDeControles.EXAMINAR, 0)
	assert_bool(pantalla.atender(_boton_del_joystick(JOY_BUTTON_START))).is_true()
	assert_bool(pantalla.capturando()).is_false()
	assert_array(_avisos).is_empty()


func test_el_foco_de_controles_queda_puesto_y_no_se_dibuja() -> void:  # AC-CFG-028
	var pantalla := _pantalla()
	var foco := pantalla.get_viewport().gui_get_focus_owner()
	assert_object(foco).is_not_null()
	assert_bool(foco != null and pantalla.is_ancestor_of(foco) and foco.has_focus()).is_true()
	assert_bool(foco != null and foco.has_focus(true)).is_false()
