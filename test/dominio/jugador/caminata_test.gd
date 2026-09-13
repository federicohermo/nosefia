## El vector de entrada, sin motor.
##
## Las tolerancias no son prolijidad: están medidas. En este build
## `Vector2(1, 1).normalized().length()` devuelve `0.99999994`, así que un `is_equal(1.0)` sería
## rojo con el código correcto.
extends GdUnitTestSuite

const Caminata := preload("res://src/dominio/jugador/caminata.gd")
const ReglasDelJugador := preload("res://src/dominio/jugador/reglas_del_jugador.gd")

const TOLERANCIA := 1e-5
const APROXIMACION := Vector3(TOLERANCIA, TOLERANCIA, TOLERANCIA)


func test_la_diagonal_no_camina_mas_rapido_que_la_recta() -> void:
	# El bug clásico del controlador de primera persona: adelante más derecha suman raíz de dos
	# si nadie normaliza, y no se nota jugando hasta que alguien lo aprovecha.
	assert_float(Caminata.direccion(Vector2(1.0, 1.0), 0.0).length()).is_equal_approx(
		1.0, TOLERANCIA
	)


func test_la_entrada_nula_da_el_vector_nulo_y_ninguna_componente_es_nan() -> void:
	# Godot ya cubre normalizar el vector nulo —medido: devuelve `(0, 0, 0)`—, así que esto
	# verifica un contrato del motor en vez de tapar un agujero. Si algún día lo rompe, este
	# test avisa antes de que el jugador se teletransporte a ninguna parte.
	var quieto := Caminata.direccion(Vector2.ZERO, 0.0)
	assert_vector(quieto).is_equal(Vector3.ZERO)
	assert_bool(is_nan(quieto.x) or is_nan(quieto.y) or is_nan(quieto.z)).is_false()


func test_con_el_yaw_en_cero_el_adelante_apunta_al_menos_z() -> void:
	assert_vector(Caminata.direccion(Vector2(0.0, 1.0), 0.0)).is_equal_approx(
		Vector3(0.0, 0.0, -1.0), APROXIMACION
	)


func test_girar_la_mirada_un_cuarto_de_vuelta_gira_el_adelante() -> void:
	# Es lo que hace que caminar sea en primera persona y no en un sistema de coordenadas fijo.
	assert_vector(Caminata.direccion(Vector2(0.0, 1.0), PI / 2.0)).is_equal_approx(
		Vector3(-1.0, 0.0, 0.0), APROXIMACION
	)


func test_la_velocidad_de_la_diagonal_tiene_el_largo_de_la_velocidad_maxima() -> void:
	# La tolerancia es 1e-4 y no 1e-5 porque el error relativo de la normalización se multiplica
	# por la velocidad máxima.
	#
	# La velocidad sale de `ReglasDelJugador` y no es un `3.5` escrito acá: la aserción es
	# relativa al valor que se pasa, así que ajustar el tacto no la pone en rojo, y un número
	# fijo re-tipeado en un test es la segunda casa que la convención del repo prohíbe.
	var maxima := ReglasDelJugador.VELOCIDAD_DE_CAMINATA
	var velocidad := Caminata.velocidad(Vector2(1.0, 1.0), 0.0, maxima)
	assert_float(velocidad.length()).is_equal_approx(maxima, 1e-4)


func test_la_velocidad_no_saca_al_jugador_del_piso() -> void:
	# La componente vertical la pone la gravedad en `escenas/`, no la caminata: si acá saliera
	# distinta de cero el jugador flotaría y el síntoma no nombraría a este archivo.
	var maxima := ReglasDelJugador.VELOCIDAD_DE_CAMINATA
	assert_float(Caminata.velocidad(Vector2(1.0, 1.0), 0.7, maxima).y).is_equal(0.0)
