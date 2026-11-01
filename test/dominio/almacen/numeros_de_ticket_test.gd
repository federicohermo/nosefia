extends GdUnitTestSuite


func test_ningun_numero_se_repite_en_toda_la_partida() -> void:  # AC-PLY-107
	var numeros := NumerosDeTicket.new()
	var vistos: Dictionary[int, bool] = {}
	for _vez in NumerosDeTicket.MAXIMO:
		var numero := numeros.sortear()
		assert_bool(vistos.has(numero)).is_false()
		vistos[numero] = true


func test_el_numero_tiene_cuatro_cifras() -> void:  # AC-PLY-107
	var numeros := NumerosDeTicket.new()
	for _vez in 200:
		var numero := numeros.sortear()
		assert_int(numero).is_between(1, NumerosDeTicket.MAXIMO)
		assert_int(("%04d" % numero).length()).is_equal(4)


func test_la_misma_semilla_sortea_lo_mismo() -> void:  # AC-PLY-107
	var uno := NumerosDeTicket.new(42)
	var otro := NumerosDeTicket.new(42)
	for _vez in 20:
		assert_int(uno.sortear()).is_equal(otro.sortear())


func test_no_sale_en_orden() -> void:  # AC-PLY-107
	var numeros := NumerosDeTicket.new()
	var salidos: Array[int] = []
	for _vez in 10:
		salidos.append(numeros.sortear())
	var consecutivos := true
	for indice in range(1, salidos.size()):
		consecutivos = consecutivos and salidos[indice] == salidos[indice - 1] + 1
	assert_bool(consecutivos).is_false()


func test_agotados_los_numeros_sigue_sorteando() -> void:  # AC-PLY-107
	var numeros := NumerosDeTicket.new()
	for _vez in NumerosDeTicket.MAXIMO:
		numeros.sortear()
	assert_int(numeros.sortear()).is_between(1, NumerosDeTicket.MAXIMO)


func test_la_partida_lleva_la_cuenta_de_los_numeros() -> void:  # AC-PLY-107
	var partida := Partida.nueva()
	var primero := partida.numeros_de_ticket.sortear()
	assert_int(partida.numeros_de_ticket.sortear()).is_not_equal(primero)
