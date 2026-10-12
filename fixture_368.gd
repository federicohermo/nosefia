## Sonda del #368: capturas y medición de la fila de atrás apagada.
##
## godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility \
##   --resolution 1280x720 --script <este> -- <modo> <salida> <variante> [saturacion brillo]
##
## modo: listar | capturar | medir. Con saturacion y brillo, pisa los valores de las constantes
## en cada grupo (sólo en el árbol con el cambio). Sin ellos, deja lo que el árbol trae.
extends SceneTree

const ALMACEN := "res://src/escenas/almacen.tscn"
## Las tres vistas: nombre de la vista, producto que enfoca y distancia horizontal del ojo al
## centro de su fila de adelante, en metros.
const VISTAS: Array[Array] = [
	["cara_de_lado", "Marolini", 1.15],
	["cabecera", "Malbardo", 1.15],
	["bandeja_de_heladera", "Coracola", 1.05],
]
## Cuadros por vista: llvmpipe dibuja el local entero en cientos de ms.
const CUADROS := 40
const CUADROS_PARA_CALENTAR := 8

var _almacen: Node3D
var _puesto: Node3D
var _jugador: Node3D
var _camara: Camera3D
var _piso := 0.0


func _initialize() -> void:
	_correr.call_deferred()


func _argumentos() -> PackedStringArray:
	return OS.get_cmdline_user_args()


func _correr() -> void:
	var args := _argumentos()
	var modo := args[0]
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_almacen = (load(ALMACEN) as PackedScene).instantiate()
	root.add_child(_almacen)
	_puesto = _almacen.get("_reposicion_manual")
	_jugador = _almacen.get("_jugador")
	_camara = _jugador.get_node("Giro/Camara")
	_piso = _jugador.global_position.y
	_jugador.set_physics_process(false)
	# El reloj del turno cuenta tiempo de pared: con cuadros lentos la jornada se cierra sola.
	(_almacen.get("_reloj") as Node).set_process(false)
	_jugador.set_process(false)
	_jugador.set_process_unhandled_input(false)
	for capa: CanvasLayer in _almacen.find_children("*", "CanvasLayer", true, false):
		capa.visible = false
	if args.size() >= 5:
		_pisar(float(args[3]), float(args[4]))
	if modo != "listar":
		_vaciar_la_mitad()
	for i in 10:
		await process_frame
	if modo == "listar":
		_listar()
	elif modo == "capturar":
		# Varias variantes en una carga: «nombre:saturacion:brillo,…», o un nombre solo.
		for pedido in args[2].split(","):
			var partes := pedido.split(":")
			if partes.size() == 3:
				_pisar(float(partes[1]), float(partes[2]))
			await _capturar(args[1], partes[0])
	elif modo == "medir":
		await _medir(args[1], args[2])
	quit()


func _pisar(saturacion: float, brillo: float) -> void:
	for grupo: Node in _puesto.get_children():
		if grupo is MultiMeshInstance3D and str(grupo.name).begins_with("ProductosDe"):
			var material := (grupo as MultiMeshInstance3D).material_override as ShaderMaterial
			if material == null:
				push_error("variante pedida sobre un árbol sin el material de la fila de atrás")
				quit(3)
				return
			material.set_shader_parameter("saturacion_atras", saturacion)
			material.set_shader_parameter("brillo_atras", brillo)


## Vacía los casilleros impares de los productos de las tres vistas, por el estante del dominio:
## con la fila de adelante entera, la de atrás casi no se ve de frente.
func _vaciar_la_mitad() -> void:
	var estante: Estante = (_almacen.get("_repositor") as Repositor).estante()
	for vista in VISTAS:
		var producto := _producto(vista[1])
		for indice in estante.casilleros_ocupados(producto):
			if indice % 2 == 1:
				estante.agarrar(producto, indice)
		_puesto.call("_mostrar_lo_puesto", producto.id)


func _listar() -> void:
	print("piso=", _piso, " jugador=", _jugador.global_position)
	var disposicion: Resource = _puesto.get("disposicion")
	var guias: Array = _puesto.get("_guias_sumadas")
	for producto in Catalogo.todos():
		var centro := _centro(producto.nombre)
		var frente := _frente(producto)
		var primera: int = _puesto.call("_primera_dibujada", producto.id)
		print(
			(
				"%s centro=%s frente=%s guias=%d atras=%d"
				% [
					producto.nombre,
					centro,
					frente,
					guias[producto.id],
					primera - guias[producto.id]
				]
			)
		)
	for nodo: Node in _almacen.find_children("*eladera*", "Node3D", true, false):
		print("heladera ", nodo.get_path(), " ", (nodo as Node3D).global_position)


func _centro(nombre: String) -> Vector3:
	var zonas := _puesto.get_node("ZonaDe" + nombre).get_children()
	var centro := Vector3.ZERO
	for zona: Node3D in zonas:
		centro += zona.global_position / zonas.size()
	return centro


func _frente(producto: Producto) -> Vector3:
	var disposicion: DisposicionDeLaGondola = _puesto.get("disposicion")
	return DisposicionDeLaGondola.frente(
		disposicion.principales[producto.id], disposicion.filas_de_adelante[producto.id]
	)


func _producto(nombre: String) -> Producto:
	for producto in Catalogo.todos():
		if producto.nombre == nombre:
			return producto
	return null


