## Lo que se dibuja del jugador al girar y caminar: la cámara y lo que lleva en la mano.
##
## Mide en cada cuadro dibujado, no en cada paso de física. La física corre a 60 Hz y el cuadro a
## 144: lo que se ve entre dos pasos es interpolado, y ahí aparecía el temblor. Un test por paso
## de física no lo ve nunca.
##
## El mouse entra por `Input`, como el de verdad: el motor lo reparte al principio del cuadro,
## antes del paso de física. El medidor lee lo dibujado después de todos.
##
## En este piso libre, lo que se lleva no temblaba contra la cámara ni antes del arreglo. Los
## saltos medidos en el local eran del brazo, que corre la mano al rozar un mueble. Los casos
## quedan de testigo: correr la cámara sin correr la caja da 58 mm por cuadro.
extends GdUnitTestSuite

const JUGADOR := preload("res://src/escenas/jugador.tscn")

## El monitor del issue fue a 144 Hz. Con el cuadro sin tope, casi todos caen en el mismo punto
## entre dos pasos de física y el temblor no aparece.
const CUADROS_POR_SEGUNDO := 144

## Píxeles de mouse por cuadro. Con la sensibilidad del dominio dan los 0,018 rad medidos.
const MOUSE_POR_CUADRO := 6.0

## Cuadros de arranque que no se miden: el jugador todavía cae al piso.
const CUADROS_DE_ARRANQUE := 60

## Cuánto puede moverse lo que se lleva respecto de la cámara en un cuadro, en metros.
const TEMBLOR_ADMITIDO := 0.001

var _fps_anterior := 0


class Medidor:
	extends Node

	var camara: Camera3D
	var sostenido: Node3D
	var dibujadas: Array[Transform3D] = []
	var relativos: Array[Vector3] = []

	func _init() -> void:
		process_priority = 1000

	func _process(_delta: float) -> void:
		var vista := camara.get_global_transform_interpolated()
		dibujadas.append(vista)
		if sostenido != null:
			relativos.append(
				vista.affine_inverse() * sostenido.get_global_transform_interpolated().origin
			)


class Mouse:
	extends Node

	func _process(_delta: float) -> void:
		var evento := InputEventMouseMotion.new()
		evento.relative = Vector2(MOUSE_POR_CUADRO, 0.0)
		Input.parse_input_event(evento)


func before_test() -> void:
	_fps_anterior = Engine.max_fps
	Engine.max_fps = CUADROS_POR_SEGUNDO


func after_test() -> void:
	Engine.max_fps = _fps_anterior
	Input.action_release(ReglasDelJugador.ACCION_ADELANTE)


func test_girar_con_el_mouse_dibuja_el_mismo_giro_en_cada_cuadro() -> void:
	var jugador := await _jugador_en_un_piso_libre()
	var medidor := _medir(jugador, null)
	_mover_el_mouse(jugador)
	await _esperar(8.0)
	var pedido := MOUSE_POR_CUADRO * ReglasDelJugador.SENSIBILIDAD_DEL_MOUSE
	var parejos := 0
	var razones: Array[float] = []
	for indice in range(1, medidor.dibujadas.size()):
		var antes := medidor.dibujadas[indice - 1].basis.get_euler().y
		var ahora := medidor.dibujadas[indice].basis.get_euler().y
		var razon := absf(wrapf(ahora - antes, -PI, PI)) / pedido
		razones.append(razon)
		if razon >= 0.9 and razon <= 1.1:
			parejos += 1
	razones.sort()
	(
		assert_float(float(parejos) / razones.size())
		. override_failure_message(
			(
				"sólo %d de %d cuadros dibujan el giro pedido; van de %.2f a %.2f veces"
				% [parejos, razones.size(), razones.front(), razones.back()]
			)
		)
		. is_greater_equal(0.95)
	)


func test_un_producto_en_la_mano_no_tiembla_contra_la_camara() -> void:
	var jugador := await _jugador_en_un_piso_libre()
	var producto := _cuerpo_suelto(jugador)
	var agarre: Agarre = jugador.get("agarre")
	assert_bool(agarre.pedir_agarrar(UnidadDeProducto.new(Catalogo.todos()[0]), producto)).is_true()
	await _comprobar_que_no_tiembla(jugador, producto)


func test_una_caja_en_la_mano_no_tiembla_contra_la_camara() -> void:
	var jugador := await _jugador_en_un_piso_libre()
	var caja := _cuerpo_suelto(jugador)
	var agarre: Agarre = jugador.get("agarre")
	assert_bool(agarre.pedir_agarrar(ObjetoDelAlmacen.new(), caja)).is_true()
	# Lo mismo que hace la reposición con una caja recién levantada: la baja a la cintura.
	agarre.mover_lo_sostenido(jugador.get_node("PuntoDeCaja"))
	jugador.call("ocupar_el_frente", true)
	await _comprobar_que_no_tiembla(jugador, caja)


