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
## quedan de testigo de que lo que se lleva cuelga del giro y no del cuerpo.
extends GdUnitTestSuite

const JUGADOR := preload("res://src/escenas/jugador.tscn")
const ALMACEN := preload("res://src/escenas/almacen.tscn")

## Un rincón del depósito donde caminar hacia adelante lleva la caja contra la pared.
const RINCON_DEL_DEPOSITO := Vector2(10.4, -4.0)

## El monitor del issue fue a 144 Hz. Con el cuadro sin tope, casi todos caen en el mismo punto
## entre dos pasos de física y el temblor no aparece.
const CUADROS_POR_SEGUNDO := 144

## Píxeles de mouse por cuadro. Con la sensibilidad del dominio dan los 0,018 rad medidos.
const MOUSE_POR_CUADRO := 6.0

## El mouse medido en el juego: uno de cada cinco o seis cuadros llegaba sin movimiento.
const REPORTES_POR_SEGUNDO := 125

## Cuadros de arranque que no se miden: el jugador todavía cae al piso.
const CUADROS_DE_ARRANQUE := 60

## Cuánto puede moverse lo que se lleva respecto de la cámara en un cuadro, en metros.
const TEMBLOR_ADMITIDO := 0.001


class Medidor:
	extends Node

	var camara: Camera3D
	var sostenido: Node3D
	var dibujadas: Array[Transform3D] = []
	var relativos: Array[Vector3] = []

	## Lo que el motor dibuja de un nodo. Un hijo sin interpolar sigue la interpolación de su
	## padre, así que cuenta cualquier ancestro. Medido: en una rama sin nada interpolado,
	## `get_global_transform_interpolated()` devuelve un valor viejo.
	static func dibujado(nodo: Node3D) -> Transform3D:
		var actual: Node = nodo
		while actual is Node3D:
			if actual.is_physics_interpolated_and_enabled():
				return nodo.get_global_transform_interpolated()
			actual = actual.get_parent()
		return nodo.global_transform

	func _init() -> void:
		process_priority = 1000

	func _process(_delta: float) -> void:
		var vista := dibujado(camara)
		dibujadas.append(vista)
		if sostenido != null:
			relativos.append(vista.affine_inverse() * dibujado(sostenido).origin)


## Marca el ritmo de los cuadros como el vsync del juego. `Engine.max_fps` no sirve en headless:
## medido, los cuadros alternan entre 0,3 y 15,5 ms, y un giro suavizado por tiempo sale
## desparejo aunque en el juego sea parejo.
class RitmoDePantalla:
	extends Node

	var _proximo := 0

	func _init() -> void:
		process_priority = -2000

	func _process(_delta: float) -> void:
		if _proximo == 0:
			_proximo = Time.get_ticks_usec()
		while Time.get_ticks_usec() < _proximo:
			pass
		_proximo += 1000000 / CUADROS_POR_SEGUNDO


## Suelta con el clic al final de un cuadro: ahí queda lo que se dibujó, y el evento de verdad
## llega antes de que nada lo cambie. Un clic después del `await` llega con la física ya corrida.
class Clic:
	extends Node

	var jugador: Node3D
	var producto: Node3D
	var armado := false
	var visto := Vector3.ZERO
	var aparecido := Vector3.ZERO
	var _esperando := false

	func _init() -> void:
		process_priority = 2000

	func _process(_delta: float) -> void:
		if _esperando:
			aparecido = Medidor.dibujado(producto).origin
			_esperando = false
		if not armado:
			return
		armado = false
		var agarre: Agarre = jugador.get("agarre")
		visto = Medidor.dibujado(agarre.punto_de_soltado).origin
		var evento := InputEventAction.new()
		evento.action = ReglasDeLosObjetos.ACCION_AGARRAR
		evento.pressed = true
		jugador.call("_unhandled_input", evento)
		_esperando = true


class Mouse:
	extends Node

	func _process(_delta: float) -> void:
		var evento := InputEventMouseMotion.new()
		evento.relative = Vector2(MOUSE_POR_CUADRO, 0.0)
		Input.parse_input_event(evento)


## El mouse de un lado al otro, como girando contra una pared.
class MouseDeLadoALado:
	extends Node

	func _process(_delta: float) -> void:
		var evento := InputEventMouseMotion.new()
		evento.relative = Vector2(10.0 * sin(Time.get_ticks_msec() / 400.0), 0.0)
		Input.parse_input_event(evento)


## Un mouse que reporta a su ritmo y no al de la pantalla, como el del issue. Mueve lo mismo por
## segundo que `Mouse`.
class MouseLento:
	extends Node

	var _proximo := 0

	func _process(_delta: float) -> void:
		var ahora := Time.get_ticks_usec()
		if _proximo == 0:
			_proximo = ahora
		while _proximo <= ahora:
			var evento := InputEventMouseMotion.new()
			evento.relative = Vector2(
				MOUSE_POR_CUADRO * CUADROS_POR_SEGUNDO / REPORTES_POR_SEGUNDO, 0.0
			)
			Input.parse_input_event(evento)
			_proximo += 1000000 / REPORTES_POR_SEGUNDO


func after_test() -> void:
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


