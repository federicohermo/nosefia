extends GdUnitTestSuite

const GENERADOR := "res://assets/models/generar_fotos_del_jefe.gd"


func test_reloj_y_gondolas_encuadran_su_tema_sin_cambiar_el_reparto() -> void:  # AC-EMP-047
	var constantes: Dictionary = (load(GENERADOR) as GDScript).get_script_constant_map()
	var escena: PackedScene = load("res://src/escenas/almacen.tscn")
	var almacen: Node3D = auto_free(escena.instantiate())
	almacen.set("_partida", Partida.nueva())
	get_tree().root.add_child(almacen)
	almacen.get_node("Interfaz/PersianaDeLaNoche").terminar()
	(almacen.get("_reloj") as Node).set_process(false)
	var jugador: CharacterBody3D = almacen.get("_jugador")
	jugador.call("suspender")
	jugador.set_physics_process(false)
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
	for nombre: String in ["PLANO_DEL_RELOJ", "PLANO_DE_LAS_GONDOLAS"]:
		var plano: Array = constantes[nombre]
		camara.fov = plano[3]
		camara.look_at_from_position(plano[1], plano[2])
		var rayo := PhysicsRayQueryParameters3D.create(
			camara.global_position, camara.global_position - camara.global_basis.z * 25.0
		)
		rayo.exclude = [jugador.get_rid()]
		var golpe := camara.get_world_3d().direct_space_state.intersect_ray(rayo)
		assert_dict(golpe).is_not_empty()
		if not golpe.is_empty():
			var ruta := str(almacen.get_path_to(golpe.collider as Node))
			assert_str(ruta.to_lower()).contains((plano[4] as String).to_lower())
	var jornada := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA
	almacen.set("_partida", Partida.desde({"jornada": jornada}))
	almacen.call("_al_abrir_la_jornada", jornada)
	almacen.set("_partida", Partida.nueva())
	almacen.call("_al_abrir_la_jornada", ReglasDeLaPartida.PRIMERA_JORNADA)
	var repositor: Repositor = almacen.get("_repositor")
	assert_bool(repositor.estante().completada()).is_true()
	for indice: int in cajas.size():
		(
			assert_bool((cajas[indice] as Node3D).global_transform.is_equal_approx(poses[indice]))
			. is_true()
		)
