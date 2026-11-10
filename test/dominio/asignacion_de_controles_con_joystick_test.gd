## Los botones del joystick dentro de la asignación de controles: el esquema de fábrica, qué
## acepta cada ranura, el intercambio entre botones y cómo se leen del archivo.
extends GdUnitTestSuite

const TECLA := AsignacionDeControles.TipoDeEntrada.TECLA
const BOTON := AsignacionDeControles.TipoDeEntrada.BOTON_DEL_MOUSE
const JOYSTICK := AsignacionDeControles.TipoDeEntrada.BOTON_DEL_JOYSTICK
const RANURA := AsignacionDeControles.RANURA_DEL_JOYSTICK


func _entrada(asignacion: AsignacionDeControles, accion: StringName, ranura: int) -> Vector2i:
	var entrada := asignacion.entrada(accion, ranura)
	return Vector2i(entrada["tipo"], entrada["codigo"])


func _de_fabrica(asignacion: AsignacionDeControles) -> bool:
	return asignacion.datos() == AsignacionDeControles.new().datos()


## Los datos de fábrica con el botón de esa acción cambiado a mano.
func _con_el_boton(accion: StringName, crudo: Variant) -> Dictionary:
	var datos := AsignacionDeControles.new().datos()
	var guardadas: Array = datos[String(accion)]
	guardadas[RANURA] = crudo
	return datos


func test_las_acciones_de_boton_tienen_el_boton_de_la_ficha() -> void:  # AC-CFG-025
	var asignacion := AsignacionDeControles.new()
	var esperados: Dictionary[StringName, int] = {
		AsignacionDeControles.AGARRAR: JOY_BUTTON_A,
		AsignacionDeControles.INTERACTUAR: JOY_BUTTON_RIGHT_SHOULDER,
		AsignacionDeControles.AGACHARSE: JOY_BUTTON_LEFT_SHOULDER,
		AsignacionDeControles.CELULAR: JOY_BUTTON_B,
		AsignacionDeControles.EXAMINAR: JOY_BUTTON_X,
	}
	# Correr es la sexta: tiene el gatillo derecho y no un botón.
	assert_int(esperados.size() + 1).is_equal(AsignacionDeControles.ACCIONES_CON_BOTON.size())
	for accion: StringName in esperados:
		assert_vector(_entrada(asignacion, accion, RANURA)).is_equal(
			Vector2i(JOYSTICK, esperados[accion])
		)


func test_movimiento_y_pausa_no_tienen_boton_de_joystick() -> void:  # AC-CFG-025
	var asignacion := AsignacionDeControles.new()
	var sin_boton: Array[StringName] = AsignacionDeControles.DIRECCIONES.duplicate()
	sin_boton.append(AsignacionDeControles.PAUSA)
	for accion: StringName in sin_boton:
		for ranura: int in AsignacionDeControles.ranuras_de(accion):
			assert_bool(AsignacionDeControles.es_del_joystick(accion, ranura)).is_false()
			assert_int(_entrada(asignacion, accion, ranura).x).is_not_equal(JOYSTICK)
		assert_bool(asignacion.asignar(accion, 0, JOYSTICK, JOY_BUTTON_Y)).is_false()
	assert_bool(_de_fabrica(asignacion)).is_true()


func test_un_boton_se_asigna_a_la_ranura_del_joystick() -> void:  # AC-CFG-026
	var asignacion := AsignacionDeControles.new()
	var examinar := AsignacionDeControles.EXAMINAR
	assert_bool(asignacion.asignar(examinar, RANURA, JOYSTICK, JOY_BUTTON_Y)).is_true()
	assert_vector(_entrada(asignacion, examinar, RANURA)).is_equal(Vector2i(JOYSTICK, JOY_BUTTON_Y))
	assert_vector(_entrada(asignacion, examinar, 0)).is_equal(Vector2i(TECLA, KEY_E))


func test_un_boton_que_ya_tiene_otra_accion_las_intercambia() -> void:  # AC-CFG-026
	var asignacion := AsignacionDeControles.new()
	asignacion.asignar(AsignacionDeControles.EXAMINAR, RANURA, JOYSTICK, JOY_BUTTON_LEFT_SHOULDER)
	assert_vector(_entrada(asignacion, AsignacionDeControles.EXAMINAR, RANURA)).is_equal(
		Vector2i(JOYSTICK, JOY_BUTTON_LEFT_SHOULDER)
	)
	assert_vector(_entrada(asignacion, AsignacionDeControles.AGACHARSE, RANURA)).is_equal(
		Vector2i(JOYSTICK, JOY_BUTTON_X)
	)
	assert_vector(_entrada(asignacion, AsignacionDeControles.AGACHARSE, 0)).is_equal(
		Vector2i(TECLA, KEY_CTRL)
	)


func test_el_mismo_boton_no_cambia_nada() -> void:  # AC-CFG-026
	var asignacion := AsignacionDeControles.new()
	var cambio := asignacion.asignar(AsignacionDeControles.AGARRAR, RANURA, JOYSTICK, JOY_BUTTON_A)
	assert_bool(cambio).is_false()
	assert_bool(_de_fabrica(asignacion)).is_true()


