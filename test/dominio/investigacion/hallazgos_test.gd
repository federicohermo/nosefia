## Que examinar dos veces la misma lata no revele nada nuevo, y que eso se pueda ver.
##
## Es el mordisco entero del spec: el reloj corre igual, así que repetir es tiempo puro perdido.
## `registrar()` contesta si el hallazgo es NUEVO, y de ese `bool` cuelga que la revelación se
## muestre como descubrimiento o como algo ya leído.
extends GdUnitTestSuite

const Hallazgos := preload("res://src/dominio/investigacion/hallazgos.gd")
const ObjetoDelAlmacen := preload("res://src/dominio/almacen/objeto_del_almacen.gd")
const Revelacion := preload("res://src/dominio/investigacion/revelacion.gd")


func _con_revelacion(un_id: StringName) -> Resource:
	var revelacion := Revelacion.new()
	revelacion.texto = "La fecha está tachada con marcador."
	var objeto := ObjetoDelAlmacen.new()
	objeto.id = un_id
	objeto.revelacion = revelacion
	return objeto


func test_el_primer_examen_revela_y_el_segundo_no() -> void:  # 006-AC5
	var hallazgos := Hallazgos.new()
	var lata := _con_revelacion(&"lata_de_tomate")
	assert_bool(hallazgos.registrar(lata)).is_true()
	assert_bool(hallazgos.registrar(lata)).is_false()
	assert_int(hallazgos.cantidad()).is_equal(1)


func test_dos_objetos_distintos_son_dos_hallazgos() -> void:  # 006-AC5
	var hallazgos := Hallazgos.new()
	assert_bool(hallazgos.registrar(_con_revelacion(&"lata_de_tomate"))).is_true()
	assert_bool(hallazgos.registrar(_con_revelacion(&"cuaderno"))).is_true()
	assert_int(hallazgos.cantidad()).is_equal(2)


func test_la_identidad_es_el_id_y_no_la_instancia() -> void:  # 006-AC5
	# Dos latas de tomate de la misma góndola son dos `Resource` distintos y el mismo secreto:
	# si la identidad fuera la instancia, el jugador podría cobrar el mismo hallazgo tantas
	# veces como latas haya en la estantería, y el minuto que no se paga dejaría de doler.
	var hallazgos := Hallazgos.new()
	assert_bool(hallazgos.registrar(_con_revelacion(&"lata_de_tomate"))).is_true()
	assert_bool(hallazgos.registrar(_con_revelacion(&"lata_de_tomate"))).is_false()
	assert_int(hallazgos.cantidad()).is_equal(1)


func test_un_objeto_sin_revelacion_no_es_un_hallazgo() -> void:  # 006-AC5
	var hallazgos := Hallazgos.new()
	var cajon := ObjetoDelAlmacen.new()
	cajon.id = &"cajon"
	assert_bool(hallazgos.registrar(cajon)).is_false()
	assert_int(hallazgos.cantidad()).is_equal(0)


func test_nada_no_es_un_hallazgo() -> void:  # 006-AC5
	var hallazgos := Hallazgos.new()
	assert_bool(hallazgos.registrar(null)).is_false()
	assert_int(hallazgos.cantidad()).is_equal(0)


func test_lo_ya_visto_se_puede_preguntar_sin_registrarlo() -> void:
	# La pregunta que hace la vista para decidir si lo que muestra es un descubrimiento. Si
	# preguntarlo lo registrara, mirar el HUD marcaría el hallazgo como visto.
	var hallazgos := Hallazgos.new()
	var lata := _con_revelacion(&"lata_de_tomate")
	assert_bool(hallazgos.ya_visto(lata)).is_false()
	assert_int(hallazgos.cantidad()).is_equal(0)
	hallazgos.registrar(lata)
	assert_bool(hallazgos.ya_visto(lata)).is_true()
