## Una fila de la tabla: cuándo tiene sonido y cuándo puede sonar por donde dice.
extends GdUnitTestSuite

const ENTRADA := "res://src/dominio/ambiente/entrada_sonora.gd"

## Un bus que no está declarado en ningún lado. Es la forma exacta del bug que este archivo
## existe para cerrar: un `AudioStreamPlayer` con este bus no tira ningún error y sale por
## `Master`, medido.
const BUS_INVENTADO := "Efectoss"


func _entrada(bus: String = EntradaSonora.BUS_DE_EFECTOS) -> EntradaSonora:
	var entrada := EntradaSonora.new()
	entrada.bus = bus
	return entrada


func test_una_fila_sin_stream_no_tiene_sonido() -> void:
	# Es un estado normal mientras el sonido no esté elegido: que la fila exista igual es lo que
	# permite que agregarlo después no toque código.
	assert_bool(_entrada().tiene_sonido()).is_false()


func test_una_fila_con_stream_tiene_sonido() -> void:
	var entrada := _entrada()
	entrada.stream = AudioStreamGenerator.new()
	assert_bool(entrada.tiene_sonido()).is_true()


func test_una_fila_con_un_bus_declarado_es_valida() -> void:
	for bus: String in EntradaSonora.BUSES:
		(
			assert_bool(_entrada(bus).es_valida())
			. override_failure_message("`%s` está declarado y la fila lo rechaza" % bus)
			. is_true()
		)


func test_una_fila_con_un_bus_que_no_existe_no_es_valida() -> void:  # AC-AMB-004
	# **Es el bug que no se ve**: el motor no dice nada y el sonido sale por `Master`. Por eso la
	# fila se rechaza en vez de sonar por el canal equivocado.
	assert_bool(_entrada(BUS_INVENTADO).es_valida()).is_false()
	assert_bool(_entrada("").es_valida()).is_false()


func test_el_bus_maestro_no_es_uno_de_los_cuatro() -> void:  # AC-AMB-003
	# `Master` es el destino de los cuatro, no un canal más: una fila que saliera por él se
	# saltearía la mezcla entera sin que nada lo diga.
	assert_bool(EntradaSonora.BUSES.has(EntradaSonora.BUS_MAESTRO)).is_false()
	assert_int(EntradaSonora.BUSES.size()).is_equal(4)


func test_una_fila_sin_senal_no_tiene_fuente() -> void:  # AC-AMB-005
	var entrada := _entrada()
	assert_bool(entrada.tiene_fuente()).is_false()
	entrada.senal = &"tarea_completada"
	assert_bool(entrada.tiene_fuente()).is_true()


func test_los_eventos_estan_enumerados_en_un_solo_lugar() -> void:  # AC-AMB-002
	# El `enum` es el único lugar donde están: un sistema con su propia lista se desincronizaría
	# el día que se agregue un sonido, y el síntoma sería un evento que nunca suena.
	assert_int(EntradaSonora.Evento.size()).is_greater(0)
	var texto := FileAccess.get_file_as_string(ENTRADA)
	assert_str(texto).is_not_empty()
	assert_bool(texto.contains("enum Evento")).is_true()


func test_el_consumo_de_tiempo_del_turno_no_es_un_evento() -> void:  # AC-AMB-002
	# Es la señal que el reloj emite en cada cuadro: con una fila, sonaría una vez por cuadro.
	for evento: String in EntradaSonora.Evento.keys():
		assert_str(evento).not_contains("TIEMPO")
		assert_str(evento).not_contains("CONSUM")


func test_lo_nuevo_va_al_final_y_no_renumera_lo_que_habia() -> void:
	# Los `.tres` guardan el evento y la sonoridad por número. Un valor metido en el medio le
	# cambiaría el significado a cada fila de abajo sin que el archivo cambie un byte.
	assert_int(EntradaSonora.Sonoridad.MOPA).is_equal(8)
	assert_int(EntradaSonora.Sonoridad.BALDE).is_equal(9)
	assert_int(EntradaSonora.Evento.PORTON_TRABADO).is_equal(22)
	(
		assert_array(
			[
				EntradaSonora.Evento.BALDE_LLENADO,
				EntradaSonora.Evento.BALDE_TENIDO,
				EntradaSonora.Evento.BALDE_VACIADO,
				EntradaSonora.Evento.MOPA_MOJADA,
				EntradaSonora.Evento.UNIDAD_DEVUELTA,
			]
		)
		. is_equal([23, 24, 25, 26, 27])
	)


func test_devolver_es_un_evento_de_objeto_y_los_gestos_con_el_balde_no() -> void:
	# Un evento de objeto tiene una fila por sonoridad. Los gestos con el balde no traen el balde,
	# así que no tienen de dónde sacar una.
	var devolver := EntradaSonora.Evento.UNIDAD_DEVUELTA
	assert_bool(EntradaSonora.EVENTOS_DE_OBJETO.has(devolver)).is_true()
	for gesto: EntradaSonora.Evento in [
		EntradaSonora.Evento.BALDE_LLENADO,
		EntradaSonora.Evento.BALDE_TENIDO,
		EntradaSonora.Evento.BALDE_VACIADO,
		EntradaSonora.Evento.MOPA_MOJADA,
	]:
		assert_bool(EntradaSonora.EVENTOS_DE_OBJETO.has(gesto)).is_false()
