extends GdUnitTestSuite

const ESCENA := preload("res://src/escenas/objetos/llave.tscn")
const AvanceDelEpilogo := preload("res://test/avance_del_epilogo.gd")
const JORNADA_7 := QuejasDeLaJornada.JORNADA
const JORNADA_6 := JORNADA_7 - 1
const JORNADA_5 := JORNADA_6 - 1
const CUARTA := JORNADA_5 - 1

var _almacen: Node3D
var _ruta_anterior: String
var _tamano_anterior: Vector2i


func before_test() -> void:
	_ruta_anterior = Guardado.ruta_por_defecto
	_tamano_anterior = get_window().size
	get_window().size = Vector2i(1920, 1080)
	Guardado.ruta_por_defecto = "user://llave_810_prueba.guardado"
	Guardado.new().borrar()


func after_test() -> void:
	get_tree().paused = false
	Input.action_release(ReglasDelJugador.ACCION_AGACHARSE)
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
	var encontradas: Array[String] = []
	for hipotesis: String in elecciones.values():
		encontradas.append(hipotesis)
	var guardada := {
		"jornada": jornada, "medios": 0, "elecciones": elecciones, "expediente": encontradas
	}
	assert_bool(Guardado.new().escribir(PartidaSerializada.sanear(guardada))).is_true()
	_almacen = (load("res://src/escenas/almacen.tscn") as PackedScene).instantiate()
	add_child(_almacen)
	(_almacen.get_node("Interfaz/PersianaDeLaNoche") as PersianaDeLaNoche).terminar()
	(_almacen.get("_reloj") as Node).set_process(false)
	await _cuadros(5)
	assert_int((_almacen.get("_partida") as Partida).jornada()).is_equal(jornada)


func _por_la_6c() -> Dictionary:
	return {CUARTA: "2A", JORNADA_5: "5B", JORNADA_6: "6C"}


func _por_la_6b() -> Dictionary:
	return {CUARTA: "2A", JORNADA_5: "5A", JORNADA_6: "6B"}


func _partida() -> Partida:
	return _almacen.get("_partida") as Partida


func _llave() -> ObjetoAgarrable:
	return _almacen.get_node_or_null("Objetos/Llave") as ObjetoAgarrable


func _palanca() -> ObjetoAgarrable:
	return _almacen.get_node_or_null("Objetos/Palanca") as ObjetoAgarrable


func _puerta_del_jefe() -> Node:
	return _almacen.get_node("Estructura/puertajefe/CuerpoDeLaHoja")


func _agarre() -> Agarre:
	return _almacen.get("_agarre") as Agarre


## Mira el objeto desde el pasillo, agachado: de pie la estantería tapa la llave.
func _la_mira_lo_encuentra(objeto: ObjetoAgarrable) -> bool:
	var jugador := _almacen.get("_jugador") as CharacterBody3D
	var camara: Camera3D = jugador.get("_camara")
	var piso := objeto.global_position * Vector3(1.0, 0.0, 1.0)
	jugador.call("ubicar", Transform3D(Basis.IDENTITY, piso + Vector3(1.0, 0.0, 0.0)))
	Input.action_press(ReglasDelJugador.ACCION_AGACHARSE)
	jugador.call("_acomodar_la_vista", ReglasDelJugador.DURACION_DEL_AGACHE * 2.0)
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


## Cuántos avisos da la puerta de cada clase mientras se la acciona.
func _contar_avisos(puerta: Node) -> Dictionary:
	var avisos := {"abierta": 0, "trabada": 0}
	puerta.connect("puerta_abierta", func(_p: Node3D) -> void: avisos["abierta"] += 1)
	puerta.connect("puerta_forzada_con_llave", func(_p: Node3D) -> void: avisos["abierta"] += 1)
	puerta.connect("puerta_trabada", func(_p: Node3D) -> void: avisos["trabada"] += 1)
	puerta.connect("porton_trabado", func(_p: Node3D) -> void: avisos["trabada"] += 1)
	return avisos


