extends GdUnitTestSuite

const GENERADOR := "res://assets/models/generar_fotos_del_jefe.gd"


func test_reloj_y_gondolas_tienen_encuadres_desde_la_primera_jornada() -> void:  # AC-EMP-047
	var generador: GDScript = load(GENERADOR)
	var constantes: Dictionary = generador.get_script_constant_map()
	var planos: Array = constantes["PLANOS"]
	assert_int(planos.size()).is_equal(9)
	if planos.size() != 9:
		return
	assert_vector(constantes["TAMANO"]).is_equal(Vector2i(960, 540))
	var escena: PackedScene = load("res://src/escenas/almacen.tscn")
	var almacen: Node3D = auto_free(escena.instantiate())
	almacen.set("_partida", Partida.nueva())
	get_tree().root.add_child(almacen)
	almacen.get_node("Interfaz/PersianaDeLaNoche").terminar()
	(almacen.get("_reloj") as Node).set_process(false)
	var jugador: CharacterBody3D = almacen.get("_jugador")
	jugador.call("suspender")
	jugador.set_physics_process(false)
	var repositor: Repositor = almacen.get("_repositor")
	assert_bool(repositor.estante().completada()).is_true()
	for cuerpo: RigidBody3D in almacen.find_children("*", "RigidBody3D", true, false):
		cuerpo.freeze = true
	var cajas: Array = almacen.get("_cajas_de_productos")
	var poses: Array[Transform3D] = []
	for caja: Node3D in cajas:
		poses.append(caja.global_transform)
	var camara: Camera3D = auto_free(Camera3D.new())
	almacen.add_child(camara)
	for cuadro: int in 4:
		await get_tree().physics_frame
	var nuevos := 0
	for plano: Array in planos:
		if plano[0] not in [2, 6, 10, 13]:
			continue
		if plano[0] == 13:
			var jornada := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA
			almacen.set("_partida", Partida.desde({"jornada": jornada}))
			almacen.call("_al_abrir_la_jornada", jornada)
			for cuerpo: RigidBody3D in almacen.find_children("*", "RigidBody3D", true, false):
				cuerpo.freeze = true
			for cuadro: int in 4:
				await get_tree().physics_frame
		camara.fov = plano[3]
		camara.look_at_from_position(plano[1], plano[2])
		var rayo := PhysicsRayQueryParameters3D.create(
			camara.global_position, camara.global_position - camara.global_basis.z * 25.0
		)
		rayo.exclude = [jugador.get_rid()]
		var golpe := camara.get_world_3d().direct_space_state.intersect_ray(rayo)
		if plano[0] == 6:
			var acceso: CollisionShape3D = almacen.get_node("Estructura/Ventanilla/AccesoAlCobro")
			var forma := acceso.shape as BoxShape3D
			var hueco := AABB(-forma.size / 2.0, forma.size)
			assert_dict(golpe).is_empty()
			assert_bool(acceso.disabled).is_true()
			(
				assert_bool(
					(
						hueco.intersects_segment(
							acceso.to_local(rayo.from), acceso.to_local(rayo.to)
						)
						!= null
					)
				)
				. is_true()
			)
			continue
		assert_dict(golpe).is_not_empty()
		if golpe.is_empty():
			continue
		var ruta := str(almacen.get_path_to(golpe.collider as Node))
		assert_str(ruta.to_lower()).contains((plano[4] as String).to_lower())
		if plano[0] == 13:
			continue
		nuevos += 1
		assert_int(plano.size()).is_equal(6)
		assert_str(plano[5]).is_equal("intro-reloj.png" if plano[0] == 2 else "intro-gondolas.png")
	assert_int(nuevos).is_equal(2)
	almacen.set("_partida", Partida.nueva())
	almacen.call("_al_abrir_la_jornada", ReglasDeLaPartida.PRIMERA_JORNADA)
	assert_bool(repositor.estante().completada()).is_true()
	for indice: int in cajas.size():
		(
			assert_bool((cajas[indice] as Node3D).global_transform.is_equal_approx(poses[indice]))
			. is_true()
		)
