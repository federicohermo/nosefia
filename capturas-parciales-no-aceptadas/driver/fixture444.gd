extends Node

const TEXTOS: Array[String] = [
	"Hola, ¿qué tal? Qué tarde se hizo… me alegra que todavía esté abierto el negocio.",
	(
		"Salí tardísimo del trabajo y no tuve un buen día. No vendimos suficiente. "
		+ "Por eso busco un momento de tranquilidad y placer, ¿vos entendes?"
	),
	"Quiero una botella de jabón Poético, una lata de papitas Progres y unos preservativos Duronga.",
	(
		"¡Guau, salió la colección de los productos del Chiqui Tapia! No me había dado cuenta. "
		+ "Ese señor es mi ídolo. Siempre me da los mejores tips."
	),
	"Gracias, compañero. Cuando quieras podes venir a casa y los probamos juntos.",
	"Hola… ¿me darías un vino Terminator, un Fernet God y una cajita de Actroncito?",
	"Zzzzzz.zzzzz.zzzzz",
	"Perdon, me quedé dormida... ¿En dónde estaba?",
	"Ah sí, gracias… Espero que esto me ayude a dormir mejor…"
]

# Sólo prepara jornada, pose, reloj y objetos reales; cada gesto llega desde el driver externo.
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
var _cerrando := false
var _ultimo_id := 0
var _tiempo := 0.0
var _etapa := "cargando"
var _nativo := false
var _archivo_comandos := ""
var _archivo_estado := ""
var _carpeta_capturas := ""
var _ultima_captura := ""
var _guion: Resource
var _deposito_inicial: Dictionary[int, int] = {}
var _unidades_preparadas: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_nativo = not OS.has_feature("web")
	if _nativo:
		_archivo_comandos = OS.get_environment("NOSEFIA444_COMANDOS")
		_archivo_estado = OS.get_environment("NOSEFIA444_ESTADO")
		_carpeta_capturas = OS.get_environment("NOSEFIA444_CAPTURAS")
		get_tree().root.size = Vector2i(1280, 720)
		get_tree().root.position = Vector2i(40, 40)
		DirAccess.make_dir_recursive_absolute(_carpeta_capturas)
	call_deferred("_abrir")


func _requerir(condicion: bool, mensaje: String) -> bool:
	if not condicion:
		_fallos.append(mensaje)
		push_error("FIXTURE_444: " + mensaje)
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
	_guion = load("res://assets/dialogos/compradores_jornada_2.tres")
	if not _requerir(_guion != null, "El PCK no contiene guiones444"):
		return
	var textos := PackedStringArray()
	for clave: String in ["fede", "despedida_fede", "mia", "despedida_mia"]:
		var bloque: PackedStringArray = _guion.get(clave)
		for texto: String in bloque:
			textos.append(texto.replace("[color=#e4f850]", "").replace("[/color]", ""))
	_requerir(Array(textos) == TEXTOS, "Los nueve textos no coinciden con la fuente fijada")
	_almacen = load("res://src/escenas/almacen.tscn").instantiate()
	var partida: GDScript = load("res://src/dominio/empleo/partida.gd")
	_almacen.set("_partida", partida.call("desde", {"jornada": 2, "medios": 0}))
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
	_etapa = "jornada2"
	_ocupado = false
	await _publicar()
	print("FIXTURE_444_LISTO")


func _process(delta: float) -> void:
	_tiempo += delta
	if not _cerrando and not _ocupado and _tiempo >= 0.1 and is_instance_valid(_almacen):
		_tiempo = 0.0
		_ocupado = true
		call_deferred("_leer_comando")


func _leer_comando() -> void:
	var texto := "null"
	if _nativo:
		if FileAccess.file_exists(_archivo_comandos):
			texto = FileAccess.get_file_as_string(_archivo_comandos)
	else:
		texto = Engine.get_singleton("JavaScriptBridge").call(
			"eval", "JSON.stringify(window.__444_command || null)", true
		)
	var comando: Variant = JSON.parse_string(texto)
	if comando is Dictionary and int(comando.get("id", 0)) > _ultimo_id:
		await _preparar(comando)
		if _cerrando:
			return
		_ultimo_id = int(comando.id)
	await _publicar()
	_ocupado = false


