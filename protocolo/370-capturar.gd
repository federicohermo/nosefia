extends SceneTree

const AYUDANTE := preload("res://test/escenas/bolsa_en_la_mano.gd")
const DESTINO := "C:/Users/fede_/AppData/Local/Temp/nosefia-batch-364-370-20261010/370-capturas"


func _initialize() -> void:
	call_deferred("_correr")


func _validar(almacen: Node3D, tacho: StaticBody3D, nombre: String, sacada: bool) -> bool:
	almacen.get("_jugador").call("_leer_la_mira")
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	var candidato: CampoDeInteraccion.Candidato = jugador.call("_medir_candidato", tacho)
	var malla := tacho.get_parent() as MeshInstance3D
	var foto := camara.global_transform
	var dibujo := foto
	var antecesor: Node = camara
	while antecesor != null:
		if antecesor is Node3D and antecesor.is_physics_interpolated_and_enabled():
			dibujo = camara.get_global_transform_interpolated()
			break
		antecesor = antecesor.get_parent()
	var libres := AYUDANTE.sitios(almacen, tacho)
	var en_piso := false
	for sitio in libres:
		en_piso = en_piso or sitio.distance_to(jugador.global_position) < 0.01
	var recolector: RecolectorDeBasura = almacen.get("_recolector")
	if (
		jugador.get("_enfocado") != tacho
		or not candidato.visible
		or candidato.distancia > ReglasDelJugador.ALCANCE_DE_LA_MIRA
		or malla.material_overlay == null
		or not en_piso
		or not dibujo.is_equal_approx(foto)
		or recolector.tarea().tiene_bolsa(tacho.get("tacho")) == sacada
	):
		push_error("Captura inválida: " + nombre)
		return false
	return true


func _guardar(almacen: Node3D, tacho: StaticBody3D, nombre: String, sacada: bool) -> bool:
	for _cuadro in 5:
		await process_frame
	if not _validar(almacen, tacho, nombre, sacada):
		return false
	await RenderingServer.frame_post_draw
	if not _validar(almacen, tacho, nombre, sacada):
		return false
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	var foto := camara.global_transform
	var candidato: CampoDeInteraccion.Candidato = jugador.call("_medir_candidato", tacho)
	var imagen := root.get_texture().get_image()
	if imagen.is_empty() or imagen.save_png(DESTINO + "/" + nombre + ".png") != OK:
		push_error("No se pudo guardar: " + nombre)
		return false
	print(
		(
			JSON
			. stringify(
				{
					"captura": nombre,
					"piso": str(jugador.global_position),
					"ojo": str(foto.origin),
					"foco": str(tacho.get_path()),
					"distancia": candidato.distancia,
					"sacada": sacada,
					"jornada": (almacen.get("_partida") as Partida).jornada(),
				}
			)
		)
	)
	return true


func _correr() -> void:
	DirAccess.make_dir_recursive_absolute(DESTINO)
	root.size = Vector2i(1280, 720)
	var escena := load("res://src/escenas/almacen.tscn") as PackedScene
	var almacen := escena.instantiate() as Node3D
	almacen.set("_partida", Partida.desde({"jornada": 2, "medios": 0}))
	root.add_child(almacen)
	almacen.get("_reloj").set_process(false)
	for _cuadro in 10:
		await physics_frame
	for numero in 3:
		var tacho := almacen.get_node(AYUDANTE.RUTAS[numero]) as StaticBody3D
		if not await AYUDANTE.enfocar(almacen, tacho):
			push_error("Sin foco del tacho " + str(numero))
			quit(1)
			return
		var nombre: String = ["local", "escritorio", "bano"][numero]
		if not await _guardar(almacen, tacho, nombre + "-antes", false):
			quit(1)
			return
		var bolsa := AYUDANTE.sacar(almacen, numero)
		if bolsa == null or not await _guardar(almacen, tacho, nombre + "-despues", true):
			quit(1)
			return
		almacen.get("_recolector").pedir_tirar(true)
	for tipo: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
		for audio: Node in almacen.find_children("*", tipo, true, false):
			audio.call("stop")
			audio.set("stream", null)
	almacen.queue_free()
	await process_frame
	await process_frame
	print("CAPTURAS_370_OK")
	quit(0)
