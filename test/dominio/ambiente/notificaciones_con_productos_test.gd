extends GdUnitTestSuite


func test_quien_dejo_productos_avisa_el_texto_largo_y_no_el_corto() -> void:  # AC-NTF-033
	var estado := Notificaciones.new()
	estado.se_fue(_comprador(), true)
	assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.CLIENTE_CANSADO_CON_PRODUCTOS])


func test_quien_no_dejo_nada_avisa_el_texto_corto() -> void:  # AC-NTF-033
	var estado := Notificaciones.new()
	estado.se_fue(_comprador(), false)
	assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.CLIENTE_CANSADO])


func test_una_identidad_avisa_una_sola_vez_por_jornada_con_cualquier_texto() -> void:  # AC-NTF-033
	var estado := Notificaciones.new()
	var comprador := _comprador()
	estado.se_fue(comprador, true)
	estado.se_fue(comprador, false)
	assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.CLIENTE_CANSADO_CON_PRODUCTOS])
	estado.avanzar(Notificaciones.DURACION)
	estado.se_fue(comprador, true)
	assert_array(estado.visibles()).is_empty()
	estado.vaciar()
	estado.se_fue(comprador, false)
	assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.CLIENTE_CANSADO])


func test_el_texto_largo_dura_lo_mismo_que_los_demas_avisos() -> void:  # AC-NTF-033
	var estado := Notificaciones.new()
	estado.se_fue(_comprador(), true)
	estado.avanzar(Notificaciones.DURACION - 0.1)
	assert_array(estado.visibles()).has_size(1)
	estado.avanzar(0.1)
	assert_array(estado.visibles()).is_empty()


func test_dos_compradores_distintos_dejan_un_aviso_de_cada_texto() -> void:  # AC-NTF-033
	var estado := Notificaciones.new()
	estado.se_fue(_comprador("Uno"), false)
	estado.se_fue(_comprador("Otro"), true)
	assert_array(estado.visibles()).is_equal(
		[Notificaciones.Tipo.CLIENTE_CANSADO_CON_PRODUCTOS, Notificaciones.Tipo.CLIENTE_CANSADO]
	)


func test_quien_vence_con_productos_retira_su_llegada_pendiente() -> void:  # AC-NTF-033
	var estado := Notificaciones.new()
	var comprador := Compradores.de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA)[0]
	estado.llego(comprador)
	estado.se_fue(comprador, true)
	assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.CLIENTE_CANSADO_CON_PRODUCTOS])


func _comprador(nombre := "Comprador") -> Comprador:
	return Comprador.new(nombre, Venta.new(), 0)
