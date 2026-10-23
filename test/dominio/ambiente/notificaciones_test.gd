extends GdUnitTestSuite


func test_la_llegada_fisica_espera_a_que_se_inicie_su_conversacion() -> void:  # AC-NTF-012
	var estado := Notificaciones.new()
	var comprador := Compradores.de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA)[0]
	estado.llego(comprador)
	estado.avanzar(30.0)
	assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.CLIENTE])
	estado.atendido(Compradores.de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA)[1])
	assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.CLIENTE])
	estado.atendido(comprador)
	assert_array(estado.visibles()).is_empty()
	estado.llego(comprador)
	assert_array(estado.visibles()).is_empty()
	estado.vaciar()
	estado.llego(comprador)
	assert_array(estado.visibles()).has_size(1)
	estado.se_fue(comprador)
	assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.CLIENTE_CANSADO])


func test_la_salida_se_deduplica_dura_tres_segundos_y_se_reinicia() -> void:  # AC-NTF-011
	var estado := Notificaciones.new()
	var comprador := _comprador()
	estado.llego(comprador)
	estado.se_fue(comprador)
	assert_array(estado.visibles()).is_equal(
		[Notificaciones.Tipo.CLIENTE_CANSADO, Notificaciones.Tipo.CLIENTE]
	)
	estado.avanzar(2.9)
	estado.se_fue(comprador)
	assert_array(estado.visibles()).has_size(2)
	estado.avanzar(0.1)
	assert_array(estado.visibles()).is_empty()
	estado.se_fue(comprador)
	assert_array(estado.visibles()).is_empty()
	estado.vaciar()
	estado.se_fue(comprador)
	assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.CLIENTE_CANSADO])


func _comprador() -> Comprador:
	return Comprador.new("Comprador", Venta.new(), 0)


func test_reabrir_con_el_mismo_comprador_no_reinicia_el_aviso() -> void:  # AC-NTF-001
	var estado := Notificaciones.new()
	var comprador := _comprador()
	estado.llego(comprador)
	estado.avanzar(2.0)
	estado.llego(comprador)
	assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.CLIENTE])
	estado.avanzar(1.0)
	assert_array(estado.visibles()).is_empty()


func test_otro_comprador_renueva_el_tipo_sin_duplicarlo() -> void:  # AC-NTF-001
	var estado := Notificaciones.new()
	estado.llego(_comprador())
	estado.avanzar(2.0)
	estado.llego(_comprador())
	estado.avanzar(2.9)
	assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.CLIENTE])
	estado.avanzar(0.1)
	assert_array(estado.visibles()).is_empty()


func test_un_comprador_ya_avisado_tampoco_avisa_despues_de_vencer() -> void:  # AC-NTF-001
	var estado := Notificaciones.new()
	var comprador := _comprador()
	estado.llego(comprador)
	estado.avanzar(3.0)
	estado.llego(comprador)
	assert_array(estado.visibles()).is_empty()


func test_el_lector_avisa_solo_por_renglones_llenos() -> void:  # AC-NTF-002
	var estado := Notificaciones.new()
	estado.lectura_rechazada(GeneradorDeTickets.Resultado.NO_ES_PRODUCTO)
	estado.lectura_rechazada(GeneradorDeTickets.Resultado.ANOTADO)
	estado.lectura_rechazada(GeneradorDeTickets.Resultado.SIN_LECTOR)
	assert_array(estado.visibles()).is_empty()
	estado.lectura_rechazada(GeneradorDeTickets.Resultado.LLENO)
	assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.LECTURA_FALLIDA])
	estado.avanzar(2.0)
	for motivo: GeneradorDeTickets.Resultado in [
		GeneradorDeTickets.Resultado.NO_ES_PRODUCTO,
		GeneradorDeTickets.Resultado.ANOTADO,
		GeneradorDeTickets.Resultado.SIN_LECTOR,
	]:
		estado.lectura_rechazada(motivo)
	estado.avanzar(1.0)
	assert_array(estado.visibles()).is_empty()


func test_el_aviso_sigue_a_2_9_y_sale_a_3_0() -> void:  # AC-NTF-003
	var estado := Notificaciones.new()
	estado.llego(_comprador())
	estado.avanzar(2.9)
	assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.CLIENTE])
	estado.avanzar(0.1)
	assert_array(estado.visibles()).is_empty()


