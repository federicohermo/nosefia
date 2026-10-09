extends SceneTree

const CARPETA := "C:/Users/fede_/orca/workspaces/nosefia/darter/.claude/scratch/batch-64-309/"

func _initialize() -> void:
	call_deferred("_montar")

func _montar() -> void:
	await _medir()
	print("SONDA304_SCOPE_LIBERADO")
	call_deferred("quit")

func _medir() -> void:
	var almacen: Node3D = load("res://src/escenas/almacen.tscn").instantiate()
	root.add_child(almacen)
	var jugador: CharacterBody3D = almacen.get_node("Jugador")
	jugador.set_physics_process(false)
	jugador.set_process(false)
	jugador.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	var agarre: Agarre = almacen.get("_agarre")
	var caja: CajaRegistradora = almacen.get_node("Servicios/CajaRegistradora")
	var puesto: StaticBody3D = almacen.get_node("Estructura/cajaregistradora/StaticBody3D")
	almacen.call("_al_abrir_la_jornada", 1)
	for numero: int in [1,2]:
		almacen.get_node("Estructura/bano_puerta_%d/CuerpoDeLaHoja" % numero).call("usar")
	for _cuadro in 60:
		await physics_frame
	for numero: int in [1,2]:
		var puerta: Node3D = almacen.get_node("Estructura/bano_puerta_%d/CuerpoDeLaHoja" % numero)
		if not (puerta.call("puerta") as Puerta).abierta():
			push_error("Cabina no abierta")
			quit(1)
			return
	caja.pedir_anotar(UnidadDeProducto.new(Catalogo.de(Producto.Id.MAROLINI)))
	var renglones := caja.generador().renglones()
	var avisos: Array[int] = []
	caja.ticket_desechado.connect(func() -> void: avisos.append(1))
	for pantalla: Vector2i in [Vector2i(1920,1080),Vector2i(1280,720)]:
		root.size = pantalla
		for _cuadro in 4:
			await process_frame
		for nombre: String in ["inodoro","bano_inodoro_2","vanitory","bano_lavatorio_2"]:
			caja.pedir_imprimir()
			var papel: ObjetoAgarrable = puesto.get("_en_ranura")
			if papel == null or not agarre.pedir_agarrar(papel.datos,papel):
				push_error("Ticket propio no impreso/agarrado")
				quit(1)
				return
			var objetivo: PhysicsBody3D = almacen.get_node("Estructura/"+nombre+"/StaticBody3D")
			var visual: MeshInstance3D = objetivo.get("mallas")[0]
			var centro := visual.to_global(visual.mesh.get_aabb().get_center())
			var sitios := _posiciones(almacen,objetivo,centro)
			print("SONDA304_SITIOS ",nombre,"=",sitios.size()," centro=",centro)
			if sitios.is_empty() or not visual.is_visible_in_tree():
				push_error("Artefacto no visible/alcanzable: "+nombre)
				quit(1)
				return
			jugador.global_position=sitios[0]
			jugador.reset_physics_interpolation()
			camara.position=Vector3.UP*ReglasDelJugador.ALTURA_DE_LA_CAMARA
			camara.look_at(centro)
			camara.reset_physics_interpolation()
			for _cuadro in 4:
				await physics_frame
			jugador.call("_leer_la_mira")
			var pose := camara.global_transform
			for _cuadro in 6:
				await process_frame
			await RenderingServer.frame_post_draw
			if not _validar_foto(jugador,objetivo,centro,pose) or agarre.manos().sostenido()!=papel.datos:
				push_error("Pose/foco/hand no validos")
				quit(1)
				return
			root.get_texture().get_image().save_png(CARPETA+"304-antes-"+nombre+"-"+str(pantalla.x)+".png")
			print("SONDA304_MONTAJE ",JSON.stringify({"artefacto":nombre,"jugador":str(jugador.global_position),"camara":str(camara.global_position),"foco":str(jugador.get("_enfocado").get_path()),"held":str(agarre.manos().sostenido().id),"destino":str(objetivo.call("destino_del_uso"))}))
			var cantidad_antes := avisos.size()
			var evento := InputEventAction.new()
			evento.action = ReglasDelJugador.ACCION_USAR
			evento.pressed = true
			jugador.call("_unhandled_input",evento)
			for _cuadro in 4:
				await process_frame
			await RenderingServer.frame_post_draw
			if not _validar_foto(jugador,objetivo,centro,pose):
				quit(1)
				return
			if objetivo.call("destino_del_uso") == ReglasDeLaLimpieza.ID_DEL_INODORO:
				if is_instance_valid(papel) or agarre.manos().sostenido() != null or avisos.size() != cantidad_antes+1:
					push_error("Inodoro no descartó exactamente su ticket")
					quit(1)
					return
				jugador.call("_unhandled_input",evento)
				if avisos.size() != cantidad_antes+1:
					push_error("Descarte duplicado con mano vacía")
					quit(1)
					return
			else:
				if not is_instance_valid(papel) or agarre.manos().sostenido() != papel.datos or avisos.size() != cantidad_antes:
					push_error("Lavatorio consumió el ticket")
					quit(1)
					return
			if caja.generador().renglones() != renglones:
				push_error("Descarte alteró el programa")
				quit(1)
				return
			root.get_texture().get_image().save_png(CARPETA+"304-despues-"+nombre+"-"+str(pantalla.x)+".png")
			print("SONDA304_DESCARTE_VALIDADO ",nombre," resolución=",pantalla," eventos=",avisos.size())
			if agarre.manos().sostenido() != null:
				agarre.soltar(false)
	jugador.suspender()
	for tipo: String in ["AudioStreamPlayer","AudioStreamPlayer3D"]:
		for voz in almacen.find_children("*",tipo,true,false):
			voz.stop()
			voz.stream=null
	await create_timer(0.2).timeout
	almacen.queue_free()
	for _cuadro in 4:
		await physics_frame
	print("SONDA304_MONTAJE_LIBERADO")