func test_lo_soltado_girando_se_dibuja_donde_se_veia_el_punto_de_soltado() -> void:
	# Soltar pasa entre dos pasos de física. Antes, lo soltado aparecía un paso atrás: 57 mm
	# caminando, medido.
	var jugador := await _jugador_en_un_piso_libre()
	var producto := _cuerpo_suelto(jugador)
	var agarre: Agarre = jugador.get("agarre")
	var datos := UnidadDeProducto.new(Catalogo.todos()[0])
	assert_bool(agarre.pedir_agarrar(datos, producto)).is_true()
	_mover_el_mouse(jugador)
	Input.action_press(ReglasDelJugador.ACCION_ADELANTE)
	await _esperar(1.0)
	var mayor := 0.0
	for vez in 10:
		# Cuadros sueltos, para soltar en distintos puntos entre dos pasos de física.
		for cuadro in 7:
			await get_tree().process_frame
		var visto := agarre.punto_de_soltado.get_global_transform_interpolated().origin
		agarre.soltar(true)
		await get_tree().process_frame
		mayor = maxf(mayor, visto.distance_to(producto.get_global_transform_interpolated().origin))
		agarre.pedir_agarrar(datos, producto)
	(
		assert_float(mayor)
		. override_failure_message(
			"lo soltado apareció a %.1f mm de donde se veía" % (mayor * 1000.0)
		)
		. is_less_equal(TEMBLOR_ADMITIDO)
	)


func test_caminar_derecho_hace_avanzar_la_camara_en_cada_cuadro() -> void:
	var jugador := await _jugador_en_un_piso_libre()
	var medidor := _medir(jugador, null)
	Input.action_press(ReglasDelJugador.ACCION_ADELANTE)
	await _esperar(3.0)
	var quietos := 0
	for indice in range(1, medidor.dibujadas.size()):
		var paso := medidor.dibujadas[indice].origin - medidor.dibujadas[indice - 1].origin
		if paso.length() < 1e-5:
			quietos += 1
	(
		assert_int(quietos)
		. override_failure_message(
			"%d de %d cuadros dibujan la cámara quieta" % [quietos, medidor.dibujadas.size()]
		)
		. is_equal(0)
	)


func _comprobar_que_no_tiembla(jugador: CharacterBody3D, sostenido: Node3D) -> void:
	var medidor := _medir(jugador, sostenido)
	_mover_el_mouse(jugador)
	Input.action_press(ReglasDelJugador.ACCION_ADELANTE)
	await _esperar(4.0)
	var saltos := 0
	var mayor := 0.0
	for indice in range(1, medidor.relativos.size()):
		var salto := medidor.relativos[indice].distance_to(medidor.relativos[indice - 1])
		mayor = maxf(mayor, salto)
		if salto > TEMBLOR_ADMITIDO:
			saltos += 1
	(
		assert_int(saltos)
		. override_failure_message(
			(
				"%d de %d cuadros mueven lo que se lleva contra la cámara; el mayor, %.1f mm"
				% [saltos, medidor.relativos.size(), mayor * 1000.0]
			)
		)
		. is_equal(0)
	)


## Un piso grande y nada más: los criterios se miden sin obstáculos que corran la mano.
func _jugador_en_un_piso_libre() -> CharacterBody3D:
	var mundo: Node3D = auto_free(Node3D.new())
	var piso := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(200.0, 1.0, 200.0)
	forma.shape = caja
	piso.add_child(forma)
	piso.position = Vector3.DOWN * 0.5
	mundo.add_child(piso)
	var jugador: CharacterBody3D = JUGADOR.instantiate()
	mundo.add_child(jugador)
	add_child(mundo)
	for cuadro in CUADROS_DE_ARRANQUE:
		await get_tree().physics_frame
	return jugador


## Un cuerpo físico como los del almacén, al lado del jugador para poder agarrarlo.
func _cuerpo_suelto(jugador: CharacterBody3D) -> RigidBody3D:
	var cuerpo := RigidBody3D.new()
	var forma := CollisionShape3D.new()
	forma.shape = BoxShape3D.new()
	(forma.shape as BoxShape3D).size = Vector3.ONE * 0.1
	cuerpo.add_child(forma)
	jugador.get_parent().add_child(cuerpo)
	cuerpo.global_position = jugador.global_position + Vector3(1.0, 0.5, 0.0)
	return cuerpo


func _medir(jugador: CharacterBody3D, sostenido: Node3D) -> Medidor:
	var medidor := Medidor.new()
	medidor.camara = jugador.get_node("Camara")
	medidor.sostenido = sostenido
	jugador.get_parent().add_child(medidor)
	return medidor


func _mover_el_mouse(jugador: CharacterBody3D) -> void:
	jugador.get_parent().add_child(Mouse.new())


func _esperar(segundos: float) -> void:
	for cuadro in int(segundos * CUADROS_POR_SEGUNDO):
		await get_tree().process_frame
