## La tecla secundaria: cada acción de teclado tiene una principal que nunca queda vacía y una
## secundaria que puede estarlo.
extends GdUnitTestSuite

const TECLA := AsignacionDeControles.TipoDeEntrada.TECLA
const BOTON := AsignacionDeControles.TipoDeEntrada.BOTON_DEL_MOUSE
const DEL_JOYSTICK := AsignacionDeControles.TipoDeEntrada.BOTON_DEL_JOYSTICK
const PRINCIPAL := AsignacionDeControles.RANURA_PRINCIPAL
const SECUNDARIA := AsignacionDeControles.RANURA_SECUNDARIA
const VACIA := AsignacionDeControles.VACIA
## Las seis acciones que nacen con la secundaria vacía.
const SIN_SECUNDARIA: Array[StringName] = [
	AsignacionDeControles.CELULAR,
	AsignacionDeControles.EXAMINAR,
	AsignacionDeControles.AGACHARSE,
	AsignacionDeControles.AGARRAR,
	AsignacionDeControles.INTERACTUAR,
	AsignacionDeControles.PAUSA,
]


func _tecla(codigo: int) -> Vector2i:
	return Vector2i(TECLA, codigo)


func _entrada(asignacion: AsignacionDeControles, accion: StringName, ranura: int) -> Vector2i:
	var entrada := asignacion.entrada(accion, ranura)
	return Vector2i(entrada["tipo"], entrada["codigo"])


func _asignar(
	asignacion: AsignacionDeControles, accion: StringName, ranura: int, codigo: int
) -> bool:
	return asignacion.asignar(accion, ranura, TECLA, codigo)


func _sin_repetidas(asignacion: AsignacionDeControles) -> bool:
	var vistas: Array[Vector2i] = []
	for guardada: Dictionary in asignacion.entradas():
		var entrada := Vector2i(guardada["tipo"], guardada["codigo"])
		if entrada == VACIA:
			continue
		if entrada in vistas:
			return false
		vistas.append(entrada)
	return true


func test_las_secundarias_de_movimiento_son_las_flechas_de_su_direccion() -> void:  # AC-CFG-037
	var asignacion := AsignacionDeControles.new()
	var flechas: Dictionary[StringName, int] = {
		AsignacionDeControles.ADELANTE: KEY_UP,
		AsignacionDeControles.ATRAS: KEY_DOWN,
		AsignacionDeControles.IZQUIERDA: KEY_LEFT,
		AsignacionDeControles.DERECHA: KEY_RIGHT,
	}
	for direccion: StringName in flechas:
		assert_vector(_entrada(asignacion, direccion, SECUNDARIA)).is_equal(
			_tecla(flechas[direccion])
		)


func test_las_otras_seis_acciones_nacen_con_la_secundaria_vacia() -> void:  # AC-CFG-037
	var asignacion := AsignacionDeControles.new()
	for accion: StringName in SIN_SECUNDARIA:
		assert_vector(_entrada(asignacion, accion, SECUNDARIA)).is_equal(VACIA)
		assert_vector(_entrada(asignacion, accion, PRINCIPAL)).is_not_equal(VACIA)


func test_una_secundaria_acepta_una_tecla_y_un_clic_y_no_un_boton_del_joystick() -> void:  # AC-CFG-038
	var asignacion := AsignacionDeControles.new()
	var examinar := AsignacionDeControles.EXAMINAR
	assert_bool(_asignar(asignacion, examinar, SECUNDARIA, KEY_F)).is_true()
	assert_vector(_entrada(asignacion, examinar, SECUNDARIA)).is_equal(_tecla(KEY_F))
	assert_vector(_entrada(asignacion, examinar, PRINCIPAL)).is_equal(_tecla(KEY_E))
	(
		assert_bool(
			asignacion.asignar(examinar, SECUNDARIA, BOTON, AsignacionDeControles.BOTON_CENTRAL)
		)
		. is_true()
	)
	assert_vector(_entrada(asignacion, examinar, SECUNDARIA)).is_equal(
		Vector2i(BOTON, AsignacionDeControles.BOTON_CENTRAL)
	)
	var antes := asignacion.datos()
	assert_bool(asignacion.asignar(examinar, SECUNDARIA, DEL_JOYSTICK, JOY_BUTTON_Y)).is_false()
	assert_dict(asignacion.datos()).is_equal(antes)


