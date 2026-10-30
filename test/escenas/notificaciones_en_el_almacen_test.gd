extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const RelojDePrueba := preload("res://test/reloj_de_prueba.gd")


func after_test() -> void:
	get_tree().paused = false


func _local(jornada: int = ReglasDeLaPartida.PRIMERA_JORNADA) -> Node3D:
	var local: Node3D = auto_free(ALMACEN.instantiate())
	local.set("_partida", Partida.desde({"jornada": jornada, "medios": 0}))
	add_child(local)
	local.get("_jugador").set_physics_process(false)
	local.get("_reloj").set_process(false)
	local.get_node("Interfaz/PilaDeNotificaciones").set_process(false)
	return local


func _textos(local: Node3D) -> Array[String]:
	var pila: PilaDeNotificaciones = local.get_node("Interfaz/PilaDeNotificaciones")
	var textos: Array[String] = []
	for label: Label in pila.find_children("*", "Label", true, false):
		textos.append(label.text.replace("\n", " "))
	return textos


# AC-NTF-001, AC-NTF-006, AC-NTF-012
func test_la_llegada_avisa_hasta_conversar_y_el_cierre_vacia() -> void:
	var local := _local()
	var ventanilla: Node3D = local.get_node("Estructura/Ventanilla")
	assert_bool(ventanilla.has_method("abrir")).is_true()
	ventanilla.accionar()
	assert_array(_textos(local)).is_empty()
	var reloj: RelojDelTurno = local.get("_reloj")
	RelojDePrueba.avanzar_hasta(reloj, Vector2i(22, 0))
	assert_array(_textos(local)).is_equal(["¡HAY UN CLIENTE!"])
	var panel: PanelDeLaVentanilla = local.get_node("Interfaz/PanelDeLaVentanilla")
	assert_bool(panel.visible).is_false()
	var pila: PilaDeNotificaciones = local.get_node("Interfaz/PilaDeNotificaciones")
	pila._process(2.0)
	ventanilla.cerrar()
	ventanilla.accionar()
	assert_array(_textos(local)).is_equal(["¡HAY UN CLIENTE!"])
	pila._process(20.0)
	assert_array(_textos(local)).is_equal(["¡HAY UN CLIENTE!"])
	ventanilla.get_node("Comprador/Objetivo").call("accionar")
	assert_array(_textos(local)).is_empty()
	var caja: CajaRegistradora = local.get_node("Servicios/CajaRegistradora")
	caja.lectura_rechazada.emit(GeneradorDeTickets.Resultado.LLENO)
	assert_array(_textos(local)).is_equal(["NO SE PUDO LEER"])
	RelojDePrueba.avanzar_turno(reloj, Reglas.DURACION_DEL_TURNO)
	assert_array(_textos(local)).is_empty()


func test_la_caja_publica_el_motivo_y_solo_lleno_avisa() -> void:  # AC-NTF-002
	var local := _local()
	var caja: CajaRegistradora = local.get_node("Servicios/CajaRegistradora")
	assert_object(caja.generador()).is_not_null()
	caja.lectura_rechazada.emit(GeneradorDeTickets.Resultado.NO_ES_PRODUCTO)
	assert_array(_textos(local)).is_empty()
	caja.lectura_rechazada.emit(GeneradorDeTickets.Resultado.ANOTADO)
	assert_array(_textos(local)).is_empty()
	caja.lectura_rechazada.emit(GeneradorDeTickets.Resultado.LLENO)
	assert_array(_textos(local)).is_equal(["NO SE PUDO LEER"])


func test_el_programa_manual_no_publica_rechazo_ni_aviso() -> void:  # AC-NTF-002
	var local := _local()
	var caja: CajaRegistradora = local.get_node("Servicios/CajaRegistradora")
	caja.arrancar(GeneradorDeTickets.para_la_jornada(GeneradorDeTickets.JORNADA_SIN_LECTOR))
	assert_bool(caja.generador().es_manual()).is_true()
	var rechazos: Array[GeneradorDeTickets.Resultado] = []
	caja.lectura_rechazada.connect(
		func(motivo: GeneradorDeTickets.Resultado) -> void: rechazos.append(motivo)
	)
	caja.pedir_anotar(UnidadDeProducto.new(Catalogo.de(Producto.Id.MAROLINI)))
	assert_array(rechazos).is_empty()
	assert_array(_textos(local)).is_empty()


