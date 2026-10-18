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
const HABILITADOS_FUERA_DE_LA_WEB: Array[String] = ["NUEVO JUEGO", "CONFIGURACIONES", "SALIR"]

var _ruta: String


func before_test() -> void:
	_ruta = create_temp_dir("menu").path_join("partida.guardado")
	if FileAccess.file_exists(_ruta):
		DirAccess.remove_absolute(_ruta)


## El guardado de la escena apunta a una carpeta temporal antes de entrar al árbol: el menú lo
## lee en `_ready()`, y la partida real del usuario no puede decidir un test.
func after_test() -> void:
	var ajuste: AjusteDePreferencias = auto_free(AjusteDePreferencias.new())
	add_child(ajuste)
	ajuste.aplicar(Preferencias.new())


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


func test_muestra_los_cinco_botones_y_habilita_tres() -> void:  # AC-CFG-010
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


func test_nuevo_funde_directamente_y_continuar_conserva_su_entrada() -> void:  # AC-SAV-022
	_con_guardado()
	var menu := _menu()
	menu.set_process(false)
	var ahora: Array[int] = [0]
	menu.set("_ahora", func() -> int: return ahora[0])
	var pedidos: PedidosDelMenu = menu.get_node("PedidosDelMenu")
	assert_bool(pedidos.nuevo_juego_pedido.is_connected(menu.empezar_partida_nueva)).is_true()
	assert_bool(pedidos.continuar_pedido.is_connected(menu.entrar_al_almacen)).is_true()
	var negro: ColorRect = menu.get("_fundido")
	_boton(menu, "NUEVO JUEGO").pressed.emit()
	assert_array(menu.find_children("*", "ConfirmationDialog", true, false)).is_empty()
	assert_bool(FileAccess.file_exists(_ruta)).is_false()
	assert_bool(negro.visible).is_true()
	assert_bool(menu.get("_nuevo_juego")).is_true()
	assert_float(negro.modulate.a).is_zero()
	assert_object(menu.get("_espera")).is_null()
	ahora[0] = 150000
	menu.call("_process", 99.0)
	assert_float(negro.modulate.a).is_equal(0.5)
	assert_object(menu.get("_espera")).is_null()
	ahora[0] = 299999
	menu.call("_process", 99.0)
	assert_bool(menu.get("_fundiendo")).is_true()
	assert_object(menu.get("_espera")).is_null()
	ahora[0] = 300000
	menu.call("_process", 0.0)
	assert_bool(menu.get("_fundiendo")).is_false()
	assert_bool(negro.visible).is_false()
	assert_object(menu.get("_espera")).is_not_null()
	assert_bool((menu.get("_pantalla") as PantallaDeCarga).visible).is_true()
	menu.call("_al_fallar_la_carga")
	assert_bool((menu.get("_pantalla") as PantallaDeCarga).visible).is_false()
	assert_object(menu.get("_espera")).is_null()
	menu.empezar_partida_nueva()
	assert_bool(negro.visible).is_true()
	menu.call("_al_fallar_la_carga")
	assert_bool(negro.visible).is_false()
	assert_bool(menu.get("_fundiendo")).is_false()
	# Sin archivo el pedido llega al mismo fundido sin abrir confirmación.
	var sin_guardado := _menu()
	sin_guardado.set_process(false)
	_boton(sin_guardado, "NUEVO JUEGO").pressed.emit()
	assert_array(sin_guardado.find_children("*", "ConfirmationDialog", true, false)).is_empty()
	assert_bool(sin_guardado.get("_fundiendo")).is_true()
	assert_bool((sin_guardado.get("_fundido") as ColorRect).visible).is_true()


func _configuraciones(menu: Control) -> PantallaDeConfiguraciones:
	return menu.get("_configuraciones")


func _esc() -> InputEventAction:
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	return esc


func test_configuraciones_se_abre_y_esc_la_cierra() -> void:  # AC-CFG-010, AC-SAV-018
	var menu := _menu()
	var pantalla := _configuraciones(menu)
	assert_bool(pantalla.visible).is_false()
	_boton(menu, "CONFIGURACIONES").pressed.emit()
	assert_bool(pantalla.visible).is_true()
	assert_bool((menu.get("_marco") as Control).visible).is_false()
	assert_bool((menu.get_node("Fondo") as Control).is_visible_in_tree()).is_true()
	pantalla._unhandled_input(_esc())
	assert_bool(pantalla.visible).is_false()
	assert_bool(menu.is_inside_tree() and menu.visible).is_true()
	assert_bool((menu.get("_marco") as Control).visible).is_true()
	assert_bool(_boton(menu, "CONFIGURACIONES").has_focus()).is_true()
	assert_object(menu.get("_espera")).is_null()
	assert_bool(menu.get("_fundiendo")).is_false()


func test_cerrar_configuraciones_sin_cambios_conserva_la_copia() -> void:
	var menu := _menu()
	menu.set_process(false)
	var pantalla := _configuraciones(menu)
	assert_bool(menu.call("_sirve_la_copia")).is_true()
	_boton(menu, "CONFIGURACIONES").pressed.emit()
	pantalla._unhandled_input(_esc())
	assert_bool(pantalla.visible).is_false()
	assert_bool(menu.call("_sirve_la_copia")).is_true()
	_boton(menu, "CONFIGURACIONES").pressed.emit()
	(pantalla.marco().get_node("Volver") as Button).pressed.emit()
	assert_bool(pantalla.visible).is_false()
	assert_bool(menu.call("_sirve_la_copia")).is_true()


