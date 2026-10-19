## Cuándo la pantalla de carga deja entrar al almacén, sin levantar la escena.
extends GdUnitTestSuite


func test_recien_mostrada_no_deja_entrar() -> void:
	assert_bool(EsperaDeLaCarga.new().puede_entrar()).is_false()


func test_con_la_carga_terminada_espera_el_minimo() -> void:
	var espera := EsperaDeLaCarga.new()
	espera.terminar_carga()
	espera.avanzar(EsperaDeLaCarga.MINIMO * 0.9)
	assert_bool(espera.puede_entrar()).is_false()
	espera.avanzar(EsperaDeLaCarga.MINIMO * 0.1)
	assert_bool(espera.puede_entrar()).is_true()


func test_pasado_el_minimo_espera_la_carga() -> void:
	var espera := EsperaDeLaCarga.new()
	espera.avanzar(EsperaDeLaCarga.MINIMO * 3)
	assert_bool(espera.puede_entrar()).is_false()
	espera.terminar_carga()
	assert_bool(espera.puede_entrar()).is_true()


func test_el_tiempo_se_acumula_entre_cuadros() -> void:
	var espera := EsperaDeLaCarga.new()
	espera.terminar_carga()
	for i: int in 4:
		espera.avanzar(EsperaDeLaCarga.MINIMO / 4)
	assert_bool(espera.puede_entrar()).is_true()


## Con el local ya listo, la barra se llena en el mínimo y no lo pasa.
func test_el_avance_llega_a_uno_al_cumplir_el_minimo() -> void:
	var espera := EsperaDeLaCarga.new()
	assert_float(espera.avance()).is_zero()
	espera.avanzar(EsperaDeLaCarga.MINIMO / 2)
	assert_float(espera.avance()).is_equal_approx(0.5, 0.001)
	espera.avanzar(EsperaDeLaCarga.MINIMO * 2)
	assert_float(espera.avance()).is_equal(1.0)