func _preparar(comando: Dictionary) -> void:
	match String(comando.get("accion", "")):
		"fede", "mia":
			var mia := String(comando.accion) == "mia"
			var tiempo := 32400.0 if mia else 1800.0
			var reloj: Node = _almacen.get("_reloj")
			var turno: RefCounted = reloj.get("_turno")
			var reglas: Script = load("res://src/dominio/reglas.gd")
			var duracion: float = reglas.get_script_constant_map()["DURACION_DEL_TURNO"]
			var consumido: float = duracion - turno.call("tiempo_restante")
			var ritmo: Script = load("res://src/dominio/jornada/ritmo.gd")
			reloj.call("avanzar", maxf(0.0, tiempo - consumido) / ritmo.call("escalar", 1.0))
			await get_tree().create_timer(3.0).timeout
			var atencion: RefCounted = _almacen.get("_atenciones").call("atencion")
			if not _requerir(atencion != null, "No llegó el comprador esperado"):
				return
			var nombre: String = atencion.call("comprador").call("nombre")
			_requerir(nombre == ("Mía" if mia else "Fede"), "Llegó otra identidad: " + nombre)
			_requerir(atencion.call("comprador").get("dialogos") == _guion, "Otro guion productivo")
			_requerir(
				(
					_sprite.sprite_frames.resource_path
					== "res://assets/characters/%s/idle.tres" % ("mia" if mia else "fede")
				),
				"Otro sprite"
			)
			_requerir(_sprite.sprite_frames.get_frame_count(&"idle") == 8, "Faltan cuadros")
			_sprite.stop()
			_sprite.set_frame_and_progress(0, 0.0)
			_punto = _pixel_comun()
			if await _ubicar(_centro):
				await _mirar(_punto)
			_etapa = "mia" if mia else "fede"
		"unidad":
			var atencion: RefCounted = _almacen.get("_atenciones").call("atencion")
			var pedido: RefCounted = atencion.call("comprador").call("pedido")
			var productos: Array = pedido.call("productos")
			var indice := int(comando.get("indice", -1))
			if not _requerir(indice >= 0 and indice < productos.size(), "Índice fuera del pedido"):
				return
			var producto: RefCounted = productos[indice]
			var id: int = producto.get("id")
			if not _deposito_inicial.has(id):
				_deposito_inicial[id] = _almacen.get("_repositor").call("estante").call(
					"unidades_en_deposito", producto
				)
			_almacen.get("_reposicion_manual").call("retirar", id)
			var cuerpo: Node3D = _almacen.get("_agarre").call("cuerpo_sostenido")
			if _requerir(cuerpo != null, "La caja no produjo unidad real"):
				var identidad: RefCounted = cuerpo.get("datos")
				_requerir(identidad.get("producto").get("id") == id, "Se retiró otra identidad")
				_unidades_preparadas.append(
					{
						"producto": id,
						"cuerpo": str(cuerpo.get_instance_id()),
						"identidad": str(identidad.get_instance_id())
					}
				)
			await _sincronizar()
		"ticket":
			var atencion: RefCounted = _almacen.get("_atenciones").call("atencion")
			var pedido: RefCounted = atencion.call("comprador").call("pedido")
			var caja: Node = _almacen.get("_caja")
			caja.call("pedir_borrar")
			var unidad: Script = load("res://src/dominio/almacen/unidad_de_producto.gd")
			for producto: RefCounted in pedido.call("productos"):
				for cantidad: int in pedido.call("unidades_de", producto):
					caja.call("pedir_anotar", unidad.new(producto))
			caja.call("pedir_imprimir")
			var destino: Node = _almacen.get("_puesto_de_la_caja").get("destino_de_los_tickets")
			var papel: Node3D = null
			var clase_ticket: Script = load("res://src/dominio/almacen/ticket.gd")
			for hijo: Node in destino.get_children():
				var datos: Variant = hijo.get("datos")
				if (
					hijo is Node3D
					and hijo.visible
					and datos is Resource
					and datos.get_script() == clase_ticket
				):
					papel = hijo
					break
			if _requerir(papel != null, "La impresora no produjo ticket físico"):
				_requerir(
					_almacen.get("_agarre").call("pedir_agarrar", papel.get("datos"), papel),
					"No se agarró ticket"
				)
			await _sincronizar()
		"observar":
			await _sincronizar()
		"salir":
			if _nativo:
				_cerrando = true
				await _cerrar_nativo()
				get_tree().quit.call_deferred(0 if _fallos.is_empty() else 1)
		"capturar":
			await _sincronizar()
			var nombre: String = comando.get("nombre", "captura")
			_requerir(nombre.is_valid_filename(), "Nombre de captura inválido")
			_ultima_captura = _carpeta_capturas.path_join(nombre + ".png")
			_requerir(
				get_tree().root.get_texture().get_image().save_png(_ultima_captura) == OK,
				"No se pudo guardar PNG"
			)
		"fin":
			_requerir(_compras == 2 and _finales == 4, "Faltan ventas/retornos físicos")
			_requerir(_unidades_preparadas.size() == 6, "No se ejercieron seis unidades reales")
			var catalogo: Script = load("res://src/dominio/almacen/catalogo.gd")
			for id: int in _deposito_inicial:
				var producto: RefCounted = catalogo.call("de", id)
				var quedan: int = _almacen.get("_repositor").call("estante").call(
					"unidades_en_deposito", producto
				)
				_requerir(quedan == _deposito_inicial[id] - 1, "Descuento distinto de uno")
			_etapa = "fin"
			print("CAPTURAS_444_FIXTURE_FINAL fallos=%d" % _fallos.size())
			if _fallos.is_empty():
				print("CAPTURAS_444_FIXTURE_OK")


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
	var comprador: RefCounted = atencion.call("comprador") if atencion != null else null
	var agarre: Node = _almacen.get("_agarre")
	var cuerpo: Node3D = agarre.call("cuerpo_sostenido")
	var foco: Node3D = _jugador.call("enfocado")
	var foco_logico: int = _jugador.get("_control").call("objetivo")
	var consulta := _piso_en(_jugador.global_position)
	var interpolada := false
	var ancestro: Node = _camara
	while ancestro != null:
		if ancestro is Node3D and ancestro.is_physics_interpolated_and_enabled():
			interpolada = true
		ancestro = ancestro.get_parent()
	var dibujada := (
		_camara.get_global_transform_interpolated() if interpolada else _camara.global_transform
	)
	var mia := _etapa == "mia"
	var label: RichTextLabel = _puesto.get("panel").get_node("Fisico/Dialogo/Texto")
	var estado := {
		"id": _ultimo_id,
		"etapa": _etapa,
		"fallos": _fallos,
		"pausa": get_tree().paused,
		"suspendido": _jugador.call("suspendido"),
		"cursor": Input.mouse_mode,
		"panel": _puesto.get("_abierta"),
		"entrada": dialogo.call("entrada_actual") if dialogo != null else "",
		"texto_panel": label.text,
		"indice": dialogo.get("_indice") if dialogo != null else -1,
		"terminado": dialogo.call("terminado") if dialogo != null else true,
		"mano": str(cuerpo.get_instance_id()) if cuerpo != null else "0",
		"identidad_mano": str(cuerpo.get("datos").get_instance_id()) if cuerpo != null else "0",
		"pedido": str(comprador.call("pedido").get_instance_id()) if comprador != null else "0",
		"nombre": comprador.call("nombre") if comprador != null else "",
		"vendida": atencion.call("vendida") if atencion != null else false,
		"despachada": atencion.call("despachada") if atencion != null else false,
		"compras": _compras,
		"soltados": _soltados,
		"finales": _finales,
		"foco_fisico": str(foco.get_path()) if foco != null else "",
		"foco_logico": foco_logico,
		"contorno": _sprite.material_overlay != null,
		"visible": _sprite.visible,
		"sprite": _sprite.sprite_frames.resource_path if _sprite.sprite_frames != null else "",
		"suelo": consulta.get("collider") == _suelo,
		"capsula_libre": _contactos_en(_jugador.global_transform).is_empty(),
		"camara_actual": str(_camara.global_transform),
		"camara_dibujada": str(dibujada),
		"interpolada": interpolada,
		"jugador": str(_jugador.global_transform),
		"viewport": str(get_tree().root.size),
		"iniciales": _guion.get("mia" if mia else "fede"),
		"despedidas": _guion.get("despedida_mia" if mia else "despedida_fede"),
		"unidades_preparadas": _unidades_preparadas,
		"ultima_captura": _ultima_captura,
	}
	if _nativo:
		var archivo := FileAccess.open(_archivo_estado, FileAccess.WRITE)
		if archivo != null:
			archivo.store_string(JSON.stringify(estado))
			archivo.close()
	else:
		Engine.get_singleton("JavaScriptBridge").call(
			"eval", "window.__444_state = " + JSON.stringify(estado), true
		)


func _cerrar_nativo() -> void:
	get_tree().paused = false
	if is_instance_valid(_almacen):
		for tipo: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
			for audio: Node in _almacen.find_children("*", tipo, true, false):
				audio.call("stop")
				audio.set("stream", null)
		_almacen.queue_free()
	_almacen = null
	_jugador = null
	_puesto = null
	_camara = null
	_sprite = null
	_suelo = null
	_guion = null
	_unidades_preparadas.clear()
	for _cuadro in 4:
		await get_tree().process_frame
