## Lo que se suelta en el piso: se duerme, y el producto más delgado no lo atraviesa.
##
## Cada unidad sale de la reposición, como la arma el juego. Así el caso sigue lo que el juego
## decide sobre la física de la unidad, sin repetirlo.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const AperturaConLugar := preload("res://test/escenas/apertura_con_lugar.gd")

## Piso libre del depósito, lejos de los muebles y sin nada encima. Las unidades se apoyan en
## filas desde acá. Medido el 2026-09-30: la grilla entera entra con 40 cm alrededor de cada
## lugar. En (2.89, -10), donde estaba, el rayo que busca el piso pega en la tapa de una góndola
## del depósito desde que los sólidos tienen volumen, y las unidades caían desde 2 m.
const PISO_LIBRE := Vector3(4.18, 0.0, -8.95)

## Cuántas unidades van por fila, y a qué distancia, en metros: una que se cae no llega a la de
## al lado.
const COLUMNAS := 5
const SEPARACION := 0.8

## Cuánto se levanta cada unidad sobre el piso antes de soltarla, en metros.
const HOLGURA := 0.02

## Cuánto tiene para dormirse, y desde cuándo ya no puede girar, en segundos de física.
const SEGUNDOS_PARA_DORMIR := 8
const SEGUNDOS_PARA_ASENTARSE := 2

## El giro más rápido que se tolera después de asentarse, en rad/s.
const GIRO_QUIETO := 0.02

## Desde qué altura sobre el piso cae el producto más delgado, en metros.
const ALTURA_DE_LA_CAIDA := 1.5

## Cuánto puede bajar el centro del producto por debajo del plano del piso, en metros.
const HUNDIMIENTO := 0.05

## Cuánto se mira la caída, en segundos de física. Alcanza para caer, rebotar y asentarse.
const SEGUNDOS_DE_LA_CAIDA := 2


func _almacen() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	# La noche abre con la góndola llena, y una caja llena no entrega: estos casos sacan
	# unidades para usarlas de objeto, así que abren con lugar para reponer.
	AperturaConLugar.abrir_con_todo_el_lugar(almacen)
	await get_tree().physics_frame
	return almacen


## Una unidad del producto: la reposición la retira y la mano la suelta.
func _unidad(almacen: Node3D, producto: Producto) -> ObjetoAgarrable:
	almacen.get("_reposicion_manual").call("retirar", producto.id)
	var agarre: Agarre = almacen.get("_agarre")
	var unidad := agarre.soltar(true) as ObjetoAgarrable
	(
		assert_object(unidad)
		. override_failure_message("la reposición no retiró `%s`" % producto.nombre)
		. is_not_null()
	)
	return unidad


func _piso_en(almacen: Node3D, punto: Vector3) -> float:
	var consulta := PhysicsRayQueryParameters3D.create(
		punto + Vector3.UP * 3.0, punto + Vector3.DOWN * 3.0
	)
	var golpe := almacen.get_world_3d().direct_space_state.intersect_ray(consulta)
	var donde: Vector3 = golpe.get("position", punto)
	return donde.y


func _grosor(malla: Mesh) -> float:
	var tamano := malla.get_aabb().size
	return tamano[tamano.min_axis_index()]


## El eje de un giro que más se acerca a la vertical, hacia arriba.
static func _arriba(giro: Basis) -> Vector3:
	var mejor := Vector3.ZERO
	for columna in 3:
		var eje := giro[columna].normalized()
		if absf(eje.y) > absf(mejor.y):
			mejor = eje
	return mejor if mejor.y > 0.0 else -mejor


