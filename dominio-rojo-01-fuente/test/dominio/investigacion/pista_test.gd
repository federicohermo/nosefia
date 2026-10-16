extends GdUnitTestSuite


func test_canal_origen_y_jornada_se_cumplen_juntos() -> void:  # AC-INV-054
	for canal: Pista.Canal in Pista.Canal.values():
		var pista := Pista.new()
		pista.identidad = "A"
		pista.origen = &"origen"
		pista.jornada = 2
		pista.canal = canal
		assert_bool(pista.se_dispara_con(&"origen", canal, 2)).is_true()
		assert_bool(pista.se_dispara_con(&"otro", canal, 2)).is_false()
		assert_bool(pista.se_dispara_con(&"origen", canal, 1)).is_false()
		assert_bool(pista.se_dispara_con(&"origen", canal, 3)).is_false()
		for otro: Pista.Canal in Pista.Canal.values():
			if otro != canal:
				assert_bool(pista.se_dispara_con(&"origen", otro, 2)).is_false()
