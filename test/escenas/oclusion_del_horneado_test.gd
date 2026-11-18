extends GdUnitTestSuite

const Oclusion := preload("res://addons/hornear/oclusion.gd")

const RADIO := 1.0
const PROPORCION := 0.5
const RAYOS := 64
const ANCHO := 16
const CAPAS := 4
## La pieza: un piso de 4 m de lado que ocupa un cuadrado de 8 texeles del atlas.
const LADO_DEL_PISO := 4.0
const PIEZA := Rect2(4, 4, 8, 8)


func test_un_piso_abierto_no_se_oscurece() -> void:
	var oclusores := _oclusores([_piso()])
	var factor := _factor(oclusores, Vector3(2, 0, 2), Vector3.UP)
	assert_float(factor).is_equal(1.0)


func test_un_rincon_se_oscurece_mas_que_un_piso_abierto() -> void:
	var oclusores := _oclusores([_piso(), _pared()])
	var abierto := _factor(oclusores, Vector3(3, 0, 2), Vector3.UP)
	var rincon := _factor(oclusores, Vector3(0.05, 0, 2), Vector3.UP)
	assert_float(rincon).is_less(abierto)


func test_un_rincon_se_oscurece_mas_que_una_pared_lisa() -> void:
	var oclusores := _oclusores([_piso(), _pared()])
	var lisa := _factor(oclusores, Vector3(0, 2.5, 2), Vector3.RIGHT)
	var rincon := _factor(oclusores, Vector3(0.05, 0, 2), Vector3.UP)
	assert_float(rincon).is_less(lisa)


func test_el_factor_sale_entre_cero_y_uno() -> void:
	var oclusores := _oclusores([_piso(), _pared()])
	for x: float in [0.01, 0.2, 0.7, 2.0]:
		var factor := _factor(oclusores, Vector3(x, 0, 2), Vector3.UP)
		assert_float(factor).is_between(0.0, 1.0)


func test_una_chapa_fina_de_dos_caras_no_se_tapa_a_si_misma() -> void:
	# Dos caras a un milímetro, con las normales hacia afuera: el techo y el piso de un estante.
	var oclusores := _oclusores([_chapa(1.0, 0.001)])
	var arriba := _factor(oclusores, Vector3(2, 1.001, 2), Vector3.UP)
	var abajo := _factor(oclusores, Vector3(2, 1.0, 2), Vector3.DOWN)
	assert_float(arriba).is_equal(1.0)
	assert_float(abajo).is_equal(1.0)


func test_dos_caras_en_el_mismo_plano_tampoco_se_tapan() -> void:
	var oclusores := _oclusores([_chapa(1.0, 0.0)])
	assert_float(_factor(oclusores, Vector3(2, 1.0, 2), Vector3.UP)).is_equal(1.0)
	assert_float(_factor(oclusores, Vector3(2, 1.0, 2), Vector3.DOWN)).is_equal(1.0)


func test_el_pie_de_una_chapa_se_oscurece_al_estar_debajo_de_ella() -> void:
	var oclusores := _oclusores([_piso(), _chapa(0.3, 0.001)])
	var bajo := _factor(oclusores, Vector3(2, 0, 2), Vector3.UP)
	var libre := _factor(oclusores, Vector3(2, 0, 3.9), Vector3.UP)
	assert_float(bajo).is_less(libre)


func test_el_giro_no_cambia_el_resultado_de_un_lugar_abierto() -> void:
	var oclusores := _oclusores([_piso()])
	var direcciones := Oclusion.direcciones(RAYOS)
	for giro: float in [0.0, 1.3, 4.0]:
		var factor := Oclusion.factor_en(oclusores, Vector3(2, 0, 2), Vector3.UP, direcciones, giro)
		assert_float(factor).is_equal(1.0)


func test_el_atlas_oscurece_el_texel_del_rincon_y_no_el_del_piso_abierto() -> void:
	var resultado := _aplicar(1.0)
	assert_float(_luz(resultado.imagen, Vector2i(4, 8), 0)).is_less(1.0)
	assert_float(_luz(resultado.imagen, Vector2i(11, 8), 0)).is_equal(1.0)


