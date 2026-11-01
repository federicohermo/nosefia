extends GdUnitTestSuite

const Mapa := preload("res://src/dominio/almacen/mapa_del_corte.gd")


func _jornadas() -> Array[int]:
	var todas: Array[int] = []
	var primera := ReglasDeLaPartida.PRIMERA_JORNADA
	for jornada in range(primera, primera + ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA):
		todas.append(jornada)
	return todas


func test_solo_la_noche_del_corte_necesita_el_mapa() -> void:
	var mapa := Mapa.new(false)
	for jornada in _jornadas():
		assert_bool(mapa.hace_falta(jornada)).is_equal(
			jornada == AnomaliasDeLaJornada.JORNADA_DEL_CORTE
		)


func test_con_el_mapa_dentro_del_juego_no_hace_falta_nada() -> void:
	var mapa := Mapa.new(true)
	assert_bool(mapa.listo()).is_true()
	assert_bool(mapa.hace_falta(AnomaliasDeLaJornada.JORNADA_DEL_CORTE)).is_false()
	assert_bool(mapa.la_oscuridad_espera()).is_false()
	assert_bool(mapa.empezar()).is_false()


func test_la_oscuridad_espera_hasta_que_el_mapa_llega() -> void:
	var mapa := Mapa.new(false)
	assert_bool(mapa.la_oscuridad_espera()).is_true()
	assert_bool(mapa.empezar()).is_true()
	assert_bool(mapa.la_oscuridad_espera()).is_true()
	mapa.terminar()
	assert_bool(mapa.listo()).is_true()
	assert_bool(mapa.la_oscuridad_espera()).is_false()


func test_un_pedido_en_curso_no_se_repite() -> void:
	var mapa := Mapa.new(false)
	assert_bool(mapa.empezar()).is_true()
	assert_bool(mapa.empezar()).is_false()
	mapa.fallar()
	assert_bool(mapa.empezar()).is_true()


func test_despues_de_un_fallo_espera_antes_de_volver_a_pedir() -> void:
	var mapa := Mapa.new(false)
	mapa.empezar()
	mapa.fallar()
	var espera := mapa.espera_para_reintentar()
	assert_bool(mapa.toca_reintentar(espera / 2.0)).is_false()
	assert_bool(mapa.toca_reintentar(espera)).is_true()


func test_cada_fallo_espera_mas_que_el_anterior() -> void:
	var mapa := Mapa.new(false)
	mapa.empezar()
	mapa.fallar()
	var primera := mapa.espera_para_reintentar()
	mapa.empezar()
	mapa.fallar()
	var segunda := mapa.espera_para_reintentar()
	assert_float(segunda).is_greater(primera)
