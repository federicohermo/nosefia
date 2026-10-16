extends Node

# Sólo prepara pose/reloj/cuadro y observa. Cada gesto de juego llega desde Chrome.
# Se monta fuera del PCK por override.cfg y escena Node; no reemplaza el main original.
var _almacen: Node3D
var _jugador: CharacterBody3D
var _puesto: Node3D
var _camara: Camera3D
var _sprite: AnimatedSprite3D
var _suelo: StaticBody3D
var _altura_original := 0.0
var _centro := Vector3.ZERO
var _punto := Vector3.ZERO
var _fallos: Array[String] = []
var _soltados := 0
var _compras := 0
var _finales := 0
var _ocupado := true
var _ultimo_id := 0
var _tiempo := 0.0
var _etapa := "cargando"


func _ready() -> void:
	# SceneTree seguía observando durante pausa; el nodo debe conservar ese comportamiento.
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_abrir")


func _requerir(condicion: bool, mensaje: String) -> bool:
	if not condicion:
		_fallos.append(mensaje)
		push_error("FIXTURE_429: " + mensaje)
	return condicion


func _sincronizar() -> void:
	for _cuadro in 4:
		await get_tree().physics_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _piso_en(pie: Vector3) -> Dictionary:
	var rayo := PhysicsRayQueryParameters3D.create(
		Vector3(pie.x, _altura_original + 0.2, pie.z),
		Vector3(pie.x, _altura_original - 0.3, pie.z),
		1
	)
	rayo.exclude = [_jugador.get_rid()]
	return _jugador.get_world_3d().direct_space_state.intersect_ray(rayo)


func _contactos_en(pose: Transform3D) -> Array[Dictionary]:
	var forma: CollisionShape3D = _jugador.get_node("Cuerpo")
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma.shape
	consulta.transform = pose * forma.transform
	consulta.margin = 0.0
	consulta.collision_mask = _jugador.collision_mask
	consulta.exclude = [_jugador.get_rid()]
	return _jugador.get_world_3d().direct_space_state.intersect_shape(consulta)


func _ubicar(pie: Vector3) -> bool:
	var piso := _piso_en(pie)
	if not _requerir(piso.get("collider") == _suelo, "La pose no encuentra SueloSolido"):
		return false
	pie.y = piso.position.y + 0.002
	var pose := Transform3D(Basis.IDENTITY, pie)
	if not _requerir(_contactos_en(pose).is_empty(), "La cápsula prospectiva está solapada"):
		return false
	_jugador.call("ubicar", pose)
	await _sincronizar()
	return _requerir(
		_contactos_en(_jugador.global_transform).is_empty(), "La cápsula quedó solapada"
	)


func _mirar(punto: Vector3) -> bool:
	var direccion := punto - _camara.global_position
	var angulos := Basis.looking_at(direccion.normalized(), Vector3.UP).get_euler()
	var control: RefCounted = _jugador.get("_control")
	control.call("orientar", angulos.y)
	var sensibilidad: float = _jugador.get("_mirada").get("_sensibilidad")
	control.call("girar", Vector2(0.0, -angulos.x / sensibilidad))
	control.call("avanzar_el_dibujo", 1.0)
	_jugador.call("_aplicar_la_rotacion")
	_jugador.reset_physics_interpolation()
	await _sincronizar()
	return _requerir(
		(-_camara.global_basis.z).angle_to(punto - _camara.global_position) < 0.005,
		"La cámara dibujada no mira el punto preparado"
	)


func _abrir() -> void:
	_almacen = load("res://src/escenas/almacen.tscn").instantiate()
	var partida: GDScript = load("res://src/dominio/empleo/partida.gd")
	_almacen.set("_partida", partida.call("nueva"))
	get_tree().root.add_child(_almacen)
	_jugador = _almacen.get_node("Jugador")
	_puesto = _almacen.get_node("Estructura/Ventanilla")
	_camara = _jugador.get_node("Giro/Camara")
	_sprite = _puesto.get("comprador_visible")
	_suelo = _almacen.get_node("Estructura/SueloSolido")
	_altura_original = _jugador.global_position.y
	_almacen.get("_reloj").set_process(false)
	_almacen.get("_agarre").objeto_soltado.connect(func(_cuerpo: Node3D) -> void: _soltados += 1)
	_almacen.get("_atenciones").compra_realizada.connect(func() -> void: _compras += 1)
	_almacen.get("_atenciones").conversacion_terminada.connect(func() -> void: _finales += 1)
	await _sincronizar()
	_centro = _sprite.global_position + _sprite.global_basis.z * 1.3
	if await _ubicar(_centro):
		await _mirar(_sprite.global_position + Vector3.UP * 0.35)
	_etapa = "hueco"
	_ocupado = false
	await _publicar()
	print("FIXTURE_WEB_429_LISTO")


