## Los pedidos del menú de inicio, ejercidos sin levantar la escena.
##
## El nodo no entra al árbol: así el pedido de salir se afirma sin cerrar la corrida de tests.
extends GdUnitTestSuite

const CIERRE_DEL_JUEGO := "get_tree().quit("
const UNICO_LUGAR_DEL_CIERRE := "res://src/sistemas/marco/pedidos_del_menu.gd"

var _nuevos: int = 0
var _salidas: int = 0
var _continuaciones: int = 0
var _confirmaciones: int = 0
var _guardado: Guardado


func _pedidos(hay_guardado: bool = false) -> PedidosDelMenu:
	_nuevos = 0
	_salidas = 0
	_continuaciones = 0
	_confirmaciones = 0
	_guardado = Guardado.new()
	_guardado.ruta = create_temp_dir("pedidos").path_join("partida.guardado")
	_guardado.borrar()
	if hay_guardado:
		_guardado.escribir(PartidaSerializada.sanear({}))
	var pedidos: PedidosDelMenu = auto_free(PedidosDelMenu.new())
	pedidos.preparar(MenuDeInicio.new(false, hay_guardado), _guardado)
	pedidos.nuevo_juego_pedido.connect(func() -> void: _nuevos += 1)
	pedidos.salir_pedido.connect(func() -> void: _salidas += 1)
	pedidos.continuar_pedido.connect(func() -> void: _continuaciones += 1)
	pedidos.confirmacion_pedida.connect(func() -> void: _confirmaciones += 1)
	return pedidos


func test_nuevo_juego_pide_una_sola_vez_con_doble_clic() -> void:
	var pedidos := _pedidos()
	pedidos.elegir(MenuDeInicio.Opcion.NUEVO_JUEGO)
	pedidos.elegir(MenuDeInicio.Opcion.NUEVO_JUEGO)
	assert_int(_nuevos).is_equal(1)
	assert_int(_salidas).is_equal(0)


func test_salir_pide_una_sola_vez_con_doble_clic() -> void:
	var pedidos := _pedidos()
	pedidos.elegir(MenuDeInicio.Opcion.SALIR)
	pedidos.elegir(MenuDeInicio.Opcion.SALIR)
	assert_int(_salidas).is_equal(1)
	assert_int(_nuevos).is_equal(0)


func test_las_opciones_deshabilitadas_no_piden_nada() -> void:
	var pedidos := _pedidos()
	pedidos.elegir(MenuDeInicio.Opcion.CONTINUAR)
	pedidos.elegir(MenuDeInicio.Opcion.CONFIGURACIONES)
	pedidos.elegir(MenuDeInicio.Opcion.LOGROS)
	assert_int(_nuevos + _salidas + _continuaciones + _confirmaciones).is_equal(0)


func test_con_guardado_continuar_pide_una_sola_vez_con_doble_clic() -> void:
	var pedidos := _pedidos(true)
	pedidos.elegir(MenuDeInicio.Opcion.CONTINUAR)
	pedidos.elegir(MenuDeInicio.Opcion.CONTINUAR)
	assert_int(_continuaciones).is_equal(1)
	assert_int(_nuevos).is_equal(0)
	assert_bool(_guardado.hay_guardado()).is_true()


func test_con_guardado_nuevo_juego_confirma_antes_de_borrar() -> void:  # AC-SAV-014
	var pedidos := _pedidos(true)
	pedidos.elegir(MenuDeInicio.Opcion.NUEVO_JUEGO)
	assert_int(_confirmaciones).is_equal(1)
	assert_int(_nuevos).is_equal(0)
	assert_bool(_guardado.hay_guardado()).is_true()
	pedidos.confirmar_nuevo_juego()
	pedidos.confirmar_nuevo_juego()
	assert_int(_nuevos).is_equal(1)
	assert_bool(_guardado.hay_guardado()).is_false()


func test_sin_guardado_nuevo_juego_es_directo() -> void:  # AC-SAV-014
	_pedidos().elegir(MenuDeInicio.Opcion.NUEVO_JUEGO)
	assert_int(_confirmaciones).is_equal(0)
	assert_int(_nuevos).is_equal(1)


func test_salir_es_el_unico_cierre_del_juego() -> void:  # AC-SAV-015
	var apariciones: Array[String] = []
	for ruta: String in _scripts_de("res://src"):
		for i: int in FileAccess.get_file_as_string(ruta).count(CIERRE_DEL_JUEGO):
			apariciones.append(ruta)
	assert_array(apariciones).is_equal([UNICO_LUGAR_DEL_CIERRE])
	var pedidos := _pedidos()
	for opcion: MenuDeInicio.Opcion in MenuDeInicio.new(false).opciones():
		if opcion != MenuDeInicio.Opcion.SALIR:
			pedidos.elegir(opcion)
	assert_int(_salidas).is_equal(0)


func _scripts_de(carpeta: String) -> Array[String]:
	var rutas: Array[String] = []
	for sub: String in DirAccess.get_directories_at(carpeta):
		rutas.append_array(_scripts_de(carpeta.path_join(sub)))
	for archivo: String in DirAccess.get_files_at(carpeta):
		if archivo.ends_with(".gd"):
			rutas.append(carpeta.path_join(archivo))
	return rutas
