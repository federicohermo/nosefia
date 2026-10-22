extends Node

const ESCENA := preload("res://src/escenas/almacen.tscn")
const PUESTO := preload("res://src/escenas/puestos/ventanilla.gd")
const NOMBRES: Array[String] = ["Tin", "Tia", "Fede", "Mia"]
const PERSONAJES: Array[int] = [
	DialogosDeCompradores.Personaje.TIN,
	DialogosDeCompradores.Personaje.TIA,
	DialogosDeCompradores.Personaje.FEDE,
	DialogosDeCompradores.Personaje.MIA,
]

var _local: Node3D
var _puesto: Node3D
var _figura: AnimatedSprite3D
var _jugador: CharacterBody3D
var _marco: MarcoDelObjetivo
var _rotulo: Label
var _indice: int = 0
var _con_foco: bool = true


func _ready() -> void:
	print("CAPTURA_READY")
	_local = ESCENA.instantiate()
	print("CAPTURA_INSTANTIATED")
	_local.set(
		"_partida", Partida.desde({"jornada": Compradores.JORNADA_DE_FEDE_Y_MIA, "medios": 0})
	)
	_local.set("compradores_de_la_apertura", _compradores)
	add_child(_local)
	print("CAPTURA_ADDED")
	_local.get_node("Interfaz/ControlDePausa").free()
	var reloj: RelojDelTurno = _local.get("_reloj")
	reloj.set_process(false)
	print("CAPTURA_WAIT_FRAMES")
	await _cuadros()
	print("CAPTURA_FRAMES_DONE")
	var turno: Turno = reloj.get("_turno")
	var transcurrido: float = Reglas.DURACION_DEL_TURNO - turno.tiempo_restante()
	var hasta: float = float((20 - Reglas.HORA_DE_APERTURA) * 3600 + 30 * 60)
	var ritmo: float = float(reloj.get("_ritmo"))
	reloj.avanzar((hasta - transcurrido) / ritmo)
	_puesto = _local.get_node("Estructura/Ventanilla")
	_figura = _puesto.get("comprador_visible")
	await _cuadros()
	var entrada: Tween = _puesto.get("_entrada")
	if entrada != null:
		entrada.custom_step(20.0)
	await _cuadros()
	_jugador = _local.get_node("Jugador")
	for hijo: Node in _local.get_children():
		if hijo is MarcoDelObjetivo:
			_marco = hijo
	var pie: Vector3 = _figura.global_position + _figura.global_basis.z * 1.3
	pie.y = _jugador.global_position.y
	_jugador.call("ubicar", Transform3D(Basis.IDENTITY, pie))
	_local.process_mode = Node.PROCESS_MODE_DISABLED
	for nodo: Node in _local.find_children("*", "", true, false):
		nodo.process_mode = Node.PROCESS_MODE_DISABLED
		if nodo is CanvasLayer:
			(nodo as CanvasLayer).hide()
	get_tree().paused = false
	var camara: Camera3D = _jugador.get_node("Giro/Camara")
	camara.look_at(_figura.global_position + Vector3.UP * 0.2, Vector3.UP)
	_jugador.reset_physics_interpolation()
	_local.get_node("Interfaz").hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_rotulo = Label.new()
	_rotulo.position = Vector2(12, 12)
	_rotulo.add_theme_font_size_override("font_size", 20)
	_rotulo.add_theme_color_override("font_color", Color.WHITE)
	var capa: CanvasLayer = CanvasLayer.new()
	add_child(capa)
	capa.add_child(_rotulo)
	await _cuadros()
	_mostrar(0)
	await _cuadros()
	_jugador.call("_leer_la_mira")
	_marco.enfocar(_puesto.get("objetivo"))
	print("CAPTURA_LISTA foco_real=", _jugador.call("enfocado") == _puesto.get("objetivo"))
	if not OS.has_feature("web"):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://tmp/captura_fixture_nativo.png")


func _compradores(_jornada: int) -> Array[Comprador]:
	var compradores: Array[Comprador] = Compradores.segunda_jornada_definida()
	var guion: DialogosDeCompradores = DialogosDeCompradores.new()
	guion.fede = PackedStringArray(["Atencion de prueba."])
	guion.mia = PackedStringArray(["Atencion de prueba."])
	for comprador: Comprador in compradores:
		comprador.dialogos = guion
	return compradores


func _cuadros() -> void:
	for cuadro: int in 3:
		await get_tree().physics_frame
	await get_tree().process_frame


func _mostrar(indice: int) -> void:
	_indice = indice
	_figura.sprite_frames = PUESTO.ANIMACIONES[PERSONAJES[indice]]
	_figura.animation = &"idle"
	_figura.stop()
	_figura.set_frame_and_progress(0, 0.0)
	_figura.show()
	_marco.apagar()
	if _con_foco:
		_marco.enfocar(_puesto.get("objetivo"))
	_rotulo.text = (
		"%s | frame 0 | 20:30 | foco %s | 1-4 comprador, 0 sin foco, 9 foco"
		% [NOMBRES[_indice], "si" if _con_foco else "no"]
	)
	print("CAPTURA_COMPRADOR ", NOMBRES[_indice], " foco=", _con_foco)


func _input(evento: InputEvent) -> void:
	if _figura == null or not evento is InputEventKey:
		return
	var tecla: InputEventKey = evento as InputEventKey
	if not tecla.pressed or tecla.echo:
		return
	if tecla.keycode >= KEY_1 and tecla.keycode <= KEY_4:
		_mostrar(tecla.keycode - KEY_1)
	elif tecla.keycode == KEY_0:
		_con_foco = false
		_mostrar(_indice)
	elif tecla.keycode == KEY_9:
		_con_foco = true
		_mostrar(_indice)
