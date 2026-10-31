## Lo que le pasa a la puerta cuando el cuerpo la empuja al pasar.
extends GdUnitTestSuite


func test_empujar_abre_una_puerta_cerrada() -> void:
	var puerta := Puerta.new()
	assert_bool(puerta.empujar()).is_true()
	assert_bool(puerta.abierta()).is_true()


func test_empujar_una_puerta_abierta_no_la_cierra() -> void:
	# El cuerpo sigue contra la hoja mientras pasa: si empujar alternara, la cerraría encima.
	var puerta := Puerta.new()
	puerta.empujar()
	assert_bool(puerta.empujar()).is_false()
	assert_bool(puerta.abierta()).is_true()


func test_empujar_una_puerta_trabada_no_la_abre() -> void:
	var puerta := Puerta.new(true)
	assert_bool(puerta.empujar()).is_false()
	assert_bool(puerta.abierta()).is_false()