func test_la_pila_se_dibuja_sobre_las_interfaces_y_debajo_de_pausa() -> void:  # AC-NTF-010
	# Esta desigualdad prueba sólo CanvasLayer. La nativa externa complementa AC-NTF-010
	# con PopupMenu real antes de Esc; luego pausa real y todas las listas cerradas (#303).
	var local := _local()
	var pila: PilaDeNotificaciones = local.get_node("Interfaz/PilaDeNotificaciones")
	var pausa: CanvasLayer = local.get_node("Interfaz/MenuDePausa")
	var dialogo: CanvasLayer = auto_free(
		load("res://src/ui/diegetica/capa_de_dialogo.tscn").instantiate()
	)
	assert_int(pila.layer).is_greater(dialogo.layer)
	for interfaz in local.get_node("Interfaz").get_children():
		if interfaz is CanvasLayer and interfaz != pila and interfaz != pausa:
			assert_int(pila.layer).is_greater(interfaz.layer)
	assert_int(pila.layer).is_less(pausa.layer)


func test_todas_las_noches_y_reloj_apagado() -> void:  # AC-NTF-020, AC-NTF-023
	var primera := ReglasDeLaPartida.PRIMERA_JORNADA
	for jornada in range(primera, primera + ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA):
		var local := _local(jornada)
		var reloj: RelojDelTurno = local.get("_reloj")
		var pila: PilaDeNotificaciones = local.get_node("Interfaz/PilaDeNotificaciones")
		RelojDePrueba.avanzar_turno(reloj, Reglas.DURACION_DEL_TURNO - 3601.0)
		assert_bool(_textos(local).has("QUEDA UNA HORA DE JORNADA")).is_false()
		if jornada == Reglas.JORNADA_EN_QUE_FALLA_EL_RELOJ:
			assert_str((local.get("_reloj_de_mesa") as Label3D).text).is_empty()
		RelojDePrueba.avanzar_turno(reloj, 1.0)
		assert_bool(_textos(local).has("QUEDA UNA HORA DE JORNADA")).is_true()
		pila._process(Notificaciones.DURACION)
		RelojDePrueba.avanzar_turno(reloj, 1.0)
		assert_bool(_textos(local).has("QUEDA UNA HORA DE JORNADA")).is_false()
		local.queue_free()
		await get_tree().process_frame


func test_salto_y_reinicio_real() -> void:  # AC-NTF-021, AC-NTF-022
	var jornada := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 3
	var local := _local(jornada)
	var reloj: RelojDelTurno = local.get("_reloj")
	RelojDePrueba.avanzar_turno(reloj, Reglas.DURACION_DEL_TURNO - 3660.0)
	assert_bool(_textos(local).has("QUEDA UNA HORA DE JORNADA")).is_false()
	RelojDePrueba.avanzar_turno(reloj, 120.0)
	assert_str(_textos(local)[0]).is_equal("QUEDA UNA HORA DE JORNADA")
	RelojDePrueba.avanzar_turno(reloj, Reglas.DURACION_DEL_TURNO)
	assert_array(_textos(local)).is_empty()
	RelojDePrueba.avanzar_turno(reloj, 1.0)
	assert_array(_textos(local)).is_empty()
	assert_int((local.get("_partida") as Partida).jornada()).is_equal(jornada + 1)
	assert_bool(local.get("_ciclo").abrir_la_jornada()).is_true()
	reloj.set_process(false)
	RelojDePrueba.avanzar_turno(reloj, Reglas.DURACION_DEL_TURNO - 3600.0)
	assert_str(_textos(local)[0]).is_equal("QUEDA UNA HORA DE JORNADA")


