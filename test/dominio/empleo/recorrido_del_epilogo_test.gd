## El recorrido de un epílogo: los fundidos, el orden de las placas y el gesto de «SIGUIENTE».
extends GdUnitTestSuite

const FUNDIDO := RecorridoDelEpilogo.SEGUNDOS_DEL_FUNDIDO


func _placas(cantidad: int) -> Array[EpilogosDeLosFinales.Placa]:
	var textos: Array = []
	for indice in range(cantidad):
		textos.append("placa %d" % indice)
	return EpilogosDeLosFinales.con_texto(EpilogosDeLosFinales.FONDO_DEL_FINAL_1, textos)


## Cuenta cuántas veces avisó que la última placa se cerró.
func _contar_los_cierres(recorrido: RecorridoDelEpilogo) -> Array[int]:
	var cierres: Array[int] = [0]
	recorrido.cerrado.connect(func() -> void: cierres[0] += 1)
	return cierres


func _leyendo_la_placa(recorrido: RecorridoDelEpilogo) -> void:
	recorrido.avanzar(2.0 * FUNDIDO)


func test_la_primera_placa_entra_tras_un_fundido_a_negro_y_uno_de_entrada() -> void:  # AC-SHF-138
	var recorrido := RecorridoDelEpilogo.new(_placas(2))
	assert_float(recorrido.negro()).is_equal(0.0)
	assert_object(recorrido.placa()).is_null()
	recorrido.avanzar(FUNDIDO / 2.0)
	assert_float(recorrido.negro()).is_equal_approx(0.5, 1e-6)
	assert_object(recorrido.placa()).is_null()
	recorrido.avanzar(FUNDIDO / 2.0)
	assert_float(recorrido.negro()).is_equal_approx(1.0, 1e-6)
	assert_object(recorrido.placa()).is_not_null()
	recorrido.avanzar(FUNDIDO / 2.0)
	assert_float(recorrido.negro()).is_equal_approx(0.5, 1e-6)
	assert_bool(recorrido.esperando_el_siguiente()).is_false()
	recorrido.avanzar(FUNDIDO / 2.0)
	assert_float(recorrido.negro()).is_equal_approx(0.0, 1e-6)
	assert_bool(recorrido.esperando_el_siguiente()).is_true()


func test_entre_placas_del_mismo_fondo_se_funde_el_texto_y_no_el_negro() -> void:  # AC-SHF-138
	var recorrido := RecorridoDelEpilogo.new(_placas(2))
	_leyendo_la_placa(recorrido)
	assert_float(recorrido.opacidad_del_texto()).is_equal(1.0)
	recorrido.siguiente()
	recorrido.avanzar(FUNDIDO / 2.0)
	assert_float(recorrido.opacidad_del_texto()).is_equal_approx(0.5, 1e-6)
	assert_float(recorrido.negro()).is_equal(0.0)
	recorrido.avanzar(FUNDIDO / 2.0)
	assert_float(recorrido.opacidad_del_texto()).is_equal_approx(0.0, 1e-6)
	assert_float(recorrido.negro()).is_equal(0.0)
	recorrido.avanzar(FUNDIDO / 2.0)
	assert_float(recorrido.opacidad_del_texto()).is_equal_approx(0.5, 1e-6)
	assert_float(recorrido.negro()).is_equal(0.0)
	recorrido.avanzar(FUNDIDO / 2.0)
	assert_float(recorrido.opacidad_del_texto()).is_equal(1.0)


func test_entre_dos_placas_de_fondo_distinto_se_funde_la_pantalla() -> void:  # AC-SHF-138
	var placas: Array[EpilogosDeLosFinales.Placa] = [
		EpilogosDeLosFinales.Placa.new(EpilogosDeLosFinales.FONDO_DEL_FINAL_1, "primera"),
		EpilogosDeLosFinales.Placa.new(EpilogosDeLosFinales.FONDO_DEL_FINAL_2, "segunda"),
	]
	var recorrido := RecorridoDelEpilogo.new(placas)
	_leyendo_la_placa(recorrido)
	recorrido.siguiente()
	recorrido.avanzar(FUNDIDO)
	assert_float(recorrido.negro()).is_equal_approx(1.0, 1e-6)
	assert_object(recorrido.placa()).is_same(placas[1])


func test_de_la_ultima_placa_a_la_pantalla_de_final_se_funde_la_pantalla() -> void:  # AC-SHF-138
	var recorrido := RecorridoDelEpilogo.new(_placas(2))
	_leyendo_la_placa(recorrido)
	recorrido.siguiente()
	_leyendo_la_placa(recorrido)
	recorrido.siguiente()
	recorrido.avanzar(FUNDIDO / 2.0)
	assert_float(recorrido.negro()).is_equal_approx(0.5, 1e-6)
	recorrido.avanzar(FUNDIDO / 2.0)
	assert_float(recorrido.negro()).is_equal_approx(1.0, 1e-6)
	recorrido.avanzar(FUNDIDO / 2.0)
	assert_float(recorrido.negro()).is_equal_approx(0.5, 1e-6)


