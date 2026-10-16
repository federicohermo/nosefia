extends SceneTree

const Geometria = preload(
	"C:/Users/fede_/AppData/Local/Temp/nosefia-batch-425-435/sonda_geometrica_428.gd"
)
var almacen: Node3D
var fallas: Array[String] = []
var salida := "C:/Users/fede_/AppData/Local/Temp/nosefia-batch-425-435/428/nativo-final05"


func _init() -> void:
	call_deferred("_reproducir")


func _reproducir() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	root.show()
	Engine.max_fps = 60
	for tipo: String in ["bano", "gondola"]:
		for producto: Producto.Id in [Producto.Id.LAYSNTT, Producto.Id.ACTRONCITO]:
			await _preparar(tipo, producto)
	for cuadro in 8:
		await process_frame
	print("428_NATIVO_FINAL cuatro_gestos_reales fallas=", fallas)
	quit(0 if fallas.is_empty() else 1)


func _preparar(tipo: String, producto: Producto.Id) -> void:
	almacen = load("res://src/escenas/almacen.tscn").instantiate()
	root.add_child(almacen)
	almacen.get_node("Interfaz/PersianaDeLaNoche").terminar()
	almacen.get("_reloj").set_process(false)
	for cuadro in 8:
		await physics_frame
	var jugador: CharacterBody3D = almacen.get("_jugador")
	jugador.call("reanudar")
	jugador.set_physics_process(false)
	jugador.set_process(false)
	for numero: int in [1, 2]:
		almacen.get_node("Estructura/bano_puerta_%d/CuerpoDeLaHoja" % numero).call("alternar")
	for cuadro in 45:
		await physics_frame
	var caja: RigidBody3D = almacen.get("_cajas_de_productos")[producto]
	var malla: MeshInstance3D
	var objetivo: Vector3
	if tipo == "bano":
		malla = almacen.get_node("Estructura/bano_riel_frontal")
		var pared: MeshInstance3D = almacen.get_node("Estructura/bano_mampara_frontal")
		var blanco := pared.global_transform * pared.get_aabb()
		objetivo = blanco.get_center()
		objetivo.x = blanco.position.x
		objetivo.y = (malla.global_transform * malla.get_aabb()).end.y
	else:
		malla = almacen.get_node("Estructura/gondolanueva2")
		objetivo = malla.get_node("saladix-2oeste2").global_position
		objetivo.y = (malla.global_transform * malla.get_aabb()).end.y - 0.03
	var etiqueta := tipo + ("-grande" if producto == Producto.Id.LAYSNTT else "-chica")
	if await _pose(malla, objetivo, caja, tipo == "bano"):
		await _caso(etiqueta, malla, caja)
	else:
		fallas.append(etiqueta + ": no hay mira real desde piso libre")
	almacen.get("_agarre").entregar()
	for audio: Node in almacen.find_children("*", "Node", true, false):
		if audio is AudioStreamPlayer or audio is AudioStreamPlayer3D:
			audio.call("stop")
			audio.set("stream", null)
	almacen.queue_free()
	almacen = null
	for cuadro in 4:
		await process_frame


