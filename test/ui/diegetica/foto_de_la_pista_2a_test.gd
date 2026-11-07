extends GdUnitTestSuite

const PISTA := "res://assets/investigacion/jornada_2/pista_2a.tres"


func _colores_de_la_foto() -> Dictionary:
	var pista: Pista = load(PISTA)
	var imagen := Image.load_from_file(pista.foto.resource_path)
	var colores := {}
	for y: int in imagen.get_height():
		for x: int in imagen.get_width():
			var color := imagen.get_pixel(x, y).to_html(false)
			colores[color] = int(colores.get(color, 0)) + 1
	return colores


func test_la_foto_dibuja_la_burbuja_recibida_del_chat_actual() -> void:
	var colores := _colores_de_la_foto()
	var burbuja := PantallaDelCelular.BURBUJA_RECIBIDA.to_html(false)
	var mayor := colores.keys()[0] as String
	for color: String in colores:
		if int(colores[color]) > int(colores[mayor]):
			mayor = color
	assert_str(mayor).is_equal(burbuja)
	assert_bool(colores.has(PantallaDelCelular.BURBUJA.to_html(false))).is_false()


func test_la_foto_resalta_el_tramo_con_el_rojo_del_chat() -> void:
	assert_bool(_colores_de_la_foto().has(PantallaDelCelular.ROJO.to_html(false))).is_true()
