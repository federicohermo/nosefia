## Con la física real: el jugador suelta con el clic en toda la abertura, se espera a que el cuerpo
## se aquiete y se mira en qué habitación terminó. Un cuadro después de soltar no alcanza: lo que
## cae sobre el marco todavía está adentro, y sale recién al rodar.
extends GdUnitTestSuite

const OBJETO := "res://src/escenas/objetos/objeto_agarrable.tscn"
const RelojDePrueba := preload("res://test/reloj_de_prueba.gd")
const ReglasDelCierre := preload("res://src/dominio/almacen/reglas_del_cierre.gd")
const Habitaciones := preload("res://src/escenas/puestos/habitaciones_del_almacen.gd")

## Cuántos pasos de física se le dan a un cuerpo para aquietarse.
const PASOS_PARA_AQUIETARSE := 600

## A qué distancia del plano de la abertura se para el jugador, y qué tan al costado.
const PARADAS_CERCA: Array[Vector2] = [
	Vector2(0.0, 0.45),
	Vector2(0.6, 0.45),
	Vector2(0.0, 0.7),
	Vector2(-0.6, 0.7),
	Vector2(0.6, 0.7),
	Vector2(0.0, 1.0),
]
const UNA_PARADA: Array[Vector2] = [Vector2(0.0, 0.7)]

var _almacenes: Array[Node3D] = []


func after_test() -> void:
	for almacen in _almacenes:
		almacen.get_node("Servicios/AudioDelAlmacen/Reproductor").silenciar()
		almacen.queue_free()
	_almacenes.clear()
	for _cuadro in 4:
		await get_tree().process_frame


func _abrir() -> Node3D:
	var almacen: Node3D = load("res://src/escenas/almacen.tscn").instantiate()
	almacen.set("_partida", Partida.nueva())
	_almacenes.append(almacen)
	add_child(almacen)
	almacen.get_node("Servicios/RelojDelTurno").set_process(false)
	for _cuadro in 3:
		await get_tree().physics_frame
	return almacen


func _puesto(almacen: Node3D) -> Node3D:
	return almacen.get_node("Estructura/Ventanilla")


func _llegar(almacen: Node3D) -> Atencion:
	RelojDePrueba.avanzar_hasta(almacen.get("_reloj"), Vector2i(20, 30))
	var atendida := (almacen.get("_atenciones") as Ventanilla).atencion()
	assert_object(atendida).is_not_null()
	assert_bool(atendida.fisica()).is_true()
	assert_bool(atendida.despachada()).is_false()
	return atendida


## Un producto que el comprador no pidió: ningún intento lo acepta, y sirve para todos los puntos.
func _producto_ajeno(almacen: Node3D, atendida: Atencion) -> RigidBody3D:
	var pedidos: Array[Producto] = []
	if atendida != null:
		pedidos = atendida.comprador().pedido().productos()
	var ajeno: Producto = null
	for candidato in Catalogo.de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA):
		if not pedidos.has(candidato):
			ajeno = candidato
			break
	assert_object(ajeno).is_not_null()
	almacen.get("_reposicion_manual").retirar(ajeno.id)
	var cuerpo: RigidBody3D = (almacen.get("_agarre") as Agarre).cuerpo_sostenido()
	assert_object(cuerpo).is_not_null()
	return cuerpo


## El comprador vuelve a estar como antes del primer clic, con su entrada ya hecha o no.
func _sin_atender(almacen: Node3D, atendida: Atencion, entrando: bool) -> void:
	var puesto := _puesto(almacen)
	atendida.set("_presentado", false)
	atendida.set("_dialogo", null)
	atendida.set("_inicial_terminada", false)
	atendida.set("_de_entrega", false)
	puesto.call("cerrar")
	if entrando:
		puesto.call("_iniciar_entrada")
	else:
		_terminar_la_entrada(puesto)


