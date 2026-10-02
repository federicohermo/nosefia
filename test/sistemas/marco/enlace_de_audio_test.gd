## El enlazador: conecta sólo las señales que la fuente declara, con la aridad que informa el
## motor, y declara las que no encontró.
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


func test_enlaza_las_tres_aridades_leyendolas_del_motor() -> void:
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


func test_una_fuente_que_no_declara_la_senal_no_se_enlaza_y_se_declara() -> void:
	var enlace := _enlace(
		[_entrada(EntradaSonora.Evento.TAREA_CUMPLIDA, CON_UN_ARGUMENTO)] as Array[EntradaSonora]
	)
	enlace.enlazar_todo([auto_free(FuenteMuda.new())])
	assert_array(enlace.enlazados()).is_empty()
	assert_bool(enlace.sin_fuente().has(EntradaSonora.Evento.TAREA_CUMPLIDA)).is_true()


func test_los_dos_rubros_parten_el_enum_sin_solaparse() -> void:
	# Todo evento cae en uno de los dos y en uno solo: si se solaparan, un sonido podría estar
	# enlazado y contado como faltante al mismo tiempo, y el rojo no diría nada.
	var enlace := _enlace(
		[_entrada(EntradaSonora.Evento.TAREA_CUMPLIDA, CON_UN_ARGUMENTO)] as Array[EntradaSonora]
	)
	enlace.enlazar_todo([_fuente()])
	var total := enlace.enlazados().size() + enlace.sin_fuente().size()
	assert_int(total).is_equal(EntradaSonora.Evento.size())
	for evento: EntradaSonora.Evento in enlace.enlazados():
		assert_bool(enlace.sin_fuente().has(evento)).is_false()


func test_enlazar_dos_veces_no_duplica_la_conexion() -> void:
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


func test_dos_fuentes_con_la_misma_senal_suenan_las_dos() -> void:
	# Atar sólo la primera dejaría mudas a las otras.
	var enlace := _enlace(
		[_entrada(EntradaSonora.Evento.TAREA_CUMPLIDA, CON_UN_ARGUMENTO)] as Array[EntradaSonora]
	)
	var una := _fuente()
	var otra := _fuente()
	enlace.enlazar_todo([una, otra])
	assert_int(enlace.enlazados().size()).is_equal(1)
	una.tarea_completada.emit(1)
	otra.tarea_completada.emit(2)
	assert_int(_pedidos.size()).is_equal(2)


func test_una_fila_sin_senal_queda_sin_fuente_y_no_rompe_nada() -> void:
	# **Es un estado normal**: el ambiente del local no lo dispara ninguna señal, y por eso su
	# fila deja la señal vacía en vez de nombrar una que no existe.
	var muda := _entrada(EntradaSonora.Evento.AMBIENTE_DEL_LOCAL, &"")
	var enlace := _enlace([muda] as Array[EntradaSonora])
	enlace.enlazar_todo([_fuente()])
	assert_bool(enlace.sin_fuente().has(EntradaSonora.Evento.AMBIENTE_DEL_LOCAL)).is_true()


func test_una_fila_con_un_bus_no_declarado_no_se_enlaza() -> void:
	# Enlazarla dejaría una señal pidiendo un sonido que después se rechaza en cada emisión.
	var mala := _entrada(EntradaSonora.Evento.TAREA_CUMPLIDA, CON_UN_ARGUMENTO)
	mala.bus = "Efectoss"
	var enlace := _enlace([mala] as Array[EntradaSonora])
	enlace.enlazar_todo([_fuente()])
	assert_bool(enlace.sin_fuente().has(EntradaSonora.Evento.TAREA_CUMPLIDA)).is_true()


## Las manos del jugador: avisan qué agarraron y qué soltaron.
class ManosDePrueba:
	extends Node

	signal objeto_agarrado(nodo: Node3D)
	signal objeto_soltado(nodo: Node3D)


## Un objeto suelto: contesta sus datos y avisa cada contacto.
class ObjetoDePrueba:
	extends Node3D

	signal contacto_recibido(nodo: Node3D, rapidez: float)

	var datos := ObjetoDelAlmacen.new()

	func interactuar() -> ObjetoDelAlmacen:
		return datos


