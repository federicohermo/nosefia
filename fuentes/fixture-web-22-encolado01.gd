extends Node

var _local: Node3D
var _partida: RefCounted
var _expediente: RefCounted
var _celular: Node
var _pantalla: Node
var _jugador: CharacterBody3D
var _fallos: Array[String] = []
var _nuevas: Array[String] = []
var _notas_emitidas: Array[String] = []
var _pensamientos: Array[String] = []
var _ultimo_id := 0
var _ocupado := true
var _etapa := "cargando"
var _tiempo := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_abrir.call_deferred()


func _exigir(condicion: bool, detalle: String) -> void:
	if not condicion:
		_fallos.append(detalle)
		push_error("FIXTURE_WEB_22: " + detalle)


func _sincronizar() -> void:
	for _paso: int in 6:
		await get_tree().physics_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _abrir() -> void:
	var clase: Script = load("res://src/dominio/empleo/partida.gd")
	_partida = clase.call("nueva")
	_partida.call("abrir_la_jornada")
	var tareas: Array = _partida.call("obligatorias")
	for tarea: RefCounted in tareas:
		tarea.call("completar")
	_partida.call("cerrar_la_jornada", tareas.size())
	_expediente = _partida.get("expediente")
	_local = (load("res://src/escenas/almacen.tscn") as PackedScene).instantiate()
	_local.set("_partida", _partida)
	get_tree().root.add_child(_local)
	_celular = _local.get("_celular")
	_pantalla = _local.get("_pantalla_del_celular")
	_jugador = _local.get("_jugador")
	_local.get_node("Servicios/Investigador").connect(
		"pista_nueva", func(pista: Resource) -> void: _nuevas.append(pista.get("identidad"))
	)
	_local.get_node("Servicios/Investigador").connect(
		"nota_agregada", func(nota: Resource) -> void: _notas_emitidas.append(nota.get("identidad"))
	)
	(_jugador.get("examen") as Node).connect(
		"pensamiento_pedido", func(texto: String) -> void: _pensamientos.append(texto)
	)
	_local.get_node("Interfaz/PersianaDeLaNoche").call("terminar")
	(_local.get("_reloj") as Node).set_process(false)
	await _sincronizar()
	var colilla := _local.get_node("Objetos/Colilla") as RigidBody3D
	var pie := colilla.global_position + Vector3(0, 0.1, 0.75)
	var consulta := PhysicsRayQueryParameters3D.create(pie, pie + Vector3.DOWN * 0.5, 1)
	consulta.exclude = [_jugador.get_rid(), colilla.get_rid()]
	var piso := _jugador.get_world_3d().direct_space_state.intersect_ray(consulta)
	_exigir(piso.get("collider") == _local.get_node("Estructura/SueloSolido"), "pose sin piso real")
	if piso.is_empty():
		return
	pie.y = piso.position.y + 0.002
	_jugador.call("ubicar", Transform3D(Basis.IDENTITY, pie))
	await _sincronizar()
	var camara: Camera3D = _jugador.get("_camara")
	var angulos := Basis.looking_at(colilla.global_position - camara.global_position).get_euler()
	var control: RefCounted = _jugador.get("_control")
	control.call("orientar", angulos.y)
	var sensibilidad: float = _jugador.get("_mirada").get("_sensibilidad")
	control.call("girar", Vector2(0, -angulos.x / sensibilidad))
	control.call("avanzar_el_dibujo", 1.0)
	_jugador.call("_aplicar_la_rotacion")
	await _sincronizar()
	_jugador.call("_leer_la_mira")
	var rayo := PhysicsRayQueryParameters3D.create(camara.global_position, colilla.global_position)
	rayo.exclude = [_jugador.get_rid()]
	var golpe := _jugador.get_world_3d().direct_space_state.intersect_ray(rayo)
	_exigir(golpe.get("collider") == colilla, "rayo no encuentra la colilla")
	_exigir(_jugador.is_on_floor(), "el jugador no tiene contacto con piso")
	_exigir(_jugador.call("enfocado") == colilla, "mira real no enfoca colilla")
	_exigir(_expediente.call("identidades").is_empty(), "el fixture fabricó un descubrimiento")
	_etapa = "colilla"
	_ocupado = false
	await _publicar()
	print("FIXTURE_WEB_22_LISTO")


func _process(delta: float) -> void:
	_tiempo += delta
	if not _ocupado and _tiempo >= 0.1:
		_tiempo = 0.0
		_ocupado = true
		_leer_comando.call_deferred()


func _leer_comando() -> void:
	var texto: String = JavaScriptBridge.eval("JSON.stringify(window.__22_command || null)", true)
	var comando: Variant = JSON.parse_string(texto)
	if comando is Dictionary and int(comando.get("id", 0)) > _ultimo_id:
		await _preparar(comando)
		_ultimo_id = int(comando.id)
	await _publicar()
	_ocupado = false