func test_el_atlas_oscurece_las_cuatro_capas_y_no_toca_el_alfa() -> void:
	var resultado := _aplicar(1.0)
	for capa: int in CAPAS:
		var texel := resultado.imagen.get_pixel(4, 8 + capa * ANCHO)
		assert_float(texel.r).is_less(1.0)
		assert_float(texel.g).is_equal_approx(texel.r, 0.0001)
		assert_float(texel.b).is_equal_approx(texel.r, 0.0001)
		assert_float(texel.a).is_equal(1.0)


func test_con_nivel_cero_el_atlas_no_cambia() -> void:
	var resultado := _aplicar(0.0)
	assert_float(_luz(resultado.imagen, Vector2i(4, 8), 0)).is_equal(1.0)


func test_un_nivel_menor_oscurece_menos() -> void:
	var entero := _luz(_aplicar(1.0).imagen, Vector2i(4, 8), 0)
	var medio := _luz(_aplicar(0.5).imagen, Vector2i(4, 8), 0)
	assert_float(medio).is_greater(entero)
	assert_float(medio).is_less(1.0)


func test_la_luz_oscurecida_es_de_media_precision_para_que_el_exr_comprima() -> void:
	var resultado := _aplicar(0.37)
	var luz := _luz(resultado.imagen, Vector2i(4, 8), 0)
	assert_float(luz).is_less(1.0)
	assert_float(luz).is_equal(_a_media_precision(luz))


func test_el_atlas_nunca_se_aclara() -> void:
	var resultado := _aplicar(1.0)
	for y: int in ANCHO * CAPAS:
		for x: int in ANCHO:
			assert_float(_luz(resultado.imagen, Vector2i(x, y), 0)).is_less_equal(1.0)


func test_lo_que_no_es_una_pieza_no_cambia() -> void:
	var resultado := _aplicar(1.0)
	assert_float(_luz(resultado.imagen, Vector2i(0, 0), 0)).is_equal(1.0)
	assert_float(_luz(resultado.imagen, Vector2i(15, 15), 3)).is_equal(1.0)


func test_el_borde_de_la_pieza_recibe_el_factor_de_su_vecino() -> void:
	var resultado := _aplicar(1.0)
	var borde := _luz(resultado.imagen, Vector2i(3, 8), 0)
	var vecino := _luz(resultado.imagen, Vector2i(4, 8), 0)
	assert_float(borde).is_equal_approx(vecino, 0.0001)
	var esquina := _luz(resultado.imagen, Vector2i(3, 3), 0)
	assert_float(esquina).is_equal_approx(_luz(resultado.imagen, Vector2i(4, 4), 0), 0.0001)


func test_el_atlas_conserva_sus_dimensiones_y_su_formato() -> void:
	var resultado := _aplicar(1.0)
	assert_int(resultado.imagen.get_width()).is_equal(ANCHO)
	assert_int(resultado.imagen.get_height()).is_equal(ANCHO * CAPAS)
	assert_int(resultado.imagen.get_format()).is_equal(Image.FORMAT_RGBAF)


func test_una_pieza_con_uv2_fuera_de_su_rectangulo_frena_el_paso_y_se_nombra() -> void:
	var pieza := _pieza_del_piso()
	pieza.uv2[1] = Vector2(1.5, 0.0)
	var resultado := Oclusion.aplicar(_atlas(), [pieza], _oclusores([_piso()]), 1.0, RAYOS)
	assert_str(resultado.error).contains(pieza.clave)
	assert_float(_luz(resultado.imagen, Vector2i(4, 8), 0)).is_equal(1.0)


func test_la_pieza_de_una_malla_trae_sus_triangulos_en_el_mundo() -> void:
	var caja := BoxMesh.new()
	caja.size = Vector3(2, 2, 2)
	caja.add_uv2 = true
	var mundo := Transform3D(Basis.IDENTITY, Vector3(10, 0, 0))
	var pieza := Oclusion.pieza_de(caja, mundo, "caja", PIEZA, 0)
	assert_int(pieza.posiciones.size()).is_equal(36)
	assert_int(pieza.uv2.size()).is_equal(36)
	for punto: Vector3 in pieza.posiciones:
		assert_float(punto.x).is_between(9.0, 11.0)


