extends Node

var carpeta: String
var almacen: Node3D
var jugador: Node3D
var entrada: Node3D
var persiana: CanvasLayer
var pantalla: CanvasLayer
var reloj: Node
var ciclo: Node
var segundos: float = 0.0
var inicio_usec: int
var siguiente_captura: float = 0.0
var cuadro: int = 0
var eventos: Array[Dictionary] = []
var muestras: Array[Dictionary] = []
var inicio: bool = false
var pausas: int = 0
var pausa_hasta: float = 0.0
var cerrada_desde: float = -1.0
var audio: AudioEffectRecord
var indice_del_audio: int


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	inicio_usec = Time.get_ticks_usec()
	almacen = get_tree().current_scene
	jugador = almacen.get("_jugador")
	entrada = almacen.get_node("Estructura/puertaentrada/CuerpoDeLaHoja")
	persiana = almacen.get_node("Interfaz/PersianaDeLaNoche")
	pantalla = almacen.get("_pantalla")
	reloj = almacen.get("_reloj")
	ciclo = almacen.get("_ciclo")
	entrada.connect("puerta_abierta", _puerta_abierta)
	entrada.connect("hoja_quieta", _hoja_quieta)
	ciclo.connect("jornada_cerrada", _jornada_cerrada)
	DirAccess.make_dir_recursive_absolute(carpeta)
	audio = AudioEffectRecord.new()
	indice_del_audio = AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, audio)
	audio.set_recording_active(true)
	RenderingServer.frame_post_draw.connect(_dibujado)


func _process(_delta: float) -> void:
	segundos = (Time.get_ticks_usec() - inicio_usec) / 1000000.0
	if not inicio and segundos >= 0.35:
		inicio = true
		_evento("solicitud")
		var gesto: InputEventMouseButton = InputEventMouseButton.new()
		gesto.button_index = MOUSE_BUTTON_LEFT
		gesto.pressed = true
		gesto.position = (
			get_viewport().get_final_transform() * (get_viewport().get_visible_rect().size * 0.5)
		)
		gesto.global_position = gesto.position
		Input.parse_input_event(gesto)
		var liberacion: InputEventMouseButton = gesto.duplicate()
		liberacion.pressed = false
		Input.parse_input_event(liberacion)
	if inicio and pausas == 0 and segundos >= 0.6 and not pantalla.visible:
		get_tree().paused = true
		pausa_hasta = segundos + 0.4
		pausas = 1
		_evento("pausa_giro")
	elif get_tree().paused and segundos >= pausa_hasta:
		get_tree().paused = false
		_evento("reanudar")
	var angulo: float = entrada.call("puerta").angulo()
	if pausas == 1 and angulo > 0.15 and angulo < 1.4:
		get_tree().paused = true
		pausa_hasta = segundos + 0.4
		pausas = 2
		_evento("pausa_puerta")
	if cerrada_desde >= 0.0 and segundos > cerrada_desde + 2.0:
		_finalizar()
	elif segundos > 15.0:
		_finalizar()


func _dibujado() -> void:
	if segundos < siguiente_captura:
		return
	siguiente_captura = segundos + 0.09
	var ruta: String = carpeta.path_join("cuadro_%04d.png" % cuadro)
	var imagen: Image = get_viewport().get_texture().get_image()
	imagen.resize(imagen.get_width() / 2, imagen.get_height() / 2)
	imagen.save_png(ruta)
	var vista: Transform3D = jugador.call("mira")
	var euler: Vector3 = vista.basis.get_euler()
	muestras.append(
		{
			"archivo": ruta.get_file(),
			"segundos": segundos,
			"yaw": euler.y,
			"pitch": euler.x,
			"posicion":
			[jugador.global_position.x, jugador.global_position.y, jugador.global_position.z],
			"angulo_puerta": entrada.call("puerta").angulo(),
			"persiana": persiana.visible,
			"devolucion": pantalla.visible,
			"suspendido": jugador.call("suspendido"),
			"pausa": get_tree().paused
		}
	)
	cuadro += 1


func _puerta_abierta(_puerta: Node3D) -> void:
	_evento("puerta_abierta_sonido_habitual")


func _hoja_quieta(_puerta: PhysicsBody3D) -> void:
	_evento("hoja_quieta")


func _jornada_cerrada(jornada: int, cumplidas: int) -> void:
	cerrada_desde = segundos
	_evento("jornada_cerrada_%d_cumplidas_%d" % [jornada, cumplidas])


func _evento(nombre: String) -> void:
	eventos.append(
		{
			"segundos": segundos,
			"evento": nombre,
			"angulo_puerta": entrada.call("puerta").angulo(),
			"persiana": persiana.visible
		}
	)


func _finalizar() -> void:
	set_process(false)
	RenderingServer.frame_post_draw.disconnect(_dibujado)
	audio.set_recording_active(false)
	var grabacion: AudioStreamWAV = audio.get_recording()
	grabacion.save_to_wav(carpeta.path_join("audio.wav"))
	AudioServer.remove_bus_effect(0, indice_del_audio)
	var archivo: FileAccess = FileAccess.open(carpeta.path_join("secuencia.json"), FileAccess.WRITE)
	archivo.store_string(JSON.stringify({"eventos": eventos, "muestras": muestras}, "\t"))
	archivo.close()
	queue_free()