## La conversación inicial ya terminó y queda sólo entregar.
func _por_entregar(almacen: Node3D, atendida: Atencion) -> void:
	var puesto := _puesto(almacen)
	atendida.set("_presentado", true)
	atendida.set("_dialogo", null)
	atendida.set("_inicial_terminada", true)
	atendida.set("_de_entrega", false)
	puesto.call("cerrar")
	_terminar_la_entrada(puesto)


func _terminar_la_entrada(puesto: Node3D) -> void:
	var entrada: Tween = puesto.get("_entrada")
	if entrada != null and entrada.is_valid():
		entrada.custom_step(20.0)


## Los puntos del plano de la abertura y los de la pared que la rodea, medidos desde el puesto.
## Se leen de la escena: el ancho del antepecho y la altura del borde superior.
func _puntos(puesto: Node3D) -> Dictionary[Vector3, bool]:
	var lado: float = (puesto.get("antepecho") as MeshInstance3D).get_aabb().size.x / 2.0
	var alto: float = (puesto.get("borde_superior") as Marker3D).position.y
	var puntos: Dictionary[Vector3, bool] = {}
	for x: float in [-lado * 0.97, -lado * 0.6, 0.0, lado * 0.6, lado * 0.97]:
		for y: float in [alto * 0.05, alto * 0.35, alto * 0.65, alto * 0.93]:
			puntos[Vector3(x, y, 0.0)] = true
	for x: float in [-lado * 0.6, lado * 0.6]:
		puntos[Vector3(x, alto * 1.1, -0.1)] = false
		puntos[Vector3(x, -0.08, -0.1)] = false
	for y: float in [alto * 0.2, alto * 0.8]:
		puntos[Vector3(-lado * 1.2, y, -0.1)] = false
		puntos[Vector3(lado * 1.2, y, -0.1)] = false
	return puntos


func _mirar(almacen: Node3D, parada: Vector2, punto: Vector3, altura: float) -> void:
	var puesto := _puesto(almacen)
	var jugador: CharacterBody3D = almacen.get_node("Jugador")
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	var lugar: Vector3 = puesto.global_transform * Vector3(parada.x, 0.0, -parada.y)
	lugar.y = altura
	jugador.call("ubicar", Transform3D(Basis.IDENTITY, lugar))
	await get_tree().physics_frame
	await get_tree().physics_frame
	var objetivo: Vector3 = puesto.global_transform * punto
	var direccion := camara.global_position.direction_to(objetivo)
	var yaw := atan2(-direccion.x, -direccion.z)
	jugador.call("ubicar", Transform3D(Basis(Vector3.UP, yaw), jugador.global_position))
	camara.rotation.x = asin(direccion.y)
	for _cuadro in 3:
		await get_tree().physics_frame
	assert_float((-camara.global_basis.z).dot(direccion)).is_greater(0.999)


## Si desde la cámara se ve el punto sin que la pared lo tape: la premisa de cada punto del hueco.
func _a_la_vista(almacen: Node3D, punto: Vector3) -> bool:
	var jugador: CharacterBody3D = almacen.get_node("Jugador")
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	var consulta := PhysicsRayQueryParameters3D.create(
		camara.global_position, _puesto(almacen).global_transform * punto, 1
	)
	consulta.exclude = [jugador.get_rid()]
	return jugador.get_world_3d().direct_space_state.intersect_ray(consulta).is_empty()


func _pulsar_real() -> void:
	for presionado: bool in [true, false]:
		var evento := InputEventMouseButton.new()
		evento.button_index = MOUSE_BUTTON_LEFT
		evento.pressed = presionado
		evento.position = get_viewport().get_visible_rect().get_center()
		evento.global_position = evento.position
		Input.parse_input_event(evento)
		Input.flush_buffered_events()
		await get_tree().process_frame


func _aquietar(almacen: Node3D, cuerpo: RigidBody3D) -> void:
	var agarre: Agarre = almacen.get("_agarre")
	for paso in PASOS_PARA_AQUIETARSE:
		await get_tree().physics_frame
		if agarre.cuerpo_sostenido() == cuerpo:
			return
		if paso > 2 and cuerpo.sleeping:
			return


