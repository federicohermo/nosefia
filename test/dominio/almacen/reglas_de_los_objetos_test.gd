## Un archivo de constantes no tiene comportamiento que probar: lo que se prueba son sus
## invariantes, y acá son de orden. Las tres distancias se miden desde el ojo, así que el día que
## alguien ajuste el tacto de agarrar sin mirar el resto, una de ellas se pasa del alcance de la
## mira y el jugador suelta cosas que ya no puede volver a agarrar. Eso no se ve leyendo el
## archivo: los tres números están bien cada uno por su cuenta.
extends GdUnitTestSuite

const ObjetoDelAlmacen := preload("res://src/dominio/almacen/objeto_del_almacen.gd")
const ReglasDeLosObjetos := preload("res://src/dominio/almacen/reglas_de_los_objetos.gd")
const ReglasDelJugador := preload("res://src/dominio/jugador/reglas_del_jugador.gd")


func test_las_distancias_van_de_la_mas_cerca_a_la_mas_lejos() -> void:  # AC-PLY-011
	# Examinar acerca el objeto a la cara, llevarlo lo deja a la altura de la mano y soltarlo lo
	# aleja. Si el orden se invierte, examinar ALEJA el objeto en vez de acercarlo, y el bug se
	# siente como «la E no hace nada»: lo que revela queda demasiado chico para leerse.
	assert_float(ReglasDeLosObjetos.DISTANCIA_DE_EXAMEN).is_less(
		ReglasDeLosObjetos.DISTANCIA_DE_CARGA
	)
	assert_float(ReglasDeLosObjetos.DISTANCIA_DE_CARGA).is_less_equal(
		ReglasDeLosObjetos.DISTANCIA_DE_SOLTADO
	)


func test_las_distancias_son_positivas_y_caben_en_el_alcance_de_la_mira() -> void:  # AC-PLY-011
	# Una distancia negativa deja el objeto atrás de la cabeza, y una mayor que el alcance de la
	# mira lo suelta afuera del rayo: se puede tirar algo y no poder volver a levantarlo.
	for distancia in [
		ReglasDeLosObjetos.DISTANCIA_DE_EXAMEN,
		ReglasDeLosObjetos.DISTANCIA_DE_CARGA,
		ReglasDeLosObjetos.DISTANCIA_DE_SOLTADO,
	]:
		assert_float(distancia).is_greater(0.0)
		assert_float(distancia).is_less(ReglasDelJugador.ALCANCE_DE_LA_MIRA)


func test_se_lleva_una_sola_cosa_a_la_vez() -> void:  # AC-PLY-008
	# El 015 se apoya en este 1: afirma que las bolsas de una jornada son más que las manos, o
	# sea que sacar la basura cuesta más de un viaje. Subirlo a 2 le afloja el precio en tiempo
	# a media tarea obligatoria sin que ese spec se entere.
	assert_int(ReglasDeLosObjetos.MANOS_DISPONIBLES).is_equal(1)


func test_las_dos_acciones_nuevas_no_se_pisan_con_las_de_caminar() -> void:
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


func test_se_retira_de_toda_caja_apoyada_y_nunca_de_la_que_se_lleva() -> void:  # AC-STK-016
	# Apoyada vale en cualquier lado: el piso, un mostrador, un estante, otra caja. Lo que cobra
	# el traslado no es la altura: es que mientras se lleva la caja no se le saca nada.
	assert_bool(ReglasDeLosObjetos.se_puede_retirar(false)).is_true()
	assert_bool(ReglasDeLosObjetos.se_puede_retirar(true)).is_false()


