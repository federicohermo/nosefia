extends Node

const DESTINO := "C:/Users/fede_/AppData/Local/Temp/nosefia-batch-425-435/434-capturas-original"
var _almacen: Node3D
var _camara := Camera3D.new()
var _rotulo := Label.new()
var _vistas: Array[Dictionary] = []
var _indice := 0
var _ocupado := false


func _ready() -> void:
	get_tree().root.size = Vector2i(1600, 900)
	_almacen = load("res://src/escenas/almacen.tscn").instantiate()
	_almacen.set("_partida", Partida.desde({"jornada": 2, "medios": 0}))
	add_child(_almacen)
	_almacen.get("_reloj").set_process(false)
	_almacen.get("_jugador").set_physics_process(false)
	_almacen.get("_jugador").set_process_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_camara.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_camara.near = 0.03
	add_child(_camara)
	_camara.make_current()
	var lienzo := CanvasLayer.new()
	lienzo.layer = 100
	add_child(lienzo)
	_rotulo.position = Vector2(20, 18)
	_rotulo.add_theme_font_size_override("font_size", 22)
	_rotulo.add_theme_color_override("font_color", Color.WHITE)
	_rotulo.add_theme_color_override("font_outline_color", Color.BLACK)
	_rotulo.add_theme_constant_override("outline_size", 6)
	lienzo.add_child(_rotulo)
	var datos := [
		[
			"01-almacen",
			"gondolanueva",
			Vector3.LEFT,
			"Mueble A original · almacén\nProyecciones originales: Po?tico / Amargadito"
		],
		[
			"02-cereales-dulces",
			"gondolanueva",
			Vector3.RIGHT,
			"Mueble A original · dulces junto a cereales\nUakas / Marranos · fuentes originales"
		],
		[
			"03-malbardo-amargadito",
			"gondolanueva",
			Vector3.BACK,
			"Mueble A original · cabecera\nMalbardo / Amargadito"
		],
		[
			"04-bebidas-sin-frio",
			"gondolanueva",
			Vector3.FORWARD,
			"Mueble A original · bebidas sin refrigerar\nOaaaa / Terminator"
		],
		[
			"05-dulces",
			"gondolanueva2",
			Vector3.RIGHT,
			"Mueble B original · snacks dulces\nOremos / Petisas / Cosa de Maní / Feel Ricky Fort"
		],
		[
			"06-salados",
			"gondolanueva2",
			Vector3.LEFT,
			"Mueble B original · snacks salados\nDonsaturados / Prongles / Chisitos / Laysntt"
		],
		[
			"07-jorgillo-saladik",
			"gondolanueva2",
			Vector3.BACK,
			"Mueble B original · cabecera\nJorgillo / Saladik"
		],
		[
			"08-golosinas",
			"gondolanueva2",
			Vector3.FORWARD,
			"Mueble B original · golosinas\nBurbaloo / Flinpuf"
		],
		[
			"09-no-comestibles",
			"gondolanueva_001",
			Vector3.BACK,
			"Estantería · no comestibles\nActroncito / Durextra / Poético"
		],
		[
			"10-heladera-1",
			"heladeranueva",
			Vector3.BACK,
			"Heladera 1 original\nAlturas y bandejas conservadas"
		],
		[
			"11-heladera-2",
			"heladeranueva_001",
			Vector3.BACK,
			"Heladera 2 original\nAlturas y bandejas conservadas"
		],
	]
	for dato: Array in datos:
		_vistas.append({"nombre": dato[0], "mueble": dato[1], "frente": dato[2], "texto": dato[3]})
	for numero in 2:
		var nombre: String = ["heladeranueva", "heladeranueva_001"][numero]
		(
			_almacen
			. get_node("Estructura/%s/puerta_heladera_%d/CuerpoDeLaHoja" % [nombre, numero])
			. call("alternar")
		)
	for cuadro in 65:
		await get_tree().physics_frame
	await _mostrar()


func _input(evento: InputEvent) -> void:
	if evento.is_action_pressed("ui_right") and not _ocupado:
		_indice += 1
		if _indice < _vistas.size():
			_mostrar()
		else:
			print("434_MAPA_COMPLETO_OK")


func _mostrar() -> void:
	_ocupado = true
	var vista := _vistas[_indice]
	var mueble: MeshInstance3D = _almacen.get_node("Estructura/" + vista["mueble"])
	var caja := mueble.global_transform * mueble.mesh.get_aabb()
	var frente: Vector3 = vista["frente"]
	var centro := caja.get_center()
	centro.y = 1.05
	var ancho := absf(frente.x) * caja.size.x + absf(frente.z) * caja.size.z
	var ojo := centro + frente * (ancho / 2.0 + 1.1)
	ojo.y = ReglasDelJugador.ALTURA_DE_LA_CAMARA
	_camara.fov = (
		115.0
		if vista["nombre"] in ["01-almacen", "02-cereales-dulces", "05-dulces", "06-salados"]
		else 90.0
	)
	_camara.look_at_from_position(ojo, centro)
	_rotulo.text = "Base original 2ec25dda · " + str(vista["mueble"])
	for cuadro in 35:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	print(
		(
			"434_VISTA:"
			+ JSON.stringify(
				{
					"nombre": vista["nombre"],
					"indice": _indice,
					"jornada": (_almacen.get("_partida") as Partida).jornada(),
					"cupo_duronga": 0,
					"camara": str(_camara.global_transform)
				}
			)
		)
	)
	_ocupado = false
	if OS.has_feature("web"):
		return
	DirAccess.make_dir_recursive_absolute(DESTINO)
	var imagen := get_viewport().get_texture().get_image()
	if imagen.is_empty() or imagen.save_png(DESTINO + "/nativo-" + vista["nombre"] + ".png") != OK:
		get_tree().quit(1)
		return
	_indice += 1
	if _indice < _vistas.size():
		await _mostrar()
	else:
		print("434_MAPA_COMPLETO_OK")
		_almacen.queue_free()
		await get_tree().process_frame
		get_tree().quit(0)
