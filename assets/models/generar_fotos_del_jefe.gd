## Captura las siete fotos del chat desde el modelo jugable y valida cada tema antes de guardar.
## Desde PowerShell con una pantalla disponible:
## & $env:GODOT_BIN --path . --rendering-driver opengl3 `
##   --script assets/models/generar_fotos_del_jefe.gd -- assets/ui/manada/fotos
extends SceneTree

const TAMANO := Vector2i(960, 540)
const PLANOS := [
	[
		4,
		Vector3(-2.05, 1.682598, 4.050001),
		Vector3(-2.417298, 1.682598, 4.050001),
		55.0,
		"board tareas/"
	],
	[6, Vector3(-0.80, 1.70, 4.80), Vector3(-0.80, 1.74, 6.38), 60.0, "Estructura/Ventanilla"],
	[
		7,
		Vector3(-0.80, 1.65, 4.35),
		Vector3(-1.05, 1.28, 3.57),
		55.0,
		"cajaregistradora/StaticBody3D"
	],
	[8, Vector3(0.0, 1.65, 4.60), Vector3(-0.05, 1.50, 3.60), 55.0, "base compu/StaticBody3D"],
	[9, Vector3(2.70, 1.45, -9.73), Vector3(-0.40, 1.45, -9.73), 72.0, "Caja"],
	[
		11,
		Vector3(8.35, 1.50, -14.30),
		Vector3(10.78, 1.40, -13.43),
		62.0,
		"nota instrucciones",
	],
	[13, Vector3(-0.20, 1.90, -13.15), Vector3(-2.95, 1.15, -11.50), 62.0, "Caja"],
]

var _local: Node3D
var _jugador: CharacterBody3D
var _camara: Camera3D
var _cajas: Array[Node3D] = []
var _poses: Array[Transform3D] = []
var _informe: Array[Dictionary] = []
var _salida: String


func _initialize() -> void:
	_generar.call_deferred()


func _fallar(mensaje: String) -> void:
	push_error("FOTOS374: " + mensaje)
	quit(1)


func _generar() -> void:
	var argumentos := OS.get_cmdline_user_args()
	if argumentos.is_empty():
		_fallar("falta la carpeta de salida")
		return
	_salida = argumentos[0]
	if DirAccess.make_dir_recursive_absolute(_salida) != OK:
		_fallar("no se pudo crear " + _salida)
		return
	root.size = TAMANO
	root.content_scale_size = TAMANO
	var escena := load("res://src/escenas/almacen.tscn") as PackedScene
	if escena == null:
		_fallar("no cargó el almacén")
		return
	_local = escena.instantiate() as Node3D
	_local.set("_partida", Partida.nueva())
	root.add_child(_local)
	_local.get_node("Interfaz/PersianaDeLaNoche").terminar()
	(_local.get("_reloj") as Node).set_process(false)
	_jugador = _local.get("_jugador") as CharacterBody3D
	_jugador.call("suspender")
	_jugador.set_physics_process(false)
	_jugador.set_process(false)
	for nodo: Node in _local.find_children("*", "CanvasLayer", true, false):
		(nodo as CanvasLayer).hide()
	for nodo: Node in _local.find_children("*", "RigidBody3D", true, false):
		var cuerpo := nodo as RigidBody3D
		cuerpo.freeze = true
		cuerpo.linear_velocity = Vector3.ZERO
		cuerpo.angular_velocity = Vector3.ZERO
	var cajas: Array = _local.get("_cajas_de_productos")
	for caja: Node3D in cajas:
		_cajas.append(caja)
		_poses.append(caja.global_transform)
	if _cajas.size() != Catalogo.todos().size():
		_fallar("no se encontraron todas las cajas de la noche")
		return
	_camara = Camera3D.new()
	_camara.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_local.add_child(_camara)
	_camara.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	for plano: Array in PLANOS:
		if not await _fotografiar(plano):
			return
	var informe := FileAccess.open(_salida.path_join("encuadres.json"), FileAccess.WRITE)
	if informe == null:
		_fallar("no se pudo escribir el informe")
		return
	informe.store_string(JSON.stringify(_informe, "\t"))
	informe.close()
	for nodo: Node in _local.find_children("*", "AudioStreamPlayer", true, false):
		(nodo as AudioStreamPlayer).stop()
		(nodo as AudioStreamPlayer).stream = null
	for nodo: Node in _local.find_children("*", "AudioStreamPlayer3D", true, false):
		(nodo as AudioStreamPlayer3D).stop()
		(nodo as AudioStreamPlayer3D).stream = null
	_camara = null
	_jugador = null
	_cajas.clear()
	_local.queue_free()
	_local = null
	for _cuadro: int in 4:
		await process_frame
	print("FOTOS374_FINAL 7/7")
	quit(0)


