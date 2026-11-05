## Al continuar, la bandeja cuenta como nuevo sólo lo de la jornada que arranca.
extends GdUnitTestSuite

const JEFE := Conversacion.Interlocutor.JEFE
const COMPLETA := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA


func _mensaje(identidad: String, jornada: int, momento: Mensaje.Momento) -> Mensaje:
	var mensaje := Mensaje.new()
	mensaje.identidad = identidad
	mensaje.jornada = jornada
	mensaje.momento = momento
	mensaje.texto = identidad
	return mensaje


func test_continuar_deja_leido_lo_de_jornadas_anteriores() -> void:  # AC-INV-230
	var guion := Conversacion.de(JEFE)
	var bandeja := Bandeja.new([guion])
	bandeja.abrir_jornada(COMPLETA)
	var devolucion := _mensaje("devolucion_previa", COMPLETA - 1, Mensaje.Momento.CIERRE)
	assert_bool(bandeja.recibir(JEFE, devolucion)).is_true()
	var legada := Mensaje.new()
	legada.texto = "legada"
	legada.jornada = 0
	legada.momento = Mensaje.Momento.SIN_FECHA
	assert_bool(bandeja.recibir(JEFE, legada)).is_true()
	var de_la_jornada := guion.mensajes.filter(
		func(mensaje: Mensaje) -> bool: return mensaje.jornada == COMPLETA and mensaje.vale_para([])
	)
	assert_array(de_la_jornada).is_not_empty()
	assert_int(bandeja.no_leidos(JEFE)).is_greater(de_la_jornada.size())
	bandeja.dar_por_leidos_los_anteriores_a(COMPLETA)
	assert_int(bandeja.no_leidos(JEFE)).is_equal(de_la_jornada.size())
	assert_int(bandeja.no_leidos_totales()).is_equal(de_la_jornada.size())
	var mensajes := bandeja.mensajes_de(JEFE)
	assert_object(mensajes[bandeja.primer_no_leido(JEFE)]).is_same(de_la_jornada[0])
	var nuevo := _mensaje("llega_ahora", COMPLETA, Mensaje.Momento.CIERRE)
	assert_bool(bandeja.recibir(JEFE, nuevo)).is_true()
	assert_int(bandeja.no_leidos(JEFE)).is_equal(de_la_jornada.size() + 1)
	assert_bool(bandeja.marcar_leida(JEFE)).is_true()
	assert_int(bandeja.no_leidos(JEFE)).is_zero()
	assert_bool(bandeja.esta_leida(JEFE)).is_true()


func test_lo_que_llega_tras_leer_el_chat_cuenta_pese_a_la_legada_sin_fecha() -> void:  # AC-INV-230
	var bandeja := Bandeja.new([Conversacion.de(JEFE)])
	bandeja.abrir_jornada(COMPLETA)
	var legada := Mensaje.new()
	legada.texto = "legada"
	legada.jornada = 0
	legada.momento = Mensaje.Momento.SIN_FECHA
	assert_bool(bandeja.recibir(JEFE, legada)).is_true()
	bandeja.dar_por_leidos_los_anteriores_a(COMPLETA)
	assert_bool(bandeja.marcar_leida(JEFE)).is_true()
	assert_int(bandeja.no_leidos(JEFE)).is_zero()
	var nuevo := _mensaje("llega_despues", COMPLETA, Mensaje.Momento.CIERRE)
	assert_bool(bandeja.recibir(JEFE, nuevo)).is_true()
	assert_int(bandeja.no_leidos(JEFE)).is_equal(1)
	assert_int(bandeja.no_leidos_totales()).is_equal(1)
	assert_int(bandeja.primer_no_leido(JEFE)).is_equal(bandeja.mensajes_de(JEFE).find(nuevo))
	assert_bool(bandeja.marcar_leida(JEFE)).is_true()
	assert_int(bandeja.no_leidos(JEFE)).is_zero()


func test_continuar_sin_mensajes_de_la_jornada_deja_el_chat_en_cero() -> void:  # AC-INV-230
	var vacio := Conversacion.new()
	vacio.interlocutor = JEFE
	var bandeja := Bandeja.new([vacio])
	bandeja.abrir_jornada(COMPLETA)
	(
		assert_bool(bandeja.recibir(JEFE, _mensaje("vieja", COMPLETA - 1, Mensaje.Momento.CIERRE)))
		. is_true()
	)
	assert_int(bandeja.no_leidos(JEFE)).is_equal(1)
	bandeja.dar_por_leidos_los_anteriores_a(COMPLETA)
	assert_int(bandeja.no_leidos(JEFE)).is_zero()
	assert_int(bandeja.primer_no_leido(JEFE)).is_equal(-1)