func test_cada_clase_de_entrada_va_a_su_ranura() -> void:  # AC-CFG-026
	var asignacion := AsignacionDeControles.new()
	var examinar := AsignacionDeControles.EXAMINAR
	assert_bool(asignacion.asignar(examinar, RANURA, TECLA, KEY_F)).is_false()
	assert_bool(asignacion.asignar(examinar, RANURA, BOTON, MOUSE_BUTTON_MIDDLE)).is_false()
	assert_bool(asignacion.asignar(examinar, 0, JOYSTICK, JOY_BUTTON_Y)).is_false()
	assert_bool(_de_fabrica(asignacion)).is_true()


func test_start_y_lo_que_no_es_un_boton_no_se_aceptan() -> void:  # AC-CFG-026
	var asignacion := AsignacionDeControles.new()
	var examinar := AsignacionDeControles.EXAMINAR
	var no_aceptados: Array[int] = [
		AsignacionDeControles.BOTON_DE_PAUSA, JOY_BUTTON_INVALID, JOY_BUTTON_SDL_MAX, JOY_BUTTON_MAX
	]
	for codigo: int in no_aceptados:
		var acepta := AsignacionDeControles.acepta(examinar, JOYSTICK, codigo, false, RANURA)
		assert_bool(acepta).is_false()
		assert_bool(asignacion.asignar(examinar, RANURA, JOYSTICK, codigo)).is_false()
	assert_bool(_de_fabrica(asignacion)).is_true()


func test_start_cancela_la_espera_igual_que_la_tecla_de_pausa() -> void:  # AC-CFG-026
	var asignacion := AsignacionDeControles.new()
	assert_bool(asignacion.cancela_la_espera(JOYSTICK, JOY_BUTTON_START)).is_true()
	assert_bool(asignacion.cancela_la_espera(TECLA, KEY_ESCAPE)).is_true()
	assert_bool(asignacion.cancela_la_espera(JOYSTICK, JOY_BUTTON_A)).is_false()


func test_los_botones_se_guardan_como_numeros_y_vuelven_iguales() -> void:  # AC-CFG-030
	var asignacion := AsignacionDeControles.new()
	asignacion.asignar(AsignacionDeControles.EXAMINAR, RANURA, JOYSTICK, JOY_BUTTON_LEFT_SHOULDER)
	var datos := asignacion.datos()
	var guardadas: Array = datos[String(AsignacionDeControles.EXAMINAR)]
	var boton: Dictionary = guardadas[RANURA]
	assert_int(typeof(boton["tipo"])).is_equal(TYPE_INT)
	assert_int(typeof(boton["codigo"])).is_equal(TYPE_INT)
	assert_array(AsignacionDeControles.desde(datos).entradas()).is_equal(asignacion.entradas())


func test_un_archivo_sin_botones_de_joystick_da_los_de_fabrica() -> void:  # AC-CFG-030
	var datos := AsignacionDeControles.new().datos()
	for accion: StringName in AsignacionDeControles.ACCIONES_CON_BOTON:
		var guardadas: Array = datos[String(accion)]
		guardadas.resize(1)
	assert_bool(_de_fabrica(AsignacionDeControles.desde(datos))).is_true()


func test_un_boton_ilegible_vuelve_al_de_fabrica_y_los_demas_se_conservan() -> void:  # AC-CFG-030
	var ilegibles: Array[Variant] = [
		{"tipo": "joystick", "codigo": JOY_BUTTON_Y},
		{"tipo": JOYSTICK, "codigo": "Y"},
		{"tipo": JOYSTICK, "codigo": AsignacionDeControles.BOTON_DE_PAUSA},
		{"tipo": TECLA, "codigo": KEY_F},
		"Y",
	]
	for ilegible: Variant in ilegibles:
		var datos := _con_el_boton(AsignacionDeControles.EXAMINAR, ilegible)
		var agacharse: Array = datos[String(AsignacionDeControles.AGACHARSE)]
		agacharse[RANURA] = {"tipo": JOYSTICK, "codigo": JOY_BUTTON_Y}
		var leida := AsignacionDeControles.desde(datos)
		assert_vector(_entrada(leida, AsignacionDeControles.EXAMINAR, RANURA)).is_equal(
			Vector2i(JOYSTICK, JOY_BUTTON_X)
		)
		assert_vector(_entrada(leida, AsignacionDeControles.AGACHARSE, RANURA)).is_equal(
			Vector2i(JOYSTICK, JOY_BUTTON_Y)
		)


func test_dos_acciones_con_el_mismo_boton_descartan_el_bloque_completo() -> void:  # AC-CFG-030
	var datos := _con_el_boton(
		AsignacionDeControles.EXAMINAR, {"tipo": JOYSTICK, "codigo": JOY_BUTTON_LEFT_SHOULDER}
	)
	var agarrar: Array = datos[String(AsignacionDeControles.AGARRAR)]
	agarrar[0] = {"tipo": TECLA, "codigo": KEY_F}
	assert_bool(_de_fabrica(AsignacionDeControles.desde(datos))).is_true()


func test_un_boton_guardado_para_movimiento_o_pausa_se_ignora() -> void:  # AC-CFG-030
	var datos := AsignacionDeControles.new().datos()
	var boton := {"tipo": JOYSTICK, "codigo": JOY_BUTTON_Y}
	var pausa: Array = datos[String(AsignacionDeControles.PAUSA)]
	pausa[AsignacionDeControles.RANURA_SECUNDARIA] = boton
	var adelante: Array = datos[String(AsignacionDeControles.ADELANTE)]
	adelante[AsignacionDeControles.RANURA_SECUNDARIA] = boton
	assert_bool(_de_fabrica(AsignacionDeControles.desde(datos))).is_true()