func test_en_la_web_esc_solo_entra_a_la_secundaria_de_pausa() -> void:  # AC-CFG-038
	var asignacion := AsignacionDeControles.new()
	(
		assert_bool(
			asignacion.asignar(AsignacionDeControles.EXAMINAR, SECUNDARIA, TECLA, KEY_ESCAPE, true)
		)
		. is_false()
	)
	assert_vector(_entrada(asignacion, AsignacionDeControles.EXAMINAR, SECUNDARIA)).is_equal(VACIA)
	var pausa := AsignacionDeControles.new()
	assert_bool(_asignar(pausa, AsignacionDeControles.PAUSA, PRINCIPAL, KEY_P)).is_true()
	(
		assert_bool(pausa.asignar(AsignacionDeControles.PAUSA, SECUNDARIA, TECLA, KEY_ESCAPE, true))
		. is_true()
	)
	assert_vector(_entrada(pausa, AsignacionDeControles.PAUSA, SECUNDARIA)).is_equal(
		_tecla(KEY_ESCAPE)
	)


func test_la_secundaria_de_pausa_tambien_cancela_la_espera() -> void:  # AC-CFG-038
	var asignacion := AsignacionDeControles.new()
	assert_bool(_asignar(asignacion, AsignacionDeControles.PAUSA, SECUNDARIA, KEY_P)).is_true()
	assert_bool(asignacion.cancela_la_espera(TECLA, KEY_P)).is_true()
	assert_bool(asignacion.cancela_la_espera(TECLA, KEY_ESCAPE)).is_true()
	assert_bool(asignacion.cancela_la_espera(TECLA, KEY_F)).is_false()
	assert_bool(AsignacionDeControles.new().cancela_la_espera(VACIA.x, VACIA.y)).is_false()


func test_vaciar_una_secundaria_la_deja_vacia_y_conserva_la_principal() -> void:  # AC-CFG-039
	var asignacion := AsignacionDeControles.new()
	var examinar := AsignacionDeControles.EXAMINAR
	_asignar(asignacion, examinar, SECUNDARIA, KEY_F)
	assert_bool(asignacion.vaciar(examinar, SECUNDARIA)).is_true()
	assert_vector(_entrada(asignacion, examinar, SECUNDARIA)).is_equal(VACIA)
	assert_vector(_entrada(asignacion, examinar, PRINCIPAL)).is_equal(_tecla(KEY_E))
	assert_bool(asignacion.vaciar(AsignacionDeControles.ADELANTE, SECUNDARIA)).is_true()
	assert_vector(_entrada(asignacion, AsignacionDeControles.ADELANTE, SECUNDARIA)).is_equal(VACIA)


func test_vaciar_una_principal_el_joystick_o_una_vacia_no_cambia_nada() -> void:  # AC-CFG-039
	var asignacion := AsignacionDeControles.new()
	var antes := asignacion.datos()
	var examinar := AsignacionDeControles.EXAMINAR
	assert_bool(asignacion.vaciar(examinar, PRINCIPAL)).is_false()
	assert_bool(asignacion.vaciar(AsignacionDeControles.ADELANTE, PRINCIPAL)).is_false()
	assert_bool(asignacion.vaciar(examinar, AsignacionDeControles.RANURA_DEL_JOYSTICK)).is_false()
	assert_bool(asignacion.vaciar(examinar, SECUNDARIA)).is_false()
	assert_bool(asignacion.vaciar(&"accion_que_no_existe", SECUNDARIA)).is_false()
	assert_dict(asignacion.datos()).is_equal(antes)


func test_la_principal_y_la_secundaria_de_una_accion_se_intercambian() -> void:  # AC-CFG-040
	var asignacion := AsignacionDeControles.new()
	var adelante := AsignacionDeControles.ADELANTE
	assert_bool(_asignar(asignacion, adelante, SECUNDARIA, KEY_W)).is_true()
	assert_vector(_entrada(asignacion, adelante, SECUNDARIA)).is_equal(_tecla(KEY_W))
	assert_vector(_entrada(asignacion, adelante, PRINCIPAL)).is_equal(_tecla(KEY_UP))
	assert_bool(_sin_repetidas(asignacion)).is_true()


