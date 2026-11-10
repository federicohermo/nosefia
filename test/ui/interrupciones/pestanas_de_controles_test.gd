## Las pestañas de la pantalla de controles, sus glifos y la tecla secundaria: se ve una sola
## pestaña, se abre en la del último dispositivo, L1 y R1 las cambian, JOYSTICK lista sólo lo que se
## reasigna, y una secundaria se llena con una tecla y se vacía con SUPR.
extends GdUnitTestSuite

const ESCENA := "res://src/ui/interrupciones/pantalla_de_controles.tscn"
const ESCENA_DE_CONFIGURACIONES := "res://src/ui/interrupciones/pantalla_de_configuraciones.tscn"
const TECLA := AsignacionDeControles.TipoDeEntrada.TECLA
const DEL_JOYSTICK := AsignacionDeControles.TipoDeEntrada.BOTON_DEL_JOYSTICK
const PRINCIPAL := AsignacionDeControles.RANURA_PRINCIPAL
const SECUNDARIA := AsignacionDeControles.RANURA_SECUNDARIA
const EN_EL_JOYSTICK := AsignacionDeControles.RANURA_DEL_JOYSTICK

var _avisos: Array[AsignacionDeControles] = []


func before_test() -> void:
	_avisos = []


func _pantalla(con_el_joystick: bool = false) -> PantallaDeControles:
	var pantalla: PantallaDeControles = auto_free(load(ESCENA).instantiate())
	add_child(pantalla)
	pantalla.preparar(AsignacionDeControles.new())
	pantalla.poner_joystick_conectado(true)
	pantalla.controles_cambiados.connect(func(a: AsignacionDeControles) -> void: _avisos.append(a))
	pantalla.abrir(con_el_joystick)
	return pantalla


func _tecla(codigo: int) -> InputEventKey:
	var evento := InputEventKey.new()
	evento.physical_keycode = codigo as Key
	evento.pressed = true
	return evento


func _boton(indice: int) -> InputEventJoypadButton:
	var evento := InputEventJoypadButton.new()
	evento.button_index = indice as JoyButton
	evento.pressed = true
	return evento


func _eje(valor: float) -> InputEventJoypadMotion:
	var evento := InputEventJoypadMotion.new()
	evento.axis = JOY_AXIS_LEFT_X
	evento.axis_value = valor
	return evento


func _entrada(asignacion: AsignacionDeControles, accion: StringName, ranura: int) -> Vector2i:
	var entrada := asignacion.entrada(accion, ranura)
	return Vector2i(entrada["tipo"], entrada["codigo"])


func _nombres(filas: Array[HBoxContainer]) -> Array[String]:
	var nombres: Array[String] = []
	for fila: HBoxContainer in filas:
		nombres.append((fila.get_child(0) as Label).text)
	return nombres


func _asignar(pantalla: PantallaDeControles, accion: StringName, ranura: int, codigo: int) -> void:
	pantalla.elegir(accion, ranura)
	pantalla.atender(_tecla(codigo))


func test_se_ve_una_sola_pestana_a_la_vez() -> void:  # AC-CFG-031
	var pantalla := _pantalla()
	assert_bool(pantalla.pestana_del_joystick()).is_false()
	assert_bool(pantalla.filas(false)[0].is_visible_in_tree()).is_true()
	assert_bool(pantalla.filas(true)[0].is_visible_in_tree()).is_false()
	pantalla.elegir_pestana(true)
	assert_bool(pantalla.filas(false)[0].is_visible_in_tree()).is_false()
	assert_bool(pantalla.filas(true)[0].is_visible_in_tree()).is_true()
	pantalla.elegir_pestana(false)
	assert_bool(pantalla.filas(false)[0].is_visible_in_tree()).is_true()


func test_cada_pestana_tiene_su_texto_y_el_dibujo_de_su_dispositivo() -> void:  # AC-CFG-031
	var pantalla := _pantalla()
	var esperadas := {
		"_pestana_del_teclado":
		[PantallaDeControles.TEXTO_DEL_TECLADO, DibujoDeDispositivo.Dispositivo.TECLADO],
		"_pestana_del_joystick":
		[PantallaDeControles.TEXTO_DEL_JOYSTICK, DibujoDeDispositivo.Dispositivo.MANDO],
	}
	for nombre: String in esperadas:
		var pestana: Button = pantalla.get(nombre)
		var rotulos := pestana.find_children("*", "Label", true, false)
		assert_str((rotulos[0] as Label).text).is_equal(esperadas[nombre][0])
		var dibujos := pestana.find_children("*", "DibujoDeDispositivo", true, false)
		assert_int(dibujos.size()).is_equal(1)
		assert_int((dibujos[0] as DibujoDeDispositivo).dispositivo).is_equal(esperadas[nombre][1])