func test_cambiar_una_preferencia_invalida_la_copia() -> void:
	for campo: Preferencias.Campo in Preferencias.CAMPOS:
		var menu := _menu()
		menu.set_process(false)
		var pantalla := _configuraciones(menu)
		_boton(menu, "CONFIGURACIONES").pressed.emit()
		assert_bool(menu.call("_sirve_la_copia")).is_true()
		var fila: HBoxContainer = pantalla.filas()[Preferencias.CAMPOS.find(campo)]
		(fila.get_child(1) as Button).pressed.emit()
		pantalla._unhandled_input(_esc())
		assert_bool(pantalla.visible).is_false()
		assert_bool(menu.call("_sirve_la_copia")).is_false()
		remove_child(menu)


func test_la_letra_cambia_al_volver_de_configuraciones() -> void:  # AC-CFG-008, AC-CFG-010
	var menu := _menu()
	_boton(menu, "CONFIGURACIONES").pressed.emit()
	var pantalla := _configuraciones(menu)
	var titulo: Label = pantalla.marco().get_node("Titulo")
	var antes := titulo.get_theme_font_size("font_size")
	var fila: HBoxContainer = pantalla.filas()[Preferencias.CAMPOS.find(Preferencias.Campo.TEXTOS)]
	(fila.get_child(3) as Button).pressed.emit()
	await get_tree().process_frame
	assert_int(titulo.get_theme_font_size("font_size")).is_equal(antes)
	(
		assert_float(ArchivoDePreferencias.new().cargar().valor(Preferencias.Campo.TEXTOS))
		. is_equal_approx(1.1, 1e-6)
	)
	var volver: Button = pantalla.marco().get_node_or_null("Volver")
	assert_object(volver).is_not_null()
	if volver == null:
		return
	assert_bool(volver.is_visible_in_tree()).is_true()
	volver.pressed.emit()
	await get_tree().process_frame
	assert_bool(pantalla.visible).is_false()
	assert_bool((menu.get("_marco") as Control).is_visible_in_tree()).is_true()
	assert_int(titulo.get_theme_font_size("font_size")).is_greater(antes)


func test_mas_en_el_brillo_llega_al_disco_con_la_pantalla_abierta() -> void:  # AC-CFG-012
	var menu := _menu()
	_boton(menu, "CONFIGURACIONES").pressed.emit()
	var pantalla := _configuraciones(menu)
	var fila: HBoxContainer = pantalla.filas()[Preferencias.CAMPOS.find(Preferencias.Campo.BRILLO)]
	(fila.get_child(3) as Button).pressed.emit()
	assert_bool(pantalla.visible).is_true()
	var leidas := ArchivoDePreferencias.new().cargar()
	assert_float(leidas.valor(Preferencias.Campo.BRILLO)).is_equal_approx(110.0, 1e-6)


func test_al_abrir_el_juego_la_musica_guardada_en_cero_ya_esta_callada() -> void:  # AC-CFG-013
	var guardadas := Preferencias.new()
	guardadas.poner(Preferencias.Campo.MUSICA, 0.0)
	assert_bool(ArchivoDePreferencias.new().escribir(guardadas)).is_true()
	_menu()
	var bus := AudioServer.get_bus_index(EntradaSonora.BUS_DE_MUSICA)
	assert_bool(AudioServer.is_bus_mute(bus)).is_true()


func test_un_archivo_de_preferencias_ilegible_no_impide_el_menu() -> void:  # AC-CFG-014
	var crudo := FileAccess.open(ArchivoDePreferencias.ruta_por_defecto, FileAccess.WRITE)
	crudo.store_string("{ ilegible")
	crudo.close()
	var menu := _menu()
	assert_bool(_boton(menu, "NUEVO JUEGO").disabled).is_false()
	var pantalla := _configuraciones(menu)
	_boton(menu, "CONFIGURACIONES").pressed.emit()
	for campo: Preferencias.Campo in Preferencias.CAMPOS:
		var fila: HBoxContainer = pantalla.filas()[Preferencias.CAMPOS.find(campo)]
		assert_float((fila.get_child(2) as HSlider).value).is_equal_approx(
			Preferencias.new().valor(campo), 1e-6
		)


## En la web, el almacén se calienta debajo del menú, detenido. Lo que corre siempre, como la
## pausa, escucharía Esc en el menú: pausaría el árbol con el menú en pantalla.
func test_la_pausa_del_almacen_que_se_calienta_no_escucha_el_menu() -> void:
	var menu := _menu()
	menu.set_process(false)
	var modelo := Node3D.new()
	var pausa := ControlDePausa.new()
	modelo.add_child(pausa)
	pausa.owner = modelo
	var escena := PackedScene.new()
	assert_int(escena.pack(modelo)).is_equal(OK)
	modelo.free()
	menu.set("_almacen", escena)
	menu.call("_calentar_debajo_del_menu")
	var copia: Node3D = auto_free(menu.get("_copia"))
	var pausas := copia.find_children("*", "ControlDePausa", true, false)
	assert_array(pausas).has_size(1)
	assert_bool((pausas[0] as ControlDePausa).can_process()).is_false()
