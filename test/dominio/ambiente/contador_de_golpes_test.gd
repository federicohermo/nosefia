## Los golpes de un objeto soltado: cuántos suenan, a qué volumen y con qué corte.
extends GdUnitTestSuite

const RAPIDO := ContadorDeGolpes.UMBRAL_DE_GOLPE * 4.0


func test_suenan_tres_golpes_cada_uno_mas_bajo_y_mas_filtrado() -> void:  # AC-AMB-011
	var golpes := ContadorDeGolpes.new()
	var primero := golpes.contar(RAPIDO)
	var segundo := golpes.contar(RAPIDO)
	var tercero := golpes.contar(RAPIDO)
	assert_float(primero.volumen_db).is_equal(0.0)
	assert_float(primero.corte_hz).is_equal(0.0)
	assert_float(segundo.volumen_db).is_equal(-6.0)
	assert_float(segundo.corte_hz).is_greater(0.0)
	assert_float(tercero.volumen_db).is_equal(-12.0)
	assert_float(tercero.corte_hz).is_greater(segundo.corte_hz)
	assert_object(golpes.contar(RAPIDO)).is_null()
	assert_object(golpes.contar(RAPIDO)).is_null()


func test_un_contacto_lento_no_gasta_ningun_golpe() -> void:  # AC-AMB-012
	var golpes := ContadorDeGolpes.new()
	assert_object(golpes.contar(ContadorDeGolpes.UMBRAL_DE_GOLPE - 0.01)).is_null()
	assert_float(golpes.contar(ContadorDeGolpes.UMBRAL_DE_GOLPE).volumen_db).is_equal(0.0)


func test_reiniciar_vuelve_al_primer_golpe() -> void:  # AC-AMB-012
	var golpes := ContadorDeGolpes.new()
	golpes.contar(RAPIDO)
	golpes.contar(RAPIDO)
	golpes.reiniciar()
	assert_float(golpes.contar(RAPIDO).volumen_db).is_equal(0.0)


func test_agotar_deja_de_sonar_hasta_reiniciar() -> void:
	var golpes := ContadorDeGolpes.new()
	golpes.agotar()
	assert_object(golpes.contar(RAPIDO)).is_null()
	golpes.reiniciar()
	assert_object(golpes.contar(RAPIDO)).is_not_null()


func test_agarrar_reinicia_tocar_cuenta_y_colocar_agota() -> void:  # AC-AMB-013
	var golpes := ContadorDeGolpes.new()
	var tocar := EntradaSonora.Evento.OBJETO_SOLTADO
	golpes.al_evento(tocar, RAPIDO)
	golpes.al_evento(tocar, RAPIDO)
	var agarrar := golpes.al_evento(EntradaSonora.Evento.OBJETO_AGARRADO, 0.0)
	assert_float(agarrar.volumen_db).is_equal(0.0)
	assert_float(golpes.al_evento(tocar, RAPIDO).volumen_db).is_equal(0.0)
	var colocar := golpes.al_evento(EntradaSonora.Evento.PRODUCTO_COLOCADO, 0.0)
	assert_float(colocar.volumen_db).is_equal(0.0)
	assert_float(colocar.corte_hz).is_equal(0.0)
	assert_object(golpes.al_evento(tocar, RAPIDO)).is_null()


func test_un_evento_que_no_es_de_objeto_suena_pleno() -> void:
	var golpes := ContadorDeGolpes.new()
	var golpe := golpes.al_evento(EntradaSonora.Evento.TURNO_CERRADO, 0.0)
	assert_float(golpe.volumen_db).is_equal(0.0)


func test_el_golpe_pleno_no_baja_ni_filtra() -> void:
	assert_float(ContadorDeGolpes.pleno().volumen_db).is_equal(0.0)
	assert_float(ContadorDeGolpes.pleno().corte_hz).is_equal(0.0)