func test_la_llave_se_ve_se_enfoca_y_se_levanta_con_la_6c_elegida() -> void:  # AC-INV-185
	await _abrir(JORNADA_7, _por_la_6c())
	var llave := _llave()
	assert_object(llave).is_not_null()
	if llave == null:
		return
	assert_bool(llave.is_visible_in_tree()).is_true()
	assert_bool(await _la_mira_lo_encuentra(llave)).is_true()
	assert_bool(_agarre().pedir_agarrar(llave.datos, llave)).is_true()
	assert_object(_agarre().cuerpo_sostenido()).is_same(llave)


func test_con_otra_eleccion_u_otra_jornada_la_llave_no_esta() -> void:  # AC-INV-185
	var casos: Array[Array] = [
		[JORNADA_6, {CUARTA: "2A", JORNADA_5: "5B"}],
		[JORNADA_7, _por_la_6b()],
		[JORNADA_7, {CUARTA: "2A", JORNADA_5: "5B"}],
		[JORNADA_7, {}],
	]
	for caso: Array in casos:
		await _abrir(caso[0], caso[1])
		var llave := _llave()
		assert_object(llave).is_not_null()
		if llave == null:
			return
		var mensaje := "jornada %d, elecciones %s" % [caso[0], caso[1]]
		assert_bool(llave.is_visible_in_tree()).override_failure_message(mensaje).is_false()
		assert_int(llave.collision_layer).override_failure_message(mensaje).is_zero()
		assert_int(llave.collision_mask).is_zero()
		assert_int(llave.process_mode).is_equal(Node.PROCESS_MODE_DISABLED)
		assert_bool(await _la_mira_lo_encuentra(llave)).override_failure_message(mensaje).is_false()
		await _cerrar_almacen()


func test_por_cada_camino_esta_su_objeto_y_no_el_del_otro() -> void:  # AC-INV-185
	await _abrir(JORNADA_7, _por_la_6c())
	assert_bool(_llave().is_visible_in_tree()).is_true()
	assert_bool(_palanca().is_visible_in_tree()).is_false()
	await _cerrar_almacen()
	await _abrir(JORNADA_7, _por_la_6b())
	assert_bool(_palanca().is_visible_in_tree()).is_true()
	assert_bool(_llave().is_visible_in_tree()).is_false()


func test_levantar_y_soltar_la_llave_no_registra_ni_avisa() -> void:  # AC-INV-186
	await _abrir(JORNADA_7, _por_la_6c())
	var llave := _llave()
	assert_object(llave).is_not_null()
	if llave == null:
		return
	var nuevas: Array[Pista] = []
	(_almacen.get_node("Servicios/Investigador") as Investigador).pista_nueva.connect(
		func(pista: Pista) -> void: nuevas.append(pista)
	)
	var identidades := _partida().expediente.identidades()
	var notas := _partida().expediente.mensajes_de_notas().size()
	assert_bool(_agarre().pedir_agarrar(llave.datos, llave)).is_true()
	_agarre().soltar(false)
	await _cuadros()
	assert_bool(_agarre().pedir_agarrar(llave.datos, llave)).is_true()
	assert_array(Array(_partida().expediente.identidades())).is_equal(Array(identidades))
	assert_int(_partida().expediente.mensajes_de_notas().size()).is_equal(notas)
	assert_array(nuevas).is_empty()
	assert_int(_partida().final()).is_equal(Partida.Final.EN_CURSO)


func test_la_llave_es_un_objeto_propio() -> void:  # AC-INV-185
	var llave: ObjetoAgarrable = auto_free(ESCENA.instantiate())
	var otros: Array[String] = ["colilla", "nota_bajo_la_puerta", "documento_impreso", "palanca"]
	for escena: String in otros:
		var otro: ObjetoAgarrable = auto_free(
			(load("res://src/escenas/objetos/%s.tscn" % escena) as PackedScene).instantiate()
		)
		assert_bool(otro.datos.id != llave.datos.id).is_true()
	assert_bool(llave.datos is UnidadDeProducto).is_false()
	assert_bool(llave.datos.es_levantable()).is_true()
	assert_bool(llave.is_in_group("interactuable")).is_true()
	var mallas := llave.find_children("*", "MeshInstance3D", true, false)
	assert_array(mallas).is_not_empty()
	for malla: MeshInstance3D in mallas:
		assert_int(malla.gi_mode).is_equal(GeometryInstance3D.GI_MODE_DYNAMIC)


