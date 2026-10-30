## El impulso con que el jugador patea una unidad del piso, sin motor.
extends GdUnitTestSuite

const Patada := preload("res://src/dominio/jugador/patada.gd")
const ReglasDelJugador := preload("res://src/dominio/jugador/reglas_del_jugador.gd")

const TOLERANCIA := 1e-4
const APROXIMACION := Vector3(TOLERANCIA, TOLERANCIA, TOLERANCIA)

## El jugador camina hacia adelante, que en Godot es -Z.
const ADELANTE := Vector3(0.0, 0.0, -1.0)
const A_LA_DERECHA := Vector3(1.0, 0.0, 0.0)


func _unidad() -> UnidadDeProducto:
	return UnidadDeProducto.new(Catalogo.de(Producto.Id.ACTRONCITO))


func _velocidad_de_caminata() -> Vector3:
	return ADELANTE * ReglasDelJugador.VELOCIDAD_DE_CAMINATA


func test_la_unidad_a_la_derecha_del_camino_se_corre_hacia_la_derecha() -> void:  # AC-PLY-155
	var delante_a_la_derecha := ADELANTE * 0.5 + A_LA_DERECHA * 0.2
	var impulso := Patada.impulso(_velocidad_de_caminata(), delante_a_la_derecha, _unidad())
	assert_float(impulso.dot(A_LA_DERECHA)).is_greater(0.0)


func test_la_unidad_a_la_izquierda_del_camino_se_corre_hacia_la_izquierda() -> void:  # AC-PLY-155
	var delante_a_la_izquierda := ADELANTE * 0.5 - A_LA_DERECHA * 0.2
	var impulso := Patada.impulso(_velocidad_de_caminata(), delante_a_la_izquierda, _unidad())
	assert_float(impulso.dot(A_LA_DERECHA)).is_less(0.0)


func test_el_impulso_es_horizontal_y_no_empuja_hacia_adelante() -> void:  # AC-PLY-155
	var impulso := Patada.impulso(_velocidad_de_caminata(), ADELANTE * 0.5, _unidad())
	assert_float(impulso.y).is_equal(0.0)
	assert_float(impulso.dot(ADELANTE)).is_equal_approx(0.0, TOLERANCIA)
	assert_float(impulso.length()).is_greater(0.0)


func test_caminando_de_costado_la_unidad_se_corre_al_costado_de_ese_camino() -> void:  # AC-PLY-155
	var hacia_la_derecha := A_LA_DERECHA * ReglasDelJugador.VELOCIDAD_DE_CAMINATA
	var atras_del_camino := A_LA_DERECHA * 0.5 + Vector3.BACK * 0.2
	var impulso := Patada.impulso(hacia_la_derecha, atras_del_camino, _unidad())
	assert_float(impulso.dot(Vector3.BACK)).is_greater(0.0)
	assert_float(impulso.dot(A_LA_DERECHA)).is_equal_approx(0.0, TOLERANCIA)


func test_con_el_jugador_quieto_el_impulso_es_cero() -> void:  # AC-PLY-155
	var impulso := Patada.impulso(Vector3.ZERO, ADELANTE * 0.5, _unidad())
	assert_vector(impulso).is_equal(Vector3.ZERO)


func test_la_velocidad_vertical_no_cuenta_como_caminar() -> void:  # AC-PLY-155
	var cayendo := Vector3(0.0, -4.0, 0.0)
	assert_vector(Patada.impulso(cayendo, ADELANTE * 0.5, _unidad())).is_equal(Vector3.ZERO)


func test_lo_que_no_es_una_unidad_de_producto_no_se_patea() -> void:  # AC-PLY-155
	var caja := ObjetoDelAlmacen.new()
	assert_vector(Patada.impulso(_velocidad_de_caminata(), ADELANTE * 0.5, caja)).is_equal(
		Vector3.ZERO
	)
	assert_vector(Patada.impulso(_velocidad_de_caminata(), ADELANTE * 0.5, null)).is_equal(
		Vector3.ZERO
	)


func test_el_impulso_es_una_fraccion_de_la_velocidad_del_jugador() -> void:  # AC-PLY-155
	var impulso := Patada.impulso(_velocidad_de_caminata(), ADELANTE * 0.5, _unidad())
	assert_float(impulso.length()).is_greater(0.0)
	assert_float(impulso.length()).is_less(ReglasDelJugador.VELOCIDAD_DE_CAMINATA)
	assert_float(impulso.length()).is_equal_approx(
		Patada.FRACCION_DE_LA_VELOCIDAD * ReglasDelJugador.VELOCIDAD_DE_CAMINATA, TOLERANCIA
	)


func test_agachado_la_unidad_se_corre_menos_porque_el_jugador_va_mas_lento() -> void:  # AC-PLY-155
	var agachado := ADELANTE * ReglasDelJugador.VELOCIDAD_AGACHADO
	var de_pie := Patada.impulso(_velocidad_de_caminata(), ADELANTE * 0.5, _unidad())
	assert_float(Patada.impulso(agachado, ADELANTE * 0.5, _unidad()).length()).is_less(
		de_pie.length()
	)


func test_dos_unidades_juntas_se_corren_cada_una_hacia_su_costado() -> void:  # AC-PLY-155
	var a_la_izquierda := Patada.impulso(
		_velocidad_de_caminata(), ADELANTE * 0.5 - A_LA_DERECHA * 0.1, _unidad()
	)
	var a_la_derecha := Patada.impulso(
		_velocidad_de_caminata(), ADELANTE * 0.5 + A_LA_DERECHA * 0.1, _unidad()
	)
	assert_vector(a_la_izquierda + a_la_derecha).is_equal_approx(Vector3.ZERO, APROXIMACION)
	assert_float(a_la_derecha.dot(A_LA_DERECHA)).is_greater(0.0)


func test_justo_sobre_el_camino_igual_se_corre() -> void:  # AC-PLY-155
	var impulso := Patada.impulso(_velocidad_de_caminata(), ADELANTE * 0.5, _unidad())
	assert_float(impulso.length()).is_greater(0.0)
