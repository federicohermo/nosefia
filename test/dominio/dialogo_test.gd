extends GdUnitTestSuite


func test_la_primera_entrada_se_muestra_sin_avanzar() -> void:
	var dialogo := _tres_entradas()
	assert_str(dialogo.entrada_actual()).is_equal("Primera")
	assert_str(dialogo.ultima_entrada_mostrada()).is_equal("Primera")
	assert_bool(dialogo.terminado()).is_false()


func test_tres_entradas_retienen_hasta_el_tercer_avance() -> void:  # AC-CTR-014
	var dialogo := _tres_entradas()
	assert_bool(dialogo.puede_abandonar()).is_false()
	assert_bool(dialogo.avanzar()).is_true()
	assert_str(dialogo.entrada_actual()).is_equal("Segunda")
	assert_bool(dialogo.avanzar()).is_true()
	assert_str(dialogo.entrada_actual()).is_equal("Tercera")
	assert_bool(dialogo.puede_abandonar()).is_false()
	assert_bool(dialogo.avanzar()).is_false()
	assert_bool(dialogo.terminado()).is_true()
	assert_bool(dialogo.puede_abandonar()).is_true()
	assert_str(dialogo.entrada_actual()).is_empty()


func test_avanzar_despues_del_final_no_borra_la_ultima_entrada() -> void:
	var dialogo := _tres_entradas()
	for paso in 3:
		dialogo.avanzar()
	assert_bool(dialogo.avanzar()).is_false()
	assert_bool(dialogo.avanzar()).is_false()
	assert_str(dialogo.entrada_actual()).is_empty()
	assert_str(dialogo.ultima_entrada_mostrada()).is_equal("Tercera")


func test_sin_entradas_se_puede_abandonar_desde_el_principio() -> void:  # AC-CTR-014
	var dialogo := Dialogo.new()
	assert_bool(dialogo.terminado()).is_true()
	assert_bool(dialogo.puede_abandonar()).is_true()
	assert_str(dialogo.entrada_actual()).is_empty()
	assert_str(dialogo.ultima_entrada_mostrada()).is_empty()
	assert_bool(dialogo.avanzar()).is_false()


func test_el_pensamiento_no_retiene_antes_de_avanzar() -> void:  # AC-INV-019
	var dialogo := Dialogo.new(PackedStringArray(["Algo debajo."]), Dialogo.Clase.PENSAMIENTO)
	assert_bool(dialogo.puede_abandonar()).is_true()
	assert_bool(dialogo.terminado()).is_false()
	assert_str(dialogo.entrada_actual()).is_equal("Algo debajo.")


func test_una_sola_entrada_se_cierra_con_el_primer_avance() -> void:
	var dialogo := Dialogo.new(PackedStringArray(["Única"]))
	assert_bool(dialogo.puede_abandonar()).is_false()
	assert_bool(dialogo.avanzar()).is_false()
	assert_bool(dialogo.puede_abandonar()).is_true()
	assert_str(dialogo.ultima_entrada_mostrada()).is_equal("Única")


func test_el_recordatorio_tiene_una_entrada_y_no_retiene() -> void:
	var dialogo := Dialogo.new(
		PackedStringArray(["Lo último que dijo."]), Dialogo.Clase.PENSAMIENTO
	)
	assert_str(dialogo.entrada_actual()).is_equal("Lo último que dijo.")
	assert_bool(dialogo.puede_abandonar()).is_true()
	assert_bool(dialogo.avanzar()).is_false()
	assert_bool(dialogo.terminado()).is_true()


func test_el_dialogo_conserva_sus_entradas_si_cambia_la_fuente() -> void:
	var entradas := PackedStringArray(["Primera", "Segunda"])
	var dialogo := Dialogo.new(entradas)
	entradas[0] = "Reemplazada"
	entradas.clear()
	assert_str(dialogo.entrada_actual()).is_equal("Primera")
	assert_bool(dialogo.avanzar()).is_true()
	assert_str(dialogo.entrada_actual()).is_equal("Segunda")


func _tres_entradas() -> Dialogo:
	return Dialogo.new(PackedStringArray(["Primera", "Segunda", "Tercera"]))
