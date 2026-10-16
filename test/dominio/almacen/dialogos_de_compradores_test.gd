extends GdUnitTestSuite

const TEXTOS := preload("res://assets/dialogos/compradores_jornada_1.tres")


func test_el_pedido_y_los_nombres_destacados_salen_de_la_ficha() -> void:  # AC-CTR-036
	var tin: Dialogo = TEXTOS.inicial(DialogosDeCompradores.Personaje.TIN)
	assert_str(tin.entrada_actual()).contains("[b][color=#e4f850]Coracola")
	assert_str(tin.entrada_actual()).not_contains("Pura-Cola")
	tin.avanzar()
	assert_str(tin.entrada_actual()).contains("[b][color=#e4f850]Malbardo")
	tin.avanzar()
	assert_bool(tin.terminado()).is_false()
	tin.avanzar()
	assert_bool(tin.terminado()).is_true()
	var tia: Dialogo = TEXTOS.inicial(DialogosDeCompradores.Personaje.TIA)
	assert_str(_visible(tia.entrada_actual())).is_equal(
		"Hola! Quiero una caja de cereal Zucarachas y una caja de galletitas Pepito, por favor."
	)
	_destacados(tia.entrada_actual(), ["Zucarachas", "Pepito"])
	tia.avanzar()
	assert_bool(tia.terminado()).is_true()
	assert_bool(TEXTOS.inicial(DialogosDeCompradores.Personaje.TIN).terminado()).is_false()


func _visible(texto: String) -> String:
	var etiquetas := RegEx.new()
	etiquetas.compile("\\[[^\\]]*\\]")
	return etiquetas.sub(texto, "", true)


func _destacados(texto: String, nombres: Array[String]) -> void:
	for nombre in nombres:
		var destacado := RegEx.new()
		destacado.compile("\\[b\\]\\[color=#[a-fA-F0-9]+\\]" + nombre + "\\[/color\\]\\[/b\\]")
		assert_object(destacado.search(texto)).is_not_null()


func test_rechazo_y_recordatorio_enumeran_el_pedido() -> void:  # AC-CTR-037
	var pedidos: Array[String] = [
		"Quiero una caja de fideos Marolini, una lata de Coracola y un paquete de cigarrillos Malbardo.",
		"Quiero una caja de cereal Zucarachas y una caja de galletitas Pepito."
	]
	var nombres: Array[Array] = [["Marolini", "Coracola", "Malbardo"], ["Zucarachas", "Pepito"]]
	var compradores := Compradores.de_la_jornada(1)
	for indice in compradores.size():
		for rechazar: bool in [false, true]:
			var dialogo: Dialogo = TEXTOS.recordatorio(compradores[indice].personaje, rechazar)
			assert_str(_visible(dialogo.entrada_actual())).is_equal(
				("Yo no pedí esto. " if rechazar else "") + pedidos[indice]
			)
			var productos: Array[String] = []
			productos.assign(nombres[indice])
			_destacados(dialogo.entrada_actual(), productos)
			dialogo.avanzar()
			assert_bool(dialogo.terminado()).is_true()


func test_despedida_de_tia_conserva_sus_cuatro_entradas() -> void:  # AC-CTR-039
	var dialogo: Dialogo = TEXTOS.despedida(DialogosDeCompradores.Personaje.TIA)
	assert_str(dialogo.entrada_actual()).is_equal("Gracias, tenía mucha hambre.")
	dialogo.avanzar()
	assert_str(dialogo.entrada_actual()).contains("empleado anterior")
	dialogo.avanzar()
	assert_str(dialogo.entrada_actual()).contains("Enrique Peldaño")
	dialogo.avanzar()
	assert_str(dialogo.entrada_actual()).contains("11 ****-****")
	dialogo.avanzar()
	assert_bool(dialogo.terminado()).is_true()


func test_tin_y_ambas_despedidas_conservan_cada_entrada() -> void:  # AC-CTR-036
	(
		assert_that(TEXTOS.tin)
		. is_equal(
			PackedStringArray(
				[
					(
						'"Hola... ¿Cómo andás?... Mmm, eee... Me parece que hoy me toca co'
						+ "cinar [color=#e4f850]huevos con arvejas[/color]... Pará, pará... "
						+ "Hoy como en lo de mi vieja, entonces..¿No tenés un paquete de [b]"
						+ "[color=#e4f850]Marolinis[/color][/b] y una [b][color=#e4f850]Cora"
						+ 'cola[/color][/b] , de onda?..."'
					),
					(
						"Gracias, che... uh, me olvidé, me quedé sin [b][color=#e4f850]Mal"
						+ "bardo[/color][/b].. ¿de casualidad no te sobra un puchito?..."
					),
					"Es un chiste, hermano... dale, pasame una caja... ¿cuánto sería t" + "odo?...",
				]
			)
		)
	)
	(
		assert_that(TEXTOS.despedida_tin)
		. is_equal(
			PackedStringArray(
				[
					"Gracias, che... sos lo más, en serio...",
				]
			)
		)
	)
	(
		assert_that(TEXTOS.despedida_tia)
		. is_equal(
			PackedStringArray(
				[
					"Gracias, tenía mucha hambre.",
					(
						"Me presento: soy el Sr.T ¡mucho gusto! Soy investigador criminal."
						+ " La última vez que estuve por acá ocurrió una tragedia. ¿No te en"
						+ "teraste lo que pasó con el empleado anterior?"
					),
					(
						"Con mi equipo de investigación seguimos analizando los movimiento"
						+ "s de Enrique Peldaño dueño de esta estación de servicio"
					),
					(
						"En fin…. voy a disfrutar de las zucarachas. Te dejo mi número de "
						+ "teléfono por si acaso..\n11 ****-**** ¡Anotalo! Hasta pronto!!"
					),
				]
			)
		)
	)
