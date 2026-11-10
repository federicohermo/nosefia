## El texto de una píldora y la letra de una palanca no tocan su contorno: quedan con aire adentro,
## como las formas de ✕ ○ □ adentro de su círculo.
extends GdUnitTestSuite

## Lo que puede ocupar la letra de una palanca de su círculo: de ahí sale un margen visible.
const LETRA_MAXIMA_EN_EL_CIRCULO := 0.8
const ANCHO_MAXIMO_EN_EL_CIRCULO := 0.6


func _glifo(forma: GlifoDeEntrada.Forma, leida: String, en_tecla: bool) -> GlifoDeEntrada:
	var glifo := GlifoDeEntrada.de_un_boton(forma, leida)
	glifo.en_tecla = en_tecla
	add_child(auto_free(glifo))
	return glifo


func test_la_pildora_deja_de_cada_lado_del_texto_el_radio_de_sus_puntas() -> void:  # AC-CFG-036
	for leida: String in ["L1", "R1"]:
		var pildora := _glifo(GlifoDeEntrada.Forma.PILDORA, leida, false)
		var aire := pildora.get_minimum_size().x - pildora.medida_del_texto().x
		assert_float(aire).is_greater_equal(pildora.get_minimum_size().y)


func test_la_letra_de_la_palanca_no_ocupa_mas_que_una_parte_del_circulo() -> void:  # AC-CFG-036
	for en_tecla: bool in [true, false]:
		for leida: String in ["L", "R", "L3", "R3"]:
			var palanca := _glifo(GlifoDeEntrada.Forma.PALANCA, leida, en_tecla)
			var circulo := palanca.contorno_dibujado().size.y
			assert_float(palanca.medida_del_texto().x).is_less_equal(
				circulo * ANCHO_MAXIMO_EN_EL_CIRCULO
			)
			assert_float(float(palanca.tamano_de_la_letra_dibujada())).is_less_equal(
				circulo * LETRA_MAXIMA_EN_EL_CIRCULO
			)


func test_el_texto_de_una_tecla_sigue_en_el_tamano_de_la_pantalla() -> void:  # AC-CFG-036
	var tecla := _glifo(GlifoDeEntrada.Forma.TECLA, "ENTER", false)
	var en_la_celda := _glifo(GlifoDeEntrada.Forma.PILDORA, "START", true)
	assert_int(tecla.tamano_de_la_letra_dibujada()).is_equal(GlifoDeEntrada.tamano_de_la_letra())
	assert_int(en_la_celda.tamano_de_la_letra_dibujada()).is_equal(
		GlifoDeEntrada.tamano_de_la_letra()
	)
