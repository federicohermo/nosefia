## La pantalla de configuraciones: seis filas, cada gesto que cambia un valor lo avisa una vez, y
## con la letra al máximo nada se sale del lienzo.
extends GdUnitTestSuite

const ESCENA := "res://src/ui/interrupciones/pantalla_de_configuraciones.tscn"
const C := Preferencias.Campo
const FILAS: Array[String] = ["EFECTOS", "MÚSICA", "BRILLO", "SENSIBILIDAD", "TEXTOS", "LENGUAJE"]

var _avisos: Array[Preferencias] = []
var _cierres: int = 0


func before_test() -> void:
	_avisos = []
	_cierres = 0


func after_test() -> void:
	var ajuste: AjusteDePreferencias = auto_free(AjusteDePreferencias.new())
	add_child(ajuste)
	ajuste.aplicar(Preferencias.new())


func _pantalla(preferencias: Preferencias = Preferencias.new()) -> PantallaDeConfiguraciones:
	var pantalla: PantallaDeConfiguraciones = auto_free(load(ESCENA).instantiate())
	add_child(pantalla)
	pantalla.preparar(preferencias)
	pantalla.preferencias_cambiadas.connect(func(p: Preferencias) -> void: _avisos.append(p))
	pantalla.cerrada.connect(func() -> void: _cierres += 1)
	pantalla.abrir()
	return pantalla


func _fila(pantalla: PantallaDeConfiguraciones, indice: int) -> HBoxContainer:
	return pantalla.filas()[indice]


func _boton(
	pantalla: PantallaDeConfiguraciones, campo: Preferencias.Campo, texto: String
) -> Button:
	for boton: Button in _fila(pantalla, Preferencias.CAMPOS.find(campo)).find_children(
		"*", "Button", false, false
	):
		if boton.text == texto:
			return boton
	return null


func _barra(pantalla: PantallaDeConfiguraciones, campo: Preferencias.Campo) -> HSlider:
	return (
		_fila(pantalla, Preferencias.CAMPOS.find(campo))
		. find_children("*", "HSlider", false, false)[0]
	)


func test_muestra_las_seis_filas_en_orden_con_menos_barra_y_mas() -> void:  # AC-CFG-001
	var pantalla := _pantalla()
	var nombres: Array[String] = []
	for fila: HBoxContainer in pantalla.filas():
		nombres.append((fila.get_child(0) as Label).text)
	assert_array(nombres).is_equal(FILAS)
	for indice: int in range(5):
		var hijos := _fila(pantalla, indice).get_children()
		assert_int(hijos.size()).is_equal(4)
		assert_str((hijos[1] as Button).text).is_equal(PantallaDeConfiguraciones.TEXTO_DE_MENOS)
		assert_object(hijos[2] as HSlider).is_not_null()
		assert_str((hijos[3] as Button).text).is_equal(PantallaDeConfiguraciones.TEXTO_DE_MAS)
	var lenguaje: OptionButton = _fila(pantalla, 5).get_child(1)
	assert_int(lenguaje.item_count).is_equal(1)
	assert_str(lenguaje.get_item_text(0)).is_equal("ESPAÑOL")


func test_mas_en_el_maximo_no_avisa_y_menos_si() -> void:  # AC-CFG-003
	var pantalla := _pantalla()
	_boton(pantalla, C.EFECTOS, PantallaDeConfiguraciones.TEXTO_DE_MAS).pressed.emit()
	assert_array(_avisos).is_empty()
	_boton(pantalla, C.EFECTOS, PantallaDeConfiguraciones.TEXTO_DE_MENOS).pressed.emit()
	assert_int(_avisos.size()).is_equal(1)
	assert_float(_avisos[0].valor(C.EFECTOS)).is_equal_approx(90.0, 1e-6)
	assert_float(_barra(pantalla, C.EFECTOS).value).is_equal_approx(90.0, 1e-6)


func test_arrastrar_el_brillo_cae_en_el_paso_y_avisa() -> void:  # AC-CFG-004
	var pantalla := _pantalla()
	_barra(pantalla, C.BRILLO).value = 123.0
	assert_int(_avisos.size()).is_equal(1)
	assert_float(_avisos[0].valor(C.BRILLO)).is_equal_approx(120.0, 1e-6)
	assert_float(_barra(pantalla, C.BRILLO).value).is_equal_approx(120.0, 1e-6)


