## La noche del corte también se prepara a oscuras: sin esa pasada, lo que dibuja el corte se enlaza
## recién cuando se corta la luz, y mientras tanto los productos no se dibujan.
extends GdUnitTestSuite

const ESPERA_MS := 5000


class EscenaConCorte:
	extends Node3D

	var cambios: Array[bool] = []
	var con_noche_del_corte := true

	func _ready() -> void:
		var malla := MeshInstance3D.new()
		malla.mesh = BoxMesh.new()
		malla.name = "Malla"
		add_child(malla)

	func oscuridad_por_preparar() -> Callable:
		return _oscurecer if con_noche_del_corte else Callable()

	func _oscurecer(a_oscuras: bool) -> void:
		cambios.append(a_oscuras)


func _escena() -> EscenaConCorte:
	var escena: EscenaConCorte = auto_free(EscenaConCorte.new())
	add_child(escena)
	return escena


func _calentamiento() -> CalentamientoDeShaders:
	var calentamiento: CalentamientoDeShaders = auto_free(CalentamientoDeShaders.new())
	add_child(calentamiento)
	return calentamiento


func test_la_noche_del_corte_se_calienta_a_oscuras_y_vuelve_la_luz() -> void:
	var escena := _escena()
	var calentamiento := _calentamiento()
	calentamiento.calentar(escena)
	assert_array(escena.cambios).is_empty()
	await assert_signal(calentamiento).wait_until(ESPERA_MS).is_emitted("terminado")
	assert_array(escena.cambios).is_equal([true, false])
	assert_bool(escena.get_node("Malla").visible).is_true()
	assert_float(calentamiento.progreso()).is_equal(1.0)


func test_otra_noche_no_pasa_por_la_oscuridad() -> void:
	var escena := _escena()
	escena.con_noche_del_corte = false
	var calentamiento := _calentamiento()
	calentamiento.calentar(escena)
	await assert_signal(calentamiento).wait_until(ESPERA_MS).is_emitted("terminado")
	assert_array(escena.cambios).is_empty()


func test_entre_noches_se_calienta_solo_la_oscuridad() -> void:
	var escena := _escena()
	var calentamiento := _calentamiento()
	calentamiento.calentar_a_oscuras(escena, escena.oscuridad_por_preparar())
	assert_array(escena.cambios).is_equal([true])
	await assert_signal(calentamiento).wait_until(ESPERA_MS).is_emitted("terminado")
	assert_array(escena.cambios).is_equal([true, false])


func test_cancelar_a_oscuras_devuelve_la_luz() -> void:
	var escena := _escena()
	var calentamiento: CalentamientoDeShaders = CalentamientoDeShaders.new()
	add_child(calentamiento)
	calentamiento.calentar_a_oscuras(escena, escena.oscuridad_por_preparar())
	calentamiento.free()
	assert_array(escena.cambios).is_equal([true, false])


func test_el_progreso_no_retrocede_al_pasar_a_oscuras() -> void:
	var escena := _escena()
	var calentamiento := _calentamiento()
	var progresos: Array[float] = []
	calentamiento.avanzo.connect(func(progreso: float) -> void: progresos.append(progreso))
	calentamiento.calentar(escena)
	await assert_signal(calentamiento).wait_until(ESPERA_MS).is_emitted("terminado")
	assert_array(progresos).is_not_empty()
	for indice: int in range(1, progresos.size()):
		assert_float(progresos[indice]).is_greater_equal(progresos[indice - 1])
