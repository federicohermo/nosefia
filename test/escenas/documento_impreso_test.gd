extends GdUnitTestSuite

const JORNADA_DEL_DOCUMENTO := GeneradorDeTickets.JORNADA_SIN_LECTOR + 1

var _almacen: Node3D
var _ruta_anterior: String
var _tamano_anterior: Vector2i


func before_test() -> void:
	_ruta_anterior = Guardado.ruta_por_defecto
	_tamano_anterior = get_window().size
	get_window().size = Vector2i(1920, 1080)
	Guardado.ruta_por_defecto = "user://documento_789_prueba.guardado"
	Guardado.new().borrar()


func after_test() -> void:
	get_tree().paused = false
	await _cerrar_almacen()
	Guardado.new().borrar()
	Guardado.ruta_por_defecto = _ruta_anterior
	get_window().size = _tamano_anterior


func _cerrar_almacen() -> void:
	if is_instance_valid(_almacen):
		_almacen.hide()
		for tipo: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
			for audio: Node in _almacen.find_children("*", tipo, true, false):
				audio.call("stop")
				audio.set("stream", null)
		_almacen.queue_free()
		await _cuadros(3)
	_almacen = null


func _cuadros(cantidad: int = 3) -> void:
	for _cuadro: int in cantidad:
		await get_tree().process_frame


## La primera semilla con la que, sin pistas en la 5 y con 2A elegida, la 6 sortea ese camino.
func _semilla_que_sortea(identidad: String) -> int:
	for semilla: int in range(1, 65):
		var partida := Partida.desde({"jornada": JORNADA_DEL_DOCUMENTO, "semilla": semilla})
		partida.expediente.registrar("2A")
		partida.expediente.elegir(JORNADA_DEL_DOCUMENTO - 2, "2A")
		partida.abrir_la_jornada()
		if partida.expediente.sorteos().get(JORNADA_DEL_DOCUMENTO, "") == identidad:
			return semilla
	return 0


## Abre la jornada con lo que se eligió antes: las hipótesis elegidas por jornada y sus pistas.
## Con `semilla` cero, la partida trae una al azar.
func _abrir(jornada: int, elecciones: Dictionary = {}, semilla: int = 0) -> void:
	var guardada := {"jornada": jornada, "medios": 0, "elecciones": elecciones}
	if semilla > 0:
		guardada["semilla"] = semilla
	var encontradas: Array[String] = []
	for hipotesis: String in elecciones.values():
		encontradas.append(hipotesis)
	guardada["expediente"] = encontradas
	assert_bool(Guardado.new().escribir(PartidaSerializada.sanear(guardada))).is_true()
	_almacen = (load("res://src/escenas/almacen.tscn") as PackedScene).instantiate()
	add_child(_almacen)
	(_almacen.get_node("Interfaz/PersianaDeLaNoche") as PersianaDeLaNoche).terminar()
	(_almacen.get("_reloj") as Node).set_process(false)
	await _cuadros(5)
	assert_int((_almacen.get("_partida") as Partida).jornada()).is_equal(jornada)


func _por_la_5a() -> Dictionary:
	return {JORNADA_DEL_DOCUMENTO - 2: "2A", JORNADA_DEL_DOCUMENTO - 1: "5A"}


func _expediente() -> Expediente:
	return (_almacen.get("_partida") as Partida).expediente


func _documento() -> ObjetoAgarrable:
	return _almacen.get_node_or_null("Objetos/DocumentoImpreso") as ObjetoAgarrable


func _la_mira_lo_encuentra(objeto: ObjetoAgarrable) -> bool:
	var jugador := _almacen.get("_jugador") as CharacterBody3D
	var camara: Camera3D = jugador.get("_camara")
	jugador.call(
		"ubicar", Transform3D(Basis.IDENTITY, objeto.global_position + Vector3(-0.1, 0.55, 0.45))
	)
	camara.look_at(objeto.global_position)
	for _cuadro: int in 12:
		await get_tree().physics_frame
	jugador.call("_leer_la_mira")
	var consulta := PhysicsRayQueryParameters3D.create(
		camara.global_position, objeto.global_position
	)
	consulta.exclude = [jugador.get_rid()]
	var golpe := jugador.get_world_3d().direct_space_state.intersect_ray(consulta)
	return golpe.get("collider") == objeto or jugador.call("enfocado") == objeto


