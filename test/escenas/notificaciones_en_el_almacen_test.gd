extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")


func _local() -> Node3D:
	var local: Node3D = auto_free(ALMACEN.instantiate())
	local.set("_partida", Partida.nueva())
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
	ventanilla.abrir()
	assert_array(_textos(local)).is_empty()
	var reloj: RelojDelTurno = local.get("_reloj")
	reloj.avanzar(120.0)
	assert_array(_textos(local)).is_equal(["¡HAY UN CLIENTE!"])
	var panel: PanelDeLaVentanilla = local.get_node("Interfaz/PanelDeLaVentanilla")
	assert_bool(panel.visible).is_true()
	var pila: PilaDeNotificaciones = local.get_node("Interfaz/PilaDeNotificaciones")
	pila._process(2.0)
	ventanilla.cerrar()
	ventanilla.abrir()
	assert_array(_textos(local)).is_equal(["¡HAY UN CLIENTE!"])
	pila._process(20.0)
	assert_array(_textos(local)).is_equal(["¡HAY UN CLIENTE!"])
	panel.comprador_pulsado.emit()
	assert_array(_textos(local)).is_empty()
	var caja: CajaRegistradora = local.get_node("Servicios/CajaRegistradora")
	caja.lectura_rechazada.emit(GeneradorDeTickets.Resultado.LLENO)
	assert_array(_textos(local)).is_equal(["NO SE PUDO LEER"])
	reloj.avanzar(Reglas.DURACION_DEL_TURNO / Ritmo.SEGUNDOS_DE_TURNO_POR_SEGUNDO_REAL)
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
	caja.arrancar(GeneradorDeTickets.para_la_jornada(3))
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
