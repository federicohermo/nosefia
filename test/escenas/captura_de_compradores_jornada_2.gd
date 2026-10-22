## Fixture de arte: no activa la agenda productiva ni publica guiones de reemplazo.
extends RefCounted

const RelojDePrueba := preload("res://test/reloj_de_prueba.gd")

var local: Node3D
var _padre: Node


func _compradores(_jornada: int) -> Array[Comprador]:
	var compradores := Compradores.segunda_jornada_definida()
	var guion := DialogosDeCompradores.new()
	guion.fede = PackedStringArray(["Atención de prueba: Fede."])
	guion.mia = PackedStringArray(["Atención de prueba: Mía."])
	for comprador in compradores:
		comprador.dialogos = guion
	return compradores


func tabla() -> Dictionary:
	var script: Script = load("res://src/escenas/puestos/ventanilla.gd")
	return script.get_script_constant_map()["ANIMACIONES"]


func crear(padre: Node) -> Node3D:
	_padre = padre
	local = load("res://src/escenas/almacen.tscn").instantiate()
	local.set(
		"_partida", Partida.desde({"jornada": Compradores.JORNADA_DE_FEDE_Y_MIA, "medios": 0})
	)
	local.set("compradores_de_la_apertura", _compradores)
	padre.add_child(local)
	local.get("_reloj").set_process(false)
	await cuadros()
	return local


func cuadros(cantidad: int = 3) -> void:
	for cuadro in cantidad:
		await _padre.get_tree().physics_frame
	await _padre.get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw


func puesto() -> Node3D:
	return local.get_node("Estructura/Ventanilla")


func figura() -> AnimatedSprite3D:
	return puesto().get("comprador_visible")


func atenciones() -> Ventanilla:
	return local.get("_atenciones")


func llegar(mia: bool = false) -> void:
	RelojDePrueba.avanzar_hasta(local.get("_reloj"), Vector2i(5, 0) if mia else Vector2i(20, 30))
	figura().stop()
	await cuadros()
	var entrada: Tween = puesto().get("_entrada")
	if entrada != null:
		entrada.custom_step(20.0)
	await cuadros()


func mirar(transparente: bool = false, lado: float = 0.0) -> Dictionary:
	var sprite := figura()
	var textura := sprite.sprite_frames.get_frame_texture(&"idle", sprite.frame)
	var imagen := textura.get_image()
	var pixel := Vector2i(-1, -1)
	for y in range(imagen.get_height() / 2, imagen.get_height() / 4, -4):
		for x in range(imagen.get_width() / 2, imagen.get_width() / 8, -4):
			var alfa := imagen.get_pixel(x, y).a
			if (
				(
					transparente
					and alfa == 0.0
					and imagen.get_region(Rect2i(x - 2, y - 2, 5, 5)).is_invisible()
				)
				or (not transparente and alfa >= 0.5)
			):
				pixel = Vector2i(x, y)
				break
		if pixel.x >= 0:
			break
	if pixel.x < 0:
		return {"pixel": pixel}
	var plano := (Vector2(pixel) + Vector2.ONE * 0.5 - textura.get_size() / 2.0) * sprite.pixel_size
	var punto := sprite.to_global(Vector3(plano.x, -plano.y, 0.0))
	var jugador: CharacterBody3D = local.get_node("Jugador")
	var altura := jugador.global_position.y
	var pie := sprite.global_position + sprite.global_basis.z * 1.3
	pie += sprite.global_basis.x * lado
	var rayo := PhysicsRayQueryParameters3D.create(
		Vector3(pie.x, altura + 0.2, pie.z), Vector3(pie.x, altura - 0.3, pie.z), 1
	)
	rayo.exclude = [jugador.get_rid()]
	var espacio := jugador.get_world_3d().direct_space_state
	var piso := espacio.intersect_ray(rayo)
	if piso.get("collider") != local.get_node("Estructura/SueloSolido"):
		return {"pixel": pixel, "piso": false}
	pie.y = piso.position.y + 0.002
	var forma: CollisionShape3D = jugador.get_node("Cuerpo")
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma.shape
	consulta.transform = Transform3D(Basis.IDENTITY, pie) * forma.transform
	consulta.collision_mask = jugador.collision_mask
	consulta.exclude = [jugador.get_rid()]
	if not espacio.intersect_shape(consulta).is_empty():
		return {"pixel": pixel, "piso": true, "capsula": false}
	jugador.call("ubicar", Transform3D(Basis.IDENTITY, pie))
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	var angulos := (
		Basis.looking_at((punto - camara.global_position).normalized(), Vector3.UP).get_euler()
	)
	var control: ControlDelJugador = jugador.get("_control")
	control.orientar(angulos.y)
	var sensibilidad: float = jugador.get("_mirada").get("_sensibilidad")
	control.girar(Vector2(0.0, -angulos.x / sensibilidad))
	control.avanzar_el_dibujo(1.0)
	jugador.call("_aplicar_la_rotacion")
	jugador.reset_physics_interpolation()
	await cuadros()
	jugador.call("_leer_la_mira")
	return {
		"pixel": pixel,
		"piso": true,
		"capsula": espacio.intersect_shape(consulta).is_empty(),
		"objetivo": jugador.call("enfocado") == puesto().get("objetivo"),
		"angulo": (-camara.global_basis.z).angle_to(punto - camara.global_position),
	}


func clic() -> void:
	for presionado: bool in [true, false]:
		var evento := InputEventMouseButton.new()
		evento.button_index = MOUSE_BUTTON_LEFT
		evento.pressed = presionado
		evento.position = _padre.get_viewport().get_visible_rect().get_center()
		evento.global_position = evento.position
		Input.parse_input_event(evento)
		Input.flush_buffered_events()
		await _padre.get_tree().process_frame


func limpiar() -> void:
	_padre.get_tree().paused = false
	if is_instance_valid(local):
		local.get_node("Servicios/AudioDelAlmacen/Reproductor").silenciar()
		local.queue_free()
	local = null
	await cuadros(4)
