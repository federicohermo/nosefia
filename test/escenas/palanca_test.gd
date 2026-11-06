extends GdUnitTestSuite

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
	Guardado.ruta_por_defecto = "user://palanca_790_prueba.guardado"
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


func _por_la_6b() -> Dictionary:
	return {CUARTA: "2A", JORNADA_5: "5A", JORNADA_6: "6B"}


func _partida() -> Partida:
	return _almacen.get("_partida") as Partida


func _palanca() -> ObjetoAgarrable:
	return _almacen.get_node_or_null("Objetos/Palanca") as ObjetoAgarrable


func _puerta_del_jefe() -> Node:
	return _almacen.get_node("Estructura/puertajefe/CuerpoDeLaHoja")


func _agarre() -> Agarre:
	return _almacen.get("_agarre") as Agarre


func _la_mira_lo_encuentra(objeto: ObjetoAgarrable) -> bool:
	var jugador := _almacen.get("_jugador") as CharacterBody3D
	var camara: Camera3D = jugador.get("_camara")
	jugador.call(
		"ubicar", Transform3D(Basis.IDENTITY, objeto.global_position + Vector3(0.0, 0.55, 0.45))
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


## Cuántos avisos da la puerta de cada clase mientras se la acciona.
func _contar_avisos(puerta: Node) -> Dictionary:
	var avisos := {"abierta": 0, "trabada": 0}
	puerta.connect("puerta_abierta", func(_p: Node3D) -> void: avisos["abierta"] += 1)
	puerta.connect("puerta_forzada_con_palanca", func(_p: Node3D) -> void: avisos["abierta"] += 1)
	puerta.connect("puerta_trabada", func(_p: Node3D) -> void: avisos["trabada"] += 1)
	puerta.connect("porton_trabado", func(_p: Node3D) -> void: avisos["trabada"] += 1)
	return avisos


func test_la_palanca_se_ve_se_enfoca_y_se_levanta_con_la_6b_elegida() -> void:  # AC-INV-177
	await _abrir(JORNADA_7, _por_la_6b())
	var palanca := _palanca()
	assert_object(palanca).is_not_null()
	if palanca == null:
		return
	assert_bool(palanca.is_visible_in_tree()).is_true()
	assert_bool(await _la_mira_lo_encuentra(palanca)).is_true()
	assert_bool(_agarre().pedir_agarrar(palanca.datos, palanca)).is_true()
	assert_object(_agarre().cuerpo_sostenido()).is_same(palanca)


func test_con_otra_eleccion_u_otra_jornada_la_palanca_no_esta() -> void:  # AC-INV-177
	var por_la_6c := {CUARTA: "2A", JORNADA_5: "5B", JORNADA_6: "6C"}
	var casos: Array[Array] = [
		[JORNADA_6, {CUARTA: "2A", JORNADA_5: "5A"}],
		[JORNADA_7, por_la_6c],
		[JORNADA_7, {CUARTA: "2A", JORNADA_5: "5A"}],
		[JORNADA_7, {}],
	]
	for caso: Array in casos:
		await _abrir(caso[0], caso[1])
		var palanca := _palanca()
		assert_object(palanca).is_not_null()
		if palanca == null:
			return
		var mensaje := "jornada %d, elecciones %s" % [caso[0], caso[1]]
		assert_bool(palanca.is_visible_in_tree()).override_failure_message(mensaje).is_false()
		assert_int(palanca.collision_layer).override_failure_message(mensaje).is_zero()
		assert_int(palanca.collision_mask).is_zero()
		assert_int(palanca.process_mode).is_equal(Node.PROCESS_MODE_DISABLED)
		(
			assert_bool(await _la_mira_lo_encuentra(palanca))
			. override_failure_message(mensaje)
			. is_false()
		)
		await _cerrar_almacen()


func test_levantar_y_soltar_la_palanca_no_registra_ni_avisa() -> void:  # AC-INV-178
	await _abrir(JORNADA_7, _por_la_6b())
	var palanca := _palanca()
	assert_object(palanca).is_not_null()
	if palanca == null:
		return
	var nuevas: Array[Pista] = []
	(_almacen.get_node("Servicios/Investigador") as Investigador).pista_nueva.connect(
		func(pista: Pista) -> void: nuevas.append(pista)
	)
	var identidades := _partida().expediente.identidades()
	var notas := _partida().expediente.mensajes_de_notas().size()
	assert_bool(_agarre().pedir_agarrar(palanca.datos, palanca)).is_true()
	_agarre().soltar(false)
	await _cuadros()
	assert_bool(_agarre().pedir_agarrar(palanca.datos, palanca)).is_true()
	assert_array(Array(_partida().expediente.identidades())).is_equal(Array(identidades))
	assert_int(_partida().expediente.mensajes_de_notas().size()).is_equal(notas)
	assert_array(nuevas).is_empty()
	assert_int(_partida().final()).is_equal(Partida.Final.EN_CURSO)


func test_la_palanca_es_un_objeto_propio_con_su_licencia() -> void:  # AC-INV-177
	var palanca: ObjetoAgarrable = auto_free(
		(load("res://src/escenas/objetos/palanca.tscn") as PackedScene).instantiate()
	)
	var otros: Array[String] = ["colilla", "nota_bajo_la_puerta", "documento_impreso"]
	for escena: String in otros:
		var otro: ObjetoAgarrable = auto_free(
			(load("res://src/escenas/objetos/%s.tscn" % escena) as PackedScene).instantiate()
		)
		assert_bool(otro.datos.id != palanca.datos.id).is_true()
	assert_bool(palanca.datos is UnidadDeProducto).is_false()
	assert_bool(palanca.datos.es_levantable()).is_true()
	assert_bool(palanca.is_in_group("interactuable")).is_true()
	var mallas := palanca.find_children("*", "MeshInstance3D", true, false)
	assert_array(mallas).is_not_empty()
	for malla: MeshInstance3D in mallas:
		assert_int(malla.gi_mode).is_equal(GeometryInstance3D.GI_MODE_DYNAMIC)
	(
		assert_bool(FileAccess.file_exists("res://assets/models/Crowbar/psx_crowbar/license.txt"))
		. is_true()
	)


func test_con_la_palanca_en_la_mano_la_puerta_abre_y_termina_la_partida() -> void:  # AC-PLY-190
	await _abrir(JORNADA_7, _por_la_6b())
	var palanca := _palanca()
	assert_bool(_agarre().pedir_agarrar(palanca.datos, palanca)).is_true()
	var puerta := _puerta_del_jefe()
	var avisos := _contar_avisos(puerta)
	puerta.call("accionar")
	await _cuadros()
	assert_bool((puerta.call("puerta") as Puerta).abierta()).is_true()
	assert_int(avisos["abierta"]).is_equal(1)
	assert_int(avisos["trabada"]).is_zero()
	assert_int(_partida().final()).is_equal(Partida.Final.JEFE_SABOTEADOR)
	assert_array(Array(_partida().expediente.identidades())).contains(["7B"])


func test_el_final_4_muestra_su_pantalla_y_borra_el_guardado() -> void:  # AC-SHF-111 AC-SAV-050
	# AC-SHF-137: sus placas no tienen texto, así que no hay epílogo ni fundido antes.
	await _abrir(JORNADA_7, _por_la_6b())
	assert_bool(Guardado.new().hay_guardado()).is_true()
	var palanca := _palanca()
	assert_bool(_agarre().pedir_agarrar(palanca.datos, palanca)).is_true()
	_puerta_del_jefe().call("accionar")
	_puerta_del_jefe().call("accionar")
	await _cuadros()
	assert_array(_almacen.find_children("*", "PantallaDeEpilogo", true, false)).is_empty()
	var pantallas := _almacen.find_children("*", "PantallaDeFinal", true, false)
	assert_int(pantallas.size()).is_equal(1)
	var pantalla := pantallas[0] as PantallaDeFinal
	assert_bool(pantalla.visible).is_true()
	assert_str(pantalla.encabezado()).is_equal(
		PantallaDeFinal.ENCABEZADOS[FinalConPantalla.Cual.JEFE_SABOTEADOR]
	)
	assert_str(pantalla.titulo()).is_equal(
		PantallaDeFinal.TITULOS[FinalConPantalla.Cual.JEFE_SABOTEADOR]
	)
	assert_bool(Guardado.new().hay_guardado()).is_false()


func test_con_la_pantalla_del_final_4_ni_pausa_ni_icono_del_celular() -> void:
	await _abrir(JORNADA_7, _por_la_6b())
	var recordatorio: Control = _almacen.get("_pantalla_del_celular").get("_recordatorio")
	assert_bool(recordatorio.is_visible_in_tree()).is_true()
	var palanca := _palanca()
	assert_bool(_agarre().pedir_agarrar(palanca.datos, palanca)).is_true()
	_puerta_del_jefe().call("accionar")
	await _cuadros()
	var pantallas := _almacen.find_children("*", "PantallaDeFinal", true, false)
	assert_bool((pantallas[0] as PantallaDeFinal).visible).is_true()
	assert_bool(recordatorio.is_visible_in_tree()).is_false()
	var pausa := _almacen.get_node("Interfaz/ControlDePausa") as ControlDePausa
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	pausa._input(esc)
	pausa.set("_cursor_antes", true)
	pausa.call("_mirar_el_cursor")
	assert_bool(get_tree().paused).is_false()


func test_el_final_4_se_anota_en_los_logros() -> void:  # AC-ACH-011
	await _abrir(JORNADA_7, _por_la_6b())
	var logros := _almacen.get("_logros") as Logros
	assert_bool(logros.final_alcanzado(Partida.Final.JEFE_SABOTEADOR)).is_false()
	var palanca := _palanca()
	assert_bool(_agarre().pedir_agarrar(palanca.datos, palanca)).is_true()
	_puerta_del_jefe().call("accionar")
	await _cuadros()
	assert_bool(logros.final_alcanzado(Partida.Final.JEFE_SABOTEADOR)).is_true()


func test_el_final_4_sin_medios_gana_empleado_ejemplar() -> void:  # AC-ACH-006
	await _abrir(JORNADA_7, _por_la_6b())
	var logros := _almacen.get("_logros") as Logros
	assert_int(_partida().legajo().medios()).is_zero()
	assert_bool(logros.desbloqueado(Logros.Logro.EMPLEADO_EJEMPLAR)).is_false()
	var palanca := _palanca()
	assert_bool(_agarre().pedir_agarrar(palanca.datos, palanca)).is_true()
	_puerta_del_jefe().call("accionar")
	await _cuadros()
	assert_bool(logros.desbloqueado(Logros.Logro.EMPLEADO_EJEMPLAR)).is_true()


func test_sin_la_palanca_en_la_mano_la_puerta_sigue_trabada() -> void:  # AC-PLY-190 AC-SHF-110
	await _abrir(JORNADA_7, _por_la_6b())
	var palanca := _palanca()
	var balde := _almacen.get_node("Objetos/Balde") as ObjetoAgarrable
	var puerta := _puerta_del_jefe()
	var avisos := _contar_avisos(puerta)
	for en_la_mano: ObjetoAgarrable in [null, balde, palanca]:
		_agarre().vaciar_las_manos()
		if en_la_mano != null and en_la_mano != palanca:
			assert_bool(_agarre().pedir_agarrar(en_la_mano.datos, en_la_mano)).is_true()
		for _gesto: int in 3:
			puerta.call("accionar")
	assert_int(avisos["trabada"]).is_equal(9)
	assert_int(avisos["abierta"]).is_zero()
	assert_bool((puerta.call("puerta") as Puerta).abierta()).is_false()
	assert_int(_partida().final()).is_equal(Partida.Final.EN_CURSO)
	assert_bool(Guardado.new().hay_guardado()).is_true()


func test_la_palanca_no_abre_otra_puerta_trabada() -> void:  # AC-PLY-190
	await _abrir(JORNADA_7, _por_la_6b())
	var palanca := _palanca()
	assert_bool(_agarre().pedir_agarrar(palanca.datos, palanca)).is_true()
	var porton := _almacen.get_node("Estructura/porton/CuerpoDeLaHoja")
	var avisos := _contar_avisos(porton)
	porton.call("accionar")
	assert_int(avisos["trabada"]).is_equal(1)
	assert_int(avisos["abierta"]).is_zero()
	assert_bool((porton.call("puerta") as Puerta).abierta()).is_false()
	assert_int(_partida().final()).is_equal(Partida.Final.EN_CURSO)


func test_el_secundario_y_el_control_suspendido_no_abren_la_puerta() -> void:  # AC-PLY-190
	await _abrir(JORNADA_7, _por_la_6b())
	var palanca := _palanca()
	var contexto: ReferenciaDeControles.Contexto = _puerta_del_jefe().call(
		"contexto_de_interaccion", palanca.datos
	)
	var ruta := ReferenciaDeControles.Ruta
	assert_int(ReferenciaDeControles.ruta(true, contexto, false)).is_equal(ruta.ACCIONAR)
	assert_int(ReferenciaDeControles.ruta(false, contexto, false)).is_equal(ruta.IGNORAR)
	assert_int(ReferenciaDeControles.ruta(true, contexto, true)).is_equal(ruta.IGNORAR)
