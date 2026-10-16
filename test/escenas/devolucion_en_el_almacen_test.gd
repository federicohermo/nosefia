## La devolución de Enrique en el almacén: baja la persiana, sube el celular fijo en su chat, los
## mensajes llegan de a uno por segundo, y la opción despacha una sola vez. La pausa se abre por
## encima y congela el tiempo de la devolución.
extends GdUnitTestSuite

const AvanceDeDevolucion := preload("res://test/avance_de_devolucion.gd")

const ESCENA_DEL_ALMACEN := "res://src/escenas/almacen.tscn"
const SEGUNDOS_REALES_DE_UN_TURNO := (
	Reglas.DURACION_DEL_TURNO / Ritmo.SEGUNDOS_DE_TURNO_POR_SEGUNDO_REAL
)
const JEFE := Conversacion.Interlocutor.JEFE

var _ruta_guardado: String


func before_test() -> void:
	_ruta_guardado = Guardado.ruta_por_defecto
	Guardado.ruta_por_defecto = "user://devolucion_430.guardado"
	Guardado.new().borrar()


func after_test() -> void:
	get_tree().paused = false
	Guardado.new().borrar()
	Guardado.ruta_por_defecto = _ruta_guardado


func _almacen(partida: Partida = null) -> Node3D:
	var almacen: Node3D = auto_free(load(ESCENA_DEL_ALMACEN).instantiate())
	if partida != null:
		almacen.set("_partida", partida)
	add_child(almacen)
	await get_tree().process_frame
	return almacen


func _cerrar(almacen: Node3D) -> PantallaDeDevolucion:
	(almacen.get_node("Servicios/RelojDelTurno") as RelojDelTurno).avanzar(
		SEGUNDOS_REALES_DE_UN_TURNO
	)
	await get_tree().process_frame
	var pantalla: PantallaDeDevolucion = almacen.get("_pantalla")
	AvanceDeDevolucion.centrar_celular(pantalla)
	return pantalla


func _celular(almacen: Node3D) -> CelularDelEmpleado:
	return almacen.get_node("Interfaz/CelularDelEmpleado")


func _pantalla_del_celular(almacen: Node3D) -> PantallaDelCelular:
	return almacen.get_node("Interfaz/PantallaDelCelular")


func _esc() -> InputEventAction:
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	return esc


func _q() -> InputEventAction:
	var q := InputEventAction.new()
	q.action = Celular.ACCION
	q.pressed = true
	return q


## Los últimos `cuantos` textos del chat de Enrique: las devoluciones van al final.
func _ultimos_del_chat(almacen: Node3D, cuantos: int) -> PackedStringArray:
	var textos := PackedStringArray()
	var mensajes := _celular(almacen).bandeja().mensajes_de(JEFE)
	for indice: int in range(maxi(0, mensajes.size() - cuantos), mensajes.size()):
		textos.append(mensajes[indice].texto)
	return textos


func test_al_cerrar_baja_la_persiana_y_sube_el_celular_fijo() -> void:  # AC-EMP-064
	var almacen: Node3D = await _almacen()
	var pantalla := await _cerrar(almacen)
	var persiana: PersianaDeLaNoche = almacen.get_node("Interfaz/PersianaDeLaNoche")
	assert_bool(persiana.en_pantalla()).is_true()
	assert_bool(pantalla.visible).is_true()
	assert_bool(_celular(almacen).celular().abierto()).is_true()
	assert_bool(_celular(almacen).celular().fijo()).is_true()
	assert_int(_celular(almacen).celular().chat()).is_equal(JEFE)
	(
		assert_bool((almacen.get_node("Servicios/RelojDelTurno") as RelojDelTurno).corriendo())
		. is_false()
	)
	assert_bool((almacen.get_node("Jugador") as Node).call("suspendido")).is_true()
	assert_int(pantalla.a_la_vista()).is_equal(1)
	assert_int((almacen.get("_partida") as Partida).jornada()).is_equal(2)
	var lista: VBoxContainer = _pantalla_del_celular(almacen).get("_mensajes")
	var separadores := lista.get_children().filter(func(hijo: Node) -> bool: return hijo is Label)
	assert_int(separadores.size()).is_equal(1)
	assert_str((separadores[0] as Label).text).is_equal("HOY")


