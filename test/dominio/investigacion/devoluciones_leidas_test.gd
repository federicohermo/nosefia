## Las devoluciones de Enrique no cuentan como mensajes nuevos al abrir la jornada.
extends GdUnitTestSuite

const JEFE := Conversacion.Interlocutor.JEFE
const PRIMERA := ReglasDeLaPartida.PRIMERA_JORNADA


func _devolucion(jornada: int) -> Mensaje:
	var devolucion := Mensaje.new()
	devolucion.identidad = "devolucion_%d" % jornada
	devolucion.jornada = jornada
	devolucion.momento = Mensaje.Momento.CIERRE
	devolucion.texto = devolucion.identidad
	return devolucion


func test_la_devolucion_de_enrique_no_cuenta_como_nueva_al_abrir_la_jornada() -> void:  # AC-INV-183
	var bandeja := Bandeja.new([Conversacion.de(JEFE)])
	bandeja.abrir_jornada(PRIMERA)
	bandeja.marcar_leida(JEFE)
	var devolucion := _devolucion(PRIMERA)
	assert_bool(bandeja.recibir(JEFE, devolucion)).is_true()
	assert_int(bandeja.no_leidos_totales()).is_equal(1)
	bandeja.abrir_jornada(PRIMERA + 1)
	var propios := Conversacion.de(JEFE).mensajes.filter(
		func(mensaje: Mensaje) -> bool:
			return mensaje.jornada == PRIMERA + 1 and mensaje.vale_para([])
	)
	assert_array(propios).is_not_empty()
	assert_int(bandeja.no_leidos_totales()).is_equal(propios.size())
	assert_bool(bandeja.mensajes_de(JEFE).has(devolucion)).is_true()


func test_una_partida_retomada_no_cuenta_las_devoluciones_como_nuevas() -> void:  # AC-INV-183
	var retomada := Bandeja.new([Conversacion.de(JEFE)])
	var devolucion := _devolucion(PRIMERA)
	retomada.recibir(JEFE, devolucion)
	retomada.abrir_jornada(PRIMERA + 1)
	var mensajes := retomada.mensajes_de(JEFE)
	assert_int(retomada.no_leidos_totales()).is_equal(
		mensajes.size() - mensajes.find(devolucion) - 1
	)
