extends SceneTree

var _local: Node3D
var _jugador: CharacterBody3D
var _vista: Camera3D
var _agarre: Agarre
var _salida: String
var _registro: Array[Dictionary] = []
var _fallo := false


func _initialize() -> void:
	_correr.call_deferred()


func _exigir(condicion: bool, motivo: String) -> void:
	if not condicion:
		_fallo = true
		push_error("DIAGNOSTICO426 " + motivo)


func _cuadros(cantidad: int = 5) -> void:
	for _i in cantidad:
		await physics_frame
		await RenderingServer.frame_post_draw


func _crear() -> void:
	_local = load("res://src/escenas/almacen.tscn").instantiate()
	_local.set("_partida", Partida.desde({"jornada": 2, "medios": 0}))
	root.add_child(_local)
	_local.get_node("Interfaz/PersianaDeLaNoche").terminar()
	(_local.get("_reloj") as Node).set_process(false)
	_jugador = _local.get("_jugador")
	_vista = _jugador.get_node("Giro/Camara")
	_agarre = _local.get("_agarre")
	_jugador.reanudar()
	await _cuadros(20)
	await _captura("arranque-" + str(_registro.size()))


func _destruir() -> void:
	for audio: Node in _local.find_children("*", "Node", true, false):
		if audio is AudioStreamPlayer or audio is AudioStreamPlayer3D:
			audio.call("stop")
			audio.set("stream", null)
	_vista = null
	_jugador = null
	_agarre = null
	_local.queue_free()
	_local = null
	for _i in 4:
		await process_frame


func _caja(id: Producto.Id) -> Node3D:
	for caja: Node3D in _local.get("_cajas_de_productos"):
		if caja.get("producto") == id:
			return caja
	return null


func _grupo(id: Producto.Id) -> MultiMeshInstance3D:
	return _local.get("_reposicion_manual").get_node("SueltosDe" + Catalogo.de(id).nombre)


func _centro(objeto: Node3D) -> Vector3:
	var malla := objeto.get_node("Malla") as MeshInstance3D
	return malla.global_transform * malla.mesh.get_aabb().get_center()


func _apuntar(punto: Vector3) -> void:
	var vector := punto - _vista.global_position
	var plano := Vector3(vector.x, 0, vector.z)
	var control: ControlDelJugador = _jugador.get("_control")
	var mirada: Mirada = control.get("_mirada")
	control.orientar(Basis.looking_at(plano, Vector3.UP).get_euler().y)
	var pitch := atan2(vector.y, plano.length())
	control.girar(Vector2(0, -pitch / float(mirada.get("_sensibilidad"))))
	await _cuadros(20)
	_jugador.call("_aplicar_la_rotacion")


func _mirar(punto: Vector3, direccion: Vector3, distancia: float) -> void:
	var ojo := punto + direccion * distancia
	ojo.y = ReglasDelJugador.ALTURA_DE_LA_CAMARA + 0.1
	var pie := ojo - Vector3.UP * ReglasDelJugador.ALTURA_DE_LA_CAMARA
	var horizontal := Vector3(punto.x, ojo.y, punto.z)
	_jugador.ubicar(Transform3D(Basis.looking_at(horizontal - ojo, Vector3.UP), pie))
	_jugador.reanudar()
	await _cuadros(20)
	_jugador.call("_aplicar_la_rotacion")
	await _apuntar(punto)
	await _cuadros()


func _enfocar(objeto: Node3D) -> bool:
	for direccion: Vector3 in [Vector3.RIGHT, Vector3.BACK, Vector3.LEFT, Vector3.FORWARD]:
		var ojo_pedido := _centro(objeto) + direccion * 1.05
		# El deposito termina en z=-8.25329; un rayo acertado no valida un ojo dentro de pared.
		if ojo_pedido.z > -8.4:
			continue
		await _mirar(_centro(objeto), direccion, 1.05)
		var enfocado: Node3D = _jugador.get("_enfocado")
		_registro.append(
			{
				"rayo": str(objeto.get_path()),
				"ojo_pedido": str(ojo_pedido),
				"ojo_en_interior_del_deposito": _vista.global_position.z < -8.25329,
				"enfocado": str(enfocado.get_path()) if enfocado else "null",
				"ojo": str(_vista.global_position),
				"distancia": _vista.global_position.distance_to(_centro(objeto))
			}
		)
		if enfocado == objeto:
			_exigir(_vista.global_position.z < -8.25329, "Ojo fuera del espesor de pared")
			return true
	_exigir(false, "No se enfoca por geometria: " + str(objeto.get_path()))
	return false


func _accion(accion: StringName) -> void:
	var evento := InputEventAction.new()
	evento.action = accion
	evento.pressed = true
	_jugador.call("_unhandled_input", evento)
	await _cuadros(2)


