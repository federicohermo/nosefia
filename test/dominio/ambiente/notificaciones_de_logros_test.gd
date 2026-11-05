## El aviso de un logro: su identidad es el logro, y sigue la duración, el orden y el cierre de los
## demás avisos.
extends GdUnitTestSuite

const L := Logros.Logro
const T := Notificaciones.Tipo


func test_un_logro_avisa_y_dura_lo_mismo_que_los_demas() -> void:  # AC-NTF-046
	var estado := Notificaciones.new()
	estado.logro_desbloqueado(L.REBELDE)
	assert_array(estado.visibles()).is_equal([T.LOGRO])
	estado.avanzar(Notificaciones.DURACION - 0.1)
	assert_array(estado.visibles()).is_equal([T.LOGRO])
	estado.avanzar(0.1)
	assert_array(estado.visibles()).is_empty()


func test_dos_logros_distintos_son_dos_avisos_el_mas_nuevo_primero() -> void:  # AC-NTF-046
	var estado := Notificaciones.new()
	estado.logro_desbloqueado(L.REBELDE)
	estado.logro_desbloqueado(L.A_LA_BASURA)
	assert_array(estado.visibles()).is_equal([T.LOGRO, T.LOGRO])
	var avisos := estado.avisos()
	assert_int(Notificaciones.logro_de(avisos[0])).is_equal(L.A_LA_BASURA)
	assert_int(Notificaciones.logro_de(avisos[1])).is_equal(L.REBELDE)


func test_un_logro_convive_con_los_otros_tipos_en_orden() -> void:  # AC-NTF-046
	var estado := Notificaciones.new()
	estado.pista_anotada()
	estado.logro_desbloqueado(L.Y_SE_MARCHO)
	estado.lectura_rechazada(GeneradorDeTickets.Resultado.LLENO)
	assert_array(estado.visibles()).is_equal([T.LECTURA_FALLIDA, T.LOGRO, T.PISTA])
	assert_int(Notificaciones.logro_de(estado.avisos()[1])).is_equal(L.Y_SE_MARCHO)


func test_el_cierre_vacia_los_logros_y_uno_ganado_despues_queda() -> void:  # AC-NTF-046
	var estado := Notificaciones.new()
	estado.logro_desbloqueado(L.REBELDE)
	estado.vaciar()
	assert_array(estado.visibles()).is_empty()
	estado.logro_desbloqueado(L.EMPLEADO_EJEMPLAR)
	assert_array(estado.visibles()).is_equal([T.LOGRO])
	assert_int(Notificaciones.logro_de(estado.avisos()[0])).is_equal(L.EMPLEADO_EJEMPLAR)


func test_un_logro_no_retiene_el_tiempo_de_los_otros() -> void:  # AC-NTF-046
	var estado := Notificaciones.new()
	estado.pista_anotada()
	estado.avanzar(2.0)
	estado.logro_desbloqueado(L.REBELDE)
	estado.avanzar(1.0)
	assert_array(estado.visibles()).is_equal([T.LOGRO])
