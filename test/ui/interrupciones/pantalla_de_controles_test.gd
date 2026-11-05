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


## Los nombres de las acciones, uno por renglón: las cuatro direcciones son un solo Movimiento.
func _nombres_de_los_renglones() -> Array[String]:
	var nombres: Array[String] = []
	for accion: StringName in AsignacionDeControles.ACCIONES:
		var nombre := AsignacionDeControles.nombre_de_la_accion(accion)
		if nombre not in nombres:
			nombres.append(nombre)
	return nombres


func test_muestra_un_renglon_por_accion_con_sus_teclas() -> void:  # AC-CFG-015, AC-CFG-016
	var pantalla := _pantalla()
	var nombres: Array[String] = []
	var botones: int = 0
	for fila: HBoxContainer in pantalla.filas():
		nombres.append((fila.get_child(0) as Label).text)
		botones += fila.get_child(1).get_child_count()
	assert_array(nombres).is_equal(_nombres_de_los_renglones())
	assert_int(botones).is_equal(AsignacionDeControles.new().entradas().size())
	var movimiento: Node = pantalla.filas()[0].get_child(1)
	var ranuras_de_movimiento: int = 0
	for direccion: StringName in AsignacionDeControles.DIRECCIONES:
		ranuras_de_movimiento += AsignacionDeControles.ranuras_de(direccion)
	assert_int(movimiento.get_child_count()).is_equal(ranuras_de_movimiento)
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
		assert_str(pantalla.texto_de(entrada["accion"], entrada["ranura"])).is_not_empty()


func test_movimiento_se_reasigna_desde_su_renglon() -> void:  # AC-CFG-016, AC-CFG-019
	var pantalla := _pantalla()
	var renglon := pantalla.filas()[0]
	for direccion: StringName in AsignacionDeControles.DIRECCIONES:
		for ranura: int in AsignacionDeControles.ranuras_de(direccion):
			assert_bool(renglon.is_ancestor_of(pantalla.boton_de(direccion, ranura))).is_true()
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