func _habitacion(almacen: Node3D, cuerpo: Node3D) -> ReglasDelCierre.Habitacion:
	var habitaciones: Habitaciones = almacen.get("_habitaciones")
	return habitaciones.de(cuerpo.global_position)


## Suelta el cuerpo con el clic desde cada parada y cada punto. Devuelve lo que terminó afuera.
func _barrer(
	almacen: Node3D, cuerpo: RigidBody3D, paradas: Array[Vector2], antes: Callable
) -> Array:
	var agarre: Agarre = almacen.get("_agarre")
	var jugador: CharacterBody3D = almacen.get_node("Jugador")
	var altura := jugador.global_position.y
	var puntos := _puntos(_puesto(almacen))
	var afuera: Array[String] = []
	for parada in paradas:
		for punto: Vector3 in puntos:
			antes.call()
			await _mirar(almacen, parada, punto, altura)
			if puntos[punto]:
				assert_bool(_a_la_vista(almacen, punto)).is_true()
			await _pulsar_real()
			await _aquietar(almacen, cuerpo)
			# La mano se asoma por la abertura: lo sostenido no cuenta, no se soltó.
			if agarre.cuerpo_sostenido() == cuerpo:
				continue
			if _habitacion(almacen, cuerpo) == ReglasDelCierre.Habitacion.AFUERA:
				afuera.append("parada %s, punto %s" % [parada, punto])
			assert_bool(agarre.pedir_agarrar(cuerpo.get("datos"), cuerpo)).is_true()
			await get_tree().physics_frame
	return afuera


# AC-CTR-151
func test_con_el_comprador_esperando_ninguna_soltada_termina_afuera() -> void:
	var almacen := await _abrir()
	var atendida := _llegar(almacen)
	var cuerpo := _producto_ajeno(almacen, atendida)
	var afuera := await _barrer(
		almacen, cuerpo, PARADAS_CERCA, _sin_atender.bind(almacen, atendida, false)
	)
	assert_array(afuera).is_empty()


# AC-CTR-151
func test_mientras_entra_el_comprador_ninguna_soltada_termina_afuera() -> void:
	var almacen := await _abrir()
	var atendida := _llegar(almacen)
	var cuerpo := _producto_ajeno(almacen, atendida)
	var afuera := await _barrer(
		almacen, cuerpo, UNA_PARADA, _sin_atender.bind(almacen, atendida, true)
	)
	assert_array(afuera).is_empty()


# AC-CTR-151
func test_con_la_compra_por_entregar_ninguna_soltada_termina_afuera() -> void:
	var almacen := await _abrir()
	var atendida := _llegar(almacen)
	var cuerpo := _producto_ajeno(almacen, atendida)
	var afuera := await _barrer(almacen, cuerpo, UNA_PARADA, _por_entregar.bind(almacen, atendida))
	assert_array(afuera).is_empty()


# AC-CTR-151
func test_con_la_compra_a_medias_ninguna_soltada_termina_afuera() -> void:
	var almacen := await _abrir()
	var atendida := _llegar(almacen)
	_por_entregar(almacen, atendida)
	var pedido: Producto = atendida.comprador().pedido().productos()[0]
	almacen.get("_reposicion_manual").retirar(pedido.id)
	_puesto(almacen).call("_al_pulsar")
	var agarre: Agarre = almacen.get("_agarre")
	assert_object(agarre.cuerpo_sostenido()).is_null()
	var cuerpo := _producto_ajeno(almacen, atendida)
	var afuera := await _barrer(almacen, cuerpo, UNA_PARADA, _por_entregar.bind(almacen, atendida))
	assert_array(afuera).is_empty()


## La misma soltada sale sin comprador: sin este caso, el barrido de arriba no vería nada.
# AC-CTR-151
func test_sin_comprador_la_misma_soltada_termina_afuera() -> void:
	var almacen := await _abrir()
	var cuerpo := _producto_ajeno(almacen, null)
	var afuera := await _barrer(almacen, cuerpo, UNA_PARADA, func() -> void: pass)
	assert_array(afuera).is_not_empty()


