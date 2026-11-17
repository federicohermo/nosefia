extends GdUnitTestSuite

const Mezcla := preload("res://addons/hornear/mezcla.gd")

const ANCHO := 8
const CAPAS := 2
const PIEZA := Vector2i(2, 2)


func test_con_nivel_uno_la_pieza_toma_la_luz_del_otro_horneado() -> void:
	var resultado := _mezclar(1.0)
	assert_float(_luz(resultado.imagen, Vector2i(2, 2), 0)).is_equal_approx(0.0, 0.0001)


func test_con_nivel_cero_el_atlas_es_el_de_la_base() -> void:
	var resultado := _mezclar(0.0)
	assert_float(_luz(resultado.imagen, Vector2i(2, 2), 0)).is_equal_approx(1.0, 0.0001)


func test_el_nivel_mezcla_en_linea_recta() -> void:
	var resultado := _mezclar(0.75)
	assert_float(_luz(resultado.imagen, Vector2i(2, 2), 0)).is_equal_approx(0.25, 0.0001)


func test_la_pieza_se_lee_del_lugar_que_tiene_en_el_otro_atlas() -> void:
	# En el otro horneado la pieza está en (4, 4) y es lo único con otra luz; en la base está en
	# (2, 2). La mezcla escribe en el lugar de la base y no toca el (4, 4).
	var resultado := _mezclar(1.0)
	assert_float(_luz(resultado.imagen, Vector2i(4, 4), 0)).is_equal_approx(1.0, 0.0001)


func test_la_mezcla_alcanza_todas_las_capas_de_la_pieza() -> void:
	var resultado := _mezclar(1.0)
	assert_float(_luz(resultado.imagen, Vector2i(2, 2), 1)).is_equal_approx(0.0, 0.0001)


func test_lo_que_no_es_una_pieza_no_cambia() -> void:
	var resultado := _mezclar(1.0)
	assert_float(_luz(resultado.imagen, Vector2i(7, 7), 0)).is_equal_approx(1.0, 0.0001)
	assert_float(_luz(resultado.imagen, Vector2i(0, 0), 1)).is_equal_approx(1.0, 0.0001)


func test_el_atlas_conserva_sus_dimensiones_y_su_formato() -> void:
	var resultado := _mezclar(0.75)
	assert_int(resultado.imagen.get_width()).is_equal(ANCHO)
	assert_int(resultado.imagen.get_height()).is_equal(ANCHO * CAPAS)
	assert_int(resultado.imagen.get_format()).is_equal(Image.FORMAT_RGBAF)


func test_una_pieza_que_el_otro_horneado_no_trae_queda_como_estaba_y_se_cuenta() -> void:
	var otro := _piezas(Vector2i(4, 4), "otra_malla")
	var resultado := Mezcla.mezclar(
		_atlas(1.0), _atlas_del_otro(), _piezas(Vector2i(2, 2)), otro, 1.0
	)
	assert_int(resultado.sin_par).is_equal(1)
	assert_float(_luz(resultado.imagen, Vector2i(2, 2), 0)).is_equal_approx(1.0, 0.0001)


func test_una_pieza_que_cambia_de_tamano_queda_como_estaba_y_se_cuenta() -> void:
	var otro := _piezas(Vector2i(4, 4), "malla", Vector2i(3, 3))
	var resultado := Mezcla.mezclar(
		_atlas(1.0), _atlas_del_otro(), _piezas(Vector2i(2, 2)), otro, 1.0
	)
	assert_int(resultado.sin_par).is_equal(1)
	assert_float(_luz(resultado.imagen, Vector2i(2, 2), 0)).is_equal_approx(1.0, 0.0001)


func test_el_interior_de_una_pieza_gana_sobre_el_borde_de_su_vecina() -> void:
	# Dos piezas pegadas en la base y separadas en el otro: el borde de la primera cae sobre el
	# interior de la segunda, y ahí tiene que valer la luz de la segunda.
	var en_la_base := _piezas(Vector2i(1, 1), "a") + _piezas(Vector2i(3, 1), "b")
	var en_el_otro := _piezas(Vector2i(1, 5), "a") + _piezas(Vector2i(4, 5), "b")
	var otro := _atlas(1.0)
	_pintar(otro, Vector2i(1, 5), PIEZA, 0.0)
	_pintar(otro, Vector2i(4, 5), PIEZA, 0.5)
	var resultado := Mezcla.mezclar(_atlas(1.0), otro, en_la_base, en_el_otro, 1.0)
	assert_float(_luz(resultado.imagen, Vector2i(3, 1), 0)).is_equal_approx(0.5, 0.0001)
	assert_float(_luz(resultado.imagen, Vector2i(1, 1), 0)).is_equal_approx(0.0, 0.0001)


func _mezclar(nivel: float) -> Mezcla.Resultado:
	return Mezcla.mezclar(
		_atlas(1.0), _atlas_del_otro(), _piezas(Vector2i(2, 2)), _piezas(Vector2i(4, 4)), nivel
	)


## El atlas del otro horneado: luz 1 en todos lados, y 0 donde está la pieza.
func _atlas_del_otro() -> Image:
	var imagen := _atlas(1.0)
	for capa: int in CAPAS:
		_pintar(imagen, Vector2i(4, 4 + capa * ANCHO), PIEZA, 0.0)
	return imagen


func _atlas(valor: float) -> Image:
	var imagen := Image.create(ANCHO, ANCHO * CAPAS, false, Image.FORMAT_RGBAF)
	imagen.fill(Color(valor, valor, valor, 1.0))
	return imagen


func _pintar(imagen: Image, desde: Vector2i, tamano: Vector2i, valor: float) -> void:
	for y: int in tamano.y:
		for x: int in tamano.x:
			imagen.set_pixel(desde.x + x, desde.y + y, Color(valor, valor, valor, 1.0))


## Una pieza en el formato de `user_data`: ruta, rectángulo, rebanada e instancia.
func _piezas(esquina: Vector2i, ruta: String = "malla", tamano: Vector2i = PIEZA) -> Array:
	var rect := Rect2(Vector2(esquina) / ANCHO, Vector2(tamano) / ANCHO)
	return [NodePath(ruta), rect, 0, 0]


func _luz(imagen: Image, texel: Vector2i, capa: int) -> float:
	return imagen.get_pixel(texel.x, texel.y + capa * ANCHO).r