func _process(delta: float) -> void:
	_tiempo += delta
	if not _ocupado and _tiempo >= 0.1 and is_instance_valid(_almacen):
		_tiempo = 0.0
		_ocupado = true
		call_deferred("_leer_comando")


func _leer_comando() -> void:
	var texto: String = JavaScriptBridge.eval("JSON.stringify(window.__429_command || null)", true)
	var comando: Variant = JSON.parse_string(texto)
	if comando is Dictionary and int(comando.get("id", 0)) > _ultimo_id:
		await _preparar(comando)
		_ultimo_id = int(comando.id)
	await _publicar()
	_ocupado = false


func _preparar(comando: Dictionary) -> void:
	match String(comando.get("accion", "")):
		"llegar":
			_almacen.get("_reloj").call("avanzar", 120.0)
			await get_tree().create_timer(3.0).timeout
			_sprite.stop()
			_sprite.set_frame_and_progress(0, 0.0)
			_punto = _pixel_comun()
			await _mirar(_punto)
			_etapa = "tin"
		"cuadro":
			_sprite.stop()
			_sprite.set_frame_and_progress(int(comando.cuadro), 0.0)
			await _sincronizar()
		"caja":
			var caja: Node3D = _almacen.get("_cajas_de_productos")[0]
			_requerir(
				_almacen.get("_agarre").call("pedir_agarrar", caja.get("datos"), caja),
				"No se pudo preparar la caja real"
			)
			await _sincronizar()
		"lateral":
			await _lateral(float(comando.lado))
		"centro":
			if await _ubicar(_centro):
				await _mirar(_punto)
		"oculto":
			await _mirar_busto_oculto()
		"fin":
			print("FIXTURE_WEB_429_FINAL ", JSON.stringify({"fallos": _fallos}))


func _pixel_comun() -> Vector3:
	var cuadros := _sprite.sprite_frames
	var textura := cuadros.get_frame_texture(&"idle", 0)
	var imagenes: Array[Image] = []
	for cuadro in cuadros.get_frame_count(&"idle"):
		imagenes.append(cuadros.get_frame_texture(&"idle", cuadro).get_image())
	for y in range(textura.get_height() / 4, textura.get_height() / 2, 4):
		for x in range(textura.get_width() / 8, textura.get_width() * 7 / 8, 4):
			var opaco := true
			for imagen in imagenes:
				if imagen.get_pixel(x, y).a == 0.0:
					opaco = false
					break
			if opaco:
				var local := (
					(Vector2(x, y) + Vector2.ONE * 0.5 - textura.get_size() / 2.0)
					* _sprite.pixel_size
				)
				return _sprite.to_global(Vector3(local.x, -local.y, 0.0))
	_requerir(false, "No hay punto opaco compartido por los cuadros reales")
	return _sprite.global_position


func _mirar_busto_oculto() -> void:
	var antepecho: MeshInstance3D = _puesto.get("antepecho")
	var textura := _sprite.sprite_frames.get_frame_texture(&"idle", _sprite.frame)
	var imagen := textura.get_image()
	var inversa := antepecho.global_transform.affine_inverse()
	var caras := antepecho.mesh.get_faces()
	for distancia: float in [1.3, 1.6, 1.9]:
		var pie := _sprite.global_position + _sprite.global_basis.z * distancia
		var piso := _piso_en(pie)
		if piso.get("collider") != _suelo:
			continue
		pie.y = piso.position.y + 0.002
		if not _contactos_en(Transform3D(Basis.IDENTITY, pie)).is_empty():
			continue
		if not await _ubicar(pie):
			return
		var desde := inversa * _camara.global_position
		for y in range(imagen.get_height() / 2, imagen.get_height(), 4):
			for x in range(imagen.get_width() / 4, imagen.get_width() * 3 / 4, 4):
				if imagen.get_pixel(x, y).a == 0.0:
					continue
				var local := (
					(Vector2(x, y) + Vector2.ONE * 0.5 - textura.get_size() / 2.0)
					* _sprite.pixel_size
				)
				var punto := _sprite.to_global(Vector3(local.x, -local.y, 0.0))
				var hasta := inversa * punto
				for indice in range(0, caras.size(), 3):
					var golpe: Variant = Geometry3D.segment_intersects_triangle(
						desde, hasta, caras[indice], caras[indice + 1], caras[indice + 2]
					)
					if golpe == null:
						continue
					print(
						"PREMISA_OCLUSION_429 ",
						JSON.stringify(
							{
								"pixel": str(Vector2i(x, y)),
								"alfa": imagen.get_pixel(x, y).a,
								"punto": str(punto),
								"ojo": str(_camara.global_position),
								"triangulo": indice / 3,
								"golpe_local": str(golpe)
							}
						)
					)
					await _mirar(punto)
					_requerir(
						not _puesto.get("objetivo").call(
							"admite_foco_en", punto, _camara.global_position
						),
						"El antepecho permite enfocar el busto geométricamente oculto"
					)
					return
	_requerir(false, "No se halló punto opaco realmente oculto desde una pose libre")