func test_una_malla_sin_uv2_no_es_una_pieza() -> void:
	var caja := BoxMesh.new()
	caja.add_uv2 = false
	assert_object(Oclusion.pieza_de(caja, Transform3D.IDENTITY, "caja", PIEZA, 0)).is_null()


func _factor(oclusores: Oclusion.Oclusores, punto: Vector3, normal: Vector3) -> float:
	return Oclusion.factor_en(oclusores, punto, normal, Oclusion.direcciones(RAYOS), 0.0)


func _aplicar(nivel: float) -> Oclusion.Resultado:
	var oclusores := _oclusores([_piso(), _pared()])
	return Oclusion.aplicar(_atlas(), [_pieza_del_piso()], oclusores, nivel, RAYOS)


func _a_media_precision(valor: float) -> float:
	var imagen := Image.create(1, 1, false, Image.FORMAT_RGBAF)
	imagen.set_pixel(0, 0, Color(valor, 0.0, 0.0, 1.0))
	imagen.convert(Image.FORMAT_RGBAH)
	imagen.convert(Image.FORMAT_RGBAF)
	return imagen.get_pixel(0, 0).r


func _oclusores(mallas: Array) -> Oclusion.Oclusores:
	return Oclusion.oclusores_de(mallas, RADIO, PROPORCION)


func _atlas() -> Image:
	var imagen := Image.create(ANCHO, ANCHO * CAPAS, false, Image.FORMAT_RGBAF)
	imagen.fill(Color(1.0, 1.0, 1.0, 1.0))
	return imagen


## El piso es una pieza: su UV2 cubre el rectángulo entero.
func _pieza_del_piso() -> Oclusion.Pieza:
	var pieza := Oclusion.Pieza.new()
	pieza.clave = "piso#-1"
	pieza.rect = Rect2(PIEZA.position / ANCHO, PIEZA.size / ANCHO)
	pieza.rebanada = 0
	pieza.posiciones = _piso()
	pieza.normales = PackedVector3Array()
	for i: int in pieza.posiciones.size():
		pieza.normales.append(Vector3.UP)
	pieza.uv2 = PackedVector2Array()
	for punto: Vector3 in pieza.posiciones:
		pieza.uv2.append(Vector2(punto.x, punto.z) / LADO_DEL_PISO)
	return pieza


func _luz(imagen: Image, texel: Vector2i, capa: int) -> float:
	return imagen.get_pixel(texel.x, texel.y + capa * ANCHO).r


## Un cuadrado horizontal de `LADO_DEL_PISO`, con la cara hacia arriba.
func _piso() -> PackedVector3Array:
	return _cuadrado_horizontal(0.0, LADO_DEL_PISO, true)


## Una pared vertical en x = 0, de 3 m de alto.
func _pared() -> PackedVector3Array:
	return PackedVector3Array(
		[
			Vector3(0, 0, 0),
			Vector3(0, 3, 0),
			Vector3(0, 3, LADO_DEL_PISO),
			Vector3(0, 0, 0),
			Vector3(0, 3, LADO_DEL_PISO),
			Vector3(0, 0, LADO_DEL_PISO),
		]
	)


## Dos cuadrados horizontales a `espesor` de distancia, con las caras hacia afuera.
func _chapa(altura: float, espesor: float) -> PackedVector3Array:
	var caras := _cuadrado_horizontal(altura + espesor, LADO_DEL_PISO, true)
	caras.append_array(_cuadrado_horizontal(altura, LADO_DEL_PISO, false))
	return caras


func _cuadrado_horizontal(altura: float, lado: float, hacia_arriba: bool) -> PackedVector3Array:
	var a := Vector3(0, altura, 0)
	var b := Vector3(lado, altura, 0)
	var c := Vector3(lado, altura, lado)
	var d := Vector3(0, altura, lado)
	if hacia_arriba:
		return PackedVector3Array([a, d, c, a, c, b])
	return PackedVector3Array([a, b, c, a, c, d])
