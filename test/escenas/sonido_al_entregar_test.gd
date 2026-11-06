## Lo que suena al entregarle un producto al comprador: lo mismo que ese producto hace al apoyarse.
## Se cuenta qué se le pidió al reproductor, porque el driver de los tests no mezcla.
extends GdUnitTestSuite

const OBJETO := "res://src/escenas/objetos/objeto_agarrable.tscn"
const REPRODUCTOR := "Servicios/AudioDelAlmacen/Reproductor"
const TinYTia := preload("res://test/escenas/tin_y_tia.gd")
const RelojDePrueba := preload("res://test/reloj_de_prueba.gd")

var _almacen: Node3D
var _agarre: Agarre
var _reproductor: ReproductorDeSonidos
var _apoyos: Array[int] = []


func before_test() -> void:
	_almacen = load("res://src/escenas/almacen.tscn").instantiate()
	_almacen.set("_partida", Partida.desde({"jornada": ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA}))
	_almacen.set("compradores_de_la_apertura", TinYTia.en_cualquier_jornada)
	add_child(_almacen)
	_almacen.get_node("Jugador").set_physics_process(false)
	_almacen.get_node("Servicios/RelojDelTurno").set_process(false)
	for _cuadro in 3:
		await get_tree().physics_frame
	_agarre = _almacen.get("_agarre")
	_reproductor = _almacen.get_node(REPRODUCTOR)
	_apoyos.clear()
	_reproductor.sonido_pedido.connect(_anotar)


func after_test() -> void:
	_reproductor.silenciar()
	_almacen.queue_free()
	for _cuadro in 4:
		await get_tree().process_frame


func _anotar(evento: EntradaSonora.Evento) -> void:
	if evento == EntradaSonora.Evento.OBJETO_SOLTADO:
		_apoyos.append(1)


## Deja la primera entrada dicha, para que la ventanilla ya reciba productos.
func _atender() -> Atencion:
	var atenciones: Ventanilla = _almacen.get("_atenciones")
	RelojDePrueba.avanzar_hasta(_almacen.get("_reloj"), Vector2i(20, 30))
	atenciones.pedir_interaccion(null)
	while not atenciones.puede_abandonar():
		atenciones.pedir_interaccion(null)
	assert_bool(atenciones.atencion().conversacion_iniciada()).is_true()
	return atenciones.atencion()


## Le entrega al comprador lo que lleva en la mano, como el clic sobre la ventanilla.
func _entregar_lo_que_se_lleva() -> void:
	_almacen.get_node("Estructura/Ventanilla").call("_al_pulsar")


## Si alguna voz del espacio quedó pedida con una variante de la fila de ese producto, y desde la
## ventanilla.
func _suena_como_apoyo_de(producto: Producto) -> bool:
	var fila := _reproductor.tabla().de(
		EntradaSonora.Evento.OBJETO_SOLTADO, Catalogo.sonoridad_de(producto.id)
	)
	assert_object(fila).is_not_null()
	var lugar: Marker3D = _almacen.get_node("Estructura/Ventanilla").get("apoyo_de_entregas")
	for voz in _reproductor.voces_en_el_espacio():
		for indice in fila.cantidad_de_variantes():
			if (
				voz.stream == fila.variante(indice)
				and voz.global_position.is_equal_approx(lugar.global_position)
			):
				return true
	return false


func test_cada_producto_entregado_suena_una_vez_como_al_apoyarse_en_la_ventanilla() -> void:
	var atendida := _atender()
	var productos: Array[Producto] = atendida.comprador().pedido().productos()
	for producto in productos:
		_reproductor.silenciar()
		var antes := _apoyos.size()
		_almacen.get("_reposicion_manual").retirar(producto.id)
		assert_object(_agarre.cuerpo_sostenido()).is_not_null()
		_entregar_lo_que_se_lleva()
		assert_object(_agarre.cuerpo_sostenido()).is_null()
		assert_int(_apoyos.size() - antes).is_equal(1)
		assert_bool(_suena_como_apoyo_de(producto)).is_true()


func test_el_producto_que_el_comprador_rechaza_no_suena() -> void:
	var atendida := _atender()
	var pedidos: Array[Producto] = atendida.comprador().pedido().productos()
	var ajeno: Producto = null
	for candidato in Catalogo.todos():
		if not pedidos.has(candidato):
			ajeno = candidato
			break
	assert_object(ajeno).is_not_null()
	var cuerpo: ObjetoAgarrable = auto_free(load(OBJETO).instantiate())
	cuerpo.datos = UnidadDeProducto.new(ajeno)
	_almacen.add_child(cuerpo)
	assert_bool(_agarre.pedir_agarrar(cuerpo.datos, cuerpo)).is_true()
	_entregar_lo_que_se_lleva()
	assert_object(_agarre.cuerpo_sostenido()).is_same(cuerpo)
	assert_int(_apoyos.size()).is_zero()


func test_entregar_el_ticket_no_suena_como_producto() -> void:
	var atendida := _atender()
	var productos: Array[Producto] = atendida.comprador().pedido().productos()
	for producto in productos:
		_almacen.get("_reposicion_manual").retirar(producto.id)
		_entregar_lo_que_se_lleva()
	var antes := _apoyos.size()
	var ticket: ObjetoAgarrable = auto_free(load(OBJETO).instantiate())
	ticket.datos = Ticket.new(productos)
	_almacen.add_child(ticket)
	assert_bool(_agarre.pedir_agarrar(ticket.datos, ticket)).is_true()
	_entregar_lo_que_se_lleva()
	assert_object(_agarre.cuerpo_sostenido()).is_null()
	assert_int(_apoyos.size()).is_equal(antes)