func test_un_cuadro_largo_saca_todos_los_avisos() -> void:  # AC-NTF-003
	var estado := Notificaciones.new()
	estado.llego(_comprador())
	estado.lectura_rechazada(GeneradorDeTickets.Resultado.LLENO)
	estado.avanzar(10.0)
	assert_array(estado.visibles()).is_empty()
	estado.llego(_comprador())
	estado.avanzar(2.9)
	assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.CLIENTE])


func test_repetir_el_tipo_lo_pone_primero_y_reinicia_solo_su_tiempo() -> void:  # AC-NTF-004
	var estado := Notificaciones.new()
	estado.lectura_rechazada(GeneradorDeTickets.Resultado.LLENO)
	estado.avanzar(2.0)
	estado.llego(_comprador())
	estado.lectura_rechazada(GeneradorDeTickets.Resultado.LLENO)
	assert_array(estado.visibles()).is_equal(
		[Notificaciones.Tipo.LECTURA_FALLIDA, Notificaciones.Tipo.CLIENTE]
	)
	estado.avanzar(2.9)
	assert_int(estado.visibles().size()).is_equal(2)
	estado.avanzar(0.1)
	assert_array(estado.visibles()).is_empty()


func test_repetir_un_tipo_no_renueva_el_otro() -> void:  # AC-NTF-004
	var estado := Notificaciones.new()
	estado.llego(_comprador())
	estado.lectura_rechazada(GeneradorDeTickets.Resultado.LLENO)
	estado.avanzar(2.0)
	estado.lectura_rechazada(GeneradorDeTickets.Resultado.LLENO)
	estado.avanzar(1.0)
	assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.LECTURA_FALLIDA])
	estado.avanzar(1.9)
	assert_int(estado.visibles().size()).is_equal(1)
	estado.avanzar(0.1)
	assert_array(estado.visibles()).is_empty()


func test_los_tipos_se_ordenan_del_mas_nuevo_al_mas_viejo() -> void:  # AC-NTF-005
	var estado := Notificaciones.new()
	estado.llego(_comprador())
	estado.lectura_rechazada(GeneradorDeTickets.Resultado.LLENO)
	assert_array(estado.visibles()).is_equal(
		[Notificaciones.Tipo.LECTURA_FALLIDA, Notificaciones.Tipo.CLIENTE]
	)


func test_vaciar_borra_ambos_tipos_y_olvida_compradores() -> void:  # AC-NTF-006
	var estado := Notificaciones.new()
	var comprador := _comprador()
	estado.llego(comprador)
	estado.lectura_rechazada(GeneradorDeTickets.Resultado.LLENO)
	estado.vaciar()
	assert_array(estado.visibles()).is_empty()
	estado.llego(comprador)
	assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.CLIENTE])


func test_null_y_avances_no_positivos_no_cambian_el_estado() -> void:  # AC-NTF-007
	var estado := Notificaciones.new()
	estado.llego(null)
	assert_array(estado.visibles()).is_empty()
	estado.llego(_comprador())
	estado.avanzar(2.9)
	estado.avanzar(-10.0)
	estado.avanzar(0.0)
	assert_int(estado.visibles().size()).is_equal(1)
	estado.avanzar(0.1)
	assert_array(estado.visibles()).is_empty()


func test_modificar_la_lista_devuelta_no_borra_lo_visible() -> void:  # AC-NTF-005
	var estado := Notificaciones.new()
	estado.llego(_comprador())
	estado.lectura_rechazada(GeneradorDeTickets.Resultado.LLENO)
	var copia := estado.visibles()
	copia.clear()
	assert_array(estado.visibles()).is_equal(
		[Notificaciones.Tipo.LECTURA_FALLIDA, Notificaciones.Tipo.CLIENTE]
	)


func test_las_siete_avisan_sin_renovarse_por_otra_lectura() -> void:  # AC-NTF-020
	var estado := Notificaciones.new()
	estado.actualizar_tiempo(3601.0)
	assert_array(estado.visibles()).is_empty()
	assert_str(Marcador.hora(3600.0)).is_equal("07:00")
	estado.actualizar_tiempo(3600.0)
	assert_array(estado.visibles()).has_size(1)
	estado.avanzar(2.0)
	estado.actualizar_tiempo(3600.0)
	estado.actualizar_tiempo(3599.0)
	assert_array(estado.visibles()).has_size(1)
	estado.avanzar(1.0)
	assert_array(estado.visibles()).is_empty()


