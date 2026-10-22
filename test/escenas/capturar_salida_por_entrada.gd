extends SceneTree

const ALMACEN := "res://src/escenas/almacen.tscn"
const DESTINO := "res://docs/evidence/entrada-de-dos-puertas/"


func _initialize() -> void:
	_capturar.call_deferred()


func _crear() -> Node3D:
	var almacen: Node3D = load(ALMACEN).instantiate()
	almacen.set("compradores_de_la_apertura", func(_n: int) -> Array[Comprador]: return [])
	root.add_child(almacen)
	almacen.get("_reloj").set_process(false)
	var hojas: Array = almacen.get("_hojas_de_entrada")
	var izquierda: Marker3D = hojas[0].get("eje_de_la_bisagra")
	var derecha: Marker3D = hojas[1].get("eje_de_la_bisagra")
	var centro := (izquierda.global_position + derecha.global_position) * 0.5
	var ancho := derecha.global_position.distance_to(izquierda.global_position)
	var jugador: Node3D = almacen.get("_jugador")
	var lugar := jugador.global_position
	lugar.x = centro.x + ancho * 0.04
	lugar.z = centro.z - minf(ancho * 0.55, ReglasDelJugador.ALCANCE_DE_LA_MIRA * 0.8)
	var hoja: MeshInstance3D = hojas[0].get("hoja")
	var objetivo := hoja.global_transform * hoja.get_aabb().get_center()
	var direccion := objetivo - lugar
	direccion.y = 0.0
	jugador.call("ubicar", Transform3D(Basis.looking_at(direccion), lugar))
	jugador.call("reanudar")
	return almacen


func _foto(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	var ruta := DESTINO + nombre + ".png"
	assert(root.get_texture().get_image().save_png(ruta) == OK)
	print("Captura real ", ruta)


func _capturar() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Las capturas necesitan el renderer del juego.")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DESTINO))
	Guardado.ruta_por_defecto = "user://captura-entrada.guardado"
	Guardado.new().borrar()
	var almacen := _crear()
	for _cuadro in 60:
		await physics_frame
	var jugador: Node3D = almacen.get("_jugador")
	var hojas: Array = almacen.get("_hojas_de_entrada")
	print(
		"Foco real ", jugador.get("_enfocado"), " vista ", jugador.call("mira"), " hoja ", hojas[0]
	)
	assert(jugador.get("_enfocado") == hojas[0])
	for tarea: Tarea in (almacen.get("_partida") as Partida).obligatorias():
		(almacen.get("_reloj") as RelojDelTurno).completar(tarea)
	for presionado: bool in [true, false]:
		var clic := InputEventMouseButton.new()
		clic.button_index = MOUSE_BUTTON_LEFT
		clic.pressed = presionado
		Input.parse_input_event(clic)
	var abierta := false
	for _cuadro in 240:
		await process_frame
		if (
			is_equal_approx(hojas[0].call("puerta").angulo(), Puerta.ANGULO_ABIERTA)
			and is_equal_approx(hojas[1].call("puerta").angulo(), Puerta.ANGULO_ABIERTA)
		):
			abierta = true
			break
	assert(abierta)
	print("J1 dos ángulos completos. Vista ", jugador.call("mira"))
	await _foto("j1-dos-hojas-abiertas")
	almacen.queue_free()
	await process_frame
	assert(Guardado.new().escribir({"jornada": 4}))
	almacen = _crear()
	for _cuadro in 30:
		await physics_frame
	for entrada: Node3D in almacen.get("_hojas_de_entrada"):
		assert(not entrada.call("puerta").abierta())
		assert(is_zero_approx(entrada.call("puerta").angulo()))
	assert(not almacen.call("_puede_salir"))
	print("J4 cargada desde guardado. Dos hojas cerradas y salida deshabilitada.")
	await _foto("j4-dos-hojas-cerradas")
	Guardado.new().borrar()
	almacen.queue_free()
	await process_frame
	quit()
