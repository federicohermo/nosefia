## «Nuevo juego» con un guardado previo: el almacén que se calentó debajo del menú leyó la partida
## vieja y no sirve, pero la carga no vuelve a calentar el local.
extends GdUnitTestSuite

const ESCENA_DEL_MENU := "res://src/escenas/menu_de_inicio.tscn"
const DOBLE := preload("res://test/escenas/doble_del_almacen.gd")

var _ruta: String
var _ruta_anterior: String


func before_test() -> void:
	_ruta = create_temp_dir("nuevo_con_guardado").path_join("partida.guardado")
	_ruta_anterior = Guardado.ruta_por_defecto
	Guardado.ruta_por_defecto = _ruta


func after_test() -> void:
	Guardado.ruta_por_defecto = _ruta_anterior


func _paquete_del_doble() -> PackedScene:
	var doble: Node3D = DOBLE.new()
	var paquete := PackedScene.new()
	assert_int(paquete.pack(doble)).is_equal(OK)
	doble.free()
	return paquete


## Un menú con la copia ya calentada, hecha con la partida del guardado.
func _menu_con_la_copia(jornada: int) -> Control:
	Guardado.new().escribir(PartidaSerializada.sanear({"jornada": jornada}))
	var menu: Control = auto_free(load(ESCENA_DEL_MENU).instantiate())
	add_child(menu)
	menu.set_process(false)
	menu.set("_almacen", _paquete_del_doble())
	menu.call("_calentar_debajo_del_menu")
	auto_free(menu.get("_copia"))
	menu.call("_al_calentar_debajo_del_menu")
	return menu


func _elegir_nuevo_juego(menu: Control) -> void:
	var pedidos: PedidosDelMenu = menu.find_children("*", "PedidosDelMenu", true, false)[0]
	pedidos.elegir(MenuDeInicio.Opcion.NUEVO_JUEGO)


func test_la_copia_calentada_de_un_guardado_no_sirve_para_un_nuevo_juego() -> void:
	var menu := _menu_con_la_copia(ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1)
	_elegir_nuevo_juego(menu)
	assert_int(menu.call("_camino_de_la_entrada")).is_equal(
		EntradaAlAlmacen.Camino.UN_ALMACEN_NUEVO
	)


func test_el_almacen_nuevo_arranca_sin_nada_del_guardado_viejo() -> void:
	var jornada_guardada := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1
	var menu := _menu_con_la_copia(jornada_guardada)
	var copia: Node3D = menu.get("_copia")
	assert_int(copia.get("partida").jornada()).is_equal(jornada_guardada)
	_elegir_nuevo_juego(menu)
	var nuevo: Node3D = auto_free(menu.call("_instanciar_un_almacen_nuevo"))
	assert_object(nuevo).is_not_same(copia)
	assert_int(nuevo.get("partida").jornada()).is_equal(ReglasDeLaPartida.PRIMERA_JORNADA)
	assert_bool(copia.is_queued_for_deletion()).is_true()
	assert_bool(nuevo.is_inside_tree()).is_true()
	assert_int(nuevo.process_mode).is_equal(Node.PROCESS_MODE_DISABLED)
