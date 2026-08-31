## La aritmética de la cámara, ejercida sin levantar una escena.
##
## Todos los casos arman la `Mirada` con sensibilidad `0.01` y no con la del juego: es la que da
## números redondos —100 píxeles, un radián— y deja que ajustar el tacto en
## `reglas_del_jugador.gd` no ponga en rojo un test que no habla del tacto sino de la cuenta.
extends GdUnitTestSuite

const Mirada := preload("res://src/dominio/mirada.gd")

const SENSIBILIDAD := 0.01
const MINIMO := -1.4
const MAXIMO := 1.4


func test_cien_pixeles_a_la_derecha_giran_el_yaw_un_radian_y_no_tocan_el_pitch() -> void:
	# El signo es negativo y no es un detalle: mover el mouse a la derecha tiene que girar la
	# vista a la derecha, y en Godot eso es un yaw decreciente —la rotación positiva alrededor
	# de +Y va al otro lado—. Está medido en los cuatro cuadrantes en el research del spec 004.
	var mirada := Mirada.new(SENSIBILIDAD, MINIMO, MAXIMO)
	mirada.girar(Vector2(100.0, 0.0))
	assert_float(mirada.yaw()).is_equal_approx(-1.0, 1e-5)
	assert_float(mirada.pitch()).is_equal(0.0)


func test_mirar_muy_para_abajo_deja_el_pitch_clavado_en_el_minimo() -> void:
	# `clampf` devuelve el límite exacto —medido—, así que acá no hace falta tolerancia.
	var mirada := Mirada.new(SENSIBILIDAD, MINIMO, MAXIMO)
	mirada.girar(Vector2(0.0, 1000.0))
	assert_float(mirada.pitch()).is_equal(MINIMO)


func test_mirar_muy_para_arriba_deja_el_pitch_clavado_en_el_maximo() -> void:
	var mirada := Mirada.new(SENSIBILIDAD, MINIMO, MAXIMO)
	mirada.girar(Vector2(0.0, -1000.0))
	assert_float(mirada.pitch()).is_equal(MAXIMO)


func test_seis_vueltas_seguidas_dejan_el_yaw_adentro_de_una_vuelta() -> void:
	# Girar en redondo es legal; lo que no puede es que el número crezca sin límite. Cuatrocientos
	# pasos de 0,1 rad son 40 radianes, más de seis vueltas: sin `wrapf` el valor se iría.
	var mirada := Mirada.new(SENSIBILIDAD, MINIMO, MAXIMO)
	for _i in range(400):
		mirada.girar(Vector2(10.0, 0.0))
	assert_float(mirada.yaw()).is_between(-PI, PI)
	# El intervalo es semiabierto: `is_between` incluye los dos extremos, así que el de arriba
	# hay que excluirlo aparte.
	assert_float(mirada.yaw()).is_less(PI)


func test_una_mirada_recien_creada_arranca_derecha() -> void:
	# Si el estado inicial no fuera cero, cada uno de los casos de arriba estaría midiendo un
	# delta contra un origen que nadie declaró.
	var mirada := Mirada.new(SENSIBILIDAD, MINIMO, MAXIMO)
	assert_float(mirada.yaw()).is_equal(0.0)
	assert_float(mirada.pitch()).is_equal(0.0)