func test_una_principal_recibe_la_entrada_de_la_secundaria_de_otra_accion() -> void:  # AC-CFG-040
	var asignacion := AsignacionDeControles.new()
	var examinar := AsignacionDeControles.EXAMINAR
	var agacharse := AsignacionDeControles.AGACHARSE
	_asignar(asignacion, agacharse, SECUNDARIA, KEY_F)
	assert_bool(_asignar(asignacion, examinar, PRINCIPAL, KEY_F)).is_true()
	assert_vector(_entrada(asignacion, examinar, PRINCIPAL)).is_equal(_tecla(KEY_F))
	assert_vector(_entrada(asignacion, agacharse, SECUNDARIA)).is_equal(_tecla(KEY_E))
	assert_bool(_asignar(asignacion, examinar, PRINCIPAL, KEY_UP)).is_true()
	assert_vector(_entrada(asignacion, AsignacionDeControles.ADELANTE, SECUNDARIA)).is_equal(
		_tecla(KEY_F)
	)
	assert_bool(_sin_repetidas(asignacion)).is_true()


func test_una_secundaria_vacia_toma_la_entrada_de_otra_secundaria_y_la_deja_vacia() -> void:  # AC-CFG-040
	var asignacion := AsignacionDeControles.new()
	var examinar := AsignacionDeControles.EXAMINAR
	var agacharse := AsignacionDeControles.AGACHARSE
	_asignar(asignacion, agacharse, SECUNDARIA, KEY_F)
	assert_bool(_asignar(asignacion, examinar, SECUNDARIA, KEY_F)).is_true()
	assert_vector(_entrada(asignacion, examinar, SECUNDARIA)).is_equal(_tecla(KEY_F))
	assert_vector(_entrada(asignacion, agacharse, SECUNDARIA)).is_equal(VACIA)
	assert_bool(_sin_repetidas(asignacion)).is_true()


func test_una_secundaria_vacia_no_le_saca_la_principal_a_otra_accion() -> void:  # AC-CFG-040
	var asignacion := AsignacionDeControles.new()
	var antes := asignacion.datos()
	assert_bool(_asignar(asignacion, AsignacionDeControles.EXAMINAR, SECUNDARIA, KEY_Q)).is_false()
	assert_bool(_asignar(asignacion, AsignacionDeControles.AGACHARSE, SECUNDARIA, KEY_W)).is_false()
	(
		assert_bool(
			asignacion.asignar(
				AsignacionDeControles.EXAMINAR,
				SECUNDARIA,
				BOTON,
				AsignacionDeControles.BOTON_IZQUIERDO
			)
		)
		. is_false()
	)
	assert_dict(asignacion.datos()).is_equal(antes)


func test_principal_que_ocupa_nombra_la_accion_que_tiene_la_entrada_como_principal() -> void:  # AC-CFG-040
	var asignacion := AsignacionDeControles.new()
	assert_str(asignacion.principal_que_ocupa(_tecla(KEY_Q))).is_equal(
		AsignacionDeControles.CELULAR
	)
	assert_str(asignacion.principal_que_ocupa(_tecla(KEY_W))).is_equal(
		AsignacionDeControles.ADELANTE
	)
	assert_str(asignacion.principal_que_ocupa(_tecla(KEY_UP))).is_equal("")
	assert_str(asignacion.principal_que_ocupa(_tecla(KEY_F))).is_equal("")
	assert_str(asignacion.principal_que_ocupa(VACIA)).is_equal("")


func test_las_secundarias_se_guardan_y_una_vaciada_sigue_vacia() -> void:  # AC-CFG-041
	var asignacion := AsignacionDeControles.new()
	_asignar(asignacion, AsignacionDeControles.EXAMINAR, SECUNDARIA, KEY_F)
	asignacion.vaciar(AsignacionDeControles.ADELANTE, SECUNDARIA)
	var leida := AsignacionDeControles.desde(asignacion.datos())
	assert_array(leida.entradas()).is_equal(asignacion.entradas())
	assert_vector(_entrada(leida, AsignacionDeControles.EXAMINAR, SECUNDARIA)).is_equal(
		_tecla(KEY_F)
	)
	assert_vector(_entrada(leida, AsignacionDeControles.ADELANTE, SECUNDARIA)).is_equal(VACIA)


