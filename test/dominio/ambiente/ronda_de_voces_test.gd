## A qué voz le toca el sonido siguiente. Aritmética pura: ni un `Node` en toda la suite.
extends GdUnitTestSuite


func test_el_local_tiene_voces_de_sobra_para_cinco_sonidos_seguidos() -> void:  # 021-AC2
	# El piso importa más que el número: con menos de cinco, cinco pedidos seguidos se pisarían
	# entre ellos y no habría cómo distinguir un sonido perdido de uno que nunca se pidió — y en
	# headless tampoco se puede preguntar cuál está libre: el estado de reproducción no
	# cambia nunca con el driver dummy.
	(
		assert_int(RondaDeVoces.VOCES_DEL_LOCAL)
		. override_failure_message(
			"con %d voces, cinco sonidos seguidos se pisan" % RondaDeVoces.VOCES_DEL_LOCAL
		)
		. is_greater_equal(5)
	)


func test_cada_voz_sale_una_sola_vez_por_vuelta() -> void:  # 021-AC2
	var ronda := RondaDeVoces.new(RondaDeVoces.VOCES_DEL_LOCAL)
	var vistas: Array[int] = []
	for _pedido in range(RondaDeVoces.VOCES_DEL_LOCAL):
		var voz := ronda.siguiente()
		assert_bool(vistas.has(voz)).is_false()
		vistas.append(voz)
	assert_int(vistas.size()).is_equal(RondaDeVoces.VOCES_DEL_LOCAL)


func test_la_vuelta_siguiente_empieza_de_nuevo() -> void:  # 021-AC2
	var ronda := RondaDeVoces.new(2)
	ronda.siguiente()
	ronda.siguiente()
	assert_int(ronda.siguiente()).is_equal(0)


func test_dos_rondas_no_comparten_el_turno() -> void:  # 021-AC2
	# Con el contador declarado como estático, dos reproductores se robarían las voces entre
	# ellos y el segundo empezaría por donde terminó el primero.
	var una := RondaDeVoces.new(3)
	una.siguiente()
	assert_int(RondaDeVoces.new(3).siguiente()).is_equal(0)