func test_la_musica_cambia_con_la_pantalla_todavia_abierta() -> void:  # AC-CFG-009
	var pantalla := _pantalla()
	var ajuste: AjusteDePreferencias = auto_free(AjusteDePreferencias.new())
	add_child(ajuste)
	pantalla.preferencias_cambiadas.connect(ajuste.aplicar)
	_barra(pantalla, C.MUSICA).value = 50.0
	assert_bool(pantalla.visible).is_true()
	var bus := AudioServer.get_bus_index(EntradaSonora.BUS_DE_MUSICA)
	assert_float(AudioServer.get_bus_volume_db(bus)).is_equal_approx(-6.0206, 1e-3)


func test_cada_aviso_es_una_copia() -> void:
	var pantalla := _pantalla()
	_boton(pantalla, C.MUSICA, PantallaDeConfiguraciones.TEXTO_DE_MENOS).pressed.emit()
	_boton(pantalla, C.MUSICA, PantallaDeConfiguraciones.TEXTO_DE_MENOS).pressed.emit()
	assert_float(_avisos[0].valor(C.MUSICA)).is_equal_approx(90.0, 1e-6)
	assert_float(_avisos[1].valor(C.MUSICA)).is_equal_approx(80.0, 1e-6)


func test_abrir_muestra_los_valores_preparados() -> void:
	var preferencias := Preferencias.new()
	preferencias.poner(C.SENSIBILIDAD, 1.75)
	var pantalla := _pantalla(preferencias)
	assert_float(_barra(pantalla, C.SENSIBILIDAD).value).is_equal_approx(1.75, 1e-6)


func test_esc_la_cierra_y_avisa() -> void:  # AC-SAV-018
	var pantalla := _pantalla()
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	pantalla._unhandled_input(esc)
	assert_bool(pantalla.visible).is_false()
	assert_int(_cierres).is_equal(1)
	pantalla._unhandled_input(esc)
	assert_int(_cierres).is_equal(1)


func test_corre_tambien_con_el_arbol_en_pausa() -> void:
	assert_int(_pantalla().process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)


func test_con_la_letra_al_maximo_nada_se_sale_del_lienzo() -> void:  # AC-CFG-008
	var ajuste: AjusteDePreferencias = auto_free(AjusteDePreferencias.new())
	add_child(ajuste)
	var grande := Preferencias.new()
	grande.poner(C.TEXTOS, 1.5)
	ajuste.aplicar(grande)
	var pantalla := _pantalla(grande)
	await get_tree().process_frame
	await get_tree().process_frame
	var marco := pantalla.marco()
	var lienzo := Rect2(Vector2.ZERO, LienzoDeManada.TAMANO_DEL_DISENO)
	var controles := marco.find_children("*", "Control", true, false)
	assert_array(controles).is_not_empty()
	for control: Control in controles:
		# La lista del desplegable es una ventana aparte, cerrada: no se dibuja en el lienzo.
		if not control.is_visible_in_tree():
			continue
		var rect := Rect2(
			marco.get_global_transform().affine_inverse() * control.global_position, control.size
		)
		(
			assert_bool(lienzo.encloses(rect))
			. override_failure_message("%s se sale: %s" % [control.name, rect])
			. is_true()
		)
		assert_bool(control.size.x + 0.5 >= control.get_combined_minimum_size().x).is_true()
		assert_bool(control.size.y + 0.5 >= control.get_combined_minimum_size().y).is_true()
	for disponible: Vector2 in [Vector2(1920, 1080), Vector2(1280, 720)]:
		LienzoDeManada.ajustar(marco, disponible)
		var escalado := Rect2(marco.position, LienzoDeManada.TAMANO_DEL_DISENO * marco.scale)
		assert_bool(Rect2(Vector2.ZERO, disponible).grow(0.5).encloses(escalado)).is_true()


func test_la_pantalla_usa_el_tema_y_no_declara_estilos() -> void:
	var texto := FileAccess.get_file_as_string(ESCENA)
	assert_str(texto).contains("res://assets/ui/manada/tema.tres")
	assert_str(texto).not_contains("theme_override_")
