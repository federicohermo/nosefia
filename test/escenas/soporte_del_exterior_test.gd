## El soporte sigue los seis pavimentos existentes y recibe las soltadas por el hueco libre.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const Exterior := preload("res://src/escenas/puestos/exterior_del_almacen.gd")
var _almacen: Node3D


func after_test() -> void:
	if is_instance_valid(_almacen):
		for tipo: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
			for audio: Node in _almacen.find_children("*", tipo, true, false):
				audio.call("stop")
				audio.set("stream", null)
		_almacen.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_almacen = null


func test_cada_pavimento_tiene_soporte_con_sus_mismos_triangulos() -> void:  # AC-CLN-045
	_almacen = Exterior.new()
	add_child(_almacen)
	var pavimentos: Array[Node] = _almacen.find_children(
		"Pavimento*", "MeshInstance3D", false, false
	)
	assert_array(pavimentos).has_size(6)
	for malla: MeshInstance3D in pavimentos:
		var formas := malla.find_children("*", "CollisionShape3D", true, false)
		assert_array(formas).has_size(1)
		if formas.size() != 1:
			continue
		var forma: CollisionShape3D = formas[0]
		assert_bool(forma.shape is ConcavePolygonShape3D).is_true()
		assert_array((forma.shape as ConcavePolygonShape3D).get_faces()).contains_exactly(
			malla.mesh.get_faces()
		)
		assert_bool(forma.transform.is_equal_approx(Transform3D.IDENTITY)).is_true()


func test_los_dos_laterales_reales_dejan_caer_apoyar_y_recoger_un_cuerpo() -> void:  # AC-CLN-045
	_almacen = ALMACEN.instantiate()
	add_child(_almacen)
	var jugador: Node3D = _almacen.get("_jugador")
	jugador.set_process(false)
	jugador.set_physics_process(false)
	var ventana: Node3D = _almacen.get_node("Estructura/Ventanilla")
	var vidrio := _limites(ventana.get_node("Vidrio"))
	var pared: Node = _almacen.get_node("Estructura/almacen/Volumen")
	var izquierda := _limites(pared.get_node("local_caja_lateral"))
	var derecha := _limites(pared.get_node("local_caja_centro"))
	var dintel := _limites(pared.get_node("local_ventanilla_alto"))
	# La holgura superior es numérica, no un tercer paso físico.
	assert_float(absf(dintel.position.y - vidrio.end.y)).is_less(0.00001)
	var agarre: Agarre = _almacen.get("_agarre")
	for lado: int in 2:
		# El papel real cabe por el lateral; una caja de producto más ancha no cabe.
		var productos: Array[Producto] = [Catalogo.de(Producto.Id.ACTRONCITO)]
		_almacen.get("_caja").ticket_impreso.emit(Ticket.new(productos))
		var cuerpo: ObjetoAgarrable = _almacen.get_node("Estructura/Ticket")
		assert_bool(agarre.pedir_agarrar(cuerpo.datos, cuerpo)).is_true()
		var forma: CollisionShape3D = cuerpo.get_node("Forma")
		var limites := forma.shape.get_debug_mesh().get_aabb()
		var giro := Basis.IDENTITY
		if limites.size.y < limites.size.x and limites.size.y < limites.size.z:
			giro = Basis(Vector3.FORWARD, PI / 2)
		elif limites.size.z < limites.size.x:
			giro = Basis(Vector3.UP, PI / 2)
		var orientado := Transform3D(giro, Vector3.ZERO) * limites
		var desde := izquierda.end.x if lado == 0 else vidrio.end.x
		var hasta := vidrio.position.x if lado == 0 else derecha.position.x
		assert_float(orientado.size.x).is_less(hasta - desde)
		var centro := Vector3((desde + hasta) / 2, vidrio.get_center().y, vidrio.end.z)
		centro.z += orientado.size.z / 2 + 0.02
		# La forma real entra entre jamba y vidrio; no se escala ni se sustituye por una caja falsa.
		assert_float(centro.x - orientado.size.x / 2).is_greater(desde)
		assert_float(centro.x + orientado.size.x / 2).is_less(hasta)
		agarre.punto_de_soltado.global_position = centro
		cuerpo.global_basis = giro
		assert_object(agarre.soltar(true)).is_same(cuerpo)
		cuerpo.global_position = centro
		cuerpo.global_basis = giro
		var alto := cuerpo.global_position.y
		for cuadro in 120:
			await get_tree().physics_frame
		assert_float(cuerpo.global_position.y).is_less(alto - 0.2)
		var altura_del_pavimento := Exterior.ALTURA_DEL_SUELO
		assert_float(cuerpo.global_position.y).is_greater(altura_del_pavimento - 0.02)
		var apoyado := cuerpo.global_position
		for cuadro in 20:
			await get_tree().physics_frame
		assert_vector(cuerpo.global_position).is_equal_approx(apoyado, Vector3.ONE * 0.03)
		# El punto de vista se deriva del cuerpo apoyado, sin cambiar el alcance de interacción.
		jugador.global_position = cuerpo.global_position + Vector3(0, 0, 0.5)
		var camara: Camera3D = jugador.get_node("Giro/Camara")
		camara.look_at(cuerpo.global_position)
		for cuadro in 4:
			await get_tree().physics_frame
		var candidato: CampoDeInteraccion.Candidato = jugador.call("_medir_candidato", cuerpo)
		assert_float(candidato.distancia).is_less_equal(ReglasDelJugador.ALCANCE_DE_LA_MIRA)
		jugador.call("_leer_la_mira")
		assert_object(jugador.get("_enfocado")).is_same(cuerpo)
		var evento := InputEventMouseButton.new()
		evento.button_index = MOUSE_BUTTON_LEFT
		evento.pressed = true
		jugador.call("_unhandled_input", evento)
		assert_object(agarre.cuerpo_sostenido()).is_same(cuerpo)
		# Los consumidores del foco reciben la pérdida mientras el papel todavía vive.
		jugador.call("suspender")
		agarre.entregar()
		cuerpo.queue_free()
		await get_tree().process_frame
		jugador.call("reanudar")


func _limites(forma: CollisionShape3D) -> AABB:
	return forma.global_transform * forma.shape.get_debug_mesh().get_aabb()