## Para al jugador en el pasillo frente a la fila del producto, con la cámara a su altura, y
## lo hace mirar el centro de la fila. Devuelve la pose pedida.
func _posar(vista: Array) -> Dictionary:
	var producto := _producto(vista[1])
	var centro := _centro(producto.nombre)
	var frente := _frente(producto)
	var horizontal := Vector3(frente.x, 0.0, frente.z).normalized()
	var ojo := centro + horizontal * float(vista[2])
	ojo.y = _piso + ReglasDelJugador.ALTURA_DE_LA_CAMARA
	_camara.position = Vector3.UP * ReglasDelJugador.ALTURA_DE_LA_CAMARA
	_jugador.global_position = ojo - _camara.position
	_jugador.get_node("Giro").rotation = Vector3.ZERO
	_camara.look_at(centro)
	_jugador.reset_physics_interpolation()
	_camara.reset_physics_interpolation()
	return {"vista": vista[0], "producto": producto.nombre, "ojo": ojo, "mira_a": centro}


## La pose y el foco del cuadro que se guarda: la cámara está donde se pidió, mira adonde se
## pidió, y lo enfocado es nada o un casillero de la fila de adelante.
func _comprobar(pose: Dictionary) -> Dictionary:
	for i in 4:
		await physics_frame
	_jugador.call("_leer_la_mira")
	var ojo: Vector3 = pose["ojo"]
	var mira_a: Vector3 = pose["mira_a"]
	var real := _camara.global_transform
	var adelante := -real.basis.z
	var pedido := (mira_a - ojo).normalized()
	var enfocado: Node3D = _jugador.get("_enfocado")
	var foco := "nada"
	var foco_ok := true
	if enfocado != null:
		foco = str(enfocado.get_path())
		# La fila de atrás no tiene cuerpo: lo enfocado de la góndola sólo puede ser un casillero
		# de la fila de adelante. Lo que no es de la góndola (la hoja de la heladera) también vale.
		foco_ok = (enfocado.get("casillero") != null or not foco.contains("/ReposicionManual/"))
	var resultado := {
		"vista": pose["vista"],
		"producto": pose["producto"],
		"ojo_pedido": [ojo.x, ojo.y, ojo.z],
		"ojo_real": [real.origin.x, real.origin.y, real.origin.z],
		"mira_a": [mira_a.x, mira_a.y, mira_a.z],
		"altura_sobre_el_piso": real.origin.y - _piso,
		"desvio_del_ojo_m": real.origin.distance_to(ojo),
		"angulo_de_la_mira_grados": rad_to_deg(adelante.angle_to(pedido)),
		"foco": foco,
		"foco_en_la_fila_de_adelante_o_nada": foco_ok,
	}
	resultado["pose_ok"] = (
		resultado["desvio_del_ojo_m"] < 0.001 and resultado["angulo_de_la_mira_grados"] < 0.1
	)
	return resultado


func _capturar(carpeta: String, variante: String) -> void:
	DirAccess.make_dir_recursive_absolute(carpeta)
	var poses: Array[Dictionary] = []
	for vista in VISTAS:
		var pose := _posar(vista)
		for i in 30:
			await process_frame
		var comprobado: Dictionary = await _comprobar(pose)
		await RenderingServer.frame_post_draw
		var imagen := root.get_texture().get_image()
		var ruta := "%s/%s-%s.png" % [carpeta, vista[0], variante]
		imagen.save_png(ruta)
		comprobado["archivo"] = ruta.get_file()
		comprobado["dibujos"] = Performance.get_monitor(
			Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME
		)
		poses.append(comprobado)
		if not comprobado["pose_ok"] or not comprobado["foco_en_la_fila_de_adelante_o_nada"]:
			push_error("pose o foco fuera de lo pedido: %s" % comprobado)
			_guardar("%s/poses-%s.json" % [carpeta, variante], poses)
			quit(2)
			return
	_guardar("%s/poses-%s.json" % [carpeta, variante], poses)


func _medir(archivo: String, variante: String) -> void:
	var resultados: Array[Dictionary] = []
	for vista in VISTAS:
		var pose := _posar(vista)
		var comprobado: Dictionary = await _comprobar(pose)
		for i in CUADROS_PARA_CALENTAR:
			await process_frame
		var cuadros: Array[float] = []
		var dibujos: Array[float] = []
		var anterior := Time.get_ticks_usec()
		for i in CUADROS:
			await process_frame
			var ahora := Time.get_ticks_usec()
			cuadros.append((ahora - anterior) / 1000.0)
			anterior = ahora
			dibujos.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		(
			resultados
			. append(
				{
					"vista": vista[0],
					"pose_ok": comprobado["pose_ok"],
					"muestras": cuadros.size(),
					"cuadro_ms_p50": _percentil(cuadros, 0.5),
					"cuadro_ms_p95": _percentil(cuadros, 0.95),
					"dibujos_p50": _percentil(dibujos, 0.5),
					"dibujos_max": dibujos.max(),
				}
			)
		)
	var informe := {
		"variante": variante,
		"godot": Engine.get_version_info().string,
		"gpu": RenderingServer.get_video_adapter_name(),
		"renderizador": RenderingServer.get_current_rendering_method(),
		"resolucion": str(root.get_visible_rect().size),
		"resultados": resultados,
	}
	_guardar(archivo, [informe])


static func _percentil(valores: Array[float], proporcion: float) -> float:
	var ordenados := valores.duplicate()
	ordenados.sort()
	return ordenados[maxi(0, ceili(ordenados.size() * proporcion) - 1)]


func _guardar(ruta: String, datos: Array) -> void:
	var texto := JSON.stringify(datos, "\t")
	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	archivo.store_string(texto)
	archivo.close()
	print(texto)