func _caso(nombre: String, malla: MeshInstance3D, caja: RigidBody3D) -> void:
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var agarre: Agarre = almacen.get("_agarre")
	if caja == null:
		fallas.append(nombre + ": falta caja Lays del reporte")
		return
	var mascara := caja.collision_mask
	if not agarre.pedir_agarrar(caja.get("datos"), caja):
		fallas.append(nombre + ": no se sostuvo caja")
		return
	for cuadro in 8:
		jugador.call("_acomodar_las_manos", 1.0 / 60.0)
		await physics_frame
	jugador.call("_leer_la_mira")
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	var desde := camara.global_position
	var hasta := desde - camara.global_basis.z * ReglasDelJugador.ALCANCE_DE_LA_MIRA
	var visible: Dictionary = Geometria.impacto_visible(malla, desde, hasta)
	var consulta := PhysicsRayQueryParameters3D.create(desde, hasta, mascara)
	consulta.exclude = [jugador.get_rid(), caja.get_rid()]
	var fisico := almacen.get_world_3d().direct_space_state.intersect_ray(consulta)
	print(
		"REPRO_428_PRE ",
		nombre,
		" mira=",
		camara.global_transform,
		" visible=",
		visible,
		" fisico=",
		fisico,
		" foco=",
		jugador.get("_enfocado"),
		" catalogo=",
		caja.get("datos")
	)
	var evento := InputEventAction.new()
	evento.action = ReglasDeLosObjetos.ACCION_AGARRAR
	evento.pressed = true
	jugador.call("_unhandled_input", evento)
	for cuadro in 12:
		await physics_frame
	print(
		"REPRO_428_GESTO ",
		nombre,
		" mano=",
		agarre.manos().sostenido(),
		" caja=",
		Geometria.estado_caja(caja)
	)
	print(
		"REPRO_428_APOYO ",
		nombre,
		" elegido=",
		almacen.get("_reposicion_manual").call("_apoyo_apuntado", caja)
	)
	_medir_debajo(nombre, caja, malla)
	await _capturar(nombre + "-gesto")
	var inicio := caja.global_transform
	for cuadro in 180:
		await physics_frame
	if caja.global_position.distance_to(inicio.origin) > ReglasDeLosObjetos.ROCE:
		fallas.append(nombre + ": no conserva reposo")
	if not caja.freeze or not caja.sleeping:
		fallas.append(nombre + ": no queda dormida")
	if agarre.manos().sostenido() != null:
		fallas.append(nombre + ": mano ocupada")
	if not almacen.get("_reposicion_manual").call("_entra_entera", caja):
		fallas.append(nombre + ": atraviesa solidos")
	var forma: CollisionShape3D = caja.get_node("Cuerpo")
	var limites := forma.global_transform * forma.shape.get_debug_mesh().get_aabb()
	var metal := Geometria.impacto_visible(
		malla,
		caja.global_position,
		caja.global_position + Vector3.DOWN * ReglasDeLosObjetos.CAIDA_HASTA_EL_PISO
	)
	var q := PhysicsRayQueryParameters3D.create(
		caja.global_position,
		caja.global_position + Vector3.DOWN * ReglasDeLosObjetos.CAIDA_HASTA_EL_PISO,
		mascara
	)
	q.exclude = [caja.get_rid(), jugador.get_rid()]
	var contacto := almacen.get_world_3d().direct_space_state.intersect_ray(q)
	if metal.is_empty() or contacto.is_empty():
		fallas.append(nombre + ": falta contacto bajo la base")
	else:
		if absf(limites.position.y - (metal.punto as Vector3).y) > ReglasDeLosObjetos.ROCE:
			fallas.append(nombre + ": base distinta del metal visible")
		if (metal.punto as Vector3).distance_to(contacto.position) > ReglasDeLosObjetos.ROCE:
			fallas.append(nombre + ": fisica distinta del metal visible")
	print(
		"428_NATIVO_ESTABLE ",
		nombre,
		" inicial=",
		inicio,
		" final=",
		Geometria.estado_caja(caja),
		" metal=",
		metal,
		" contacto=",
		contacto
	)
	await _capturar(nombre + "-estable")
	camara.look_at(caja.global_position)
	for cuadro in 4:
		await physics_frame
	jugador.call("_leer_la_mira")
	if jugador.get("_enfocado") != caja:
		fallas.append(nombre + ": mira real no recoge")
	jugador.call("_unhandled_input", evento)
	if agarre.cuerpo_sostenido() != caja or agarre.manos().sostenido() != caja.get("datos"):
		fallas.append(nombre + ": no recoge el mismo cuerpo y datos")
	print("428_NATIVO_RECOGIDA ", nombre, " misma_caja=", agarre.cuerpo_sostenido() == caja)
	await _capturar(nombre + "-recogida")


func _medir_debajo(nombre: String, caja: RigidBody3D, malla: MeshInstance3D) -> void:
	var espacio := almacen.get_world_3d().direct_space_state
	var forma: CollisionShape3D = caja.get_node("Cuerpo")
	var bounds: AABB = forma.global_transform * forma.shape.get_debug_mesh().get_aabb()
	var base := bounds.get_center()
	base.y = bounds.position.y
	var vista: MeshInstance3D = caja.get_node("Malla")
	var dibujo: AABB = vista.global_transform * vista.get_aabb()
	print(
		"REPRO_428_ESCALA_REAL ",
		nombre,
		" cuerpo=",
		forma.global_transform,
		" bounds=",
		bounds,
		" dibujo=",
		dibujo,
		" base_bounds=",
		base
	)
	if absf(bounds.position.y - dibujo.position.y) > ReglasDeLosObjetos.ROCE:
		fallas.append(nombre + ": cuerpo y dibujo no coinciden en la base medida")
	var desde := caja.global_position
	var hasta := desde + Vector3.DOWN * ReglasDeLosObjetos.CAIDA_HASTA_EL_PISO
	for capa: int in [1, 8, 9]:
		var q := PhysicsRayQueryParameters3D.create(desde, hasta, capa)
		q.exclude = [caja.get_rid(), almacen.get("_jugador").get_rid()]
		var golpe := espacio.intersect_ray(q)
		print(
			"REPRO_428_DEBAJO ",
			nombre,
			" desde=",
			desde,
			" hasta=",
			hasta,
			" base_bounds=",
			base,
			" capa=",
			capa,
			" golpe=",
			golpe
		)
	var visible := Geometria.impacto_visible(malla, desde, hasta)
	print("REPRO_428_MALLA_DEBAJO ", nombre, " golpe=", visible)
	if nombre.begins_with("bano"):
		var riel: MeshInstance3D = almacen.get_node("Estructura/bano_riel_frontal")
		var gris := Geometria.impacto_visible(riel, desde, hasta)
		print("REPRO_428_RIEL_DEBAJO ", nombre, " golpe=", gris)


