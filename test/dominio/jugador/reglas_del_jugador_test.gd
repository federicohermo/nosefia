## Un archivo de constantes no tiene comportamiento que probar: lo que se prueba son sus
## invariantes. Cada una de estas afirmaciones se pone en rojo el día que alguien ajuste el
## tacto del controlador y se pase de un límite que no es de gusto sino de diseño.
extends GdUnitTestSuite

const ReglasDelJugador := preload("res://src/dominio/jugador/reglas_del_jugador.gd")


func test_el_techo_angular_se_expresa_en_radianes() -> void:
	# En grados, cualquier tolerancia razonable pasaría de un cuarto de vuelta: en radianes, no.
	assert_float(ReglasDelJugador.DESVIO_MAXIMO_DE_LA_MIRA).is_less(PI / 4.0)
	assert_float(ReglasDelJugador.DESVIO_MAXIMO_DE_LA_MIRA).is_greater(
		ReglasDelJugador.DESVIO_MAXIMO_DE_PRODUCTOS
	)


func test_el_pitch_encierra_al_cero_y_no_llega_a_los_noventa_grados() -> void:
	# Es «la cámara no se da vuelta» escrito como aserción en vez de como impresión: si el
	# límite llegara a PI/2 la vista quedaría vertical, y pasándolo se invierte.
	assert_float(ReglasDelJugador.PITCH_MINIMO).is_less(0.0)
	assert_float(ReglasDelJugador.PITCH_MAXIMO).is_greater(0.0)
	assert_float(absf(ReglasDelJugador.PITCH_MINIMO)).is_less(PI / 2.0)
	assert_float(absf(ReglasDelJugador.PITCH_MAXIMO)).is_less(PI / 2.0)


func test_la_velocidad_y_la_sensibilidad_son_positivas() -> void:
	# Una velocidad negativa camina para atrás y una sensibilidad negativa invierte el mouse:
	# los dos son bugs que se sienten jugando y que nadie busca en un archivo de constantes.
	assert_float(ReglasDelJugador.VELOCIDAD_DE_CAMINATA).is_greater(0.0)
	assert_float(ReglasDelJugador.SENSIBILIDAD_DEL_MOUSE).is_greater(0.0)


func test_el_alcance_de_la_mira_supera_la_distancia_de_soltado() -> void:
	# Lo que se lleva se suelta a 1,2 m y se afirma que se lo puede volver a mirar. Un
	# alcance menor deja al jugador soltando cosas que ya no puede agarrar, y ese rojo
	# aparecería en el test de agarrar y no acá.
	assert_float(ReglasDelJugador.ALCANCE_DE_LA_MIRA).is_greater(1.2)


func test_la_proximidad_no_cuenta_la_altura() -> void:  # AC-PLY-004
	var ojo := Vector3(1.0, 1.6, 2.0)
	var abajo := Vector3(1.0, 0.0, 2.0) + Vector3.FORWARD * ReglasDelJugador.ALCANCE_DE_LA_MIRA
	var arriba := Vector3(abajo.x, 3.0, abajo.z)
	assert_float(ReglasDelJugador.proximidad(ojo, abajo)).is_equal_approx(
		ReglasDelJugador.ALCANCE_DE_LA_MIRA, 1e-5
	)
	assert_float(ReglasDelJugador.proximidad(ojo, arriba)).is_equal_approx(
		ReglasDelJugador.ALCANCE_DE_LA_MIRA, 1e-5
	)


func test_la_mira_termina_en_el_borde_del_alcance_por_empinada_que_sea() -> void:  # AC-PLY-004
	var ojo := Vector3(0.0, 1.6, 0.0)
	for direccion: Vector3 in [Vector3.FORWARD, Vector3(0.0, -1.0, -1.0), Vector3(1.0, 2.0, 0.0)]:
		var fin := ReglasDelJugador.fin_de_la_mira(ojo, direccion)
		assert_float(ReglasDelJugador.proximidad(ojo, fin)).is_equal_approx(
			ReglasDelJugador.ALCANCE_DE_LA_MIRA, 1e-5
		)


func test_la_camara_esta_a_la_altura_de_una_persona() -> void:
	# Fuera de este rango la cámara deja de ser un par de ojos: abajo se arrastra por el piso,
	# arriba mira el almacén desde un dron.
	assert_float(ReglasDelJugador.ALTURA_DE_LA_CAMARA).is_between(1.5, 1.9)


func test_los_cuatro_nombres_de_accion_son_distintos_entre_si() -> void:
	# El rojo del día que alguien copie y pegue una constante y se olvide de cambiarle el texto:
	# dos acciones con el mismo nombre hacen que una dirección no responda nunca.
	var nombres: Array[String] = [
		ReglasDelJugador.ACCION_ADELANTE,
		ReglasDelJugador.ACCION_ATRAS,
		ReglasDelJugador.ACCION_IZQUIERDA,
		ReglasDelJugador.ACCION_DERECHA,
	]
	var distintos := {}
	for nombre in nombres:
		distintos[nombre] = true
	assert_int(distintos.size()).is_equal(4)


func test_el_grupo_interactuable_tiene_nombre() -> void:
	# El contrato de «se puede interactuar» ES este String: un grupo de Godot vacío no lo
	# cumple nadie, y la mira no enfocaría nunca sin que ningún otro test lo diga.
	assert_str(ReglasDelJugador.GRUPO_INTERACTUABLE).is_not_empty()
