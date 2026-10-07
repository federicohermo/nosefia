extends GdUnitTestSuite

const Ondas := preload("res://src/escenas/objetos/ondas_del_balde.gd")
const BUFFERS: Array[String] = ["_alturas", "_siguientes", "_velocidades"]
const EMPUJE := Vector2(.4, -.2)


func test_la_amplitud_sigue_el_campo_tras_avanzar_y_reiniciar() -> void:
	var ondas := Ondas.new()
	assert_float(ondas.amplitud()).is_equal(0.0)
	ondas.perturbar(Vector2(.25, -.15), .07)
	# La perturbación cambia velocidad; las alturas todavía están en reposo.
	assert_float(ondas.amplitud()).is_equal(0.0)
	for cuadro in 10:
		ondas.avanzar(1.0 / 60.0, Vector2(.4, -.2))
		var alturas: PackedFloat32Array = ondas.get("_alturas")
		var mayor := 0.0
		for altura in alturas:
			mayor = maxf(mayor, absf(altura))
		assert_float(mayor).is_greater(0.0)
		for consulta in 3:
			assert_float(ondas.amplitud()).is_equal(mayor)
	ondas.reiniciar()
	assert_float(ondas.amplitud()).is_equal(0.0)
	ondas.avanzar(1.0 / 60.0, Vector2.ZERO)
	assert_float(ondas.amplitud()).is_equal(0.0)


func test_cada_subpaso_cruza_los_dos_buffers_sin_crear_otro() -> void:
	var ondas := Ondas.new()
	var primero: PackedFloat32Array = ondas.get("_alturas")
	var segundo: PackedFloat32Array = ondas.get("_siguientes")
	assert_bool(is_same(primero, segundo)).is_false()
	ondas.perturbar(Vector2(.25, -.15), .07)
	ondas.avanzar(Ondas.PASO, EMPUJE)
	assert_bool(is_same(ondas.get("_alturas"), segundo)).is_true()
	assert_bool(is_same(ondas.get("_siguientes"), primero)).is_true()
	# Dos subpasos en una llamada son dos cruces: quedan como estaban.
	ondas.avanzar(Ondas.PASO * 2.0, EMPUJE)
	assert_bool(is_same(ondas.get("_alturas"), segundo)).is_true()
	assert_bool(is_same(ondas.get("_siguientes"), primero)).is_true()
	ondas.avanzar(Ondas.PASO, EMPUJE)
	assert_bool(is_same(ondas.get("_alturas"), primero)).is_true()
	assert_bool(is_same(ondas.get("_siguientes"), segundo)).is_true()


func test_los_dos_buffers_son_los_mismos_con_cualquier_delta_y_tras_reiniciar() -> void:
	var ondas := Ondas.new()
	var primero: PackedFloat32Array = ondas.get("_alturas")
	var segundo: PackedFloat32Array = ondas.get("_siguientes")
	for vuelta in 3:
		ondas.perturbar(Vector2(-1.0, 1.0), .3)
		for delta: float in [0.0, 1.0 / 144.0, 1.0 / 60.0, 1.0 / 30.0, 0.1, 0.2]:
			ondas.avanzar(delta, EMPUJE)
			(
				assert_bool(_son_los_de_siempre(ondas, primero, segundo))
				. override_failure_message("avanzar %s s dejó un buffer nuevo" % delta)
				. is_true()
			)
		ondas.reiniciar()
		assert_bool(_son_los_de_siempre(ondas, primero, segundo)).is_true()


func test_una_instancia_no_comparte_buffers_con_otra() -> void:
	var movida := Ondas.new()
	var quieta := Ondas.new()
	for propio in BUFFERS:
		for ajeno in BUFFERS:
			assert_bool(is_same(movida.get(propio), quieta.get(ajeno))).is_false()
	movida.perturbar(Vector2(.25, -.15), .07)
	for avance in 3:
		movida.avanzar(Ondas.PASO, EMPUJE)
	assert_float(movida.amplitud()).is_greater(0.0)
	for nombre in BUFFERS:
		assert_bool(quieta.get(nombre) == _en_cero()).is_true()
	assert_float(quieta.amplitud()).is_equal(0.0)


func test_reiniciar_tras_un_numero_impar_de_subpasos_limpia_los_dos_buffers() -> void:
	var ondas := Ondas.new()
	ondas.perturbar(Vector2(.25, -.15), .07)
	for avance in 3:
		ondas.avanzar(Ondas.PASO, EMPUJE)
	for nombre in BUFFERS:
		(
			assert_bool(ondas.get(nombre) == _en_cero())
			. override_failure_message(nombre + " no llegó a moverse antes de reiniciar")
			. is_false()
		)
	for vez in 2:
		ondas.reiniciar()
		for nombre in BUFFERS:
			(
				assert_bool(ondas.get(nombre) == _en_cero())
				. override_failure_message(nombre + " quedó con agua tras reiniciar")
				. is_true()
			)
		assert_float(ondas.amplitud()).is_equal(0.0)
	# Perturbar después de reiniciar evoluciona igual que un campo nuevo.
	var nuevo := Ondas.new()
	for campo: Ondas in [ondas, nuevo]:
		campo.perturbar(Vector2(-.4, .3), .2)
		campo.avanzar(Ondas.PASO * 2.0, EMPUJE)
	assert_float(nuevo.amplitud()).is_greater(0.0)
	assert_bool(_evolucionan_igual(ondas, nuevo)).is_true()


func test_el_muestreo_devuelve_una_copia_que_no_toca_el_avance_siguiente() -> void:
	var tocado := Ondas.new()
	var testigo := Ondas.new()
	var puntos := PackedVector2Array([Vector2.ZERO, Vector2(.3, 0.0), Vector2(1.2, 1.2)])
	for campo: Ondas in [tocado, testigo]:
		campo.preparar_muestras(puntos)
		campo.perturbar(Vector2(.25, -.15), .07)
		campo.avanzar(Ondas.PASO, EMPUJE)
	var muestras := tocado.alturas_muestreadas()
	assert_float(absf(muestras[0])).is_greater(0.0)
	for nombre in BUFFERS:
		assert_bool(is_same(muestras, tocado.get(nombre))).is_false()
	muestras.fill(1.0)
	assert_bool(tocado.alturas_muestreadas() == testigo.alturas_muestreadas()).is_true()
	for campo: Ondas in [tocado, testigo]:
		campo.avanzar(Ondas.PASO, EMPUJE)
	assert_bool(_evolucionan_igual(tocado, testigo)).is_true()


func _son_los_de_siempre(
	ondas: Ondas, primero: PackedFloat32Array, segundo: PackedFloat32Array
) -> bool:
	var alturas: PackedFloat32Array = ondas.get("_alturas")
	var siguientes: PackedFloat32Array = ondas.get("_siguientes")
	return (
		(is_same(alturas, primero) and is_same(siguientes, segundo))
		or (is_same(alturas, segundo) and is_same(siguientes, primero))
	)


func _evolucionan_igual(uno: Ondas, otro: Ondas) -> bool:
	return (
		uno.get("_alturas") == otro.get("_alturas")
		and uno.get("_velocidades") == otro.get("_velocidades")
		and uno.amplitud() == otro.amplitud()
	)


func _en_cero() -> PackedFloat32Array:
	var ceros := PackedFloat32Array()
	ceros.resize(Ondas.LADO * Ondas.LADO)
	ceros.fill(0.0)
	return ceros