func _fotografiar(plano: Array) -> bool:
	var numero: int = plano[0]
	var tamano := (
		Vector2i(960, 674) if numero == 4 else Vector2i(640, 640) if numero == 9 else TAMANO
	)
	root.size = tamano
	root.content_scale_size = tamano
	_camara.projection = (
		Camera3D.PROJECTION_ORTHOGONAL if numero == 4 else Camera3D.PROJECTION_PERSPECTIVE
	)
	# El encuadre del corcho sigue su superficie, no el aspecto panorámico del local.
	if numero == 4:
		var corcho: MeshInstance3D = _local.get_node("Estructura/board tareas")
		_camara.size = (corcho.global_transform * corcho.get_aabb()).size.y
	if numero == 9:
		for caja: Node3D in _cajas:
			caja.global_transform = caja.call("pose_de_estanteria")
			caja.reset_physics_interpolation()
	if numero == 13:
		for indice: int in _cajas.size():
			_cajas[indice].global_transform = _poses[indice]
			_cajas[indice].reset_physics_interpolation()
		for indice: int in _cajas.size():
			if not _cajas[indice].global_transform.is_equal_approx(_poses[indice]):
				_fallar("no se restauró la pila antes de Intro13")
				return false
	_camara.fov = plano[3]
	_camara.look_at_from_position(plano[1], plano[2])
	_camara.reset_physics_interpolation()
	var numeros: CanvasLayer
	if numero == 11:
		numeros = _numerar_utiles()
	var preparada := _camara.global_transform
	for _cuadro: int in 4:
		await physics_frame
	for _cuadro: int in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	if not _camara.get_global_transform_interpolated().is_equal_approx(preparada):
		_fallar("cambió la pose dibujada de Intro%d" % numero)
		return false
	var centro := Vector2(tamano) / 2.0
	var desde := _camara.project_ray_origin(centro)
	var hacia := desde + _camara.project_ray_normal(centro) * 25.0
	var rayo := PhysicsRayQueryParameters3D.create(desde, hacia)
	rayo.exclude = [_jugador.get_rid()]
	var golpe := _camara.get_world_3d().direct_space_state.intersect_ray(rayo)
	var ruta := "sin cuerpo"
	if not golpe.is_empty():
		ruta = str(_local.get_path_to(golpe.collider as Node))
	if not ruta.to_lower().contains((plano[4] as String).to_lower()):
		_fallar("Intro%d esperaba %s; encontró %s" % [numero, plano[4], ruta])
		return false
	var imagen := root.get_texture().get_image()
	if imagen.is_empty() or imagen.get_size() != tamano:
		_fallar("imagen vacía o tamaño incorrecto de Intro%d" % numero)
		return false
	var archivo := _salida.path_join("intro-%02d.png" % numero)
	if imagen.save_png(archivo) != OK:
		_fallar("no se pudo guardar " + archivo)
		return false
	_informe.append(
		{
			"intro": numero,
			"camara": var_to_str(preparada),
			"cuerpo_central": ruta,
			"tamano": var_to_str(imagen.get_size())
		}
	)
	print("FOTO374 ", numero, " ", ruta, " ", archivo)
	if numeros != null:
		numeros.queue_free()
	return true


func _numerar_utiles() -> CanvasLayer:
	var capa := CanvasLayer.new()
	root.add_child(capa)
	var objetos: Array[String] = ["Mopa", "Balde", "JabonAzul"]
	var alturas: Array[float] = [1.65, 0.80, 0.97]
	for indice: int in objetos.size():
		var objeto: Node3D = _local.get_node("Objetos/" + objetos[indice])
		var foco := objeto.global_position
		foco.y = alturas[indice]
		var numero := Label.new()
		numero.text = str(indice + 1)
		numero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		numero.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		numero.size = Vector2(44.0, 44.0)
		numero.position = _camara.unproject_position(foco) - numero.size / 2.0
		numero.add_theme_color_override("font_color", Color("edf1be"))
		numero.add_theme_font_size_override("font_size", 32)
		var fondo := StyleBoxFlat.new()
		fondo.bg_color = Color("202020")
		fondo.border_color = Color("edf1be")
		fondo.set_border_width_all(2)
		fondo.set_corner_radius_all(22)
		numero.add_theme_stylebox_override("normal", fondo)
		capa.add_child(numero)
	return capa
