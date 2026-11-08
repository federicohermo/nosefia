## Las pestañas de la pantalla de controles, sus glifos y la tecla secundaria: se ve una sola
## pestaña, se abre en la del último dispositivo, L1 y R1 las cambian, lo fijo no se elige, y una
## secundaria se llena con una tecla y se vacía con SUPR.
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


func _nombres(filas: Array[HBoxContainer], fijas: bool) -> Array[String]:
	var nombres: Array[String] = []
	for fila: HBoxContainer in filas:
		if fila.has_meta(&"fijo") == fijas:
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


func test_las_pestanas_se_eligen_con_el_mouse_o_por_foco() -> void:  # AC-CFG-031, AC-CFG-033
	var pantalla := _pantalla()
	var del_joystick: Button = pantalla.get("_pestana_del_joystick")
	var del_teclado: Button = pantalla.get("_pestana_del_teclado")
	assert_bool(del_joystick.focus_mode != Control.FOCUS_NONE).is_true()
	del_joystick.pressed.emit()
	assert_bool(pantalla.pestana_del_joystick()).is_true()
	del_teclado.pressed.emit()
	assert_bool(pantalla.pestana_del_joystick()).is_false()


func test_cada_pestana_tiene_lo_del_local_y_lo_de_los_menus() -> void:  # AC-CFG-031
	var pantalla := _pantalla()
	for del_joystick: bool in [false, true]:
		var nombres := _nombres(pantalla.filas(del_joystick), true)
		for en_los_menus: String in [
			PantallaDeControles.TEXTO_DE_NAVEGAR,
			PantallaDeControles.TEXTO_DE_ACEPTAR,
			PantallaDeControles.TEXTO_DE_VOLVER,
		]:
			assert_array(nombres).contains([en_los_menus])


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


func test_el_aviso_del_joystick_se_actualiza_sin_cambiar_de_pestana() -> void:  # AC-CFG-034
	var pantalla := _pantalla()
	pantalla.poner_joystick_conectado(true)
	assert_str(pantalla.aviso_del_joystick()).is_equal(
		PantallaDeControles.TEXTO_DEL_JOYSTICK_CONECTADO
	)
	assert_bool(pantalla.pestana_del_joystick()).is_false()
	pantalla.elegir_pestana(true)
	pantalla.poner_joystick_conectado(false)
	assert_str(pantalla.aviso_del_joystick()).is_empty()
	assert_bool(pantalla.pestana_del_joystick()).is_true()


func test_lo_fijo_lleva_su_marca_y_no_tiene_nada_que_elegir() -> void:  # AC-CFG-035
	var pantalla := _pantalla()
	var del_teclado := _nombres(pantalla.filas(false), true)
	(
		assert_array(del_teclado)
		. contains_exactly_in_any_order(
			[
				PantallaDeControles.TEXTO_DE_VISION,
				PantallaDeControles.TEXTO_DE_NAVEGAR,
				PantallaDeControles.TEXTO_DE_ACEPTAR,
				PantallaDeControles.TEXTO_DE_VOLVER,
			]
		)
	)
	var pausa := AsignacionDeControles.nombre_de_la_accion(AsignacionDeControles.PAUSA)
	var del_joystick := _nombres(pantalla.filas(true), true)
	(
		assert_array(del_joystick)
		. contains_exactly_in_any_order(
			[
				PantallaDeControles.TEXTO_DE_MOVIMIENTO,
				PantallaDeControles.TEXTO_DE_VISION,
				pausa,
				PantallaDeControles.TEXTO_DE_NAVEGAR,
				PantallaDeControles.TEXTO_DE_ACEPTAR,
				PantallaDeControles.TEXTO_DE_VOLVER,
			]
		)
	)
	for del_dispositivo: bool in [false, true]:
		for fila: HBoxContainer in pantalla.filas(del_dispositivo):
			if fila.has_meta(&"fijo"):
				assert_array(fila.find_children("*", "Button", true, false)).is_empty()
				assert_bool(fila.modulate.a < 1.0).is_true()
	assert_int(_nombres(pantalla.filas(true), false).size()).is_equal(
		AsignacionDeControles.ACCIONES_CON_BOTON.size()
	)