func test_un_archivo_de_antes_de_las_secundarias_conserva_cada_asignacion() -> void:  # AC-CFG-041
	var examinar := AsignacionDeControles.EXAMINAR
	var agacharse := AsignacionDeControles.AGACHARSE
	var viejo := {
		String(examinar):
		[{"tipo": TECLA, "codigo": KEY_F}, {"tipo": DEL_JOYSTICK, "codigo": JOY_BUTTON_Y}],
		String(agacharse):
		[
			{"tipo": TECLA, "codigo": KEY_G},
			{"tipo": DEL_JOYSTICK, "codigo": JOY_BUTTON_LEFT_SHOULDER}
		],
		String(AsignacionDeControles.ADELANTE):
		[{"tipo": TECLA, "codigo": KEY_H}, {"tipo": TECLA, "codigo": KEY_UP}],
		String(AsignacionDeControles.PAUSA): [{"tipo": TECLA, "codigo": KEY_P}],
	}
	var leida := AsignacionDeControles.desde(viejo)
	var joystick := AsignacionDeControles.RANURA_DEL_JOYSTICK
	assert_vector(_entrada(leida, examinar, PRINCIPAL)).is_equal(_tecla(KEY_F))
	assert_vector(_entrada(leida, examinar, SECUNDARIA)).is_equal(VACIA)
	assert_vector(_entrada(leida, examinar, joystick)).is_equal(
		Vector2i(DEL_JOYSTICK, JOY_BUTTON_Y)
	)
	assert_vector(_entrada(leida, agacharse, PRINCIPAL)).is_equal(_tecla(KEY_G))
	assert_vector(_entrada(leida, agacharse, joystick)).is_equal(
		Vector2i(DEL_JOYSTICK, JOY_BUTTON_LEFT_SHOULDER)
	)
	assert_vector(_entrada(leida, AsignacionDeControles.ADELANTE, PRINCIPAL)).is_equal(
		_tecla(KEY_H)
	)
	assert_vector(_entrada(leida, AsignacionDeControles.ADELANTE, SECUNDARIA)).is_equal(
		_tecla(KEY_UP)
	)
	assert_vector(_entrada(leida, AsignacionDeControles.PAUSA, PRINCIPAL)).is_equal(_tecla(KEY_P))
	assert_vector(_entrada(leida, AsignacionDeControles.PAUSA, SECUNDARIA)).is_equal(VACIA)
	assert_vector(_entrada(leida, AsignacionDeControles.AGARRAR, joystick)).is_equal(
		Vector2i(DEL_JOYSTICK, JOY_BUTTON_A)
	)


func test_una_secundaria_ilegible_o_una_principal_vacia_vuelven_a_la_entrada_de_fabrica() -> void:  # AC-CFG-041
	var datos := AsignacionDeControles.new().datos()
	var examinar: Array = datos[String(AsignacionDeControles.EXAMINAR)]
	examinar[PRINCIPAL] = {"tipo": VACIA.x, "codigo": VACIA.y}
	examinar[SECUNDARIA] = {"tipo": "no es un numero", "codigo": KEY_F}
	var adelante: Array = datos[String(AsignacionDeControles.ADELANTE)]
	adelante[SECUNDARIA] = {"tipo": DEL_JOYSTICK, "codigo": JOY_BUTTON_Y}
	var leida := AsignacionDeControles.desde(datos)
	assert_array(leida.entradas()).is_equal(AsignacionDeControles.new().entradas())


func test_una_secundaria_y_una_principal_en_la_misma_tecla_descartan_el_bloque() -> void:  # AC-CFG-041
	var datos := AsignacionDeControles.new().datos()
	var examinar: Array = datos[String(AsignacionDeControles.EXAMINAR)]
	examinar[SECUNDARIA] = {"tipo": TECLA, "codigo": KEY_SPACE}
	assert_array(AsignacionDeControles.desde(datos).entradas()).is_equal(
		AsignacionDeControles.new().entradas()
	)


func test_dos_secundarias_vacias_no_son_una_entrada_repetida() -> void:  # AC-CFG-041
	var asignacion := AsignacionDeControles.new()
	_asignar(asignacion, AsignacionDeControles.EXAMINAR, PRINCIPAL, KEY_F)
	var datos := asignacion.datos()
	(
		assert_vector(
			_entrada(AsignacionDeControles.desde(datos), AsignacionDeControles.EXAMINAR, PRINCIPAL)
		)
		. is_equal(_tecla(KEY_F))
	)