func test_la_llave_queda_apoyada_en_el_piso_y_bajo_la_estanteria() -> void:  # AC-INV-185
	await _abrir(JORNADA_7, _por_la_6c())
	var llave := _llave()
	assert_object(llave).is_not_null()
	if llave == null:
		return
	for _cuadro: int in 90:
		await get_tree().physics_frame
	var mitad := ((llave.get_node("Forma") as CollisionShape3D).shape as BoxShape3D).size.y / 2.0
	var espacio := llave.get_world_3d().direct_space_state
	var centro := llave.global_position
	var arriba := PhysicsRayQueryParameters3D.create(centro, centro + Vector3.UP * 3.0)
	var abajo := PhysicsRayQueryParameters3D.create(centro, centro + Vector3.DOWN * 3.0)
	for consulta: PhysicsRayQueryParameters3D in [arriba, abajo]:
		consulta.exclude = [llave.get_rid()]
		consulta.collision_mask = llave.collision_mask
	var techo := espacio.intersect_ray(arriba)
	var piso := espacio.intersect_ray(abajo)
	assert_bool(techo.has("position")).is_true()
	assert_bool(piso.has("position")).is_true()
	if not (techo.has("position") and piso.has("position")):
		return
	assert_float((techo["position"] as Vector3).y).is_greater(centro.y + mitad)
	var separacion := centro.y - mitad - (piso["position"] as Vector3).y
	# Jolt deja que un cuerpo se hunda hasta su holgura de penetración sin empujarlo.
	var holgura: float = ProjectSettings.get_setting(
		"physics/jolt_physics_3d/simulation/penetration_slop", 0.02
	)
	assert_float(separacion).is_greater_equal(-holgura)
	assert_float(separacion).is_less(0.005)
	assert_float(llave.linear_velocity.length()).is_less(0.05)


func test_en_la_mano_la_llave_se_ve_de_frente_con_el_ojo_abajo() -> void:  # AC-INV-185
	await _abrir(JORNADA_7, _por_la_6c())
	var llave := _llave()
	var camara := (_almacen.get("_jugador") as CharacterBody3D).get("_camara") as Camera3D
	assert_bool(_agarre().pedir_agarrar(llave.datos, llave)).is_true()
	assert_bool(camara.is_ancestor_of(llave)).is_true()
	var malla := llave.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var tamano := malla.get_aabb().size
	var largo := 0
	var fino := 0
	for eje: int in 3:
		if tamano[eje] > tamano[largo]:
			largo = eje
		if tamano[eje] < tamano[fino]:
			fino = eje
	var arriba := camara.global_basis.y
	var derecha := camara.global_basis.x
	var adelante := -camara.global_basis.z
	var eje_largo := malla.global_basis[largo].normalized()
	var cara := malla.global_basis[fino].normalized()
	assert_float(absf(eje_largo.dot(arriba))).is_greater(absf(eje_largo.dot(derecha)))
	assert_float(absf(eje_largo.dot(arriba))).is_greater(absf(eje_largo.dot(adelante)))
	assert_float(absf(cara.dot(adelante))).is_greater(absf(cara.dot(arriba)))
	assert_float(absf(cara.dot(adelante))).is_greater(absf(cara.dot(derecha)))
	var ancho := _extremo_mas_ancho(malla, largo, fino)
	var punta := malla.global_basis[largo].normalized() * ancho
	assert_float(punta.dot(arriba)).is_less(0.0)
	var ojo := llave.get_node_or_null("Ojo") as Node3D
	assert_object(ojo).is_not_null()
	if ojo == null:
		return
	var centro := malla.global_transform * malla.get_aabb().get_center()
	assert_float((ojo.global_position - centro).dot(punta)).is_greater(0.0)