func test_las_pestanas_se_eligen_con_el_mouse_o_por_foco() -> void:  # AC-CFG-031, AC-CFG-033
	var pantalla := _pantalla()
	var del_joystick: Button = pantalla.get("_pestana_del_joystick")
	var del_teclado: Button = pantalla.get("_pestana_del_teclado")
	assert_bool(del_joystick.focus_mode != Control.FOCUS_NONE).is_true()
	del_joystick.pressed.emit()
	assert_bool(pantalla.pestana_del_joystick()).is_true()
	del_teclado.pressed.emit()
	assert_bool(pantalla.pestana_del_joystick()).is_false()


func test_cada_accion_dice_en_su_renglon_sus_funciones_de_menu() -> void:  # AC-CFG-031, AC-CFG-042
	var pantalla := _pantalla()
	var por_pestana: Dictionary = {
		false: AsignacionDeControles.ACCIONES, true: AsignacionDeControles.ACCIONES_CON_BOTON
	}
	for del_joystick: bool in por_pestana:
		var nombres: Array[String] = []
		for fila: HBoxContainer in pantalla.filas(del_joystick):
			nombres.append((fila.get_child(0) as Label).text)
		var acciones: Array = por_pestana[del_joystick]
		for accion: StringName in acciones:
			assert_array(nombres).contains([AsignacionDeControles.nombre_de_la_accion(accion)])


func test_abre_en_la_pestana_que_le_piden_y_sin_dato_en_teclado_y_mouse() -> void:  # AC-CFG-032
	assert_bool(_pantalla().pestana_del_joystick()).is_false()
	assert_bool(_pantalla(true).pestana_del_joystick()).is_true()
	var pantalla := _pantalla(true)
	pantalla.cerrar()
	pantalla.abrir()
	assert_bool(pantalla.pestana_del_joystick()).is_false()


func test_configuraciones_abre_en_la_pestana_del_ultimo_dispositivo() -> void:  # AC-CFG-032
	var configuraciones: PantallaDeConfiguraciones = auto_free(
		load(ESCENA_DE_CONFIGURACIONES).instantiate()
	)
	add_child(configuraciones)
	configuraciones.preparar(Preferencias.new())
	configuraciones.abrir()
	var ajustar: Button = configuraciones.get("_ajustar_controles")
	var controles: PantallaDeControles = configuraciones.get("_controles")
	controles.poner_joystick_conectado(true)
	ajustar.pressed.emit()
	assert_bool(controles.pestana_del_joystick()).is_false()
	controles.cerrar()
	configuraciones.anotar_el_dispositivo(_boton(JOY_BUTTON_A))
	ajustar.pressed.emit()
	assert_bool(controles.pestana_del_joystick()).is_true()
	controles.cerrar()
	configuraciones.anotar_el_dispositivo(_tecla(KEY_F))
	ajustar.pressed.emit()
	assert_bool(controles.pestana_del_joystick()).is_false()
	controles.cerrar()
	configuraciones.anotar_el_dispositivo(_eje(1.0))
	ajustar.pressed.emit()
	assert_bool(controles.pestana_del_joystick()).is_true()
	controles.cerrar()
	configuraciones.anotar_el_dispositivo(_tecla(KEY_F))
	configuraciones.anotar_el_dispositivo(_eje(0.0))
	ajustar.pressed.emit()
	assert_bool(controles.pestana_del_joystick()).is_false()


func test_l1_y_r1_cambian_de_pestana_sin_dar_la_vuelta() -> void:  # AC-CFG-033
	var pantalla := _pantalla()
	assert_bool(pantalla.atender(_boton(JOY_BUTTON_RIGHT_SHOULDER))).is_true()
	assert_bool(pantalla.pestana_del_joystick()).is_true()
	pantalla.atender(_boton(JOY_BUTTON_RIGHT_SHOULDER))
	assert_bool(pantalla.pestana_del_joystick()).is_true()
	assert_bool(pantalla.atender(_boton(JOY_BUTTON_LEFT_SHOULDER))).is_true()
	assert_bool(pantalla.pestana_del_joystick()).is_false()
	pantalla.atender(_boton(JOY_BUTTON_LEFT_SHOULDER))
	assert_bool(pantalla.pestana_del_joystick()).is_false()


