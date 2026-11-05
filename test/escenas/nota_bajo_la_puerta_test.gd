extends GdUnitTestSuite

const JORNADA_DE_LA_NOTA := GeneradorDeTickets.JORNADA_SIN_LECTOR + 1

var _almacen: Node3D
var _ruta_anterior: String
var _tamano_anterior: Vector2i


func before_test() -> void:
	_ruta_anterior = Guardado.ruta_por_defecto
	_tamano_anterior = get_window().size
	get_window().size = Vector2i(1920, 1080)
	Guardado.ruta_por_defecto = "user://nota_741_prueba.guardado"
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


## Abre la jornada con lo que se eligió antes: las hipótesis elegidas por jornada y sus pistas.
func _abrir(jornada: int, elecciones: Dictionary = {}) -> void:
	var guardada := {"jornada": jornada, "medios": 0, "elecciones": elecciones}
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


func _por_la_5b() -> Dictionary:
	return {JORNADA_DE_LA_NOTA - 2: "2A", JORNADA_DE_LA_NOTA - 1: "5B"}


func _expediente() -> Expediente:
	return (_almacen.get("_partida") as Partida).expediente


func _nota() -> ObjetoAgarrable:
	return _almacen.get_node_or_null("Objetos/NotaBajoLaPuerta") as ObjetoAgarrable


func _la_mira_la_encuentra(nota: ObjetoAgarrable) -> bool:
	var jugador := _almacen.get("_jugador") as CharacterBody3D
	var camara: Camera3D = jugador.get("_camara")
	jugador.call(
		"ubicar", Transform3D(Basis.IDENTITY, nota.global_position + Vector3(-0.1, 0.55, 0.45))
	)
	camara.look_at(nota.global_position)
	for _cuadro: int in 12:
		await get_tree().physics_frame
	jugador.call("_leer_la_mira")
	var consulta := PhysicsRayQueryParameters3D.create(camara.global_position, nota.global_position)
	consulta.exclude = [jugador.get_rid()]
	var golpe := jugador.get_world_3d().direct_space_state.intersect_ray(consulta)
	return golpe.get("collider") == nota or jugador.call("enfocado") == nota


func test_la_nota_se_ve_y_se_enfoca_con_la_5b_elegida_o_sorteada() -> void:  # AC-INV-121
	var elecciones: Array[Dictionary] = [_por_la_5b(), {JORNADA_DE_LA_NOTA - 2: "2A"}]
	for eleccion: Dictionary in elecciones:
		await _abrir(JORNADA_DE_LA_NOTA, eleccion)
		var nota := _nota()
		assert_object(nota).is_not_null()
		if nota == null:
			return
		var mensaje := "jornada %d, elecciones %s" % [JORNADA_DE_LA_NOTA, eleccion]
		assert_bool(nota.is_visible_in_tree()).override_failure_message(mensaje).is_true()
		assert_bool(await _la_mira_la_encuentra(nota)).override_failure_message(mensaje).is_true()
		var agarre: Agarre = _almacen.get("_agarre")
		assert_bool(agarre.pedir_agarrar(nota.datos, nota)).is_true()
		assert_object(agarre.cuerpo_sostenido()).is_same(nota)
		await _cerrar_almacen()


func test_otra_jornada_u_otra_eleccion_no_dejan_ver_la_nota() -> void:  # AC-INV-121
	var casos: Array[Array] = [
		[JORNADA_DE_LA_NOTA - 1, _por_la_5b()],
		[JORNADA_DE_LA_NOTA + 1, _por_la_5b()],
		[JORNADA_DE_LA_NOTA, {JORNADA_DE_LA_NOTA - 2: "2B"}],
		[JORNADA_DE_LA_NOTA, {}],
	]
	for caso: Array in casos:
		await _abrir(caso[0], caso[1])
		var nota := _nota()
		assert_object(nota).is_not_null()
		if nota == null:
			return
		var mensaje := "jornada %d, elecciones %s" % [caso[0], caso[1]]
		assert_bool(nota.is_visible_in_tree()).override_failure_message(mensaje).is_false()
		assert_int(nota.collision_layer).override_failure_message(mensaje).is_zero()
		assert_int(nota.collision_mask).is_zero()
		assert_int(nota.process_mode).is_equal(Node.PROCESS_MODE_DISABLED)
		assert_bool(await _la_mira_la_encuentra(nota)).override_failure_message(mensaje).is_false()
		await _cerrar_almacen()


func test_la_nota_en_la_mano_sale_al_abrir_la_jornada_siguiente() -> void:  # AC-INV-121
	await _abrir(JORNADA_DE_LA_NOTA, _por_la_5b())
	var nota := _nota()
	assert_object(nota).is_not_null()
	if nota == null:
		return
	var agarre: Agarre = _almacen.get("_agarre")
	assert_bool(agarre.pedir_agarrar(nota.datos, nota)).is_true()
	_almacen.call("_al_abrir_la_jornada", JORNADA_DE_LA_NOTA + 1)
	await _cuadros()
	assert_object(agarre.cuerpo_sostenido()).is_null()
	assert_bool(nota.is_visible_in_tree()).is_false()
	assert_int(nota.collision_layer).is_zero()
	var notas := _almacen.find_children("*", "ObjetoAgarrable", true, false).filter(
		func(nodo: Node) -> bool: return nodo.get("datos") == nota.datos
	)
	assert_array(notas).contains_exactly([nota])
	_almacen.call("_al_abrir_la_jornada", JORNADA_DE_LA_NOTA)
	await _cuadros()
	assert_bool(nota.is_visible_in_tree()).is_true()