func test_saltar_el_umbral_o_entrar_despues_avisa_una_vez() -> void:  # AC-NTF-021
	var estado := Notificaciones.new()
	estado.actualizar_tiempo(3660.0)
	assert_array(estado.visibles()).is_empty()
	estado.actualizar_tiempo(3540.0)
	assert_array(estado.visibles()).has_size(1)
	var iniciado_tarde := Notificaciones.new()
	iniciado_tarde.actualizar_tiempo(3540.0)
	assert_array(iniciado_tarde.visibles()).is_equal(estado.visibles())
	for restante: float in [0.0, -1.0]:
		var cerrado := Notificaciones.new()
		cerrado.actualizar_tiempo(3660.0)
		cerrado.actualizar_tiempo(restante)
		assert_array(cerrado.visibles()).is_empty()


func test_vencer_no_habilita_otro_aviso_y_otra_noche_si() -> void:  # AC-NTF-022
	var estado := Notificaciones.new()
	for _jornada in range(1, 6):
		estado.actualizar_tiempo(3600.0)
		assert_array(estado.visibles()).has_size(1)
		estado.avanzar(2.9)
		assert_array(estado.visibles()).has_size(1)
		estado.avanzar(0.1)
		assert_array(estado.visibles()).is_empty()
		estado.actualizar_tiempo(100.0)
		assert_array(estado.visibles()).is_empty()
		estado.vaciar()


func test_cierre_proximo_no_temporiza_ni_renueva_otros_avisos() -> void:  # AC-NTF-025
	var estado := Notificaciones.new()
	var esperando := Compradores.de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA)[0]
	estado.llego(esperando)
	estado.se_fue(_comprador())
	estado.lectura_rechazada(GeneradorDeTickets.Resultado.LLENO)
	var anteriores := estado.visibles()
	estado.avanzar(1.0)
	estado.actualizar_tiempo(3600.0)
	var juntos := estado.visibles()
	assert_array(juntos).has_size(4)
	assert_array(juntos.slice(1)).is_equal(anteriores)
	estado.lectura_rechazada(GeneradorDeTickets.Resultado.LLENO)
	assert_array(estado.visibles()).has_size(4)
	assert_int(estado.visibles()[0]).is_equal(Notificaciones.Tipo.LECTURA_FALLIDA)
	estado.avanzar(2.0)
	assert_array(estado.visibles()).has_size(3)
	estado.avanzar(1.0)
	assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.CLIENTE])
	estado.vaciar()
	assert_array(estado.visibles()).is_empty()


# AC-NTF-014, AC-NTF-016
func test_una_pista_avisa_una_vez_por_cuadro_y_el_cierre_la_retira() -> void:
	var estado := Notificaciones.new()
	estado.pista_anotada()
	estado.pista_anotada()
	assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.PISTA])
	estado.avanzar(2.9)
	assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.PISTA])
	estado.avanzar(0.1)
	assert_array(estado.visibles()).is_empty()
	estado.pista_anotada()
	estado.avanzar(10.0)
	assert_array(estado.visibles()).is_empty()
	estado.pista_anotada()
	estado.vaciar()
	assert_array(estado.visibles()).is_empty()


func test_otra_pista_renueva_solo_su_tipo_y_convive_en_orden() -> void:  # AC-NTF-015
	var estado := Notificaciones.new()
	estado.pista_anotada()
	estado.lectura_rechazada(GeneradorDeTickets.Resultado.LLENO)
	estado.avanzar(2.0)
	estado.pista_anotada()
	assert_array(estado.visibles()).is_equal(
		[Notificaciones.Tipo.PISTA, Notificaciones.Tipo.LECTURA_FALLIDA]
	)
	estado.avanzar(1.0)
	assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.PISTA])
	estado.avanzar(1.9)
	assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.PISTA])
	estado.avanzar(0.1)
	assert_array(estado.visibles()).is_empty()
	estado.pista_anotada()
	estado.llego(_comprador())
	estado.lectura_rechazada(GeneradorDeTickets.Resultado.LLENO)
	(
		assert_array(estado.visibles())
		. is_equal(
			[
				Notificaciones.Tipo.LECTURA_FALLIDA,
				Notificaciones.Tipo.CLIENTE,
				Notificaciones.Tipo.PISTA,
			]
		)
	)