func _lateral(lado: float) -> void:
	var preparada := false
	for distancia: float in [0.8, 0.65, 0.5]:
		var pie := _centro + _sprite.global_basis.x * lado * distancia
		var piso := _piso_en(pie)
		if piso.get("collider") != _suelo:
			continue
		pie.y = piso.position.y + 0.002
		if not _contactos_en(Transform3D(Basis.IDENTITY, pie)).is_empty():
			continue
		preparada = await _ubicar(pie)
		break
	if _requerir(preparada, "No hay pose lateral físicamente válida"):
		await _mirar(_punto)


func _publicar() -> void:
	await RenderingServer.frame_post_draw
	var atencion: RefCounted = _almacen.get("_atenciones").call("atencion")
	var dialogo: RefCounted = atencion.call("dialogo") if atencion != null else null
	var agarre: Node = _almacen.get("_agarre")
	var cuerpo: Node3D = agarre.call("cuerpo_sostenido")
	var foco: Node3D = _jugador.call("enfocado")
	var overlay := _sprite.material_overlay as ShaderMaterial
	var consulta := _piso_en(_jugador.global_position)
	var contexto: RefCounted = _puesto.get("objetivo").call(
		"contexto_de_interaccion", agarre.call("manos").call("sostenido")
	)
	var interpolada := false
	var ancestro: Node = _camara
	while ancestro != null:
		if ancestro is Node3D and ancestro.is_physics_interpolated_and_enabled():
			interpolada = true
		ancestro = ancestro.get_parent()
	var dibujada := (
		_camara.get_global_transform_interpolated() if interpolada else _camara.global_transform
	)
	var estado := {
		"id": _ultimo_id,
		"etapa": _etapa,
		"ocupado": _ocupado,
		"fallos": _fallos,
		"pausa": get_tree().paused,
		"suspendido": _jugador.call("suspendido"),
		"cursor": Input.mouse_mode,
		"panel": _puesto.get("_abierta"),
		"entrada": dialogo.call("entrada_actual") if dialogo != null else "",
		"indice": dialogo.get("_indice") if dialogo != null else -1,
		"terminado": dialogo.call("terminado") if dialogo != null else true,
		"mano": str(cuerpo.get_instance_id()) if cuerpo != null else "0",
		"pedido":
		(
			str(atencion.call("comprador").call("pedido").get_instance_id())
			if atencion != null
			else "0"
		),
		"vendida": atencion.call("vendida") if atencion != null else false,
		"compras": _compras,
		"soltados": _soltados,
		"finales": _finales,
		"primario": contexto.get("primario"),
		"foco": str(foco.get_path()) if foco != null else "",
		"frame": _sprite.frame,
		"visible": _sprite.visible,
		"contorno": overlay != null,
		"frame_del_contorno":
		(
			(
				overlay.get_shader_parameter("figura")
				== _sprite.sprite_frames.get_frame_texture(&"idle", _sprite.frame)
			)
			if overlay != null
			else false
		),
		"vidrio": _puesto.get_node_or_null("Vidrio") != null,
		"capa_generica": _puesto.collision_layer,
		"suelo": consulta.get("collider") == _suelo,
		"capsula_libre": _contactos_en(_jugador.global_transform).is_empty(),
		"camara_actual": str(_camara.global_transform),
		"camara_dibujada": str(dibujada),
		"interpolada": interpolada,
		"jugador": str(_jugador.global_transform),
		"viewport": str(get_tree().root.size),
	}
	JavaScriptBridge.eval("window.__429_state = " + JSON.stringify(estado), true)