func test_levantar_la_nota_registra_6c_una_vez() -> void:  # AC-INV-122
	await _abrir(JORNADA_DE_LA_NOTA, _por_la_5b())
	var nota := _nota()
	assert_object(nota).is_not_null()
	if nota == null:
		return
	var nuevas: Array[Pista] = []
	(_almacen.get_node("Servicios/Investigador") as Investigador).pista_nueva.connect(
		func(pista: Pista) -> void: nuevas.append(pista)
	)
	var antes := _expediente().mensajes_de_notas().size()
	var agarre: Agarre = _almacen.get("_agarre")
	assert_bool(agarre.pedir_agarrar(nota.datos, nota)).is_true()
	assert_array(Array(_expediente().identidades())).contains(["6C"])
	assert_int(nuevas.size()).is_equal(1)
	assert_int(nuevas[0].jornada).is_equal(JORNADA_DE_LA_NOTA)
	assert_int(_expediente().mensajes_de_notas().size()).is_equal(antes + 2)
	agarre.soltar(false)
	await _cuadros()
	assert_bool(agarre.pedir_agarrar(nota.datos, nota)).is_true()
	assert_int(nuevas.size()).is_equal(1)
	assert_int(_expediente().mensajes_de_notas().size()).is_equal(antes + 2)


func test_mirar_rechazar_o_pausar_no_registran_la_nota() -> void:  # AC-INV-122
	await _abrir(JORNADA_DE_LA_NOTA, _por_la_5b())
	var nota := _nota()
	assert_object(nota).is_not_null()
	if nota == null:
		return
	assert_bool(await _la_mira_la_encuentra(nota)).is_true()
	assert_array(Array(_expediente().identidades())).not_contains(["6C"])
	var agarre: Agarre = _almacen.get("_agarre")
	var balde := _almacen.get_node("Objetos/Balde") as ObjetoAgarrable
	assert_bool(agarre.pedir_agarrar(balde.datos, balde)).is_true()
	assert_bool(agarre.pedir_agarrar(nota.datos, nota)).is_false()
	assert_array(Array(_expediente().identidades())).not_contains(["6C"])
	agarre.soltar(false)
	get_tree().paused = true
	assert_bool(agarre.pedir_agarrar(nota.datos, nota)).is_true()
	assert_array(Array(_expediente().identidades())).not_contains(["6C"])
	get_tree().paused = false


func test_la_nota_es_un_papel_manuscrito_propio() -> void:  # AC-INV-126
	var escena := load("res://src/escenas/objetos/nota_bajo_la_puerta.tscn") as PackedScene
	var nota: ObjetoAgarrable = auto_free(escena.instantiate())
	var colilla := load("res://src/escenas/objetos/colilla.tscn") as PackedScene
	var de_la_colilla: ObjetoAgarrable = auto_free(colilla.instantiate())
	assert_bool(nota.datos is UnidadDeProducto).is_false()
	assert_bool(nota.datos.id != de_la_colilla.datos.id).is_true()
	assert_bool(nota.datos.es_levantable()).is_true()
	assert_str(nota.datos.texto_al_examinar()).is_not_empty()
	var texturas: Array[Texture2D] = []
	for malla: MeshInstance3D in nota.find_children("*", "MeshInstance3D", true, false):
		assert_int(malla.gi_mode).is_equal(GeometryInstance3D.GI_MODE_DYNAMIC)
		var material := malla.get_surface_override_material(0) as StandardMaterial3D
		assert_object(material).is_not_null()
		if material != null:
			assert_object(material.albedo_texture).is_not_null()
			texturas.append(material.albedo_texture)
	assert_int(texturas.size()).is_equal(2)
	if texturas.size() == 2:
		assert_bool(texturas[0] != texturas[1]).is_true()
	var caja: Node = auto_free(
		(load("res://src/escenas/objetos/caja_de_productos.tscn") as PackedScene).instantiate()
	)
	var de_la_caja := (
		(caja.get_node("Malla") as MeshInstance3D).get_active_material(0) as BaseMaterial3D
	)
	assert_object(de_la_caja).is_not_null()
	if de_la_caja != null:
		for textura: Texture2D in texturas:
			assert_str(textura.resource_path).is_not_equal(de_la_caja.albedo_texture.resource_path)
	var escrita := nota.get_node("Escrito") as MeshInstance3D
	var de_la_cara := escrita.get_surface_override_material(0) as StandardMaterial3D
	assert_str(de_la_cara.albedo_texture.resource_path).is_equal(
		"res://assets/ui/manada/pistas/nota-bajo-la-puerta.png"
	)


func test_la_nota_toca_la_puerta_del_jefe() -> void:
	await _abrir(JORNADA_DE_LA_NOTA, _por_la_5b())
	var nota := _nota()
	assert_object(nota).is_not_null()
	if nota == null:
		return
	var volumen := (
		_almacen.get_node("Estructura/puertajefe/CuerpoDeLaHoja/Volumen") as CollisionShape3D
	)
	var hoja: AABB = volumen.global_transform * volumen.shape.get_debug_mesh().get_aabb()
	var papel := (nota.get_node("Escrito") as MeshInstance3D).mesh as PlaneMesh
	var en_planta := Vector2(nota.global_position.x, nota.global_position.z)
	var cerca := Vector2(
		clampf(en_planta.x, hoja.position.x, hoja.end.x),
		clampf(en_planta.y, hoja.position.z, hoja.end.z)
	)
	assert_float(en_planta.distance_to(cerca)).is_less_equal(papel.size.x / 2.0)