func test_saltar_directamente_hasta_cerrar_no_deja_cartel() -> void:  # AC-NTF-021, AC-NTF-022
	var local := _local(ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1)
	var reloj: RelojDelTurno = local.get("_reloj")
	RelojDePrueba.avanzar_turno(reloj, Reglas.DURACION_DEL_TURNO - 3660.0)
	assert_bool(_textos(local).has("QUEDA UNA HORA DE JORNADA")).is_false()
	RelojDePrueba.avanzar_turno(reloj, 3660.0)
	assert_array(_textos(local)).is_empty()


func test_pausar_antes_del_umbral_no_consume_ni_dispara() -> void:  # AC-NTF-023
	var local := _local(ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1)
	var reloj: RelojDelTurno = local.get("_reloj")
	var restantes: Array[float] = []
	reloj.tiempo_consumido.connect(func(restante: float) -> void: restantes.append(restante))
	RelojDePrueba.avanzar_turno(reloj, Reglas.DURACION_DEL_TURNO - 3601.0)
	var antes := restantes.duplicate()
	get_tree().paused = true
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(reloj.can_process()).is_false()
	assert_array(restantes).is_equal(antes)
	assert_bool(_textos(local).has("QUEDA UNA HORA DE JORNADA")).is_false()
	get_tree().paused = false
	RelojDePrueba.avanzar_turno(reloj, 1.0)
	assert_str(_textos(local)[0]).is_equal("QUEDA UNA HORA DE JORNADA")


func test_solo_la_pista_anotada_avisa_sin_renovar_por_otros_resultados() -> void:  # AC-NTF-014
	var jornada := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1
	var local := _local(jornada)
	var investigador: Investigador = local.get("_investigador")
	var balde: ObjetoAgarrable = local.get_node("Objetos/Balde")
	var examen: Examen = local.get("_jugador").examen
	examen.objeto_revelado.emit(balde.datos, true)
	(
		assert_int(investigador.pedir_pista(balde.datos.id, Pista.Canal.LEVANTAR, jornada, true))
		. is_equal(Expediente.Resultado.DESCONOCIDA)
	)
	assert_array(_textos(local)).is_empty()
	assert_int(investigador.pedir_pista(&"colilla", Pista.Canal.LEVANTAR, jornada, true)).is_equal(
		Expediente.Resultado.ANOTADA
	)
	assert_array(_textos(local)).is_equal(["¡NUEVA PISTA!"])
	var pila: PilaDeNotificaciones = local.get_node("Interfaz/PilaDeNotificaciones")
	pila._process(2.0)
	assert_int(investigador.pedir_pista(&"colilla", Pista.Canal.LEVANTAR, jornada, true)).is_equal(
		Expediente.Resultado.REPETIDA
	)
	(
		assert_int(investigador.pedir_pista(balde.datos.id, Pista.Canal.LEVANTAR, jornada, true))
		. is_equal(Expediente.Resultado.DESCONOCIDA)
	)
	pila._process(0.9)
	assert_array(_textos(local)).is_equal(["¡NUEVA PISTA!"])
	pila._process(0.1)
	assert_array(_textos(local)).is_empty()
	assert_int(investigador.pedir_pista(&"colilla", Pista.Canal.LEVANTAR, jornada, true)).is_equal(
		Expediente.Resultado.REPETIDA
	)
	assert_array(_textos(local)).is_empty()


func test_cerrar_retira_la_pista_y_reabrir_no_la_recupera() -> void:  # AC-NTF-016
	var jornada := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1
	var local := _local(jornada)
	var investigador: Investigador = local.get("_investigador")
	assert_int(investigador.pedir_pista(&"colilla", Pista.Canal.LEVANTAR, jornada, true)).is_equal(
		Expediente.Resultado.ANOTADA
	)
	assert_array(_textos(local)).is_equal(["¡NUEVA PISTA!"])
	var reloj: RelojDelTurno = local.get("_reloj")
	RelojDePrueba.avanzar_turno(reloj, Reglas.DURACION_DEL_TURNO)
	assert_array(_textos(local)).is_empty()
	assert_bool(local.get("_ciclo").abrir_la_jornada()).is_true()
	assert_array(_textos(local)).is_empty()
