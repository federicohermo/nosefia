## El gatillo derecho: lo acepta la ranura del joystick de Correr y ninguna otra, y viaja en el
## archivo como cualquier entrada.
extends GdUnitTestSuite

const TECLA := AsignacionDeControles.TipoDeEntrada.TECLA
const JOYSTICK := AsignacionDeControles.TipoDeEntrada.BOTON_DEL_JOYSTICK
const GATILLO := AsignacionDeControles.TipoDeEntrada.GATILLO_DEL_JOYSTICK
const RANURA := AsignacionDeControles.RANURA_DEL_JOYSTICK
const CORRER := AsignacionDeControles.CORRER
const VACIA := AsignacionDeControles.VACIA
const DERECHO := JOY_AXIS_TRIGGER_RIGHT


func _entrada(asignacion: AsignacionDeControles, accion: StringName, ranura: int) -> Vector2i:
	var entrada := asignacion.entrada(accion, ranura)
	return Vector2i(entrada["tipo"], entrada["codigo"])


func _quien_tiene(asignacion: AsignacionDeControles, buscada: Vector2i) -> Array[StringName]:
	var duenas: Array[StringName] = []
	for entrada: Dictionary in asignacion.entradas():
		if Vector2i(entrada["tipo"], entrada["codigo"]) == buscada:
			duenas.append(entrada["accion"])
	return duenas


func test_solo_la_ranura_del_joystick_de_correr_acepta_el_gatillo_derecho() -> void:  # AC-CFG-047
	for accion: StringName in AsignacionDeControles.ACCIONES:
		for ranura: int in AsignacionDeControles.ranuras_de(accion):
			var debe := accion == CORRER and ranura == RANURA
			(
				assert_bool(AsignacionDeControles.acepta(accion, GATILLO, DERECHO, false, ranura))
				. override_failure_message("%s, ranura %d" % [accion, ranura])
				. is_equal(debe)
			)


func test_el_gatillo_izquierdo_y_los_ejes_de_las_palancas_no_se_aceptan() -> void:  # AC-CFG-047
	for eje: int in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X]:
		assert_bool(AsignacionDeControles.acepta(CORRER, GATILLO, eje, false, RANURA)).is_false()


func test_correr_se_reasigna_a_un_boton_libre_y_vuelve_al_gatillo() -> void:  # AC-CFG-047
	var asignacion := AsignacionDeControles.new()
	assert_bool(asignacion.asignar(CORRER, RANURA, JOYSTICK, JOY_BUTTON_Y)).is_true()
	assert_vector(_entrada(asignacion, CORRER, RANURA)).is_equal(Vector2i(JOYSTICK, JOY_BUTTON_Y))
	assert_array(_quien_tiene(asignacion, Vector2i(GATILLO, DERECHO))).is_empty()
	assert_bool(asignacion.asignar(CORRER, RANURA, GATILLO, DERECHO)).is_true()
	assert_vector(_entrada(asignacion, CORRER, RANURA)).is_equal(Vector2i(GATILLO, DERECHO))
	assert_array(_quien_tiene(asignacion, Vector2i(JOYSTICK, JOY_BUTTON_Y))).is_empty()


func test_un_boton_ocupado_no_se_asigna_a_correr_con_el_gatillo() -> void:  # AC-CFG-047
	var asignacion := AsignacionDeControles.new()
	var antes := asignacion.datos()
	assert_bool(asignacion.asignar(CORRER, RANURA, JOYSTICK, JOY_BUTTON_X)).is_false()
	assert_dict(asignacion.datos()).is_equal(antes)


func test_el_gatillo_no_se_asigna_a_otra_accion_ni_a_una_tecla() -> void:  # AC-CFG-047
	var asignacion := AsignacionDeControles.new()
	var antes := asignacion.datos()
	(
		assert_bool(asignacion.asignar(AsignacionDeControles.EXAMINAR, RANURA, GATILLO, DERECHO))
		. is_false()
	)
	assert_bool(asignacion.asignar(CORRER, 0, GATILLO, DERECHO)).is_false()
	assert_bool(asignacion.asignar(CORRER, 1, GATILLO, DERECHO)).is_false()
	assert_dict(asignacion.datos()).is_equal(antes)


func test_el_gatillo_se_guarda_y_se_lee() -> void:  # AC-CFG-047
	var datos := AsignacionDeControles.new().datos()
	var guardado: Dictionary = datos[String(CORRER)][RANURA]
	assert_array(guardado.keys()).contains_exactly_in_any_order(["tipo", "codigo"])
	var leida := AsignacionDeControles.desde(datos)
	assert_vector(_entrada(leida, CORRER, RANURA)).is_equal(Vector2i(GATILLO, DERECHO))


func test_un_gatillo_guardado_en_otra_accion_es_ilegible() -> void:  # AC-CFG-047
	var datos := AsignacionDeControles.new().datos()
	datos[String(AsignacionDeControles.EXAMINAR)][RANURA] = {"tipo": GATILLO, "codigo": DERECHO}
	var leida := AsignacionDeControles.desde(datos)
	assert_vector(_entrada(leida, AsignacionDeControles.EXAMINAR, RANURA)).is_equal(
		Vector2i(JOYSTICK, JOY_BUTTON_X)
	)
	assert_vector(_entrada(leida, CORRER, RANURA)).is_equal(Vector2i(GATILLO, DERECHO))