func test_el_recorrido_muestra_cada_placa_en_orden() -> void:  # AC-SHF-134
	var placas := _placas(6)
	var recorrido := RecorridoDelEpilogo.new(placas)
	for indice in range(placas.size()):
		_leyendo_la_placa(recorrido)
		assert_object(recorrido.placa()).is_same(placas[indice])
		assert_bool(recorrido.siguiente()).is_true()


func test_la_ultima_placa_se_cierra_con_la_misma_transicion_y_una_sola_vez() -> void:  # AC-SHF-138
	var recorrido := RecorridoDelEpilogo.new(_placas(2))
	var cierres := _contar_los_cierres(recorrido)
	_leyendo_la_placa(recorrido)
	recorrido.siguiente()
	_leyendo_la_placa(recorrido)
	assert_int(cierres[0]).is_zero()
	recorrido.siguiente()
	recorrido.avanzar(FUNDIDO - 0.25)
	assert_int(cierres[0]).is_zero()
	assert_object(recorrido.placa()).is_not_null()
	recorrido.avanzar(0.25)
	assert_int(cierres[0]).is_equal(1)
	assert_float(recorrido.negro()).is_equal_approx(1.0, 1e-6)
	assert_object(recorrido.placa()).is_null()
	assert_bool(recorrido.terminado()).is_false()
	recorrido.avanzar(FUNDIDO)
	assert_bool(recorrido.terminado()).is_true()
	assert_float(recorrido.negro()).is_equal(0.0)
	recorrido.avanzar(10.0)
	assert_int(cierres[0]).is_equal(1)


func test_con_una_sola_placa_siguiente_lleva_al_cierre() -> void:  # AC-SHF-138
	var recorrido := RecorridoDelEpilogo.new(_placas(1))
	var cierres := _contar_los_cierres(recorrido)
	_leyendo_la_placa(recorrido)
	assert_int(cierres[0]).is_zero()
	assert_bool(recorrido.siguiente()).is_true()
	recorrido.avanzar(FUNDIDO)
	assert_int(cierres[0]).is_equal(1)
	assert_object(recorrido.placa()).is_null()


func test_siguiente_en_mitad_de_un_fundido_no_hace_nada() -> void:  # AC-SHF-140
	var placas := _placas(3)
	var recorrido := RecorridoDelEpilogo.new(placas)
	assert_bool(recorrido.siguiente()).is_false()
	recorrido.avanzar(FUNDIDO * 1.5)
	assert_bool(recorrido.siguiente()).is_false()
	recorrido.avanzar(FUNDIDO * 0.5)
	assert_object(recorrido.placa()).is_same(placas[0])
	assert_bool(recorrido.siguiente()).is_true()
	recorrido.avanzar(FUNDIDO * 0.5)
	assert_bool(recorrido.siguiente()).is_false()
	recorrido.avanzar(FUNDIDO * 1.5)
	assert_object(recorrido.placa()).is_same(placas[1])


func test_dos_siguientes_seguidos_pasan_una_sola_placa() -> void:  # AC-SHF-140
	var placas := _placas(3)
	var recorrido := RecorridoDelEpilogo.new(placas)
	var cierres := _contar_los_cierres(recorrido)
	_leyendo_la_placa(recorrido)
	assert_bool(recorrido.siguiente()).is_true()
	assert_bool(recorrido.siguiente()).is_false()
	_leyendo_la_placa(recorrido)
	assert_object(recorrido.placa()).is_same(placas[1])
	assert_int(cierres[0]).is_zero()


func test_un_cuadro_largo_no_saltea_el_estado_de_lectura() -> void:  # AC-SHF-140
	var placas := _placas(2)
	var recorrido := RecorridoDelEpilogo.new(placas)
	recorrido.avanzar(100.0)
	assert_object(recorrido.placa()).is_same(placas[0])
	assert_bool(recorrido.esperando_el_siguiente()).is_true()
	assert_float(recorrido.negro()).is_equal(0.0)


func test_un_tiempo_negativo_no_mueve_nada() -> void:  # AC-SHF-138
	var recorrido := RecorridoDelEpilogo.new(_placas(1))
	recorrido.avanzar(-5.0)
	assert_float(recorrido.negro()).is_equal(0.0)
	assert_object(recorrido.placa()).is_null()