func test_volver_y_la_ayuda_muestran_la_entrada_que_tiene_pausa() -> void:  # AC-CFG-035
	var pantalla := _pantalla()
	_asignar(pantalla, AsignacionDeControles.PAUSA, PRINCIPAL, KEY_P)
	var leida := PantallaDeControles.nombre_de_la_entrada(TECLA, KEY_P)
	var volver: HBoxContainer
	for fila: HBoxContainer in pantalla.filas(false):
		if (fila.get_child(0) as Label).text == PantallaDeControles.TEXTO_DE_VOLVER:
			volver = fila
	var glifo: GlifoDeEntrada = volver.get_child(1).get_child(0)
	assert_str(glifo.texto).is_equal(leida)
	var ayuda: Array[String] = []
	for en_la_ayuda: GlifoDeEntrada in pantalla.glifos_de_la_ayuda():
		ayuda.append(en_la_ayuda.texto)
	assert_array(ayuda).is_equal(
		[PantallaDeControles.TEXTO_DE_ENTER, PantallaDeControles.TEXTO_DE_SUPR, leida]
	)


func test_la_ayuda_del_joystick_lleva_las_pildoras_la_cruz_y_el_circulo() -> void:  # AC-CFG-035
	var pantalla := _pantalla(true)
	var formas: Array[GlifoDeEntrada.Forma] = []
	for glifo: GlifoDeEntrada in pantalla.glifos_de_la_ayuda():
		formas.append(glifo.forma)
	assert_array(formas).is_equal(
		[
			GlifoDeEntrada.Forma.PILDORA,
			GlifoDeEntrada.Forma.PILDORA,
			GlifoDeEntrada.Forma.CRUZ,
			GlifoDeEntrada.Forma.CIRCULO
		]
	)


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


func test_las_teclas_son_teclas_y_cada_clic_es_un_mouse_distinto() -> void:  # AC-CFG-036
	var pantalla := _pantalla()
	assert_int(pantalla.glifo_de(AsignacionDeControles.EXAMINAR, PRINCIPAL).forma).is_equal(
		GlifoDeEntrada.Forma.TECLA
	)
	var izquierdo := pantalla.glifo_de(AsignacionDeControles.AGARRAR, PRINCIPAL)
	var derecho := pantalla.glifo_de(AsignacionDeControles.INTERACTUAR, PRINCIPAL)
	assert_int(izquierdo.forma).is_equal(GlifoDeEntrada.Forma.MOUSE)
	assert_int(derecho.forma).is_equal(GlifoDeEntrada.Forma.MOUSE)
	assert_int(izquierdo.boton_del_mouse).is_not_equal(derecho.boton_del_mouse)


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
		var texto := pantalla.texto_de(accion, SECUNDARIA)
		if accion in AsignacionDeControles.DIRECCIONES:
			assert_str(texto).is_not_equal(PantallaDeControles.TEXTO_DE_LA_RANURA_VACIA)
		else:
			assert_str(texto).is_equal(PantallaDeControles.TEXTO_DE_LA_RANURA_VACIA)
			assert_object(pantalla.glifo_de(accion, SECUNDARIA)).is_null()


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
	assert_str(pantalla.texto_de(examinar, SECUNDARIA)).is_equal(
		PantallaDeControles.TEXTO_DE_LA_RANURA_VACIA
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
	assert_str(pantalla.texto_de(celular, SECUNDARIA)).is_equal(
		PantallaDeControles.TEXTO_DE_LA_RANURA_VACIA
	)
	pantalla.elegir(celular, SECUNDARIA)
	assert_str(pantalla.aviso()).is_empty()