func test_l1_esperando_un_boton_se_asigna_y_no_cambia_de_pestana() -> void:  # AC-CFG-033
	var pantalla := _pantalla(true)
	pantalla.elegir(AsignacionDeControles.EXAMINAR, EN_EL_JOYSTICK)
	assert_bool(pantalla.atender(_boton(JOY_BUTTON_LEFT_SHOULDER))).is_true()
	assert_bool(pantalla.pestana_del_joystick()).is_true()
	assert_int(_avisos.size()).is_equal(1)
	assert_vector(_entrada(_avisos[0], AsignacionDeControles.EXAMINAR, EN_EL_JOYSTICK)).is_equal(
		Vector2i(DEL_JOYSTICK, JOY_BUTTON_LEFT_SHOULDER)
	)


func test_joystick_lista_solo_las_acciones_que_se_reasignan() -> void:  # AC-CFG-026, AC-CFG-031
	var pantalla := _pantalla()
	var esperadas: Array[String] = []
	for accion: StringName in AsignacionDeControles.ACCIONES_CON_BOTON:
		esperadas.append(AsignacionDeControles.nombre_de_la_accion(accion))
	assert_array(_nombres(pantalla.filas(true))).is_equal(esperadas)
	for del_dispositivo: bool in [false, true]:
		for fila: HBoxContainer in pantalla.filas(del_dispositivo):
			assert_array(fila.find_children("*", "Button", true, false)).is_not_empty()
			assert_float(fila.modulate.a).is_equal(1.0)


func test_el_foco_empieza_en_la_primera_accion_y_baja_por_la_lista() -> void:  # AC-CFG-026
	var pantalla := _pantalla(true)
	await get_tree().process_frame
	await get_tree().process_frame
	var celdas: Array[Button] = []
	for accion: StringName in AsignacionDeControles.ACCIONES_CON_BOTON:
		celdas.append(pantalla.boton_de(accion, EN_EL_JOYSTICK))
	assert_object(get_viewport().gui_get_focus_owner()).is_same(celdas[0])
	for i: int in range(1, celdas.size()):
		assert_object(celdas[i - 1].find_valid_focus_neighbor(SIDE_BOTTOM)).is_same(celdas[i])


func test_cada_boton_del_joystick_es_un_glifo_y_no_un_texto() -> void:  # AC-CFG-036
	var pantalla := _pantalla(true)
	var esperadas: Dictionary[StringName, GlifoDeEntrada.Forma] = {
		AsignacionDeControles.AGARRAR: GlifoDeEntrada.Forma.CRUZ,
		AsignacionDeControles.CELULAR: GlifoDeEntrada.Forma.CIRCULO,
		AsignacionDeControles.EXAMINAR: GlifoDeEntrada.Forma.CUADRADO,
		AsignacionDeControles.AGACHARSE: GlifoDeEntrada.Forma.PILDORA,
		AsignacionDeControles.INTERACTUAR: GlifoDeEntrada.Forma.PILDORA,
	}
	for accion: StringName in esperadas:
		assert_int(pantalla.glifo_de(accion, EN_EL_JOYSTICK).forma).is_equal(esperadas[accion])
		assert_str(pantalla.boton_de(accion, EN_EL_JOYSTICK).text).is_empty()
	assert_int(GlifoDeEntrada.forma_de(DEL_JOYSTICK, JOY_BUTTON_Y)).is_equal(
		GlifoDeEntrada.Forma.TRIANGULO
	)
	assert_int(GlifoDeEntrada.forma_de(DEL_JOYSTICK, JOY_BUTTON_LEFT_STICK)).is_equal(
		GlifoDeEntrada.Forma.PALANCA
	)
	assert_int(GlifoDeEntrada.forma_de(DEL_JOYSTICK, JOY_BUTTON_DPAD_UP)).is_equal(
		GlifoDeEntrada.Forma.CRUCETA
	)
	assert_int(GlifoDeEntrada.forma_de(DEL_JOYSTICK, JOY_BUTTON_START)).is_equal(
		GlifoDeEntrada.Forma.PILDORA
	)


func test_las_teclas_son_teclas_y_cada_clic_es_una_tecla_con_su_nombre() -> void:  # AC-CFG-036
	var pantalla := _pantalla()
	assert_int(pantalla.glifo_de(AsignacionDeControles.EXAMINAR, PRINCIPAL).forma).is_equal(
		GlifoDeEntrada.Forma.TECLA
	)
	var izquierdo := pantalla.glifo_de(AsignacionDeControles.AGARRAR, PRINCIPAL)
	var derecho := pantalla.glifo_de(AsignacionDeControles.INTERACTUAR, PRINCIPAL)
	assert_int(izquierdo.forma).is_equal(GlifoDeEntrada.Forma.TECLA)
	assert_int(derecho.forma).is_equal(GlifoDeEntrada.Forma.TECLA)
	assert_str(izquierdo.texto).is_equal(
		PantallaDeControles.nombre_de_la_entrada(
			AsignacionDeControles.TipoDeEntrada.BOTON_DEL_MOUSE,
			AsignacionDeControles.BOTON_IZQUIERDO
		)
	)
	assert_str(derecho.texto).is_not_equal(izquierdo.texto)
	assert_str(derecho.texto).is_not_empty()