## Hacia qué lado del eje largo cae la punta más ancha: +1 o -1. Se mide sobre los vértices de la
## malla, porque el ojo es el aro y es lo más ancho de la llave.
func _extremo_mas_ancho(malla: MeshInstance3D, largo: int, fino: int) -> float:
	var ancho := 3 - largo - fino
	var centro := malla.get_aabb().get_center()[largo]
	var minimo := [INF, INF]
	var maximo := [-INF, -INF]
	for superficie: int in malla.mesh.get_surface_count():
		var vertices := (
			malla.mesh.surface_get_arrays(superficie)[Mesh.ARRAY_VERTEX] as PackedVector3Array
		)
		for vertice: Vector3 in vertices:
			var lado := 0 if vertice[largo] < centro else 1
			minimo[lado] = minf(minimo[lado], vertice[ancho])
			maximo[lado] = maxf(maximo[lado], vertice[ancho])
	return 1.0 if maximo[1] - minimo[1] > maximo[0] - minimo[0] else -1.0


func test_la_llave_usa_el_material_del_modelo_y_la_luz_la_alcanza() -> void:  # AC-INV-185
	var llave: ObjetoAgarrable = auto_free(ESCENA.instantiate())
	var mallas := llave.find_children("*", "MeshInstance3D", true, false)
	assert_array(mallas).is_not_empty()
	for malla: MeshInstance3D in mallas:
		assert_object(malla.material_override).is_null()
		assert_object(malla.mesh.surface_get_material(0)).is_not_null()


## El export empaqueta la escena otra vez. Un ajuste sobre el modelo instanciado que la escena no
## declara editable se pierde ahí, y en el juego exportado la llave queda con el GI estático:
## negra, sin sondas que la iluminen.
func test_el_gi_dinamico_de_la_llave_sobrevive_a_empaquetar_la_escena() -> void:  # AC-INV-185
	var original: Node = auto_free(ESCENA.instantiate())
	var empaquetada := PackedScene.new()
	assert_int(empaquetada.pack(original)).is_equal(OK)
	var llave: Node = auto_free(empaquetada.instantiate())
	var mallas := llave.find_children("*", "MeshInstance3D", true, false)
	assert_array(mallas).is_not_empty()
	for malla: MeshInstance3D in mallas:
		assert_object(malla.material_override).is_null()
		assert_int(malla.gi_mode).is_equal(GeometryInstance3D.GI_MODE_DYNAMIC)


func test_con_la_llave_en_la_mano_la_puerta_abre_y_termina_la_partida() -> void:  # AC-PLY-191
	await _abrir(JORNADA_7, _por_la_6c())
	var llave := _llave()
	assert_bool(_agarre().pedir_agarrar(llave.datos, llave)).is_true()
	var puerta := _puerta_del_jefe()
	var avisos := _contar_avisos(puerta)
	puerta.call("accionar")
	await _cuadros()
	assert_bool((puerta.call("puerta") as Puerta).abierta()).is_true()
	assert_int(avisos["abierta"]).is_equal(1)
	assert_int(avisos["trabada"]).is_zero()
	assert_int(_partida().final()).is_equal(Partida.Final.JEFE_INCOMPETENTE)
	assert_array(Array(_partida().expediente.identidades())).contains(["7C"])


func test_el_final_5_muestra_su_pantalla_y_borra_el_guardado() -> void:  # AC-SHF-113 AC-SAV-051
	# AC-SHF-136
	await _abrir(JORNADA_7, _por_la_6c())
	assert_bool(Guardado.new().hay_guardado()).is_true()
	var llave := _llave()
	assert_bool(_agarre().pedir_agarrar(llave.datos, llave)).is_true()
	_puerta_del_jefe().call("accionar")
	_puerta_del_jefe().call("accionar")
	await _cuadros()
	assert_int(AvanceDelEpilogo.cuantos(_almacen)).is_equal(1)
	assert_array(_almacen.find_children("*", "PantallaDeFinal", true, false)).is_empty()
	var esperadas := EpilogosDeLosFinales.placas_de(FinalConPantalla.Cual.JEFE_INCOMPETENTE)
	var vistas := AvanceDelEpilogo.recorrer(_almacen)
	assert_int(vistas.size()).is_equal(esperadas.size())
	for indice in range(esperadas.size()):
		assert_str(vistas[indice].texto).is_equal(esperadas[indice].texto)
	var pantallas := _almacen.find_children("*", "PantallaDeFinal", true, false)
	assert_int(pantallas.size()).is_equal(1)
	var pantalla := pantallas[0] as PantallaDeFinal
	assert_bool(pantalla.visible).is_true()
	assert_str(pantalla.encabezado()).is_equal(
		PantallaDeFinal.ENCABEZADOS[FinalConPantalla.Cual.JEFE_INCOMPETENTE]
	)
	assert_str(pantalla.titulo()).is_equal(
		PantallaDeFinal.TITULOS[FinalConPantalla.Cual.JEFE_INCOMPETENTE]
	)
	assert_bool(Guardado.new().hay_guardado()).is_false()