func test_una_unidad_de_cada_producto_se_duerme_apoyada_en_el_piso() -> void:  # AC-PLY-015
	var almacen := await _almacen()
	var piso := _piso_en(almacen, PISO_LIBRE)
	var contenido: Node3D = almacen.get("_reposicion_manual").get("contenido")
	var nombres: Dictionary[ObjetoAgarrable, String] = {}
	for producto in Catalogo.todos():
		var unidad := _unidad(almacen, producto)
		var indice := nombres.size()
		var vista: MeshInstance3D = unidad.get_node("Malla")
		# Derecha, apoyada en su base. La unidad lleva la vuelta que tiene en el estante, y en la
		# rampa de una cabecera va echada hacia atrás: suelta así, cae sobre un canto y se hamaca.
		# Se la endereza por el eje del modelo más cercano a la vertical, que en un estante plano
		# ya es la vertical.
		var modelo := contenido.get_child(producto.id) as Node3D
		var derecha := Basis(Quaternion(_arriba(modelo.global_basis), Vector3.UP))
		var abajo := INF
		for punto in vista.mesh.get_faces():
			abajo = minf(abajo, (derecha * (punto + vista.position)).y)
		var lugar := (
			PISO_LIBRE
			+ Vector3(
				(indice % COLUMNAS) * SEPARACION,
				piso - abajo + HOLGURA,
				-floori(float(indice) / COLUMNAS) * SEPARACION
			)
		)
		# Si el piso de este lugar no es el medido, la unidad no queda apoyada: cae de otra altura,
		# o sobre un mueble.
		(
			assert_float(_piso_en(almacen, Vector3(lugar.x, PISO_LIBRE.y, lugar.z)))
			. override_failure_message("`%s` no queda sobre el piso libre" % producto.nombre)
			. is_equal_approx(piso, 0.001)
		)
		unidad.global_transform = Transform3D(derecha, lugar)
		unidad.linear_velocity = Vector3.ZERO
		unidad.angular_velocity = Vector3.ZERO
		nombres[unidad] = producto.nombre
	var giro_maximo := 0.0
	var el_que_mas_gira := ""
	for cuadro in SEGUNDOS_PARA_DORMIR * Engine.physics_ticks_per_second:
		await get_tree().physics_frame
		if cuadro < SEGUNDOS_PARA_ASENTARSE * Engine.physics_ticks_per_second:
			continue
		for unidad in nombres:
			if unidad.angular_velocity.length() > giro_maximo:
				giro_maximo = unidad.angular_velocity.length()
				el_que_mas_gira = nombres[unidad]
	for unidad in nombres:
		(
			assert_bool(unidad.sleeping)
			. override_failure_message(
				"`%s` sigue despierto a los %d s" % [nombres[unidad], SEGUNDOS_PARA_DORMIR]
			)
			. is_true()
		)
	(
		assert_float(giro_maximo)
		. override_failure_message(
			(
				"`%s` giró a %.3f rad/s después del segundo %d"
				% [el_que_mas_gira, giro_maximo, SEGUNDOS_PARA_ASENTARSE]
			)
		)
		. is_less_equal(GIRO_QUIETO)
	)


func test_el_producto_mas_delgado_cae_de_plano_y_no_atraviesa_el_piso() -> void:  # AC-PLY-016
	var almacen := await _almacen()
	var modelos: Array = almacen.get("_reposicion_manual").get("_modelos")
	var delgado: Producto = null
	for producto in Catalogo.todos():
		if delgado == null or _grosor(modelos[producto.id]) < _grosor(modelos[delgado.id]):
			delgado = producto
	var tamano: Vector3 = (modelos[delgado.id] as Mesh).get_aabb().size
	var lado_delgado := Vector3.ZERO
	lado_delgado[tamano.min_axis_index()] = 1.0
	var unidad := _unidad(almacen, delgado)
	var piso := _piso_en(almacen, PISO_LIBRE)
	# De plano: con el lado delgado vertical es como menos le cuesta cruzar el piso.
	unidad.global_transform = Transform3D(
		Basis(Quaternion(lado_delgado, Vector3.UP)),
		Vector3(PISO_LIBRE.x, piso + ALTURA_DE_LA_CAIDA, PISO_LIBRE.z)
	)
	unidad.linear_velocity = Vector3.ZERO
	unidad.angular_velocity = Vector3.ZERO
	var minima := unidad.global_position.y
	for cuadro in SEGUNDOS_DE_LA_CAIDA * Engine.physics_ticks_per_second:
		await get_tree().physics_frame
		minima = minf(minima, unidad.global_position.y)
	(
		assert_float(minima)
		. override_failure_message(
			"`%s` bajó hasta %.3f y el piso está en %.3f" % [delgado.nombre, minima, piso]
		)
		. is_greater_equal(piso - HUNDIMIENTO)
	)