func test_el_documento_se_ve_y_se_enfoca_con_la_5a_elegida_o_sorteada() -> void:  # AC-INV-171
	var semilla := _semilla_que_sortea("5A")
	assert_int(semilla).is_greater(0)
	var casos: Array[Array] = [[_por_la_5a(), 0], [{JORNADA_DEL_DOCUMENTO - 2: "2A"}, semilla]]
	for caso: Array in casos:
		var eleccion: Dictionary = caso[0]
		await _abrir(JORNADA_DEL_DOCUMENTO, eleccion, caso[1])
		var documento := _documento()
		assert_object(documento).is_not_null()
		if documento == null:
			return
		var mensaje := "jornada %d, elecciones %s" % [JORNADA_DEL_DOCUMENTO, eleccion]
		assert_bool(documento.is_visible_in_tree()).override_failure_message(mensaje).is_true()
		(
			assert_bool(await _la_mira_lo_encuentra(documento))
			. override_failure_message(mensaje)
			. is_true()
		)
		var agarre: Agarre = _almacen.get("_agarre")
		assert_bool(agarre.pedir_agarrar(documento.datos, documento)).is_true()
		assert_object(agarre.cuerpo_sostenido()).is_same(documento)
		await _cerrar_almacen()


func test_otra_jornada_u_otra_eleccion_no_dejan_ver_el_documento() -> void:  # AC-INV-171
	var por_la_5b := {JORNADA_DEL_DOCUMENTO - 2: "2A", JORNADA_DEL_DOCUMENTO - 1: "5B"}
	var casos: Array[Array] = [
		[JORNADA_DEL_DOCUMENTO - 1, _por_la_5a(), 0],
		[JORNADA_DEL_DOCUMENTO + 1, _por_la_5a(), 0],
		[JORNADA_DEL_DOCUMENTO, por_la_5b, 0],
		[JORNADA_DEL_DOCUMENTO, {JORNADA_DEL_DOCUMENTO - 2: "2B"}, 0],
		[JORNADA_DEL_DOCUMENTO, {}, 0],
		[JORNADA_DEL_DOCUMENTO, {JORNADA_DEL_DOCUMENTO - 2: "2A"}, _semilla_que_sortea("5B")],
	]
	for caso: Array in casos:
		await _abrir(caso[0], caso[1], caso[2])
		var documento := _documento()
		assert_object(documento).is_not_null()
		if documento == null:
			return
		var mensaje := "jornada %d, elecciones %s" % [caso[0], caso[1]]
		assert_bool(documento.is_visible_in_tree()).override_failure_message(mensaje).is_false()
		assert_int(documento.collision_layer).override_failure_message(mensaje).is_zero()
		assert_int(documento.collision_mask).is_zero()
		assert_int(documento.process_mode).is_equal(Node.PROCESS_MODE_DISABLED)
		(
			assert_bool(await _la_mira_lo_encuentra(documento))
			. override_failure_message(mensaje)
			. is_false()
		)
		await _cerrar_almacen()


func test_el_documento_en_la_mano_sale_al_abrir_la_jornada_siguiente() -> void:  # AC-INV-171
	await _abrir(JORNADA_DEL_DOCUMENTO, _por_la_5a())
	var documento := _documento()
	assert_object(documento).is_not_null()
	if documento == null:
		return
	var agarre: Agarre = _almacen.get("_agarre")
	assert_bool(agarre.pedir_agarrar(documento.datos, documento)).is_true()
	_almacen.call("_al_abrir_la_jornada", JORNADA_DEL_DOCUMENTO + 1)
	await _cuadros()
	assert_object(agarre.cuerpo_sostenido()).is_null()
	assert_bool(documento.is_visible_in_tree()).is_false()
	assert_int(documento.collision_layer).is_zero()
	var iguales := _almacen.find_children("*", "ObjetoAgarrable", true, false).filter(
		func(nodo: Node) -> bool: return nodo.get("datos") == documento.datos
	)
	assert_array(iguales).contains_exactly([documento])
	_almacen.call("_al_abrir_la_jornada", JORNADA_DEL_DOCUMENTO)
	await _cuadros()
	assert_bool(documento.is_visible_in_tree()).is_true()


func test_el_documento_y_la_nota_no_se_superponen_bajo_la_puerta() -> void:  # AC-INV-171
	await _abrir(JORNADA_DEL_DOCUMENTO, _por_la_5a())
	var documento := _documento()
	var nota := _almacen.get_node_or_null("Objetos/NotaBajoLaPuerta") as ObjetoAgarrable
	assert_object(documento).is_not_null()
	assert_object(nota).is_not_null()
	if documento == null or nota == null:
		return
	var huellas: Array[Rect2] = []
	for objeto: ObjetoAgarrable in [documento, nota]:
		var forma := objeto.get_node("Forma") as CollisionShape3D
		var caja: AABB = forma.global_transform * forma.shape.get_debug_mesh().get_aabb()
		huellas.append(
			Rect2(Vector2(caja.position.x, caja.position.z), Vector2(caja.size.x, caja.size.z))
		)
	assert_bool(huellas[0].intersects(huellas[1])).is_false()