func test_solo_una_superficie_horizontal_recibe_una_caja() -> void:
	# La componente vertical de la normal: 1 es un piso, 0 una pared. Sin el corte, apuntar a
	# una pared dejaría la caja clavada en el aire contra ella.
	assert_bool(ReglasDeLosObjetos.se_puede_apoyar_en(1.0)).is_true()
	assert_bool(ReglasDeLosObjetos.se_puede_apoyar_en(0.0)).is_false()
	assert_bool(ReglasDeLosObjetos.se_puede_apoyar_en(-1.0)).is_false()
	(
		assert_bool(ReglasDeLosObjetos.se_puede_apoyar_en(ReglasDeLosObjetos.APOYO_HORIZONTAL))
		. is_true()
	)
	(
		assert_bool(
			ReglasDeLosObjetos.se_puede_apoyar_en(ReglasDeLosObjetos.APOYO_HORIZONTAL - 0.001)
		)
		. is_false()
	)


func test_lo_que_entra_a_la_distancia_de_examen_se_examina_ahi() -> void:
	# Una lata y una unidad de producto ya se veían enteras a esa distancia: agrandar lo
	# examinado no puede alejar lo que ya estaba bien.
	for radio in [0.0, 0.1, ReglasDeLosObjetos.DISTANCIA_DE_EXAMEN / 2.0]:
		assert_float(ReglasDeLosObjetos.distancia_de_examen(radio)).is_equal(
			ReglasDeLosObjetos.DISTANCIA_DE_EXAMEN
		)


func test_lo_mas_grande_se_examina_mas_lejos() -> void:
	# Una distancia fija deja la caja grande con las esquinas afuera del cuadro, y al girarla
	# le mete una esquina adentro de la cámara.
	var chica := ReglasDeLosObjetos.distancia_de_examen(0.35)
	var grande := ReglasDeLosObjetos.distancia_de_examen(0.53)
	assert_float(chica).is_greater(ReglasDeLosObjetos.DISTANCIA_DE_EXAMEN)
	assert_float(grande).is_greater(chica)


func test_lo_examinado_queda_entero_delante_del_ojo() -> void:
	# El centro está a la distancia y la esfera se extiende un radio hacia el ojo: si la
	# distancia no le gana al radio, alguna rotación lo mete adentro de la cámara.
	for radio in [0.1, 0.35, 0.53, 1.0]:
		assert_float(ReglasDeLosObjetos.distancia_de_examen(radio)).is_greater(radio)


func test_lo_soltado_se_apoya_sobre_lo_horizontal_que_lo_admite() -> void:  # AC-PLY-034
	var corte := ReglasDeLosObjetos.APOYO_HORIZONTAL
	var caja := ObjetoDelAlmacen.new()
	caja.admite_encima = true
	var trapeador := ObjetoDelAlmacen.new()
	assert_bool(ReglasDeLosObjetos.admite_lo_soltado(corte - 0.001, null)).is_false()
	assert_bool(ReglasDeLosObjetos.admite_lo_soltado(corte, null)).is_true()
	assert_bool(ReglasDeLosObjetos.admite_lo_soltado(corte, caja)).is_true()
	assert_bool(ReglasDeLosObjetos.admite_lo_soltado(corte - 0.001, caja)).is_false()
	assert_bool(ReglasDeLosObjetos.admite_lo_soltado(1.0, trapeador)).is_false()


func test_las_teclas_giran_lo_examinado_a_velocidad_fija() -> void:  # AC-INV-022
	var velocidad := ReglasDeLosObjetos.VELOCIDAD_DE_GIRO_DEL_EXAMEN
	var tolerancia := Vector2.ONE * 0.0001
	assert_float(velocidad).is_greater(0.0)
	assert_vector(ReglasDeLosObjetos.giro_del_examen(Vector2.RIGHT, 0.5)).is_equal_approx(
		Vector2(velocidad * 0.5, 0.0), tolerancia
	)
	assert_vector(ReglasDeLosObjetos.giro_del_examen(Vector2(0.0, 1.0), 0.5)).is_equal_approx(
		Vector2(0.0, velocidad * 0.5), tolerancia
	)
	assert_vector(ReglasDeLosObjetos.giro_del_examen(Vector2.ZERO, 0.5)).is_equal(Vector2.ZERO)