## Lo deja adentro, frente a la abertura y en el aire, y le da envión hacia afuera: es lo que le
## pasa a lo que rueda, sin depender de cómo cayó.
func _empujar_por_la_abertura(puesto: Node3D, cuerpo: RigidBody3D) -> void:
	cuerpo.global_position = puesto.global_transform * Vector3(0.0, 0.4, -0.4)
	cuerpo.linear_velocity = puesto.global_basis.z * 3.0
	await get_tree().physics_frame


func test_con_comprador_un_producto_empujado_no_atraviesa_la_abertura() -> void:  # AC-CTR-151
	var almacen := await _abrir()
	_llegar(almacen)
	var cuerpo := _producto_ajeno(almacen, (almacen.get("_atenciones") as Ventanilla).atencion())
	(almacen.get("_agarre") as Agarre).soltar(false)
	await _empujar_por_la_abertura(_puesto(almacen), cuerpo)
	await _aquietar(almacen, cuerpo)
	assert_int(_habitacion(almacen, cuerpo)).is_not_equal(ReglasDelCierre.Habitacion.AFUERA)


func test_sin_comprador_un_producto_empujado_sale_por_la_abertura() -> void:  # AC-CTR-149
	var almacen := await _abrir()
	var cuerpo := _producto_ajeno(almacen, null)
	(almacen.get("_agarre") as Agarre).soltar(false)
	await _empujar_por_la_abertura(_puesto(almacen), cuerpo)
	await _aquietar(almacen, cuerpo)
	assert_int(_habitacion(almacen, cuerpo)).is_equal(ReglasDelCierre.Habitacion.AFUERA)


func test_con_comprador_lo_que_no_es_producto_sale_por_la_abertura() -> void:  # AC-CTR-150
	var almacen := await _abrir()
	_llegar(almacen)
	var ticket: ObjetoAgarrable = load(OBJETO).instantiate()
	ticket.datos = Ticket.new([])
	almacen.add_child(ticket)
	await _empujar_por_la_abertura(_puesto(almacen), ticket)
	await _aquietar(almacen, ticket)
	assert_int(_habitacion(almacen, ticket)).is_equal(ReglasDelCierre.Habitacion.AFUERA)


func test_al_irse_el_comprador_el_producto_vuelve_a_salir() -> void:  # AC-CTR-149
	var almacen := await _abrir()
	var atendida := _llegar(almacen)
	var cuerpo := _producto_ajeno(almacen, atendida)
	(almacen.get("_agarre") as Agarre).soltar(false)
	atendida.vencer()
	(almacen.get("_atenciones") as Ventanilla).comprador_vencido.emit(atendida.comprador())
	await _empujar_por_la_abertura(_puesto(almacen), cuerpo)
	await _aquietar(almacen, cuerpo)
	assert_int(_habitacion(almacen, cuerpo)).is_equal(ReglasDelCierre.Habitacion.AFUERA)


## Lo que frena a los productos no es una pared: la calle se sigue oyendo por la abertura.
func test_con_comprador_la_abertura_no_tapa_el_sonido() -> void:
	var almacen := await _abrir()
	var puesto := _puesto(almacen)
	var reproductor: ReproductorDeSonidos = almacen.get_node(
		"Servicios/AudioDelAlmacen/Reproductor"
	)
	var oido: Vector3 = puesto.global_transform * Vector3(0.6, 0.7, -1.0)
	var calle: Vector3 = puesto.global_transform * Vector3(0.6, 0.7, 1.0)
	var sin_comprador := reproductor.obstaculos_entre(oido, calle, null)
	_llegar(almacen)
	_terminar_la_entrada(puesto)
	assert_bool((puesto.get("comprador_visible") as Node3D).visible).is_true()
	assert_int(reproductor.obstaculos_entre(oido, calle, null)).is_equal(sin_comprador)