func _posiciones(almacen: Node3D, objetivo: PhysicsBody3D, centro: Vector3) -> Array[Vector3]:
	var jugador: CharacterBody3D = almacen.get_node("Jugador")
	var espacio := almacen.get_world_3d().direct_space_state
	var forma: CollisionShape3D = jugador.get_node("Cuerpo")
	var sitios: Array[Vector3] = []
	for distancia: float in [0.6,0.8,1.0,1.2,1.5,2.0]:
		for paso in 16:
			var angulo := TAU * paso / 16.0
			var punto := centro + Vector3(cos(angulo),0,sin(angulo)) * distancia
			var piso := PhysicsRayQueryParameters3D.create(punto + Vector3.UP, punto + Vector3.DOWN * 3.0, jugador.collision_mask)
			piso.exclude = [jugador.get_rid()]
			var golpe := espacio.intersect_ray(piso)
			if golpe.is_empty() or golpe.normal.y < 0.95:
				continue
			var apoyo := golpe.collider as CollisionObject3D
			var dueno := apoyo.shape_owner_get_owner(apoyo.shape_find_owner(golpe.shape)) as Node
			if apoyo.name != "SueloSolido" and dueno.name != "VolumenDelPisoDelBano" and not str(apoyo.get_path()).ends_with("/almacen/StaticBody3D"):
				continue
			var posicion: Vector3 = golpe.position + Vector3.UP * 0.02
			var consulta := PhysicsShapeQueryParameters3D.new()
			consulta.shape = forma.shape
			consulta.transform = Transform3D(Basis.IDENTITY,posicion) * forma.transform
			consulta.collision_mask = jugador.collision_mask
			consulta.exclude = [jugador.get_rid()]
			if not espacio.intersect_shape(consulta).is_empty():
				continue
			var ojo := posicion + Vector3.UP * ReglasDelJugador.ALTURA_DE_LA_CAMARA
			var rayo := PhysicsRayQueryParameters3D.create(ojo,centro,3)
			rayo.exclude = [jugador.get_rid()]
			var impacto := espacio.intersect_ray(rayo)
			if impacto.get("collider") == objetivo and ojo.distance_to(impacto.position) <= ReglasDelJugador.ALCANCE_DE_LA_MIRA:
				sitios.append(posicion)
	return sitios

func _validar_foto(jugador: CharacterBody3D, objetivo: PhysicsBody3D, centro: Vector3, pose: Transform3D) -> bool:
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	var dibujada := camara.get_global_transform_interpolated()
	var punto := camara.unproject_position(centro)
	var valida: bool = camara.is_current() and not camara.is_position_behind(centro) and root.get_visible_rect().has_point(punto) and camara.global_transform.is_equal_approx(pose) and dibujada.is_equal_approx(pose) and jugador.get("_enfocado") == objetivo
	print("SONDA304_FOCO ", objetivo.get_path(), " proyeccion=", punto, " viewport=", root.get_visible_rect(), " pose=", camara.global_transform, " dibujada=", dibujada, " enfocado=", jugador.get("_enfocado"), " valida=", valida)
	if not valida:
		push_error("Captura sin pose/proyeccion/foco real del objetivo")
	return valida
