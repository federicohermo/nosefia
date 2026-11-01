extends GdUnitTestSuite

const Descarga := preload("res://src/sistemas/marco/descarga_del_mapa.gd")
const Mapa := preload("res://src/dominio/almacen/mapa_del_corte.gd")


## Un sistema que no baja nada: cuenta los pedidos y contesta lo que se le diga.
func _sin_red(montar_bien: bool = true) -> Array:
	var sistema: Descarga = auto_free(Descarga.new())
	var pedidos := [0]
	var montados := [0]
	sistema.regla = Mapa.new(false)
	sistema.bajar = func() -> void: pedidos[0] += 1
	sistema.montar = func(_cuerpo: PackedByteArray) -> bool:
		montados[0] += 1
		return montar_bien
	return [sistema, pedidos, montados]


func test_con_el_mapa_dentro_del_juego_no_se_pide_nada() -> void:
	var sistema: Descarga = auto_free(Descarga.new())
	var pedidos := [0]
	sistema.bajar = func() -> void: pedidos[0] += 1
	assert_bool(sistema.preparar(AnomaliasDeLaJornada.JORNADA_DEL_CORTE)).is_true()
	assert_int(pedidos[0]).is_equal(0)


func test_una_noche_que_no_es_la_del_corte_no_lo_pide() -> void:
	var armado := _sin_red()
	var sistema: Descarga = armado[0]
	var pedidos: Array = armado[1]
	assert_bool(sistema.preparar(ReglasDeLaPartida.PRIMERA_JORNADA)).is_false()
	assert_int(pedidos[0]).is_equal(0)


func test_la_noche_del_corte_lo_pide_y_la_oscuridad_espera() -> void:
	var armado := _sin_red()
	var sistema: Descarga = armado[0]
	var pedidos: Array = armado[1]
	assert_bool(sistema.preparar(AnomaliasDeLaJornada.JORNADA_DEL_CORTE)).is_false()
	assert_int(pedidos[0]).is_equal(1)
	assert_bool(sistema.regla.la_oscuridad_espera()).is_true()


func test_el_paquete_montado_avisa_y_cambia_el_estado() -> void:
	var armado := _sin_red()
	var sistema: Descarga = armado[0]
	var montados: Array = armado[2]
	var avisos := [0]
	sistema.lista.connect(func() -> void: avisos[0] += 1)
	sistema.preparar(AnomaliasDeLaJornada.JORNADA_DEL_CORTE)
	sistema.llego(PackedByteArray([1, 2, 3]))
	assert_int(montados[0]).is_equal(1)
	assert_int(avisos[0]).is_equal(1)
	assert_bool(sistema.regla.listo()).is_true()
	assert_bool(sistema.regla.la_oscuridad_espera()).is_false()


func test_un_paquete_que_no_se_puede_montar_cuenta_como_fallo() -> void:
	var armado := _sin_red(false)
	var sistema: Descarga = armado[0]
	var avisos := [0]
	sistema.lista.connect(func() -> void: avisos[0] += 1)
	sistema.preparar(AnomaliasDeLaJornada.JORNADA_DEL_CORTE)
	sistema.llego(PackedByteArray([1]))
	assert_int(avisos[0]).is_equal(0)
	assert_bool(sistema.regla.listo()).is_false()
	assert_bool(sistema.regla.la_oscuridad_espera()).is_true()


func test_despues_de_un_fallo_espera_y_despues_vuelve_a_pedir() -> void:
	var armado := _sin_red()
	var sistema: Descarga = armado[0]
	var pedidos: Array = armado[1]
	sistema.preparar(AnomaliasDeLaJornada.JORNADA_DEL_CORTE)
	assert_int(pedidos[0]).is_equal(1)
	sistema.no_llego()
	var espera: float = sistema.regla.espera_para_reintentar()
	sistema._process(espera / 2.0)
	assert_int(pedidos[0]).is_equal(1)
	sistema._process(espera)
	assert_int(pedidos[0]).is_equal(2)