func test_un_mensaje_por_segundo_y_la_opcion_al_final() -> void:  # AC-EMP-062
	var almacen: Node3D = await _almacen()
	var pantalla := await _cerrar(almacen)
	var partida: Partida = almacen.get("_partida")
	var total := partida.mensajes_del_jefe().size()
	assert_int(total).is_greater(2)
	for paso: int in range(1, total):
		assert_int(pantalla.a_la_vista()).is_equal(paso)
		assert_object(_pantalla_del_celular(almacen).opcion()).is_null()
		pantalla.call("_process", 1.0)
	assert_int(pantalla.a_la_vista()).is_equal(total)
	var opcion := _pantalla_del_celular(almacen).opcion()
	assert_object(opcion).is_not_null()
	assert_str(opcion.text).is_equal("CONTINUAR")
	var lista: VBoxContainer = _pantalla_del_celular(almacen).get("_mensajes")
	assert_object(lista.get_child(lista.get_child_count() - 1)).is_same(opcion)


func test_un_cuadro_largo_no_entrega_la_devolucion_de_golpe() -> void:  # AC-EMP-062
	var almacen: Node3D = await _almacen()
	var pantalla := await _cerrar(almacen)
	assert_int(pantalla.a_la_vista()).is_equal(1)
	pantalla.call("_process", 5.0)
	assert_int(pantalla.a_la_vista()).is_equal(2)
	assert_bool(pantalla.opcion_a_la_vista()).is_false()
	pantalla.call("_process", 0.99)
	assert_int(pantalla.a_la_vista()).is_equal(2)
	pantalla.call("_process", 0.01)
	assert_int(pantalla.a_la_vista()).is_equal(3)


func test_los_intervalos_esperan_al_celular_en_el_centro() -> void:  # AC-EMP-062
	var almacen: Node3D = await _almacen()
	(almacen.get("_reloj") as RelojDelTurno).avanzar(SEGUNDOS_REALES_DE_UN_TURNO)
	var pantalla: PantallaDeDevolucion = almacen.get("_pantalla")
	assert_bool(_pantalla_del_celular(almacen).centrado()).is_false()
	pantalla.call("_process", 5.0)
	assert_int(pantalla.a_la_vista()).is_equal(1)
	AvanceDeDevolucion.centrar_celular(pantalla)
	pantalla.call("_process", 0.99)
	assert_int(pantalla.a_la_vista()).is_equal(1)
	pantalla.call("_process", 0.01)
	assert_int(pantalla.a_la_vista()).is_equal(2)


func test_q_no_cierra_y_la_pausa_congela_la_devolucion() -> void:  # AC-EMP-063, AC-SAV-018
	var almacen: Node3D = await _almacen()
	var pantalla := await _cerrar(almacen)
	pantalla.call("_process", 1.0)
	assert_int(pantalla.a_la_vista()).is_equal(2)
	almacen.call("_unhandled_input", _q())
	assert_bool(_celular(almacen).celular().abierto()).is_true()
	assert_int(_celular(almacen).celular().chat()).is_equal(JEFE)
	var pausa: ControlDePausa = almacen.get_node("Interfaz/ControlDePausa")
	var menu: MenuDePausa = almacen.get_node("Interfaz/MenuDePausa")
	pausa._input(_esc())
	assert_bool(get_tree().paused).is_true()
	assert_bool(menu.visible).is_true()
	assert_int(menu.layer).is_greater(_pantalla_del_celular(almacen).layer)
	assert_bool(pantalla.can_process()).is_false()
	pausa._input(_esc())
	assert_bool(get_tree().paused).is_false()
	assert_bool(pantalla.visible).is_true()
	assert_int(pantalla.a_la_vista()).is_equal(2)
	pantalla.call("_process", 1.0)
	assert_int(pantalla.a_la_vista()).is_equal(3)
	var partida: Partida = almacen.get("_partida")
	AvanceDeDevolucion.entregar(pantalla)
	assert_array(_ultimos_del_chat(almacen, partida.mensajes_del_jefe().size())).is_equal(
		partida.mensajes_del_jefe()
	)


