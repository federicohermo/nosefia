extends GdUnitTestSuite

const Ondas := preload("res://src/escenas/objetos/ondas_del_balde.gd")
const CUADRO := 1.0 / 60.0


## Puntos del disco de radio uno, en una grilla pareja: su promedio es el nivel medio del agua.
func _puntos_del_disco() -> PackedVector2Array:
	var puntos := PackedVector2Array()
	for y: int in range(-20, 21):
		for x: int in range(-20, 21):
			var punto := Vector2(x, y) / 20.0
			if punto.length() <= 1.0:
				puntos.append(punto)
	return puntos


func test_el_agua_nueva_esta_quieta_y_sin_empuje_no_se_mueve() -> void:
	var ondas := Ondas.new()
	ondas.avanzar(CUADRO, Vector2.ZERO)
	assert_float(ondas.amplitud()).is_equal(0.0)
	for punto: Vector2 in _puntos_del_disco():
		assert_float(ondas.altura_en(punto)).is_equal(0.0)


func test_un_golpe_levanta_el_agua_donde_cae_sin_cambiar_el_nivel_medio() -> void:
	var ondas := Ondas.new()
	var golpe := Vector2(0.5, -0.3)
	ondas.perturbar(golpe, 0.07)
	for cuadro: int in 3:
		ondas.avanzar(CUADRO, Vector2.ZERO)
	assert_float(ondas.altura_en(golpe)).is_greater(0.0)
	assert_float(ondas.altura_en(golpe)).is_greater(ondas.altura_en(-golpe))
	var suma := 0.0
	var mayor := 0.0
	var puntos := _puntos_del_disco()
	for punto: Vector2 in puntos:
		suma += ondas.altura_en(punto)
		mayor = maxf(mayor, absf(ondas.altura_en(punto)))
	assert_float(absf(suma / puntos.size())).is_less(mayor * 0.05)
	assert_float(ondas.amplitud()).is_greater_equal(mayor)


func test_acelerar_sube_el_agua_contra_la_pared_opuesta() -> void:
	var ondas := Ondas.new()
	for cuadro: int in 6:
		ondas.avanzar(CUADRO, Vector2(10.0, 0.0))
	assert_float(ondas.altura_en(Vector2(-0.95, 0.0))).is_greater(
		ondas.altura_en(Vector2(0.95, 0.0))
	)


func test_sin_empuje_el_agua_se_asienta_del_todo() -> void:
	var ondas := Ondas.new()
	ondas.perturbar(Vector2(0.8, 0.0), 0.5)
	ondas.avanzar(0.1, Vector2(20.0, 0.0))
	assert_float(ondas.amplitud()).is_greater(0.0)
	for cuadro: int in 900:
		ondas.avanzar(CUADRO, Vector2.ZERO)
	assert_float(ondas.amplitud()).is_equal(0.0)


func test_reiniciar_deja_el_agua_como_nueva() -> void:
	var ondas := Ondas.new()
	ondas.perturbar(Vector2(0.2, 0.4), 0.3)
	ondas.avanzar(CUADRO, Vector2(3.0, 1.0))
	ondas.reiniciar()
	assert_float(ondas.amplitud()).is_equal(0.0)
	ondas.avanzar(CUADRO, Vector2.ZERO)
	assert_float(ondas.altura_en(Vector2(0.2, 0.4))).is_equal(0.0)


func test_un_cuadro_largo_avanza_lo_mismo_que_sus_pasos() -> void:
	var largo := Ondas.new()
	var cortos := Ondas.new()
	for campo: Ondas in [largo, cortos]:
		campo.perturbar(Vector2(-0.4, 0.1), 0.2)
	largo.avanzar(Ondas.PASO * 3.0, Vector2(2.0, -1.0))
	for paso: int in 3:
		cortos.avanzar(Ondas.PASO, Vector2(2.0, -1.0))
	assert_bool(largo.amplitudes() == cortos.amplitudes()).is_true()


func test_una_instancia_no_comparte_su_agua_con_otra() -> void:
	var movida := Ondas.new()
	var quieta := Ondas.new()
	movida.perturbar(Vector2(0.3, 0.0), 0.4)
	movida.avanzar(CUADRO, Vector2(5.0, 0.0))
	assert_float(movida.amplitud()).is_greater(0.0)
	assert_float(quieta.amplitud()).is_equal(0.0)
