extends GdUnitTestSuite


func test_una_razon_escrita_exime() -> void:
	assert_bool(VolumenDeLosSolidos.exime("es un adorno que no se alcanza")).is_true()


func test_una_razon_vacia_no_exime() -> void:
	assert_bool(VolumenDeLosSolidos.exime("")).is_false()
	assert_bool(VolumenDeLosSolidos.exime("   ")).is_false()


func test_un_valor_que_no_es_texto_no_exime() -> void:
	assert_bool(VolumenDeLosSolidos.exime(null)).is_false()
	assert_bool(VolumenDeLosSolidos.exime(true)).is_false()