func _captura(nombre: String) -> void:
	await _cuadros(3)
	root.get_texture().get_image().save_png(_salida.path_join(nombre + ".png"))
	var actual := root.get_camera_3d()
	_registro.append(
		{
			"camara_actual": str(actual.get_path()) if actual else "null",
			"camara_esperada": str(_vista.get_path()),
			"camara_correcta": actual == _vista,
			"ojo_en_interior_del_deposito": _vista.global_position.z < -8.25329,
			"captura": nombre,
			"ojo": str(_vista.global_position),
			"mirada": str(-_vista.global_basis.z)
		}
	)


func _sacar(id: Producto.Id, indice: int, etiqueta: String) -> RigidBody3D:
	if not await _enfocar(_caja(id)):
		return null
	await _accion(ReglasDelJugador.ACCION_USAR)
	var cuerpo := _agarre.cuerpo_sostenido() as RigidBody3D
	_exigir(cuerpo != null, "Extraer " + Catalogo.de(id).nombre)
	if cuerpo == null:
		return null
	_exigir(
		(_agarre.manos().sostenido() as UnidadDeProducto).producto.id == id, "Identidad extraida"
	)
	_exigir((cuerpo.get_node("Malla") as MeshInstance3D).visible, "Malla en mano")
	if indice == 0:
		await _captura(etiqueta + "-mano")
	# El gesto de soltar es real; despues se distribuyen las unidades sobre el piso libre
	# para medir cada indice y el culling sin que una pila oculte las unidades anteriores.
	await _mirar(Vector3(4.5, 0.4, -9.4), Vector3.BACK, 1.05)
	await _apuntar(_vista.global_position + Vector3.UP + Vector3.FORWARD)
	await _cuadros()
	_exigir(_jugador.get("_enfocado") == null, "Soltar con mira vacia")
	await _accion(ReglasDeLosObjetos.ACCION_AGARRAR)
	_exigir(_agarre.cuerpo_sostenido() == null, "Soltado por el clic izquierdo")
	cuerpo.freeze = true
	cuerpo.global_position = Vector3(
		4.18 + (indice % 4) * 0.6, 0.4, -8.95 - floori(float(indice) / 4.0) * 0.6
	)
	cuerpo.linear_velocity = Vector3.ZERO
	cuerpo.angular_velocity = Vector3.ZERO
	cuerpo.reset_physics_interpolation()
	cuerpo.freeze = false
	await _cuadros(2)
	return cuerpo


func _validar(id: Producto.Id, cuerpos: Array[RigidBody3D], paso: String) -> void:
	var grupo := _grupo(id)
	grupo.call("_process", 0.0)
	var agrupados: Array = grupo.get("cuerpos")
	_exigir(grupo.multimesh.visible_instance_count == cuerpos.size(), "Cantidad dibujada " + paso)
	_exigir(agrupados.size() == cuerpos.size(), "Cantidad de cuerpos " + paso)
	for cuerpo in cuerpos:
		var indice := agrupados.find(cuerpo)
		_exigir(indice >= 0, "Indice de cuerpo " + paso)
		if indice < 0:
			continue
		_registro.append(
			{
				"estado_cuerpo": paso,
				"id": cuerpo.get_instance_id(),
				"dormido": cuerpo.sleeping,
				"congelado": cuerpo.freeze,
				"posicion": str(cuerpo.global_position),
				"velocidad": str(cuerpo.linear_velocity)
			}
		)
		var malla := cuerpo.get_node("Malla") as MeshInstance3D
		var matriz := grupo.multimesh.get_instance_transform(indice)
		var dibujado := not is_zero_approx(matriz.basis.determinant())
		_exigir(int(malla.visible) + int(dibujado) == 1, "Dibujo unico " + paso)
		if dibujado:
			_exigir(
				grupo.custom_aabb.grow(0.001).encloses(matriz * grupo.multimesh.mesh.get_aabb()),
				"AABB " + paso
			)
	_registro.append(
		{
			"validacion": paso,
			"producto": Catalogo.de(id).nombre,
			"cuerpos": cuerpos.size(),
			"capacidad": grupo.multimesh.instance_count,
			"aabb": str(grupo.custom_aabb)
		}
	)


func _cantidad() -> void:
	await _crear()
	var id := Producto.Id.JORGILLO
	var capacidad := _grupo(id).multimesh.instance_count
	var repositor: Repositor = _local.get("_repositor")
	var cantidad := repositor.caja(id).unidades()
	_exigir(cantidad >= 8 and cantidad > capacidad, "Caja que atraviesa capacidad inicial")
	var cuerpos: Array[RigidBody3D] = []
	for indice in cantidad:
		var cuerpo := await _sacar(id, indice, "gj25")
		if cuerpo == null:
			return
		cuerpos.append(cuerpo)
		_validar(id, cuerpos, "cantidad-" + str(indice + 1))
		if indice + 1 in [1, 6, 7, 8, cantidad]:
			await _mirar(Vector3(5.0, 0.2, -9.3), Vector3.BACK, 1.1)
			await _captura("gj25-" + str(indice + 1))
	var intermedia := cuerpos[floori(float(cuerpos.size()) / 2.0)]
	if not await _enfocar(intermedia):
		return
	_validar(id, cuerpos, "intermedia-enfocada")
	await _captura("gj25-intermedia-enfocada")
	await _accion(ReglasDeLosObjetos.ACCION_AGARRAR)
	_exigir(_agarre.cuerpo_sostenido() == intermedia, "Recoger intermedia")
	cuerpos.erase(intermedia)
	_validar(id, cuerpos, "intermedia-retirada")
	await _captura("gj25-intermedia-retirada")
	if await _enfocar(_caja(id)):
		await _accion(ReglasDeLosObjetos.ACCION_AGARRAR)
		_exigir(_agarre.cuerpo_sostenido() == null, "Devolver intermedia")
		_validar(id, cuerpos, "intermedia-devuelta")
	await _destruir()