func _angulos(blanco: bool, gris := false) -> Array[int]:
	if gris:
		return [180]
	var angulos: Array[int] = []
	if blanco:
		for angulo in range(0, 360, 15):
			angulos.append(angulo)
	else:
		angulos.assign([270])
	return angulos


func _pose(malla: MeshInstance3D, objetivo: Vector3, caja: RigidBody3D, blanco := false) -> bool:
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	var capsula: CollisionShape3D = jugador.get_node("Cuerpo")
	var espacio := almacen.get_world_3d().direct_space_state
	for radio: float in [0.9] if blanco else [1.2]:
		for angulo: int in _angulos(blanco, str(malla.name).begins_with("bano_riel")):
			var alrededor := (
				objetivo + Vector3(cos(deg_to_rad(angulo)), 0, sin(deg_to_rad(angulo))) * radio
			)
			var consulta := PhysicsRayQueryParameters3D.create(
				Vector3(alrededor.x, 0.8, alrededor.z),
				Vector3(alrededor.x, -1.0, alrededor.z),
				jugador.collision_mask
			)
			consulta.exclude = [jugador.get_rid(), caja.get_rid()]
			var piso := espacio.intersect_ray(consulta)
			if piso.is_empty() or piso.normal.y < 0.9:
				continue
			var suelo := piso.collider as StaticBody3D
			if suelo == null:
				continue
			var forma_del_suelo := (
				suelo.shape_owner_get_owner(suelo.shape_find_owner(piso.shape)) as Node
			)
			if not (
				suelo.name == "SueloSolido"
				or str(suelo.get_path()).ends_with("/almacen/StaticBody3D")
				or forma_del_suelo.name == "VolumenDelPisoDelBano"
			):
				continue
			var sitio: Vector3 = piso.position + Vector3.UP * 0.005
			var volumen := PhysicsShapeQueryParameters3D.new()
			volumen.shape = capsula.shape
			volumen.transform = Transform3D(Basis.IDENTITY, sitio) * capsula.transform
			volumen.collision_mask = jugador.collision_mask
			volumen.exclude = [jugador.get_rid(), caja.get_rid()]
			volumen.margin = 0.0
			if not espacio.intersect_shape(volumen).is_empty():
				continue
			jugador.global_position = sitio
			var giro: Node3D = jugador.get_node("Giro")
			giro.global_basis = Basis.looking_at(
				Vector3(objetivo.x - sitio.x, 0, objetivo.z - sitio.z)
			)
			camara.position = Vector3.UP * ReglasDelJugador.ALTURA_DE_LA_CAMARA
			camara.look_at(objetivo)
			jugador.reset_physics_interpolation()
			camara.reset_physics_interpolation()
			for cuadro in 2:
				await physics_frame
			var desde := camara.global_position
			var hasta := desde - camara.global_basis.z * ReglasDelJugador.ALCANCE_DE_LA_MIRA
			var visible: Dictionary = Geometria.impacto_visible(malla, desde, hasta)
			if visible.is_empty():
				continue
			consulta.from = desde
			consulta.to = hasta
			consulta.collision_mask = caja.collision_mask
			var fisico := espacio.intersect_ray(consulta)
			if (
				not fisico.is_empty()
				and desde.distance_to(fisico.position) < visible.distancia - 0.01
				and fisico.get("collider") != malla.get_node_or_null("Contorno")
			):
				continue
			if blanco and not str(malla.name).begins_with("bano_riel"):
				var apoyo: Dictionary = almacen.get("_reposicion_manual").call(
					"_apoyo_apuntado", caja
				)
				if (
					apoyo.is_empty()
					or (
						absf(
							(
								(apoyo.position as Vector3).y
								- (malla.global_transform * malla.get_aabb()).end.y
							)
						)
						> 0.015
					)
				):
					continue
				print("REPRO_428_BLANCO_CANDIDATO apoyo=", apoyo, " objetivo=", objetivo)
			print(
				"REPRO_428_POSE malla=",
				malla.get_path(),
				" piso=",
				piso.collider.get_path(),
				" pies=",
				sitio,
				" visible=",
				visible
			)
			return true
	return false


func _capturar(nombre: String) -> void:
	for cuadro in 10:
		await process_frame
		await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(salida)
	var codigo := root.get_texture().get_image().save_png(salida.path_join(nombre + ".png"))
	var camara: Camera3D = almacen.get("_jugador").get_node("Giro/Camara")
	print("REPRO_428_PNG ", nombre, " camara_guardada=", camara.global_transform)
	if codigo != OK:
		fallas.append("No se guardó captura " + nombre)
