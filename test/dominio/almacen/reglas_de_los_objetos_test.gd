## Un archivo de constantes no tiene comportamiento que probar: lo que se prueba son sus
## invariantes, y acá son de orden. Las tres distancias se miden desde el ojo, así que el día que
## alguien ajuste el tacto de agarrar sin mirar el resto, una de ellas se pasa del alcance de la
## mira y el jugador suelta cosas que ya no puede volver a agarrar. Eso no se ve leyendo el
## archivo: los tres números están bien cada uno por su cuenta.
extends GdUnitTestSuite

const ReglasDeLosObjetos := preload("res://src/dominio/almacen/reglas_de_los_objetos.gd")
const ReglasDelJugador := preload("res://src/dominio/jugador/reglas_del_jugador.gd")


func test_las_distancias_van_de_la_mas_cerca_a_la_mas_lejos() -> void:  # 006-AC6
	# Examinar acerca el objeto a la cara, llevarlo lo deja a la altura de la mano y soltarlo lo
	# aleja. Si el orden se invierte, examinar ALEJA el objeto en vez de acercarlo, y el bug se
	# siente como «la E no hace nada»: lo que revela queda demasiado chico para leerse.
	assert_float(ReglasDeLosObjetos.DISTANCIA_DE_EXAMEN).is_less(
		ReglasDeLosObjetos.DISTANCIA_DE_CARGA
	)
	assert_float(ReglasDeLosObjetos.DISTANCIA_DE_CARGA).is_less_equal(
		ReglasDeLosObjetos.DISTANCIA_DE_SOLTADO
	)


func test_las_distancias_son_positivas_y_caben_en_el_alcance_de_la_mira() -> void:  # 006-AC6
	# Una distancia negativa deja el objeto atrás de la cabeza, y una mayor que el alcance de la
	# mira lo suelta afuera del rayo: se puede tirar algo y no poder volver a levantarlo.
	for distancia in [
		ReglasDeLosObjetos.DISTANCIA_DE_EXAMEN,
		ReglasDeLosObjetos.DISTANCIA_DE_CARGA,
		ReglasDeLosObjetos.DISTANCIA_DE_SOLTADO,
	]:
		assert_float(distancia).is_greater(0.0)
		assert_float(distancia).is_less(ReglasDelJugador.ALCANCE_DE_LA_MIRA)


func test_se_lleva_una_sola_cosa_a_la_vez() -> void:  # 006-AC6
	# El 015 se apoya en este 1: afirma que las bolsas de una jornada son más que las manos, o
	# sea que sacar la basura cuesta más de un viaje. Subirlo a 2 le afloja el precio en tiempo
	# a media tarea obligatoria sin que ese spec se entere.
	assert_int(ReglasDeLosObjetos.MANOS_DISPONIBLES).is_equal(1)


func test_las_dos_acciones_nuevas_no_se_pisan_con_las_de_caminar() -> void:  # 006-AC6
	# El rojo del día que alguien copie una constante y se olvide de cambiarle el texto: dos
	# acciones con el mismo nombre hacen que una de las dos no responda nunca, y el motor no
	# dice una palabra.
	var nombres: Array[String] = [
		ReglasDeLosObjetos.ACCION_AGARRAR,
		ReglasDeLosObjetos.ACCION_EXAMINAR,
		ReglasDelJugador.ACCION_ADELANTE,
		ReglasDelJugador.ACCION_ATRAS,
		ReglasDelJugador.ACCION_IZQUIERDA,
		ReglasDelJugador.ACCION_DERECHA,
	]
	var distintos := {}
	for nombre in nombres:
		distintos[nombre] = true
	assert_int(distintos.size()).is_equal(nombres.size())