func test_soltar_no_suena_y_el_objeto_suena_al_tocar_algo() -> void:  # AC-AMB-013
	var alzar := _entrada(EntradaSonora.Evento.OBJETO_AGARRADO, &"objeto_agarrado")
	alzar.sonoridad = EntradaSonora.Sonoridad.LATA
	var dejar := _entrada(EntradaSonora.Evento.OBJETO_SOLTADO, &"contacto_recibido")
	dejar.sonoridad = EntradaSonora.Sonoridad.LATA
	var enlace := _enlace([alzar, dejar] as Array[EntradaSonora])
	var manos: ManosDePrueba = auto_free(ManosDePrueba.new())
	enlace.enlazar_todo([manos])
	var lata: ObjetoDePrueba = auto_free(ObjetoDePrueba.new())
	lata.datos.sonoridad = EntradaSonora.Sonoridad.LATA
	manos.objeto_agarrado.emit(lata)
	assert_array(_pedidos).is_equal([EntradaSonora.Evento.OBJETO_AGARRADO])
	manos.objeto_soltado.emit(lata)
	assert_int(_pedidos.size()).is_equal(1)
	lata.contacto_recibido.emit(lata, ContadorDeGolpes.UMBRAL_DE_GOLPE * 4.0)
	lata.contacto_recibido.emit(lata, ContadorDeGolpes.UMBRAL_DE_GOLPE / 2.0)
	assert_array(_pedidos).is_equal(
		[EntradaSonora.Evento.OBJETO_AGARRADO, EntradaSonora.Evento.OBJETO_SOLTADO]
	)


# AC-AMB-025
func test_los_gestos_con_el_balde_suenan_planos_y_un_uso_sin_efecto_no() -> void:
	# El limpiador de verdad y la tabla del juego: sus señales no traen el balde, así que llegan
	# sin origen, y una fila del espacio se rechazaría por no tener lugar.
	var tabla := TablaDeSonidos.desde_disco()
	assert_object(tabla).is_not_null()
	if tabla == null:
		return
	var enlace := _enlace(tabla.entradas)
	var rechazos := []
	enlace.reproductor.sonido_rechazado.connect(
		func(evento: EntradaSonora.Evento, _motivo: ReproductorDeSonidos.Motivo) -> void:
			rechazos.append(evento)
	)
	var limpiador: Limpiador = auto_free(Limpiador.new())
	limpiador.reloj = auto_free(RelojDelTurno.new())
	limpiador.arrancar(PisoDelLocal.de_la_jornada())
	enlace.enlazar_todo([limpiador])
	var balde := ReglasDeLaLimpieza.ID_DEL_BALDE
	var mopa := ReglasDeLaLimpieza.ID_DE_LA_MOPA
	# Cada uso, en orden. Los que no cambian nada van entre los que sí.
	var usos := [
		[balde, ReglasDeLaLimpieza.ID_DEL_LAVATORIO],
		[balde, ReglasDeLaLimpieza.ID_DEL_LAVATORIO],
		[&"jabon_rosa", balde],
		[&"jabon_amarillo", balde],
		[mopa, balde],
		[balde, ReglasDeLaLimpieza.ID_DEL_INODORO],
		[balde, ReglasDeLaLimpieza.ID_DEL_INODORO],
		[&"jabon_rosa", balde],
		[mopa, balde],
	]
	for uso: Array in usos:
		limpiador.usar(uso[0], uso[1])
	(
		assert_array(_pedidos)
		. is_equal(
			[
				EntradaSonora.Evento.BALDE_LLENADO,
				EntradaSonora.Evento.BALDE_TENIDO,
				EntradaSonora.Evento.MOPA_MOJADA,
				EntradaSonora.Evento.BALDE_VACIADO,
			]
		)
	)
	assert_array(rechazos).is_empty()
	var planas := 0
	for voz in enlace.reproductor.voces():
		if voz.stream != null:
			planas += 1
	assert_int(planas).is_equal(4)
	for voz in enlace.reproductor.voces_en_el_espacio():
		assert_object(voz.stream).is_null()


func _anotar_pedido(evento: EntradaSonora.Evento) -> void:
	_pedidos.append(evento)
