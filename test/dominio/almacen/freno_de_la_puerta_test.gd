## Cuánto frena un obstáculo a la hoja de una puerta, y dónde la detiene.
extends GdUnitTestSuite

const LARGO := 1.7
const ESPESOR := 0.2
const VANO := 1.7
const UN_GRADO := deg_to_rad(1.0)


func _hoja_en(angulo: float) -> Puerta:
	var puerta := Puerta.new()
	puerta.alternar()
	puerta.avanzar(angulo / Puerta.VELOCIDAD_DEL_GIRO)
	return puerta


func test_sin_obstaculo_o_con_uno_liviano_la_hoja_no_se_frena() -> void:  # AC-PLY-140 AC-PLY-141
	for obstaculo in [FrenoDeLaPuerta.Obstaculo.NADA, FrenoDeLaPuerta.Obstaculo.LIVIANO]:
		for puede_correrse in [true, false]:
			var freno := FrenoDeLaPuerta.decidir(obstaculo, puede_correrse, 0.0, 0.5)
			assert_float(freno.factor).is_equal(1.0)
			assert_bool(is_nan(freno.tope)).is_true()


func test_lo_pesado_que_se_puede_correr_frena_sin_detener() -> void:  # AC-PLY-142
	var freno := FrenoDeLaPuerta.decidir(FrenoDeLaPuerta.Obstaculo.PESADO, true, 1.2, 0.5)
	assert_float(freno.factor).is_between(0.0, 1.0)
	assert_float(freno.factor).is_not_equal(0.0)
	assert_float(freno.factor).is_not_equal(1.0)
	assert_bool(is_nan(freno.tope)).is_true()


func test_lo_pesado_inmovil_detiene_la_hoja_donde_toca_si_conserva_el_paso() -> void:  # AC-PLY-143
	var paso := 0.9
	for angulo in [paso, paso + UN_GRADO, Puerta.ANGULO_ABIERTA]:
		var freno := FrenoDeLaPuerta.decidir(FrenoDeLaPuerta.Obstaculo.PESADO, false, angulo, paso)
		assert_float(freno.tope).is_equal(angulo)


func test_lo_pesado_inmovil_no_detiene_la_hoja_bajo_el_angulo_de_paso() -> void:  # AC-PLY-143
	var paso := 0.9
	for angulo in [0.0, paso - UN_GRADO]:
		var freno := FrenoDeLaPuerta.decidir(FrenoDeLaPuerta.Obstaculo.PESADO, false, angulo, paso)
		assert_float(freno.factor).is_equal(1.0)
		assert_bool(is_nan(freno.tope)).is_true()


func test_en_el_angulo_de_paso_la_hoja_se_detiene_y_un_grado_menos_sigue() -> void:  # AC-PLY-148
	var paso := 0.9
	var en_el_paso := _hoja_en(paso)
	var freno := FrenoDeLaPuerta.decidir(
		FrenoDeLaPuerta.Obstaculo.PESADO, false, en_el_paso.angulo(), paso
	)
	en_el_paso.avanzar(0.1, freno.factor, freno.tope)
	assert_float(en_el_paso.angulo()).is_equal_approx(paso, 0.0001)
	var debajo := _hoja_en(paso - UN_GRADO)
	freno = FrenoDeLaPuerta.decidir(FrenoDeLaPuerta.Obstaculo.PESADO, false, debajo.angulo(), paso)
	debajo.avanzar(10.0, freno.factor, freno.tope)
	assert_float(debajo.angulo()).is_equal(Puerta.ANGULO_ABIERTA)


func test_el_angulo_de_paso_deja_pasar_y_un_grado_menos_no() -> void:  # AC-PLY-147
	var libre := FrenoDeLaPuerta.ANCHO_DEL_JUGADOR + FrenoDeLaPuerta.MARGEN_DEL_PASO
	var paso := FrenoDeLaPuerta.angulo_de_paso(LARGO, ESPESOR, VANO)
	assert_float(_hueco(paso)).is_greater_equal(libre)
	assert_float(_hueco(paso - UN_GRADO)).is_less(libre)


func test_el_angulo_de_paso_es_de_grados_enteros() -> void:  # AC-PLY-147
	var grados := rad_to_deg(FrenoDeLaPuerta.angulo_de_paso(LARGO, ESPESOR, VANO))
	assert_float(grados).is_equal_approx(roundf(grados), 0.0001)


func test_un_vano_que_no_deja_pasar_ni_abierta_la_hoja_no_se_detiene_nunca() -> void:  # AC-PLY-148
	var paso := FrenoDeLaPuerta.angulo_de_paso(LARGO, ESPESOR, FrenoDeLaPuerta.ANCHO_DEL_JUGADOR)
	assert_float(paso).is_equal(Puerta.ANGULO_ABIERTA)


func test_un_vano_de_sobra_deja_pasar_con_la_hoja_cerrada_a_medias_o_no() -> void:  # AC-PLY-147
	assert_float(FrenoDeLaPuerta.angulo_de_paso(LARGO, ESPESOR, LARGO + 2.0)).is_zero()


## El hueco que deja la hoja a lo ancho del vano, con la hoja a `angulo`.
func _hueco(angulo: float) -> float:
	return VANO - (LARGO * cos(angulo) + ESPESOR * sin(angulo))
