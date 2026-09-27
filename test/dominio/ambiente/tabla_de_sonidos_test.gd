## La tabla de sonidos del disco: que cargue, que cubra todos los eventos y que ninguna fila
## salga por un bus que no existe.
##
## **El caso del disco es el que más fácil miente.** Un `.tres` que falta hace abortar la función
## antes de afirmar, y gdUnit4 reporta el caso en verde: por eso acá se afirma primero que la
## tabla **no es nula**, con su mensaje propio, y recién después lo que dice adentro.
extends GdUnitTestSuite

const BUS_INVENTADO := "Efectoss"


func _tabla() -> TablaDeSonidos:
	var tabla := TablaDeSonidos.desde_disco()
	(
		assert_object(tabla)
		. override_failure_message("`%s` no carga o no es una tabla" % TablaDeSonidos.RUTA)
		. is_not_null()
	)
	return tabla


func test_la_tabla_del_disco_carga() -> void:
	assert_object(_tabla()).is_instanceof(TablaDeSonidos)


func test_la_tabla_cubre_todos_los_eventos() -> void:  # AC-AMB-001
	# **Un evento sin fila la pone en rojo, y el rojo dice cuál.** Sin este caso, agregar un valor
	# al `enum` dejaría un sonido que nunca se pide y nada lo diría.
	var tabla := _tabla()
	(
		assert_array(tabla.eventos_sin_fila())
		. override_failure_message(
			"la tabla no cubre los eventos %s" % str(tabla.eventos_sin_fila())
		)
		. is_empty()
	)
	assert_bool(tabla.cubre_todos()).is_true()


func test_cinco_eventos_suenan_con_su_audio_y_su_bus() -> void:
	var tabla := _tabla()
	var esperado := {
		EntradaSonora.Evento.TIMBRE_DEL_COMPRADOR:
		["SFX_EVENTO_Timbre", EntradaSonora.BUS_DE_EFECTOS],
		EntradaSonora.Evento.BOLSA_DEPOSITADA:
		["SFX_NOLEV_Basura_SacarBolsa", EntradaSonora.BUS_DE_EFECTOS],
		EntradaSonora.Evento.PASADA_DADA:
		["SFX_OBJETO_Mopa_DejarYLimpiar", EntradaSonora.BUS_DE_EFECTOS],
		EntradaSonora.Evento.TURNO_CERRADO:
		["SFX_EVENTO_FinJornada", EntradaSonora.BUS_DE_INTERFAZ],
		EntradaSonora.Evento.BOTON_DE_LA_COMPUTADORA:
		["SFX_INTERFAZ_Computadora_Boton", EntradaSonora.BUS_DE_INTERFAZ],
	}
	for evento: EntradaSonora.Evento in esperado:
		var entrada := tabla.de(evento)
		assert_object(entrada).is_not_null()
		if entrada == null:
			continue
		assert_bool(entrada.tiene_sonido()).is_true()
		if entrada.tiene_sonido():
			assert_str(entrada.stream.resource_path.get_file().get_basename()).is_equal(
				esperado[evento][0]
			)
		assert_str(entrada.bus).is_equal(esperado[evento][1])


func test_el_boton_de_la_computadora_lo_dispara_boton_pulsado() -> void:
	var entrada := _tabla().de(EntradaSonora.Evento.BOTON_DE_LA_COMPUTADORA)
	assert_object(entrada).is_not_null()
	if entrada != null:
		assert_str(entrada.senal).is_equal("boton_pulsado")


func test_cerrar_la_jornada_y_abrir_la_computadora_quedan_mudos() -> void:
	# Cerrar el turno también cierra la jornada: si sonaran los dos, sonaría doble.
	var tabla := _tabla()
	for evento in [EntradaSonora.Evento.JORNADA_CERRADA, EntradaSonora.Evento.COMPUTADORA_ABIERTA]:
		assert_bool(tabla.de(evento).tiene_sonido()).is_false()


func test_ninguna_fila_del_disco_sale_por_un_bus_que_no_existe() -> void:
	var tabla := _tabla()
	(
		assert_array(tabla.filas_invalidas())
		. override_failure_message(
			"%d filas salen por un bus no declarado" % tabla.filas_invalidas().size()
		)
		. is_empty()
	)


func test_un_evento_sin_fila_contesta_null_en_vez_de_reventar() -> void:
	# Es la misma forma que `Catalogo.de()`: con `null` el rojo lo produce una aserción, mientras
	# que un error del motor gdUnit4 lo cuenta como *error* y deja el archivo diciendo `PASSED`.
	assert_object(TablaDeSonidos.new().de(EntradaSonora.Evento.TAREA_CUMPLIDA)).is_null()


func test_una_tabla_con_una_fila_invalida_la_nombra() -> void:  # AC-AMB-004
	# El caso de arriba corre sobre una tabla que ya está bien y pasaría igual si no mirara nada.
	# Éste le pasa una que sí la viola.
	var mala := EntradaSonora.new()
	mala.bus = BUS_INVENTADO
	var tabla := TablaDeSonidos.new()
	tabla.entradas = [mala] as Array[EntradaSonora]
	assert_int(tabla.filas_invalidas().size()).is_equal(1)
	assert_bool(tabla.cubre_todos()).is_false()


func test_la_ronda_reparte_por_turno_y_vuelve_al_principio() -> void:
	var ronda := RondaDeVoces.new(3)
	assert_int(ronda.siguiente()).is_equal(0)
	assert_int(ronda.siguiente()).is_equal(1)
	assert_int(ronda.siguiente()).is_equal(2)
	assert_int(ronda.siguiente()).is_equal(0)


func test_una_ronda_sin_voces_queda_vacia_y_no_falla() -> void:  # AC-AMB-007
	# No es un caso del juego: es el que evita que un balance mal escrito divida por cero y se
	# lleve puesta la corrida entera.
	var ronda := RondaDeVoces.new(0)
	assert_int(ronda.voces()).is_equal(0)
	assert_int(ronda.siguiente()).is_equal(-1)
	assert_int(RondaDeVoces.new(-4).voces()).is_equal(0)
