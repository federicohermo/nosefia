extends GdUnitTestSuite

const AperturaConLugar := preload("res://test/escenas/apertura_con_lugar.gd")
const ALMACEN := preload("res://src/escenas/almacen.tscn")
const MUEBLES := ["heladeranueva", "heladeranueva_001", "heladera_fuera_de_servicio"]


func _almacen() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	AperturaConLugar.abrir_con_todo_el_lugar(almacen)
	await get_tree().physics_frame
	await get_tree().physics_frame
	return almacen


func _hoja(almacen: Node3D, numero: int) -> MeshInstance3D:
	return almacen.get_node("Estructura/%s/puerta_heladera_%d" % [MUEBLES[numero], numero])


func test_las_hojas_tienen_marcos_negros_y_vidrio_transparente() -> void:
	var almacen := await _almacen()
	for numero in 3:
		var hoja := _hoja(almacen, numero)
		var marco := hoja.mesh.surface_get_material(0) as StandardMaterial3D
		# El GLB convierte los factores lineales de Blender al espacio sRGB de Godot.
		assert_float(marco.albedo_color.srgb_to_linear().get_luminance()).is_less(0.05)
		var cristal := hoja.get_node("local_vidrio_heladera_%d" % numero) as MeshInstance3D
		var vidrio := cristal.get_active_material(0) as ShaderMaterial
		assert_object(vidrio).is_not_null()
		assert_object(vidrio.get_shader_parameter("reflejo_del_techo")).is_not_null()
		# El foco sólo delinea el marco; pintar el paño haría opaco el vidrio de una cara.
		var puerta := hoja.get_node("CuerpoDeLaHoja")
		assert_array(puerta.get("mallas")).contains_exactly([hoja])
		var limites := hoja.global_transform * hoja.get_aabb()
		assert_float(limites.position.y).is_equal_approx(0.66307, 0.001)
		assert_float(limites.end.y).is_equal_approx(2.50416, 0.001)


func test_abrir_cada_heladera_libera_el_rayo_hacia_sus_productos() -> void:
	var almacen := await _almacen()
	var espacio := almacen.get_world_3d().direct_space_state
	for numero in 2:
		var hoja := _hoja(almacen, numero)
		var puerta := hoja.get_node("CuerpoDeLaHoja") as PhysicsBody3D
		var centro := hoja.global_position
		var rayo := PhysicsRayQueryParameters3D.create(
			centro + Vector3.BACK * 0.6, centro + Vector3.FORWARD * 0.25, 3
		)
		assert_object(espacio.intersect_ray(rayo).get("collider")).is_same(puerta)
		assert_object(puerta.call("usar")).is_null()
		for cuadro in 60:
			await get_tree().physics_frame
		assert_bool(puerta.call("puerta").abierta()).is_true()
		assert_object(espacio.intersect_ray(rayo).get("collider")).is_not_same(puerta)
		var presentacion: Node3D = almacen.get("_reposicion_manual")
		var id: Producto.Id = [Producto.Id.CORACOLA, Producto.Id.MAYONCHIS][numero]
		presentacion.call("retirar", id)
		var casillero: Node3D = presentacion.call("casillero", id)
		var jugador: CharacterBody3D = almacen.get("_jugador")
		jugador.global_position = Vector3(casillero.global_position.x, 0.12, -5.6)
		var camara: Camera3D = jugador.get_node("Giro/Camara")
		camara.look_at(casillero.global_position)
		for cuadro in 4:
			await get_tree().physics_frame
		var consulta := PhysicsRayQueryParameters3D.create(
			camara.global_position, casillero.global_position, 3
		)
		assert_object(espacio.intersect_ray(consulta).get("collider")).is_same(casillero)
		almacen.get("_agarre").soltar(true)
		puerta.call("cerrar_de_golpe")


func test_la_heladera_fuera_de_servicio_conserva_la_puerta_trabada() -> void:
	var almacen := await _almacen()
	var puerta := _hoja(almacen, 2).get_node("CuerpoDeLaHoja")
	puerta.call("usar")
	for cuadro in 60:
		await get_tree().physics_frame
	assert_bool(puerta.call("puerta").abierta()).is_false()


func test_el_nuevo_turno_cierra_las_heladeras_activas() -> void:
	var almacen := await _almacen()
	for numero in 2:
		_hoja(almacen, numero).get_node("CuerpoDeLaHoja").call("usar")
	for cuadro in 60:
		await get_tree().physics_frame
	almacen.call("_al_abrir_la_jornada", 2)
	for numero in 2:
		(
			assert_bool(_hoja(almacen, numero).get_node("CuerpoDeLaHoja").call("puerta").abierta())
			. is_false()
		)


func test_los_botones_del_jugador_abren_y_cierran_con_el_derecho() -> void:
	var almacen := await _almacen()
	var hoja := _hoja(almacen, 0)
	var puerta := hoja.get_node("CuerpoDeLaHoja")
	var jugador: CharacterBody3D = almacen.get("_jugador")
	jugador.global_position = Vector3(hoja.global_position.x, 0.12, -5.6)
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	camara.look_at(hoja.global_position)
	for cuadro in 5:
		await get_tree().physics_frame
	assert_object(jugador.get("_enfocado")).is_same(puerta)
	var clic := InputEventMouseButton.new()
	clic.pressed = true
	clic.button_index = MOUSE_BUTTON_LEFT
	jugador.call("_unhandled_input", clic)
	assert_bool(puerta.call("puerta").abierta()).is_false()
	clic.button_index = MOUSE_BUTTON_RIGHT
	jugador.call("_unhandled_input", clic)
	assert_bool(puerta.call("puerta").abierta()).is_true()
	for cuadro in 60:
		await get_tree().physics_frame
	camara.look_at(hoja.global_position)
	for cuadro in 5:
		await get_tree().physics_frame
	assert_object(jugador.get("_enfocado")).is_same(puerta)
	jugador.call("_unhandled_input", clic)
	assert_bool(puerta.call("puerta").abierta()).is_false()
