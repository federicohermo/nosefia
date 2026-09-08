## Qué se puede llevar y qué no, sin un solo nodo en el medio.
##
## Es la mitad de agarrar que se puede ejercer sin levantar una escena, y por eso está acá: lo
## que `Agarre` hace es reparentar un `Node3D`, y eso ya no es una regla del juego.
extends GdUnitTestSuite

const Manos := preload("res://src/dominio/almacen/manos.gd")
const ObjetoDelAlmacen := preload("res://src/dominio/almacen/objeto_del_almacen.gd")


func _lata(un_id: StringName = &"lata_de_tomate") -> Resource:
	var objeto := ObjetoDelAlmacen.new()
	objeto.id = un_id
	objeto.nombre = "Lata de tomate"
	return objeto


func _puerta() -> Resource:
	# Lo fijo del almacén: la puerta, la ventanilla y el comprador. Se pueden mirar y examinar,
	# y no se pueden llevar a ningún lado.
	var objeto := ObjetoDelAlmacen.new()
	objeto.id = &"puerta"
	objeto.nombre = "Puerta"
	objeto.levantable = false
	return objeto


func test_las_manos_vacias_no_sostienen_nada() -> void:  # 006-AC1
	assert_object(Manos.new().sostenido()).is_null()


func test_agarrar_algo_levantable_lo_deja_en_la_mano() -> void:  # 006-AC1
	var manos := Manos.new()
	var lata := _lata()
	assert_bool(manos.agarrar(lata)).is_true()
	assert_object(manos.sostenido()).is_same(lata)


func test_con_las_manos_llenas_el_motivo_es_que_estan_llenas() -> void:  # 006-AC2
	# Es el motivo que el 014 cita por nombre para explicar por qué no se puede recibir lo que
	# el comprador devuelve mientras se lleva otra cosa.
	var manos := Manos.new()
	var lata := _lata()
	manos.agarrar(lata)
	var otra := _lata(&"lata_de_arvejas")
	assert_int(manos.motivo_de_rechazo(otra)).is_equal(Manos.Rechazo.MANOS_LLENAS)
	assert_bool(manos.agarrar(otra)).is_false()
	assert_object(manos.sostenido()).is_same(lata)


func test_lo_fijo_se_rechaza_por_no_ser_levantable() -> void:  # 006-AC2
	# Y se rechaza con las manos VACÍAS, que es lo que distingue los dos motivos: si el chequeo
	# de las manos llenas fuera primero, una puerta con las manos ocupadas diría el motivo que
	# el jugador puede resolver y seguiría sin poder levantarse al vaciarlas.
	var manos := Manos.new()
	assert_int(manos.motivo_de_rechazo(_puerta())).is_equal(Manos.Rechazo.NO_ES_LEVANTABLE)
	assert_bool(manos.agarrar(_puerta())).is_false()
	assert_object(manos.sostenido()).is_null()


func test_lo_llenas_no_tapa_a_lo_que_no_se_levanta() -> void:  # 006-AC2
	var manos := Manos.new()
	manos.agarrar(_lata())
	assert_int(manos.motivo_de_rechazo(_puerta())).is_equal(Manos.Rechazo.NO_ES_LEVANTABLE)


func test_nada_no_se_puede_agarrar() -> void:  # 006-AC2
	# `null` llega cuando la mira enfoca algo que no es un objeto del almacén: una pared, una
	# estantería. Sin este caso, agarrar una pared sería un `agarrar()` que devuelve `true`.
	var manos := Manos.new()
	assert_int(manos.motivo_de_rechazo(null)).is_equal(Manos.Rechazo.NO_ES_LEVANTABLE)
	assert_bool(manos.agarrar(null)).is_false()
	assert_object(manos.sostenido()).is_null()


func test_soltar_devuelve_lo_que_habia_y_deja_las_manos_vacias() -> void:  # 006-AC3
	var manos := Manos.new()
	var lata := _lata()
	manos.agarrar(lata)
	assert_object(manos.soltar()).is_same(lata)
	assert_object(manos.sostenido()).is_null()


func test_soltar_con_las_manos_vacias_devuelve_nada() -> void:  # 006-AC3
	# Quien llama —`Agarre`— se agarra de este `null` para no emitir «solté algo» cuando no
	# había nada: sin eso, cada clic al aire avisaría que se soltó un objeto.
	assert_object(Manos.new().soltar()).is_null()


func test_vaciar_se_puede_repetir() -> void:  # 006-AC3
	# Lo llama el cierre de la jornada y la suspensión del jugador, que pueden pasar dos veces
	# seguidas: la segunda no puede romper nada.
	var manos := Manos.new()
	manos.agarrar(_lata())
	manos.vaciar()
	assert_object(manos.sostenido()).is_null()
	manos.vaciar()
	assert_object(manos.sostenido()).is_null()