func test_un_mouse_mas_lento_que_la_pantalla_se_dibuja_parejo() -> void:
	var jugador := await _jugador_en_un_piso_libre()
	var medidor := _medir(jugador, null)
	jugador.get_parent().add_child(MouseLento.new())
	await _esperar(4.0)
	var giros: Array[float] = []
	for indice in range(CUADROS_DE_ARRANQUE, medidor.dibujadas.size()):
		var antes := medidor.dibujadas[indice - 1].basis.get_euler().y
		var ahora := medidor.dibujadas[indice].basis.get_euler().y
		giros.append(absf(wrapf(ahora - antes, -PI, PI)))
	var medio := 0.0
	for giro in giros:
		medio += giro / giros.size()
	var parejos := giros.filter(func(giro: float) -> bool: return absf(giro / medio - 1.0) <= 0.2)
	var quietos := giros.filter(func(giro: float) -> bool: return giro < medio * 0.1)
	(
		assert_float(float(parejos.size()) / giros.size())
		. override_failure_message(
			(
				"sólo %d de %d cuadros dibujan el giro medio; %d no giran"
				% [parejos.size(), giros.size(), quietos.size()]
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
	agarre.mover_lo_sostenido(jugador.get_node("Giro/PuntoDeCaja"))
	jugador.call("ocupar_el_frente", true)
	await _comprobar_que_no_tiembla(jugador, caja)


func test_una_caja_contra_la_pared_se_corre_sin_escalones() -> void:
	# Contra la pared el brazo corre la caja en cada paso de física. Sin interpolar ese punto, la
	# caja quedaba quieta entre dos pasos y saltaba en el siguiente: medido, 40 escalones en 4 s
	# empujando y girando en el rincón del depósito.
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	almacen.add_child(RitmoDePantalla.new())
	add_child(almacen)
	await get_tree().physics_frame
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var caja: Node3D = almacen.get("_cajas_de_productos")[Producto.Id.LAYSNTT]
	jugador.set("_enfocado", caja)
	var clic := InputEventAction.new()
	clic.action = ReglasDeLosObjetos.ACCION_AGARRAR
	clic.pressed = true
	jugador.call("_unhandled_input", clic)
	jugador.global_position = Vector3(
		RINCON_DEL_DEPOSITO.x, jugador.global_position.y, RINCON_DEL_DEPOSITO.y
	)
	Input.action_press(ReglasDelJugador.ACCION_ADELANTE)
	await _esperar(1.0)
	var medidor := _medir(jugador, caja)
	almacen.add_child(MouseDeLadoALado.new())
	await _esperar(3.0)
	var pasos: Array[float] = []
	for indice in range(1, medidor.relativos.size()):
		pasos.append(medidor.relativos[indice].distance_to(medidor.relativos[indice - 1]))
	var escalones := 0
	var moviendose := 0
	for indice in range(1, pasos.size() - 1):
		if pasos[indice - 1] > 0.001 and pasos[indice + 1] > 0.001:
			moviendose += 1
			if pasos[indice] < 0.00005:
				escalones += 1
	(
		assert_int(moviendose)
		. override_failure_message("la caja no se corrió: el caso no ejerce nada")
		. is_greater(20)
	)
	(
		assert_int(escalones)
		. override_failure_message(
			(
				"la caja quedó quieta entre dos cuadros que se mueven %d veces de %d"
				% [escalones, moviendose]
			)
		)
		. is_equal(0)
	)


func test_lo_soltado_despues_de_girar_se_dibuja_donde_se_veia_el_punto_de_soltado() -> void:
	# Soltar pasa entre dos pasos de física. Antes, lo soltado aparecía un paso atrás: 57 mm
	# caminando, medido. Se suelta con el clic, que es el camino del juego.
	var jugador := await _jugador_en_un_piso_libre()
	var producto := _cuerpo_suelto(jugador)
	var agarre: Agarre = jugador.get("agarre")
	var datos := UnidadDeProducto.new(Catalogo.todos()[0])
	assert_bool(agarre.pedir_agarrar(datos, producto)).is_true()
	var mouse := Mouse.new()
	jugador.get_parent().add_child(mouse)
	Input.action_press(ReglasDelJugador.ACCION_ADELANTE)
	await _esperar(1.0)
	# Girando, lo que se ve va atrás del mouse: el clic apunta con la mirada. Se suelta ya
	# alcanzado el giro.
	mouse.queue_free()
	await _esperar(SuavizadoDelGiro.VENTANA * 4.0)
	var clic := Clic.new()
	clic.jugador = jugador
	clic.producto = producto
	jugador.get_parent().add_child(clic)
	var mayor := 0.0
	for vez in 10:
		# Cuadros sueltos, para soltar en distintos puntos entre dos pasos de física.
		for cuadro in 7:
			await get_tree().process_frame
		clic.armado = true
		for cuadro in 2:
			await get_tree().process_frame
		mayor = maxf(mayor, clic.visto.distance_to(clic.aparecido))
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
	mundo.add_child(RitmoDePantalla.new())
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
	medidor.camara = jugador.get_node("Giro/Camara")
	medidor.sostenido = sostenido
	jugador.get_parent().add_child(medidor)
	return medidor


func _mover_el_mouse(jugador: CharacterBody3D) -> void:
	jugador.get_parent().add_child(Mouse.new())


func _esperar(segundos: float) -> void:
	for cuadro in int(segundos * CUADROS_POR_SEGUNDO):
		await get_tree().process_frame