func test_continuar_dos_veces_abre_una_sola_noche_2() -> void:  # AC-EMP-064, AC-EMP-065
	var almacen: Node3D = await _almacen()
	var pantalla := await _cerrar(almacen)
	var interfaz := _pantalla_del_celular(almacen)
	var ahora := [0]
	interfaz.set("_ahora", func() -> int: return ahora[0])
	interfaz.subir()
	AvanceDeDevolucion.animar_celular(
		interfaz, ahora, int(PantallaDelCelular.RECORRIDO_COMPLETO * 1000000.0)
	)
	var aperturas := [0]
	(almacen.get_node("Servicios/CicloDeJornadas") as CicloDeJornadas).jornada_abierta.connect(
		func(_jornada: int) -> void: aperturas[0] += 1
	)
	pantalla.elegir()
	assert_int(aperturas[0]).is_zero()
	AvanceDeDevolucion.entregar(pantalla)
	pantalla.elegir()
	pantalla.elegir()
	assert_int(aperturas[0]).is_zero()
	assert_bool((almacen.get("_jugador") as Node).call("suspendido")).is_true()
	AvanceDeDevolucion.animar_celular(
		interfaz, ahora, int(PantallaDelCelular.RECORRIDO_COMPLETO * 1000000.0) - 1000
	)
	assert_int(aperturas[0]).is_zero()
	ahora[0] += 1000
	interfaz._process(0.0)
	assert_int(aperturas[0]).is_equal(1)
	assert_bool(pantalla.visible).is_false()
	assert_bool(_celular(almacen).celular().abierto()).is_false()
	var persiana: PersianaDeLaNoche = almacen.get_node("Interfaz/PersianaDeLaNoche")
	assert_str((persiana.get("_placa") as Label).text).is_equal("NOCHE 2")
	var partida: Partida = almacen.get("_partida")
	assert_int(partida.jornada()).is_equal(2)
	persiana.terminar()
	var historial := _celular(almacen).bandeja().mensajes_de(JEFE)
	var devolucion := PackedStringArray()
	for indice: int in range(19, 19 + partida.mensajes_del_jefe().size()):
		devolucion.append(historial[indice].texto)
	assert_array(devolucion).is_equal(partida.mensajes_del_jefe())
	assert_str(historial[-2].identidad).is_equal("J2_CONTENEDOR_FOTO")
	assert_str(historial[-1].identidad).is_equal("J2_CONTENEDOR_TEXTO")


func test_despedido_vuelve_al_menu_una_sola_vez() -> void:  # AC-EMP-064, AC-EMP-065, AC-EMP-016
	var almacen: Node3D = await _almacen(
		Partida.new(Legajo.con_medios(3 * Reglas.MEDIOS_POR_APERCIBIMIENTO))
	)
	var menus := [0]
	almacen.set("_ir_al_menu", func() -> void: menus[0] += 1)
	var pantalla := await _cerrar(almacen)
	AvanceDeDevolucion.entregar(pantalla)
	assert_str(_pantalla_del_celular(almacen).opcion().text).is_equal("VOLVER AL MENÚ")
	pantalla.elegir()
	pantalla.elegir()
	assert_int(menus[0]).is_equal(1)
	var persiana: PersianaDeLaNoche = almacen.get_node("Interfaz/PersianaDeLaNoche")
	assert_bool(persiana.en_pantalla()).is_false()


