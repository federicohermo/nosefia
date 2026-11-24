extends GdUnitTestSuite

const Apoyo := preload("res://addons/hornear/apoyo.gd")

const SUELO := 0.1
const ESTANTE := Vector2(1.2, 0.4)


func test_el_fondo_de_un_estante_bajo_pide_un_volumen_desde_el_piso() -> void:
	var caras := _fondo(Vector3(2.0, SUELO + 0.18, 3.0), ESTANTE)
	var volumenes := Apoyo.volumenes(caras, SUELO)
	assert_int(volumenes.size()).is_equal(1)
	assert_float(volumenes[0].position.y).is_greater_equal(SUELO)
	assert_float(volumenes[0].end.y).is_less(SUELO + 0.18)
	assert_float(volumenes[0].end.y).is_greater(SUELO + 0.17)


func test_el_volumen_ocupa_el_rectangulo_del_estante_sin_tocar_sus_bordes() -> void:
	var caras := _fondo(Vector3(2.0, SUELO + 0.18, 3.0), ESTANTE)
	var volumen: AABB = Apoyo.volumenes(caras, SUELO)[0]
	assert_float(volumen.position.x).is_greater(2.0 - 0.6)
	assert_float(volumen.end.x).is_less(2.0 + 0.6)
	assert_float(volumen.position.z).is_greater(3.0 - 0.2)
	assert_float(volumen.end.z).is_less(3.0 + 0.2)


func test_un_estante_alto_no_pide_volumen() -> void:
	var caras := _fondo(Vector3(2.0, SUELO + 0.7, 3.0), ESTANTE)
	assert_array(Apoyo.volumenes(caras, SUELO)).is_empty()


func test_una_chapa_apoyada_en_el_piso_no_deja_hueco() -> void:
	var caras := _fondo(Vector3(2.0, SUELO, 3.0), ESTANTE)
	assert_array(Apoyo.volumenes(caras, SUELO)).is_empty()


func test_una_cara_que_mira_hacia_arriba_no_pide_volumen() -> void:
	var caras := _tapa(Vector3(2.0, SUELO + 0.18, 3.0), ESTANTE)
	assert_array(Apoyo.volumenes(caras, SUELO)).is_empty()


func test_un_detalle_chico_bajo_el_estante_no_pide_volumen() -> void:
	var caras := _fondo(Vector3(2.0, SUELO + 0.18, 3.0), Vector2(0.1, 0.1))
	assert_array(Apoyo.volumenes(caras, SUELO)).is_empty()


func test_dos_estantes_bajos_separados_piden_un_volumen_cada_uno() -> void:
	var caras := _fondo(Vector3(2.0, SUELO + 0.18, 3.0), ESTANTE)
	caras.append_array(_fondo(Vector3(5.0, SUELO + 0.2, 3.0), ESTANTE))
	assert_int(Apoyo.volumenes(caras, SUELO).size()).is_equal(2)


func test_el_estante_alto_no_cambia_el_volumen_del_bajo() -> void:
	var bajo := _fondo(Vector3(2.0, SUELO + 0.18, 3.0), ESTANTE)
	var con_alto := bajo.duplicate()
	con_alto.append_array(_fondo(Vector3(2.0, SUELO + 0.9, 3.0), ESTANTE))
	assert_array(Apoyo.volumenes(con_alto, SUELO)).is_equal(Apoyo.volumenes(bajo, SUELO))


func test_si_la_gondola_se_mueve_su_volumen_la_sigue() -> void:
	var desplazamiento := Vector3(1.5, 0.0, -2.0)
	var centro := Vector3(2.0, SUELO + 0.18, 3.0)
	var antes: AABB = Apoyo.volumenes(_fondo(centro, ESTANTE), SUELO)[0]
	var despues: AABB = Apoyo.volumenes(_fondo(centro + desplazamiento, ESTANTE), SUELO)[0]
	var tolerancia := Vector3.ONE * 0.0001
	assert_vector(despues.position).is_equal_approx(antes.position + desplazamiento, tolerancia)
	assert_vector(despues.size).is_equal_approx(antes.size, tolerancia)


## La cara de abajo de un estante: un rectángulo horizontal que mira hacia abajo.
func _fondo(centro: Vector3, tamano: Vector2) -> PackedVector3Array:
	var m := tamano * 0.5
	var a := centro + Vector3(-m.x, 0, -m.y)
	var b := centro + Vector3(m.x, 0, -m.y)
	var c := centro + Vector3(m.x, 0, m.y)
	var d := centro + Vector3(-m.x, 0, m.y)
	return PackedVector3Array([a, b, c, a, c, d])


## La cara de arriba del mismo estante.
func _tapa(centro: Vector3, tamano: Vector2) -> PackedVector3Array:
	var caras := _fondo(centro, tamano)
	var invertida := PackedVector3Array()
	@warning_ignore("integer_division")
	var cuantas: int = caras.size() / 3
	for t: int in cuantas:
		invertida.append_array(
			PackedVector3Array([caras[3 * t], caras[3 * t + 2], caras[3 * t + 1]])
		)
	return invertida