func test_un_boton_sin_glifo_propio_se_lee_por_su_nombre() -> void:  # AC-CFG-036
	var pantalla := _pantalla(true)
	pantalla.elegir(AsignacionDeControles.EXAMINAR, EN_EL_JOYSTICK)
	pantalla.atender(_boton(JOY_BUTTON_BACK))
	var glifo := pantalla.glifo_de(AsignacionDeControles.EXAMINAR, EN_EL_JOYSTICK)
	assert_int(glifo.forma).is_equal(GlifoDeEntrada.Forma.PILDORA)
	assert_str(glifo.texto).is_equal(
		PantallaDeControles.nombre_de_la_entrada(DEL_JOYSTICK, JOY_BUTTON_BACK)
	)


func test_las_secundarias_de_fabrica_se_muestran_vacias_salvo_las_flechas() -> void:  # AC-CFG-037
	var pantalla := _pantalla()
	for accion: StringName in AsignacionDeControles.ACCIONES:
		var forma := pantalla.glifo_de(accion, SECUNDARIA).forma
		if accion in AsignacionDeControles.DIRECCIONES:
			assert_int(forma).is_equal(GlifoDeEntrada.Forma.TECLA)
		else:
			assert_int(forma).is_equal(GlifoDeEntrada.Forma.RANURA_LIBRE)
			assert_str(pantalla.texto_de(accion, SECUNDARIA)).is_empty()


func test_una_secundaria_se_llena_con_una_tecla_y_la_principal_no_cambia() -> void:  # AC-CFG-038
	var pantalla := _pantalla()
	_asignar(pantalla, AsignacionDeControles.EXAMINAR, SECUNDARIA, KEY_F)
	assert_int(_avisos.size()).is_equal(1)
	assert_vector(_entrada(_avisos[0], AsignacionDeControles.EXAMINAR, SECUNDARIA)).is_equal(
		Vector2i(TECLA, KEY_F)
	)
	assert_vector(_entrada(_avisos[0], AsignacionDeControles.EXAMINAR, PRINCIPAL)).is_equal(
		Vector2i(TECLA, KEY_E)
	)
	assert_str(pantalla.texto_de(AsignacionDeControles.EXAMINAR, SECUNDARIA)).is_equal(
		PantallaDeControles.nombre_de_la_entrada(TECLA, KEY_F)
	)


func test_supr_vacia_una_secundaria_y_no_toca_una_principal() -> void:  # AC-CFG-039
	var pantalla := _pantalla()
	var examinar := AsignacionDeControles.EXAMINAR
	_asignar(pantalla, examinar, SECUNDARIA, KEY_F)
	pantalla.boton_de(examinar, SECUNDARIA).grab_focus()
	assert_bool(pantalla.atender(_tecla(KEY_DELETE))).is_true()
	assert_int(_avisos.size()).is_equal(2)
	assert_vector(_entrada(_avisos[1], examinar, SECUNDARIA)).is_equal(AsignacionDeControles.VACIA)
	assert_int(pantalla.glifo_de(examinar, SECUNDARIA).forma).is_equal(
		GlifoDeEntrada.Forma.RANURA_LIBRE
	)
	pantalla.atender(_tecla(KEY_DELETE))
	pantalla.boton_de(examinar, PRINCIPAL).grab_focus()
	pantalla.atender(_tecla(KEY_DELETE))
	assert_int(_avisos.size()).is_equal(2)
	assert_vector(_entrada(_avisos[1], examinar, PRINCIPAL)).is_equal(Vector2i(TECLA, KEY_E))


func test_una_secundaria_vacia_no_le_saca_la_principal_a_otra_y_lo_avisa() -> void:  # AC-CFG-040
	var pantalla := _pantalla()
	var celular := AsignacionDeControles.CELULAR
	pantalla.elegir(celular, SECUNDARIA)
	assert_bool(pantalla.atender(_tecla(KEY_E))).is_true()
	assert_array(_avisos).is_empty()
	assert_str(pantalla.aviso()).is_equal(
		(
			"%s %s"
			% [
				PantallaDeControles.TEXTO_DEL_AVISO,
				AsignacionDeControles.nombre_de_la_accion(AsignacionDeControles.EXAMINAR)
			]
		)
	)
	assert_int(pantalla.glifo_de(celular, SECUNDARIA).forma).is_equal(
		GlifoDeEntrada.Forma.RANURA_LIBRE
	)
	pantalla.elegir(celular, SECUNDARIA)
	assert_str(pantalla.aviso()).is_empty()
