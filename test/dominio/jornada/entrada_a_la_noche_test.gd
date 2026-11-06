extends GdUnitTestSuite

const Entrada := preload("res://src/dominio/jornada/entrada_a_la_noche.gd")


func test_la_placa_desaparece_antes_de_que_suba_la_persiana() -> void:  # AC-SHF-022
	var entrada := Entrada.new(3)
	entrada.avanzar(1.0)
	assert_float(entrada.opacidad_de_la_placa()).is_equal(1.0)
	assert_float(entrada.apertura_de_la_persiana()).is_zero()
	assert_bool(entrada.terminada()).is_false()
	entrada.avanzar(0.25)
	assert_float(entrada.opacidad_de_la_placa()).is_equal(0.5)
	assert_float(entrada.apertura_de_la_persiana()).is_zero()
	entrada.avanzar(0.25)
	assert_float(entrada.opacidad_de_la_placa()).is_zero()
	assert_float(entrada.apertura_de_la_persiana()).is_zero()
	entrada.avanzar(0.5)
	assert_float(entrada.apertura_de_la_persiana()).is_equal(0.5)
	assert_bool(entrada.terminada()).is_false()
	entrada.avanzar(0.5)
	assert_float(entrada.apertura_de_la_persiana()).is_equal(1.0)
	assert_bool(entrada.terminada()).is_true()


func test_la_bajada_de_la_persiana_frena_al_llegar_abajo() -> void:  # AC-EMP-118
	assert_float(Entrada.avance_de_la_bajada(0.0)).is_zero()
	assert_float(Entrada.avance_de_la_bajada(1.0)).is_equal(1.0)
	assert_float(Entrada.avance_de_la_bajada(0.5)).is_greater(0.5).is_less(1.0)
	var primero := Entrada.avance_de_la_bajada(0.1) - Entrada.avance_de_la_bajada(0.0)
	var ultimo := Entrada.avance_de_la_bajada(1.0) - Entrada.avance_de_la_bajada(0.9)
	assert_float(ultimo).is_greater(0.0).is_less(primero)
	var anterior := 0.0
	for paso in range(1, 21):
		var avance := Entrada.avance_de_la_bajada(paso / 20.0)
		assert_float(avance).is_greater(anterior)
		anterior = avance


func test_la_bajada_ignora_lo_que_se_sale_del_recorrido() -> void:  # AC-EMP-118
	assert_float(Entrada.avance_de_la_bajada(-0.5)).is_zero()
	assert_float(Entrada.avance_de_la_bajada(1.5)).is_equal(1.0)


func test_la_subida_de_la_persiana_sigue_pareja() -> void:  # AC-EMP-119
	var entrada := Entrada.new(2)
	entrada.avanzar(Entrada.PLACA_ENTERA + Entrada.FADE_DE_LA_PLACA)
	entrada.avanzar(Entrada.SUBIDA_DE_LA_PERSIANA / 2.0)
	assert_float(entrada.apertura_de_la_persiana()).is_equal(0.5)


func test_los_avances_son_monotonos_acotados_y_ignoran_tiempo_no_positivo() -> void:  # AC-SHF-022
	var entrada := Entrada.new(1)
	var opacidad := 1.0
	var apertura := 0.0
	for _paso in 40:
		for tiempo: float in [0.0, -1.0]:
			entrada.avanzar(tiempo)
			assert_float(entrada.opacidad_de_la_placa()).is_equal(opacidad)
			assert_float(entrada.apertura_de_la_persiana()).is_equal(apertura)
		entrada.avanzar(0.1)
		assert_float(entrada.opacidad_de_la_placa()).is_between(0.0, opacidad)
		assert_float(entrada.apertura_de_la_persiana()).is_between(apertura, 1.0)
		opacidad = entrada.opacidad_de_la_placa()
		apertura = entrada.apertura_de_la_persiana()
	assert_bool(entrada.terminada()).is_true()
	entrada.avanzar(100.0)
	assert_float(entrada.opacidad_de_la_placa()).is_zero()
	assert_float(entrada.apertura_de_la_persiana()).is_equal(1.0)
