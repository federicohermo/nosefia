extends GdUnitTestSuite


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