func _saladik() -> void:
	await _crear()
	var cuerpo := await _sacar(Producto.Id.SALADIK, 0, "gj24")
	if cuerpo == null:
		return
	var cuerpos: Array[RigidBody3D] = [cuerpo]
	await _mirar(_centro(cuerpo), Vector3.RIGHT, 1.05)
	_validar(Producto.Id.SALADIK, cuerpos, "saladik-caida")
	await _captura("gj24-caida")
	await _cuadros(160)
	if await _enfocar(cuerpo):
		_validar(Producto.Id.SALADIK, cuerpos, "saladik-enfocado")
		await _captura("gj24-enfocado")
		await _apuntar(_vista.global_position + Vector3.UP + Vector3.FORWARD)
		await _cuadros()
		_validar(Producto.Id.SALADIK, cuerpos, "saladik-foco-perdido")
		if await _enfocar(cuerpo):
			await _accion(ReglasDeLosObjetos.ACCION_AGARRAR)
			_exigir(_agarre.cuerpo_sostenido() == cuerpo, "Recogida Saladik")
			cuerpos.clear()
			_validar(Producto.Id.SALADIK, cuerpos, "saladik-mano")
			await _captura("gj24-recogido")
			if await _enfocar(_caja(Producto.Id.SALADIK)):
				await _accion(ReglasDeLosObjetos.ACCION_AGARRAR)
				_exigir(_agarre.cuerpo_sostenido() == null, "Devolucion Saladik")
				await _captura("gj24-devuelto")
	await _destruir()


func _mixtos() -> void:
	await _crear()
	var productos: Array[Producto.Id] = [
		Producto.Id.MAROLINI, Producto.Id.SALADIK, Producto.Id.LAYSNTT
	]
	var por_producto: Dictionary[Producto.Id, Array] = {}
	var lugar := 0
	for id in productos:
		var cuerpos: Array[RigidBody3D] = []
		for _unidad in 3:
			var cuerpo := await _sacar(id, lugar, "gj23")
			if cuerpo == null:
				return
			cuerpos.append(cuerpo)
			lugar += 1
		por_producto[id] = cuerpos
	await _mirar(Vector3(5.0, 0.2, -9.3), Vector3.BACK, 1.1)
	for tramo: String in ["quieto", "costado", "giro"]:
		if tramo == "costado":
			Input.action_press(ReglasDelJugador.ACCION_DERECHA)
			await _cuadros(8)
			Input.action_release(ReglasDelJugador.ACCION_DERECHA)
		if tramo == "giro":
			await _apuntar(Vector3(4.7, 0.2, -9.3))
			await _cuadros()
		for id in productos:
			var cuerpos: Array[RigidBody3D] = []
			cuerpos.assign(por_producto[id])
			_validar(id, cuerpos, "mixtos-" + tramo)
			var origen := _grupo(id).global_position
			var origen_fuera := (
				_vista.is_position_behind(origen)
				or not root.get_visible_rect().has_point(_vista.unproject_position(origen))
			)
			_exigir(origen_fuera, "Origen fuera del cuadro")
			_registro.append(
				{"origen_fuera": origen_fuera, "tramo": tramo, "producto": Catalogo.de(id).nombre}
			)
		await _captura("gj23-" + tramo)
	await _destruir()


func _correr() -> void:
	_salida = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(_salida)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	Engine.max_fps = 90
	Guardado.ruta_por_defecto = "user://diagnostico426.guardado"
	# Control del ciclo de vida del fixture: dejar dibujar la raiz antes de crear la primera escena.
	await process_frame
	await RenderingServer.frame_post_draw
	await _saladik()
	if not _fallo:
		await _cantidad()
	if not _fallo:
		await _mixtos()
	var archivo := FileAccess.open(_salida.path_join("recorrido.json"), FileAccess.WRITE)
	archivo.store_string(
		JSON.stringify(
			{
				"recorrido_de_diagnostico": true,
				"renderer": RenderingServer.get_current_rendering_driver_name(),
				"registro": _registro,
				"fallo": _fallo
			},
			"\t"
		)
	)
	archivo.close()
	print("DIAGNOSTICO426_FINAL fallo=", _fallo)
	quit(1 if _fallo else 0)
