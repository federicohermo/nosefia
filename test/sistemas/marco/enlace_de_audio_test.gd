## El enlazador: conecta sólo las señales que la fuente declara, con la aridad que informa el
## motor, y declara las que no encontró.
##
## **Las fuentes son nodos inventados acá adentro.** Es lo que prueba que este spec no nombra una
## sola clase de los otros siete: si un caso necesitara al reloj o al repositor, el enlace estaría
## atado a ellos y una señal que cambie de nombre allá rompería acá.
extends GdUnitTestSuite

const SIN_ARGUMENTOS := &"campanita"
const CON_UN_ARGUMENTO := &"tarea_completada"
const CON_DOS_ARGUMENTOS := &"jornada_cerrada"


## Una fuente de prueba con tres señales de aridad distinta. La aridad es lo que el enlazador
## tiene que leer del motor: escrita a mano se desincroniza el día que una señal gane un
## parámetro, y el síntoma sería una conexión que falla recién en runtime.
class FuenteDePrueba:
	extends Node

	signal campanita
	signal tarea_completada(cumplidas: int)
	signal jornada_cerrada(jornada: int, cumplidas: int)


## Una fuente que no declara ninguna de las tres.
class FuenteMuda:
	extends Node

	signal otra_cosa


var _pedidos: Array = []


func before_test() -> void:
	_pedidos = []


func _entrada(evento: EntradaSonora.Evento, senal: StringName) -> EntradaSonora:
	var entrada := EntradaSonora.new()
	entrada.evento = evento
	entrada.senal = senal
	entrada.bus = EntradaSonora.BUS_DE_EFECTOS
	entrada.stream = AudioStreamGenerator.new()
	return entrada


func _enlace(entradas: Array[EntradaSonora]) -> EnlaceDeAudio:
	var reproductor: ReproductorDeSonidos = auto_free(ReproductorDeSonidos.new())
	add_child(reproductor)
	var tabla := TablaDeSonidos.new()
	tabla.entradas = entradas
	reproductor.arrancar(tabla)
	reproductor.sonido_pedido.connect(_anotar_pedido)

	var enlace: EnlaceDeAudio = auto_free(EnlaceDeAudio.new())
	enlace.reproductor = reproductor
	enlace.arrancar(tabla)
	return enlace


func _fuente() -> FuenteDePrueba:
	var fuente: FuenteDePrueba = auto_free(FuenteDePrueba.new())
	return fuente


func test_enlaza_las_tres_aridades_leyendolas_del_motor() -> void:  # 021-AC8
	# Sin `unbind()`, conectar una señal de dos parámetros a un método de uno falla **en
	# runtime** — que es justo cuando ya no hay nadie mirando.
	var enlace := _enlace(
		(
			[
				_entrada(EntradaSonora.Evento.TIMBRE_DEL_COMPRADOR, SIN_ARGUMENTOS),
				_entrada(EntradaSonora.Evento.TAREA_CUMPLIDA, CON_UN_ARGUMENTO),
				_entrada(EntradaSonora.Evento.JORNADA_CERRADA, CON_DOS_ARGUMENTOS),
			]
			as Array[EntradaSonora]
		)
	)
	var fuente := _fuente()
	enlace.enlazar_todo([fuente])
	assert_int(enlace.enlazados().size()).is_equal(3)

	fuente.campanita.emit()
	fuente.tarea_completada.emit(3)
	fuente.jornada_cerrada.emit(1, 5)
	assert_int(_pedidos.size()).is_equal(3)


func test_una_fuente_que_no_declara_la_senal_no_se_enlaza_y_se_declara() -> void:  # 021-AC9
	var enlace := _enlace(
		[_entrada(EntradaSonora.Evento.TAREA_CUMPLIDA, CON_UN_ARGUMENTO)] as Array[EntradaSonora]
	)
	enlace.enlazar_todo([auto_free(FuenteMuda.new())])
	assert_array(enlace.enlazados()).is_empty()
	assert_bool(enlace.sin_fuente().has(EntradaSonora.Evento.TAREA_CUMPLIDA)).is_true()


func test_los_dos_rubros_parten_el_enum_sin_solaparse() -> void:  # 021-AC9
	# Todo evento cae en uno de los dos y en uno solo: si se solaparan, un sonido podría estar
	# enlazado y contado como faltante al mismo tiempo, y el rojo no diría nada.
	var enlace := _enlace(
		[_entrada(EntradaSonora.Evento.TAREA_CUMPLIDA, CON_UN_ARGUMENTO)] as Array[EntradaSonora]
	)
	enlace.enlazar_todo([_fuente()])
	var total := enlace.enlazados().size() + enlace.sin_fuente().size()
	assert_int(total).is_equal(EntradaSonora.Evento.size())
	for evento in enlace.enlazados():
		assert_bool(enlace.sin_fuente().has(evento)).is_false()


func test_enlazar_dos_veces_no_duplica_la_conexion() -> void:  # 021-AC9
	# De esto se agarra el cableado para poder rehacer el enlace al abrir cada jornada sin que el
	# mismo sonido se pida dos veces por evento.
	var enlace := _enlace(
		[_entrada(EntradaSonora.Evento.TAREA_CUMPLIDA, CON_UN_ARGUMENTO)] as Array[EntradaSonora]
	)
	var fuente := _fuente()
	enlace.enlazar_todo([fuente])
	enlace.enlazar_todo([fuente])
	assert_int(enlace.enlazados().size()).is_equal(1)
	fuente.tarea_completada.emit(2)
	assert_int(_pedidos.size()).is_equal(1)


func test_una_fila_sin_senal_queda_sin_fuente_y_no_rompe_nada() -> void:  # 021-AC9
	# **Es un estado normal**: el ambiente del local no lo dispara ninguna señal, y por eso su
	# fila deja la señal vacía en vez de nombrar una que no existe.
	var muda := _entrada(EntradaSonora.Evento.AMBIENTE_DEL_LOCAL, &"")
	var enlace := _enlace([muda] as Array[EntradaSonora])
	enlace.enlazar_todo([_fuente()])
	assert_bool(enlace.sin_fuente().has(EntradaSonora.Evento.AMBIENTE_DEL_LOCAL)).is_true()


func test_una_fila_con_un_bus_no_declarado_no_se_enlaza() -> void:  # 021-AC9
	# Enlazarla dejaría una señal pidiendo un sonido que después se rechaza en cada emisión.
	var mala := _entrada(EntradaSonora.Evento.TAREA_CUMPLIDA, CON_UN_ARGUMENTO)
	mala.bus = "Efectoss"
	var enlace := _enlace([mala] as Array[EntradaSonora])
	enlace.enlazar_todo([_fuente()])
	assert_bool(enlace.sin_fuente().has(EntradaSonora.Evento.TAREA_CUMPLIDA)).is_true()


func _anotar_pedido(evento: EntradaSonora.Evento) -> void:
	_pedidos.append(evento)