func test_levantar_el_documento_registra_6b_una_vez() -> void:  # AC-INV-172
	await _abrir(JORNADA_DEL_DOCUMENTO, _por_la_5a())
	var documento := _documento()
	assert_object(documento).is_not_null()
	if documento == null:
		return
	var nuevas: Array[Pista] = []
	(_almacen.get_node("Servicios/Investigador") as Investigador).pista_nueva.connect(
		func(pista: Pista) -> void: nuevas.append(pista)
	)
	var antes := _expediente().mensajes_de_notas().size()
	var agarre: Agarre = _almacen.get("_agarre")
	assert_bool(agarre.pedir_agarrar(documento.datos, documento)).is_true()
	assert_array(Array(_expediente().identidades())).contains(["6B"])
	assert_int(nuevas.size()).is_equal(1)
	assert_int(nuevas[0].jornada).is_equal(JORNADA_DEL_DOCUMENTO)
	assert_int(_expediente().mensajes_de_notas().size()).is_equal(antes + 2)
	agarre.soltar(false)
	await _cuadros()
	assert_bool(agarre.pedir_agarrar(documento.datos, documento)).is_true()
	assert_int(nuevas.size()).is_equal(1)
	assert_int(_expediente().mensajes_de_notas().size()).is_equal(antes + 2)


func test_mirar_rechazar_o_pausar_no_registran_el_documento() -> void:  # AC-INV-172
	await _abrir(JORNADA_DEL_DOCUMENTO, _por_la_5a())
	var documento := _documento()
	assert_object(documento).is_not_null()
	if documento == null:
		return
	assert_bool(await _la_mira_lo_encuentra(documento)).is_true()
	assert_array(Array(_expediente().identidades())).not_contains(["6B"])
	var agarre: Agarre = _almacen.get("_agarre")
	var balde := _almacen.get_node("Objetos/Balde") as ObjetoAgarrable
	assert_bool(agarre.pedir_agarrar(balde.datos, balde)).is_true()
	assert_bool(agarre.pedir_agarrar(documento.datos, documento)).is_false()
	assert_array(Array(_expediente().identidades())).not_contains(["6B"])
	agarre.soltar(false)
	get_tree().paused = true
	assert_bool(agarre.pedir_agarrar(documento.datos, documento)).is_true()
	assert_array(Array(_expediente().identidades())).not_contains(["6B"])
	get_tree().paused = false


func test_el_documento_es_una_hoja_impresa_propia() -> void:  # AC-INV-175
	var documento: ObjetoAgarrable = auto_free(
		(load("res://src/escenas/objetos/documento_impreso.tscn") as PackedScene).instantiate()
	)
	var nota: ObjetoAgarrable = auto_free(
		(load("res://src/escenas/objetos/nota_bajo_la_puerta.tscn") as PackedScene).instantiate()
	)
	var colilla: ObjetoAgarrable = auto_free(
		(load("res://src/escenas/objetos/colilla.tscn") as PackedScene).instantiate()
	)
	assert_bool(documento.datos is UnidadDeProducto).is_false()
	assert_bool(documento.datos.id != nota.datos.id).is_true()
	assert_bool(documento.datos.id != colilla.datos.id).is_true()
	assert_bool(documento.datos.es_levantable()).is_true()
	assert_str(documento.datos.texto_al_examinar()).is_not_empty()
	var caja: Node = auto_free(
		(load("res://src/escenas/objetos/caja_de_productos.tscn") as PackedScene).instantiate()
	)
	var de_la_caja := (
		(caja.get_node("Malla") as MeshInstance3D).get_active_material(0) as BaseMaterial3D
	)
	var de_la_nota := (
		(nota.get_node("Escrito") as MeshInstance3D).get_surface_override_material(0)
		as StandardMaterial3D
	)
	var texturas: Array[Texture2D] = []
	for malla: MeshInstance3D in documento.find_children("*", "MeshInstance3D", true, false):
		assert_int(malla.gi_mode).is_equal(GeometryInstance3D.GI_MODE_DYNAMIC)
		var material := malla.get_surface_override_material(0) as StandardMaterial3D
		assert_object(material).is_not_null()
		if material != null:
			texturas.append(material.albedo_texture)
			assert_bool(material.albedo_texture != de_la_caja.albedo_texture).is_true()
			assert_bool(material.albedo_texture != de_la_nota.albedo_texture).is_true()
	assert_int(texturas.size()).is_equal(2)
	if texturas.size() == 2:
		assert_bool(texturas[0] != texturas[1]).is_true()
	var impreso := documento.get_node("Impreso") as MeshInstance3D
	var de_la_cara := impreso.get_surface_override_material(0) as StandardMaterial3D
	assert_str(de_la_cara.albedo_texture.resource_path).is_equal(
		"res://assets/ui/manada/pistas/documento-impreso.png"
	)
