## El texto de una píldora, de una palanca y de una tecla va en el tamaño de la pantalla,
## centrado por su tinta adentro de su contorno, y el contorno crece hasta dejarle aire: el texto
## no se achica.
extends GdUnitTestSuite

const TOLERANCIA := 0.5


func _glifo(forma: GlifoDeEntrada.Forma, leida: String, en_tecla: bool) -> GlifoDeEntrada:
	var glifo := GlifoDeEntrada.de_un_boton(forma, leida)
	glifo.en_tecla = en_tecla
	glifo.theme = GlifoDeEntrada.TEMA
	add_child(auto_free(glifo))
	return glifo


func _con_contorno() -> Array[GlifoDeEntrada]:
	var glifos: Array[GlifoDeEntrada] = []
	for leida: String in ["L", "R", "L3", "R3"]:
		for en_tecla: bool in [true, false]:
			glifos.append(_glifo(GlifoDeEntrada.Forma.PALANCA, leida, en_tecla))
	for leida: String in ["L1", "R1"]:
		glifos.append(_glifo(GlifoDeEntrada.Forma.PILDORA, leida, false))
	return glifos


func test_el_texto_de_un_contorno_mide_lo_mismo_que_el_de_una_tecla() -> void:  # AC-CFG-036
	for glifo: GlifoDeEntrada in _con_contorno():
		var tecla := _glifo(GlifoDeEntrada.Forma.TECLA, glifo.texto, false)
		assert_vector(glifo.rect_del_texto().size).is_equal(tecla.rect_del_texto().size)


func test_el_texto_queda_centrado_en_su_contorno_en_los_dos_ejes() -> void:  # AC-CFG-036
	for glifo: GlifoDeEntrada in _con_contorno():
		var texto := glifo.rect_del_texto().get_center()
		var contorno := glifo.contorno_dibujado().get_center()
		assert_float(texto.x).is_equal_approx(contorno.x, TOLERANCIA)
		assert_float(texto.y).is_equal_approx(contorno.y, TOLERANCIA)


func test_el_texto_de_una_tecla_queda_centrado_en_su_rectangulo() -> void:  # AC-CFG-036
	for leida: String in ["ENTER", "E", "ESC"]:
		var tecla := _glifo(GlifoDeEntrada.Forma.TECLA, leida, false)
		tecla.size = tecla.get_minimum_size()
		var centro := tecla.marco_dibujado().get_center()
		assert_float(tecla.rect_del_texto().get_center().x).is_equal_approx(centro.x, TOLERANCIA)
		assert_float(tecla.rect_del_texto().get_center().y).is_equal_approx(centro.y, TOLERANCIA)


func test_una_palanca_deja_aire_entre_las_esquinas_del_texto_y_su_borde() -> void:  # AC-CFG-036
	for glifo: GlifoDeEntrada in _con_contorno():
		if glifo.forma != GlifoDeEntrada.Forma.PALANCA:
			continue
		var texto := glifo.rect_del_texto()
		var contorno := glifo.contorno_dibujado()
		var esquina := (texto.size / 2.0).length()
		assert_float(esquina + GlifoDeEntrada.AIRE_DEL_TEXTO).is_less_equal(contorno.size.y / 2.0)


func test_una_pildora_deja_aire_arriba_y_abajo_del_texto() -> void:  # AC-CFG-036
	for leida: String in ["L1", "R1"]:
		var pildora := _glifo(GlifoDeEntrada.Forma.PILDORA, leida, false)
		var aire := (pildora.contorno_dibujado().size.y - pildora.rect_del_texto().size.y) / 2.0
		assert_float(aire).is_greater_equal(GlifoDeEntrada.AIRE_DEL_TEXTO)


func test_una_pildora_deja_de_cada_lado_del_texto_el_radio_de_sus_puntas() -> void:  # AC-CFG-036
	for leida: String in ["L1", "R1"]:
		var pildora := _glifo(GlifoDeEntrada.Forma.PILDORA, leida, false)
		var contorno := pildora.contorno_dibujado()
		var aire := (contorno.size.x - pildora.rect_del_texto().size.x) / 2.0
		assert_float(aire).is_greater_equal(contorno.size.y / 2.0)


func test_el_circulo_de_una_palanca_entra_en_el_rectangulo_de_la_tecla() -> void:  # AC-CFG-036
	for leida: String in ["L", "R", "L3", "R3"]:
		var palanca := _glifo(GlifoDeEntrada.Forma.PALANCA, leida, true)
		palanca.size = palanca.get_minimum_size()
		var dentro := palanca.marco_dibujado().grow(-float(GlifoDeEntrada.GROSOR_DEL_BORDE))
		assert_bool(dentro.encloses(palanca.contorno_dibujado())).is_true()
