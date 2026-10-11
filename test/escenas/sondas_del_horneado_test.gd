extends GdUnitTestSuite

const Sondas := preload("res://addons/hornear/sondas.gd")


func test_el_relleno_conserva_una_sonda_tenue_junto_a_otra_mas_luminosa() -> void:
	var puntos := PackedVector3Array([Vector3.ZERO, Vector3.RIGHT])
	var sh := _coeficientes([Color(0.006, 0.005, 0.004), Color(0.1, 0.2, 0.15)])
	var resultado: Dictionary = Sondas.rellenar_coeficientes(puntos, sh)
	assert_array(Array(resultado.sh)).is_equal(Array(sh))


func test_una_sonda_sin_luz_toma_los_coeficientes_de_su_vecina() -> void:
	var puntos := PackedVector3Array([Vector3.ZERO, Vector3.RIGHT])
	var sh := _coeficientes([Color(0, 0, 0), Color(0.006, 0.005, 0.004)])
	var resultado: Dictionary = Sondas.rellenar_coeficientes(puntos, sh)
	assert_int(resultado.rellenadas).is_equal(1)
	assert_array(Array(resultado.sh).slice(0, 9)).is_equal(Array(sh).slice(9, 18))


func test_una_sonda_sin_vecinas_con_luz_se_conserva_negra() -> void:
	var puntos := PackedVector3Array([Vector3.ZERO])
	var sh := _coeficientes([Color(0, 0, 0)])
	var resultado: Dictionary = Sondas.rellenar_coeficientes(puntos, sh)
	assert_array(Array(resultado.sh)).is_equal(Array(sh))


func _coeficientes(colores: Array[Color]) -> PackedColorArray:
	var sh := PackedColorArray()
	for color: Color in colores:
		sh.append(color)
		for indice: int in 8:
			sh.append(Color(0, 0, 0, 0))
	return sh
