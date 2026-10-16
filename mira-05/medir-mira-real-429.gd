extends "D:/nosefia-carril-A-429-444/429-paquete-nativo-03/capturar-paquete-429.gd"


func _medir_mira() -> void:
	var cache := _medir_cache()
	var medidas: Array[Dictionary] = []
	for mano: String in ["vacia", "caja", "unidad"]:
		_almacen.get("azar_de_la_apertura").set("seed", 429)
		_almacen.call("_al_abrir_la_jornada", 1)
		_almacen.get("_reloj").set_process(false)
		_jugador.set_physics_process(false)
		_jugador.set_process(false)
		if mano == "caja":
			var caja: Node3D = _almacen.get("_cajas_de_productos")[0]
			_requerir(
				_almacen.get("_agarre").call("pedir_agarrar", caja.get("datos"), caja),
				"No se preparó mano con caja"
			)
		elif mano == "unidad":
			_almacen.get("_reposicion_manual").call("retirar", Producto.Id.ACTRONCITO)
			_requerir(
				_almacen.get("_agarre").call("cuerpo_sostenido") != null,
				"No se preparó mano con unidad"
			)
		await _sincronizar()
		var sondas := await _sondar_pasillos()
		var mayor := -1
		var mejor := Transform3D.IDENTITY
		for sonda: Dictionary in sondas:
			if sonda.poblacion.size() > mayor:
				mayor = sonda.poblacion.size()
				mejor = sonda.pose
		if not _requerir(mayor >= 0, "No hay pose física libre para " + mano):
			continue
		_jugador.call("ubicar", mejor)
		await _sincronizar()
		var campo: Area3D = _jugador.get_node("Giro/Camara/CampoDeInteraccion")
		var poblacion := _poblacion(campo)
		_requerir(
			poblacion.size() == mayor, "La densidad medida cambió al volver a la pose elegida"
		)
		_requerir(
			_contactos_en(_jugador.global_transform).is_empty(), "La cápsula de CPU está solapada"
		)
		_requerir(
			_piso_en(_jugador.global_position).get("collider") == _suelo,
			"La sonda CPU abandonó SueloSolido"
		)
		var muestras: Array[int] = []
		for _consulta in 20:
			_jugador.call("_leer_la_mira")
		for _consulta in 200:
			var inicio := Time.get_ticks_usec()
			_jugador.call("_leer_la_mira")
			muestras.append(Time.get_ticks_usec() - inicio)
		muestras.sort()
		medidas.append(
			{
				"mano": mano,
				"pose": str(mejor),
				"camara": str(_camara.global_transform),
				"poblacion": poblacion,
				"campo": campo.get_overlapping_bodies().size(),
				"maximo_medido": mayor,
				"sondas": sondas,
				"consultas": 200,
				"p50_us": muestras[100],
				"p95_us": muestras[190],
				"max_us": muestras.back()
			}
		)
	var archivo := FileAccess.open(_salida.path_join("medicion-mira-real.json"), FileAccess.WRITE)
	(
		archivo
		. store_string(
			(
				JSON
				. stringify(
					{
						"alcance":
						"CPU nativa por consulta en la pose más densa de las sondas físicamente válidas por cada estado de mano. Máscaras, papeles y grupos productivos intactos; las poblaciones cambian por diseño y no son control de igual carga. Cuerpo/cámara fijos sólo durante la medición CPU; no acredita FPS ni Web.",
						"cache_comprador": cache,
						"medidas": medidas
					},
					"\t"
				)
			)
		)
	)
	archivo.close()


func _medir_cache() -> Array[Dictionary]:
	var objetivo: Node3D = _puesto.get("objetivo")
	var sprite: AnimatedSprite3D = _puesto.get("comprador_visible")
	var registros: Array[Dictionary] = []
	for cuadro: int in [0, 3]:
		sprite.stop()
		sprite.set_frame_and_progress(cuadro, 0.0)
		_jugador.call("_leer_la_mira")
		var textura := sprite.sprite_frames.get_frame_texture(&"idle", cuadro)
		var imagenes: Dictionary = objetivo.get("_imagenes")
		var imagen: Image = imagenes.get(textura)
		_requerir(imagen != null, "La consulta no guardó el alfa del cuadro")
		var cantidad := imagenes.size()
		for _consulta in 200:
			_jugador.call("_leer_la_mira")
		var despues: Dictionary = objetivo.get("_imagenes")
		_requerir(
			despues.size() == cantidad and despues.get(textura) == imagen,
			"Se reemplazó la imagen de alfa en consultas repetidas"
		)
		registros.append(
			{
				"frame": cuadro,
				"consultas": 200,
				"imagenes_antes": cantidad,
				"imagenes_despues": despues.size(),
				"image_id_antes": str(imagen.get_instance_id()),
				"image_id_despues": str(despues.get(textura).get_instance_id())
			}
		)
	return registros


func _poblacion(campo: Area3D) -> PackedStringArray:
	var resultado := PackedStringArray()
	for cuerpo: Node3D in campo.get_overlapping_bodies():
		if cuerpo.is_in_group("interactuable"):
			resultado.append(str(cuerpo.get_path()))
	resultado.sort()
	return resultado


func _sondar_pasillos() -> Array[Dictionary]:
	var sondas: Array[Dictionary] = []
	var campo: Area3D = _jugador.get_node("Giro/Camara/CampoDeInteraccion")
	for ruta: String in ["gondolanueva", "gondolanueva2", "gondolanueva_001"]:
		var mueble: Node3D = _almacen.get_node("Estructura/" + ruta)
		var limites := AABB()
		var primero := true
		for malla: MeshInstance3D in mueble.find_children("*", "MeshInstance3D", true, false):
			var caja := malla.global_transform * malla.get_aabb()
			limites = caja if primero else limites.merge(caja)
			primero = false
		for lado: float in [-1.0, 1.0]:
			for fraccion: float in [0.25, 0.5, 0.75]:
				var pie := limites.get_center()
				pie.x += lado * (limites.size.x / 2.0 + 0.65)
				pie.z = limites.position.z + limites.size.z * fraccion
				var piso := _piso_en(pie)
				if piso.get("collider") != _suelo:
					continue
				pie.y = piso.position.y + 0.003
				var direccion := limites.get_center() - pie
				direccion.y = 0.0
				var pose := Transform3D(Basis.looking_at(direccion.normalized(), Vector3.UP), pie)
				if not _contactos_en(pose).is_empty():
					continue
				_jugador.call("ubicar", pose)
				await _sincronizar()
				sondas.append({"mueble": ruta, "pose": pose, "poblacion": _poblacion(campo)})
	return sondas
