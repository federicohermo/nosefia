## Una nota del cuaderno: su título y su texto.
extends GdUnitTestSuite


func test_la_nota_conserva_lo_que_se_escribio() -> void:  # 009-AC4
	var nota := Nota.new("Turno del martes", "La puerta del fondo estaba abierta.")
	assert_str(nota.titulo()).is_equal("Turno del martes")
	assert_str(nota.texto()).is_equal("La puerta del fondo estaba abierta.")


func test_una_nota_puede_no_tener_cuerpo() -> void:  # 009-AC4
	# El título alcanza para anotar algo al pasar, que es lo que el jugador va a hacer mientras
	# el reloj corre. Exigir el cuerpo le cobraría segundos a un recordatorio de dos palabras.
	var nota := Nota.new("Revisar el depósito", "")
	assert_str(nota.titulo()).is_equal("Revisar el depósito")
	assert_str(nota.texto()).is_empty()
