## El menú de inicio: que el juego abre en él y que muestra lo que contesta el dominio.
##
## Ningún caso aprieta un botón que entra al almacén: cambiar de escena se llevaría la corrida.
extends GdUnitTestSuite

const ESCENA_DEL_MENU := "res://src/escenas/menu_de_inicio.tscn"
const TEXTOS_FUERA_DE_LA_WEB: Array[String] = [
	"CONTINUAR",
	"NUEVO JUEGO",
	"LOGROS",
	"CONFIGURACIONES",
	"SALIR",
]
const HABILITADOS_FUERA_DE_LA_WEB: Array[String] = ["NUEVO JUEGO", "SALIR"]

var _ruta: String


func before_test() -> void:
	_ruta = create_temp_dir("menu").path_join("partida.guardado")
	if FileAccess.file_exists(_ruta):
		DirAccess.remove_absolute(_ruta)


## El guardado de la escena apunta a una carpeta temporal antes de entrar al árbol: el menú lo
## lee en `_ready()`, y la partida real del usuario no puede decidir un test.
func _menu() -> Control:
	var menu: Control = auto_free(load(ESCENA_DEL_MENU).instantiate())
	(menu.get("_guardado") as Guardado).ruta = _ruta
	add_child(menu)
	return menu


func _con_guardado() -> void:
	var guardado := Guardado.new()
	guardado.ruta = _ruta
	guardado.escribir(PartidaSerializada.sanear({}))


func _boton(menu: Control, texto: String) -> Button:
	for boton: Button in menu.find_children("*", "Button", true, false):
		if boton.text == texto:
			return boton
	return null


func _habilitados(menu: Control) -> Array[String]:
	var habilitados: Array[String] = []
	for boton: Button in menu.get_node("Marco").find_children("*", "Button", true, false):
		if not boton.disabled:
			habilitados.append(boton.text)
	return habilitados


func test_el_juego_abre_en_el_menu() -> void:  # AC-SAV-012
	assert_str(ProjectSettings.get_setting("application/run/main_scene")).is_equal(ESCENA_DEL_MENU)
	assert_object(_menu()).is_not_null()


func test_muestra_los_cinco_botones_y_habilita_dos() -> void:
	var textos: Array[String] = []
	var menu := _menu()
	for boton: Button in menu.get_node("Marco").find_children("*", "Button", true, false):
		textos.append(boton.text)
	assert_array(textos).is_equal(TEXTOS_FUERA_DE_LA_WEB)
	assert_array(_habilitados(menu)).is_equal(HABILITADOS_FUERA_DE_LA_WEB)


func test_sin_guardado_continuar_esta_cerrado_por_los_tres_lados() -> void:  # AC-SAV-013
	var menu := _menu()
	var pedidos: PedidosDelMenu = menu.get_node("PedidosDelMenu")
	var pedidos_emitidos: Array[String] = []
	pedidos.continuar_pedido.connect(func() -> void: pedidos_emitidos.append("continuar"))
	pedidos.nuevo_juego_pedido.connect(func() -> void: pedidos_emitidos.append("nuevo"))
	var boton := _boton(menu, "CONTINUAR")
	boton.pressed.emit()
	assert_bool(MenuDeInicio.new(false, false).habilitada(MenuDeInicio.Opcion.CONTINUAR)).is_false()
	assert_array(pedidos_emitidos).is_empty()
	assert_bool(boton.disabled).is_true()


func test_con_guardado_continuar_se_habilita_y_entra_al_almacen() -> void:
	_con_guardado()
	var menu := _menu()
	var pedidos: PedidosDelMenu = menu.get_node("PedidosDelMenu")
	assert_bool(_boton(menu, "CONTINUAR").disabled).is_false()
	assert_bool(pedidos.continuar_pedido.is_connected(menu.entrar_al_almacen)).is_true()


func test_un_guardado_corrupto_deja_continuar_cerrado_y_se_borra() -> void:
	var archivo := FileAccess.open(_ruta, FileAccess.WRITE)
	archivo.store_string("{ corrupto")
	archivo.close()
	var menu := _menu()
	assert_bool(_boton(menu, "CONTINUAR").disabled).is_true()
	assert_bool(FileAccess.file_exists(_ruta)).is_false()


func test_un_guardado_futuro_deja_continuar_cerrado_y_el_archivo_intacto() -> void:
	var guardado := Guardado.new()
	guardado.ruta = _ruta
	var futuro := PartidaSerializada.sanear({})
	futuro[PartidaSerializada.CLAVE_DE_VERSION] = PartidaSerializada.VERSION + 1
	guardado.escribir(futuro)
	var menu := _menu()
	assert_bool(_boton(menu, "CONTINUAR").disabled).is_true()
	assert_bool(FileAccess.file_exists(_ruta)).is_true()


func test_con_guardado_nuevo_juego_abre_la_confirmacion_y_cancelar_no_borra() -> void:
	_con_guardado()
	var menu := _menu()
	var pedidos: PedidosDelMenu = menu.get_node("PedidosDelMenu")
	var nuevos: Array[int] = [0]
	pedidos.nuevo_juego_pedido.connect(func() -> void: nuevos[0] += 1)
	var confirmacion: ConfirmationDialog = menu.get_node("Confirmacion")
	assert_bool(confirmacion.visible).is_false()
	_boton(menu, "NUEVO JUEGO").pressed.emit()
	assert_bool(confirmacion.visible).is_true()
	confirmacion.canceled.emit()
	assert_int(nuevos[0]).is_equal(0)
	assert_bool(FileAccess.file_exists(_ruta)).is_true()
	assert_bool(confirmacion.confirmed.is_connected(pedidos.confirmar_nuevo_juego)).is_true()


func test_configuraciones_y_salir_van_en_la_fila_debajo_de_la_columna() -> void:
	var menu := _menu()
	var columna: Array[String] = []
	var fila: Array[String] = []
	for boton: Button in menu.get_node("Marco/Opciones").get_children():
		columna.append(boton.text)
	for boton: Button in menu.get_node("Marco/Fila").get_children():
		fila.append(boton.text)
	assert_array(columna).is_equal(["CONTINUAR", "NUEVO JUEGO", "LOGROS"])
	assert_array(fila).is_equal(["CONFIGURACIONES", "SALIR"])


func test_el_menu_no_declara_estilos_propios() -> void:
	var texto := FileAccess.get_file_as_string(ESCENA_DEL_MENU)
	assert_str(texto).contains("res://assets/ui/manada/tema.tres")
	assert_str(texto).contains("res://assets/ui/manada/fondo_inicio.png")
	assert_str(texto).not_contains("theme_override_")
