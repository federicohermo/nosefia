## Un archivo guardado antes de que existiera Correr: Agacharse estaba de fábrica en Espacio y
## ahora lo está en Ctrl. Migra lo que era el esquema de fábrica y respeta lo que el jugador eligió.
extends GdUnitTestSuite

const TECLA := AsignacionDeControles.TipoDeEntrada.TECLA
const DEL_JOYSTICK := AsignacionDeControles.TipoDeEntrada.BOTON_DEL_JOYSTICK
const PRINCIPAL := AsignacionDeControles.RANURA_PRINCIPAL
const SECUNDARIA := AsignacionDeControles.RANURA_SECUNDARIA
const DEL_JOYSTICK_RANURA := AsignacionDeControles.RANURA_DEL_JOYSTICK
const VACIA := AsignacionDeControles.VACIA


func _entrada(asignacion: AsignacionDeControles, accion: StringName, ranura: int) -> Vector2i:
	var entrada := asignacion.entrada(accion, ranura)
	return Vector2i(entrada["tipo"], entrada["codigo"])


func _tecla(codigo: int) -> Vector2i:
	return Vector2i(TECLA, codigo)


## Los datos de fábrica sin la acción de correr, como los escribía el juego antes de ella.
func _de_antes_de_correr() -> Dictionary:
	var datos := AsignacionDeControles.new().datos()
	datos.erase(String(AsignacionDeControles.CORRER))
	datos[String(AsignacionDeControles.AGACHARSE)][PRINCIPAL] = {"tipo": TECLA, "codigo": KEY_SPACE}
	return datos


func _poner(datos: Dictionary, accion: StringName, ranura: int, entrada: Vector2i) -> void:
	datos[String(accion)][ranura] = {"tipo": entrada.x, "codigo": entrada.y}


func test_el_espacio_de_antes_pasa_a_ctrl_y_correr_llega_de_fabrica() -> void:  # AC-CFG-046
	var leida := AsignacionDeControles.desde(_de_antes_de_correr())
	var agacharse := AsignacionDeControles.AGACHARSE
	var correr := AsignacionDeControles.CORRER
	assert_vector(_entrada(leida, agacharse, PRINCIPAL)).is_equal(_tecla(KEY_CTRL))
	assert_vector(_entrada(leida, correr, PRINCIPAL)).is_equal(_tecla(KEY_SHIFT))
	assert_vector(_entrada(leida, correr, DEL_JOYSTICK_RANURA)).is_equal(
		Vector2i(DEL_JOYSTICK, JOY_BUTTON_LEFT_STICK)
	)
	assert_vector(_entrada(leida, AsignacionDeControles.EXAMINAR, PRINCIPAL)).is_equal(
		_tecla(KEY_E)
	)


func test_una_principal_reasignada_se_conserva() -> void:  # AC-CFG-046
	var datos := _de_antes_de_correr()
	_poner(datos, AsignacionDeControles.AGACHARSE, PRINCIPAL, _tecla(KEY_F))
	var leida := AsignacionDeControles.desde(datos)
	assert_vector(_entrada(leida, AsignacionDeControles.AGACHARSE, PRINCIPAL)).is_equal(
		_tecla(KEY_F)
	)
	assert_vector(_entrada(leida, AsignacionDeControles.CORRER, PRINCIPAL)).is_equal(
		_tecla(KEY_SHIFT)
	)


func test_migrar_la_principal_conserva_la_secundaria_y_el_joystick() -> void:  # AC-CFG-046
	var datos := _de_antes_de_correr()
	var agacharse := AsignacionDeControles.AGACHARSE
	_poner(datos, agacharse, SECUNDARIA, _tecla(KEY_G))
	_poner(datos, agacharse, DEL_JOYSTICK_RANURA, Vector2i(DEL_JOYSTICK, JOY_BUTTON_Y))
	var leida := AsignacionDeControles.desde(datos)
	assert_vector(_entrada(leida, agacharse, PRINCIPAL)).is_equal(_tecla(KEY_CTRL))
	assert_vector(_entrada(leida, agacharse, SECUNDARIA)).is_equal(_tecla(KEY_G))
	assert_vector(_entrada(leida, agacharse, DEL_JOYSTICK_RANURA)).is_equal(
		Vector2i(DEL_JOYSTICK, JOY_BUTTON_Y)
	)


func test_si_otra_ranura_ya_tiene_ctrl_agacharse_conserva_espacio() -> void:  # AC-CFG-046
	var datos := _de_antes_de_correr()
	_poner(datos, AsignacionDeControles.EXAMINAR, PRINCIPAL, _tecla(KEY_CTRL))
	var leida := AsignacionDeControles.desde(datos)
	assert_vector(_entrada(leida, AsignacionDeControles.AGACHARSE, PRINCIPAL)).is_equal(
		_tecla(KEY_SPACE)
	)
	assert_vector(_entrada(leida, AsignacionDeControles.EXAMINAR, PRINCIPAL)).is_equal(
		_tecla(KEY_CTRL)
	)


func test_un_archivo_que_ya_tiene_correr_no_toca_agacharse() -> void:  # AC-CFG-046
	var datos := AsignacionDeControles.new().datos()
	_poner(datos, AsignacionDeControles.AGACHARSE, PRINCIPAL, _tecla(KEY_SPACE))
	var leida := AsignacionDeControles.desde(datos)
	assert_vector(_entrada(leida, AsignacionDeControles.AGACHARSE, PRINCIPAL)).is_equal(
		_tecla(KEY_SPACE)
	)


func test_sin_asignaciones_agacharse_esta_en_ctrl_y_correr_en_shift() -> void:  # AC-CFG-046
	var leida := AsignacionDeControles.desde({})
	assert_vector(_entrada(leida, AsignacionDeControles.AGACHARSE, PRINCIPAL)).is_equal(
		_tecla(KEY_CTRL)
	)
	assert_vector(_entrada(leida, AsignacionDeControles.CORRER, PRINCIPAL)).is_equal(
		_tecla(KEY_SHIFT)
	)
