extends GdUnitTestSuite

const Tapa := preload("res://src/dominio/almacen/tapa_del_contenedor.gd")


func test_arranca_abierta_y_recibe_bolsas() -> void:  # AC-CLN-034
	var tapa := Tapa.new()
	assert_float(tapa.angulo()).is_equal(Tapa.ANGULO_ABIERTA)
	assert_bool(tapa.recibe_bolsas()).is_true()


func test_cerrar_corta_el_descarte_antes_de_terminar_el_giro() -> void:  # AC-CLN-035
	var tapa := Tapa.new()
	tapa.alternar()
	assert_bool(tapa.recibe_bolsas()).is_false()
	assert_float(tapa.angulo()).is_equal(Tapa.ANGULO_ABIERTA)
	assert_float(tapa.avanzar(0.1)).is_between(0.0, Tapa.ANGULO_ABIERTA - 0.01)
	assert_float(tapa.avanzar(10.0)).is_equal(0.0)
	assert_bool(tapa.recibe_bolsas()).is_false()


func test_abrir_recupera_el_descarte_al_terminar_el_giro() -> void:  # AC-CLN-035
	var tapa := Tapa.new()
	tapa.alternar()
	tapa.avanzar(1.0)
	tapa.alternar()
	assert_float(tapa.avanzar(0.1)).is_between(0.01, Tapa.ANGULO_ABIERTA - 0.01)
	assert_bool(tapa.recibe_bolsas()).is_false()
	assert_float(tapa.avanzar(1.0)).is_equal(Tapa.ANGULO_ABIERTA)
	assert_bool(tapa.recibe_bolsas()).is_true()


func test_se_puede_invertir_el_giro_sin_saltar_al_otro_tope() -> void:  # AC-CLN-034
	var tapa := Tapa.new()
	tapa.alternar()
	var intermedio := tapa.avanzar(0.2)
	tapa.alternar()
	assert_float(tapa.angulo()).is_equal(intermedio)
	assert_float(tapa.avanzar(0.1)).is_greater(intermedio)


func test_dividir_los_cuadros_da_el_mismo_angulo() -> void:  # AC-CLN-034
	var tapa := Tapa.new()
	var otra := Tapa.new()
	tapa.alternar()
	otra.alternar()
	tapa.avanzar(0.3)
	for cuadro: int in 3:
		otra.avanzar(0.1)
	assert_float(otra.angulo()).is_equal_approx(tapa.angulo(), 0.00001)


func test_el_tiempo_negativo_no_mueve_la_tapa() -> void:  # AC-CLN-034
	var tapa := Tapa.new()
	tapa.alternar()
	var antes := tapa.avanzar(0.2)
	assert_float(tapa.avanzar(-10.0)).is_equal(antes)


func test_reiniciar_la_jornada_la_deja_abierta() -> void:  # AC-CLN-034
	var tapa := Tapa.new()
	tapa.alternar()
	tapa.avanzar(1.0)
	tapa.reiniciar()
	assert_float(tapa.angulo()).is_equal(Tapa.ANGULO_ABIERTA)
	assert_bool(tapa.recibe_bolsas()).is_true()


func test_un_paso_obstruido_no_mueve_la_tapa_y_se_puede_invertir() -> void:  # AC-CLN-034
	var tapa := Tapa.new()
	tapa.alternar()
	var antes := tapa.avanzar(0.2)
	assert_float(tapa.angulo_siguiente(0.1)).is_less(antes)
	assert_float(tapa.angulo()).is_equal(antes)
	assert_float(tapa.avanzar(0.1, false)).is_equal(antes)
	assert_bool(tapa.recibe_bolsas()).is_false()
	tapa.alternar()
	assert_float(tapa.avanzar(0.1)).is_greater(antes)
	tapa.avanzar(1.0)
	assert_bool(tapa.recibe_bolsas()).is_true()