func _preparar(comando: Dictionary) -> void:
	match String(comando.get("accion", "")):
		"cerrar":
			var reglas: Script = load("res://src/dominio/reglas.gd")
			var ritmo: Script = load("res://src/dominio/jornada/ritmo.gd")
			(_local.get("_reloj") as Node).call(
				"avanzar",
				(
					float(reglas.get_script_constant_map()["DURACION_DEL_TURNO"])
					/ float(ritmo.get_script_constant_map()["SEGUNDOS_DE_TURNO_POR_SEGUNDO_REAL"])
				)
			)
			await get_tree().create_timer(0.5).timeout
			var devolucion: Node = _local.get("_pantalla")
			for _paso: int in 30:
				if devolucion.call("opcion_a_la_vista"):
					break
				devolucion.call("_process", 1.0)
				await _sincronizar()
			_etapa = "cierre2"
		"fijar_notas":
			_celular.call("mostrar_fijo", 4)
			await get_tree().create_timer(0.5).timeout
			_etapa = "notas_fijas"
		"abrir3":
			(_local.get("_ciclo") as Node).call("abrir_la_jornada")
			_local.get_node("Interfaz/PersianaDeLaNoche").call("terminar")
			(_local.get("_reloj") as Node).set_process(false)
			await _sincronizar()
			_exigir(_partida.get("expediente") == _expediente, "se sustituyó el expediente")
			_etapa = "jornada3"
		"fin":
			print("FIXTURE_WEB_22_FINAL ", JSON.stringify({"fallos": _fallos}))


func _burbuja(lista: VBoxContainer, indice: int) -> Control:
	for hijo: Node in lista.get_children():
		if hijo.has_meta("indice_de_mensaje") and int(hijo.get_meta("indice_de_mensaje")) == indice:
			return hijo as Control
	return null


func _publicar() -> void:
	await RenderingServer.frame_post_draw
	var telefono: RefCounted = _celular.call("celular")
	var lista: VBoxContainer = _pantalla.get("_mensajes")
	var scroll: ScrollContainer = _pantalla.get("_scroll")
	var notas: Array = _expediente.call("mensajes_de_notas")
	var menu: Array[Dictionary] = []
	var fotos: Array[Dictionary] = []
	var rotulos: Array[String] = []
	var puntos: Dictionary = {}
	if telefono.call("pantalla") == 0:
		var conversaciones: Array = _celular.call("bandeja").call("conversaciones")
		for indice: int in mini(lista.get_child_count(), conversaciones.size()):
			menu.append(
				{
					"quien": conversaciones[indice].get("interlocutor"),
					"punto":
					_punto((lista.get_child(indice) as Control).get_global_rect().get_center())
				}
			)
	else:
		for hijo: Node in lista.get_children():
			if hijo is Label:
				rotulos.append(hijo.text)
		if telefono.call("chat") == 3:
			var burbuja := _burbuja(lista, 5)
			if burbuja != null:
				var texto := (
					burbuja.find_children("*", "RichTextLabel", true, false)[0] as RichTextLabel
				)
				var fuente := texto.get_theme_font("normal_font")
				var tamano := texto.get_theme_font_size("normal_font_size")
				var prefijo := (
					fuente.get_string_size("y te aviso q ", HORIZONTAL_ALIGNMENT_LEFT, -1, tamano).x
				)
				puntos = {
					"prefijo":
					_punto(
						texto.get_global_transform() * Vector2(8, fuente.get_height(tamano) / 2)
					),
					"tramo":
					_punto(
						(
							texto.get_global_transform()
							* Vector2(prefijo + 8, fuente.get_height(tamano) / 2)
						)
					)
				}
		elif telefono.call("chat") == 4:
			for indice: int in [0, 2]:
				var burbuja := _burbuja(lista, indice)
				if burbuja != null:
					var boton := (
						burbuja.find_children("*", "TextureButton", true, false)[0] as Control
					)
					fotos.append(
						{
							"indice": indice,
							"punto": _punto(boton.get_global_rect().get_center()),
							"visible":
							scroll.get_global_rect().has_point(boton.get_global_rect().get_center())
						}
					)
	var colilla := _local.get_node("Objetos/Colilla") as Node3D
	var agarre: Node = _local.get("_agarre")
	var estado := {
		"id": _ultimo_id,
		"etapa": _etapa,
		"fallos": _fallos,
		"jornada": _partida.call("jornada"),
		"pistas": _expediente.call("identidades"),
		"notas": notas.size(),
		"nuevas": _nuevas,
		"notas_emitidas": _notas_emitidas,
		"pensamientos": _pensamientos,
		"colilla_en_mano": agarre.call("cuerpo_sostenido") == colilla,
		"abierto": telefono.call("abierto"),
		"fijo": telefono.call("fijo"),
		"pantalla": telefono.call("pantalla"),
		"chat": telefono.call("chat"),
		"menu": menu,
		"fotos": fotos,
		"puntos": puntos,
		"rotulos": rotulos,
		"scroll": scroll.scroll_vertical,
		"adjunto": (_pantalla.get("_adjunto") as RichTextLabel).text,
		"cerrar_foto":
		_punto((_pantalla.get("_telefono") as Control).get_global_rect().get_center()),
		"viewport": _punto(Vector2(get_tree().root.size)),
		"volver": _punto((_pantalla.get("_volver") as Control).get_global_rect().get_center())
	}
	JavaScriptBridge.eval("window.__22_state = " + JSON.stringify(estado), true)


func _punto(punto: Vector2) -> Array[float]:
	return [punto.x, punto.y]