func test_el_final_5_se_anota_en_los_logros() -> void:  # AC-ACH-011
	await _abrir(JORNADA_7, _por_la_6c())
	var logros := _almacen.get("_logros") as Logros
	assert_bool(logros.final_alcanzado(Partida.Final.JEFE_INCOMPETENTE)).is_false()
	var llave := _llave()
	assert_bool(_agarre().pedir_agarrar(llave.datos, llave)).is_true()
	_puerta_del_jefe().call("accionar")
	await _cuadros()
	assert_bool(logros.final_alcanzado(Partida.Final.JEFE_INCOMPETENTE)).is_true()


func test_sin_la_llave_en_la_mano_la_puerta_sigue_trabada() -> void:  # AC-PLY-191 AC-SHF-112
	await _abrir(JORNADA_7, _por_la_6c())
	var llave := _llave()
	var balde := _almacen.get_node("Objetos/Balde") as ObjetoAgarrable
	var puerta := _puerta_del_jefe()
	var avisos := _contar_avisos(puerta)
	for en_la_mano: ObjetoAgarrable in [null, balde, llave]:
		_agarre().vaciar_las_manos()
		if en_la_mano != null and en_la_mano != llave:
			assert_bool(_agarre().pedir_agarrar(en_la_mano.datos, en_la_mano)).is_true()
		for _gesto: int in 3:
			puerta.call("accionar")
	assert_int(avisos["trabada"]).is_equal(9)
	assert_int(avisos["abierta"]).is_zero()
	assert_bool((puerta.call("puerta") as Puerta).abierta()).is_false()
	assert_int(_partida().final()).is_equal(Partida.Final.EN_CURSO)
	assert_bool(Guardado.new().hay_guardado()).is_true()


func test_la_llave_no_abre_otra_puerta_trabada() -> void:  # AC-PLY-191
	await _abrir(JORNADA_7, _por_la_6c())
	var llave := _llave()
	assert_bool(_agarre().pedir_agarrar(llave.datos, llave)).is_true()
	var porton := _almacen.get_node("Estructura/porton/CuerpoDeLaHoja")
	var avisos := _contar_avisos(porton)
	porton.call("accionar")
	assert_int(avisos["trabada"]).is_equal(1)
	assert_int(avisos["abierta"]).is_zero()
	assert_bool((porton.call("puerta") as Puerta).abierta()).is_false()
	assert_int(_partida().final()).is_equal(Partida.Final.EN_CURSO)


func test_el_secundario_y_el_control_suspendido_no_abren_la_puerta() -> void:  # AC-PLY-191
	await _abrir(JORNADA_7, _por_la_6c())
	var llave := _llave()
	var contexto: ReferenciaDeControles.Contexto = _puerta_del_jefe().call(
		"contexto_de_interaccion", llave.datos
	)
	var ruta := ReferenciaDeControles.Ruta
	assert_int(ReferenciaDeControles.ruta(true, contexto, false)).is_equal(ruta.ACCIONAR)
	assert_int(ReferenciaDeControles.ruta(false, contexto, false)).is_equal(ruta.IGNORAR)
	assert_int(ReferenciaDeControles.ruta(true, contexto, true)).is_equal(ruta.IGNORAR)