func test_volver_al_menu_desde_la_pausa_conserva_el_guardado() -> void:  # AC-SAV-020
	var almacen: Node3D = await _almacen()
	var menus := [0]
	almacen.set("_ir_al_menu", func() -> void: menus[0] += 1)
	var pantalla := await _cerrar(almacen)
	var guardado := FileAccess.get_file_as_string(Guardado.ruta_por_defecto)
	assert_str(guardado).is_not_empty()
	var pausa: ControlDePausa = almacen.get_node("Interfaz/ControlDePausa")
	var menu: MenuDePausa = almacen.get_node("Interfaz/MenuDePausa")
	pausa._input(_esc())
	assert_bool(pantalla.visible).is_true()
	var volver: Button = menu.get_node("Fondo/Panel/Opciones/VolverAlMenu")
	volver.pressed.emit()
	volver.pressed.emit()
	assert_int(menus[0]).is_equal(1)
	assert_str(FileAccess.get_file_as_string(Guardado.ruta_por_defecto)).is_equal(guardado)
	var retomada := Partida.desde(Guardado.new().cargar())
	assert_int(retomada.jornada()).is_equal(2)
	assert_array(retomada.mensajes_del_jefe()).is_equal(
		(almacen.get("_partida") as Partida).mensajes_del_jefe()
	)


func test_retomar_trae_las_devoluciones() -> void:  # AC-INV-037, AC-SAV-024, AC-EMP-066
	var devoluciones := ["Buenas", "Que no se repita, ok?", "Hola", "Sin comentarios."]
	var datos := {
		PartidaSerializada.clave(PartidaSerializada.Campo.JORNADA): 3,
		PartidaSerializada.clave(PartidaSerializada.Campo.MEDIOS): 4,
		PartidaSerializada.clave(PartidaSerializada.Campo.DEVOLUCIONES): devoluciones,
	}
	var almacen: Node3D = await _almacen(Partida.desde(datos))
	var bandeja := _celular(almacen).bandeja()
	var guion := 0
	for mensaje: Mensaje in Conversacion.de(JEFE).mensajes:
		if mensaje.jornada <= 3:
			guion += 1
	assert_int(bandeja.mensajes_de(JEFE).size()).is_equal(guion + devoluciones.size())
	assert_array(_ultimos_del_chat(almacen, devoluciones.size())).is_equal(
		PackedStringArray(devoluciones)
	)
	assert_int(bandeja.no_leidos(JEFE)).is_equal(bandeja.mensajes_de(JEFE).size())


func test_recibir_con_una_foto_abierta_conserva_foto_e_historial() -> void:  # AC-EMP-063
	var almacen: Node3D = await _almacen()
	var pantalla := await _cerrar(almacen)
	var celular := _celular(almacen)
	var interfaz := _pantalla_del_celular(almacen)
	var mensajes := celular.bandeja().mensajes_de(JEFE)
	var foto := -1
	for indice: int in mensajes.size():
		if mensajes[indice].foto != null:
			foto = indice
			break
	assert_int(foto).is_greater_equal(0)
	for cuadro: int in 4:
		await get_tree().process_frame
	var scroll: ScrollContainer = interfaz.get("_scroll")
	scroll.scroll_vertical = 100
	assert_int(scroll.scroll_vertical).is_equal(100)
	celular.pedir_foto(foto)
	assert_int(celular.celular().pantalla()).is_equal(Celular.Pantalla.FOTO)
	var ampliada: Control = interfaz.get("_foto_ampliada")
	assert_bool(ampliada.visible).is_true()
	AvanceDeDevolucion.entregar(pantalla)
	for cuadro: int in 4:
		await get_tree().process_frame
	assert_bool(ampliada.visible).is_true()
	assert_int(scroll.scroll_vertical).is_equal(100)
	celular.pedir_cerrar_foto()
	assert_bool(ampliada.visible).is_false()
	var lista: VBoxContainer = interfaz.get("_mensajes")
	var textos := PackedStringArray()
	for etiqueta: Node in lista.find_children("*", "RichTextLabel", true, false):
		textos.append((etiqueta as RichTextLabel).text)
	var partida: Partida = almacen.get("_partida")
	assert_array(textos.slice(textos.size() - partida.mensajes_del_jefe().size())).is_equal(
		partida.mensajes_del_jefe()
	)
	assert_object(lista.get_child(lista.get_child_count() - 1)).is_same(interfaz.opcion())
