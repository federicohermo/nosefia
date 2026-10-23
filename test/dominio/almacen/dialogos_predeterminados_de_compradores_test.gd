extends GdUnitTestSuite

const TERCERA := ReglasDeLaPartida.PRIMERA_JORNADA + 2
const QUINTA := ReglasDeLaPartida.PRIMERA_JORNADA + 4
const AMARILLO := "[color=#e4f850]"
const PISTA := "#e7a1f4"
const CASOS: Array[Array] = [
	[Producto.Id.POETICO],
	[Producto.Id.POETICO, Producto.Id.PROGRES],
	[Producto.Id.POETICO, Producto.Id.PROGRES, Producto.Id.DURONGA],
]
const TEXTOS: Array[String] = [
	"Buenas noches. Quiero [color=#e4f850]una botella de Poético[/color].",
	(
		"Buenas noches. Quiero [color=#e4f850]una botella de Poético[/color]"
		+ " y [color=#e4f850]un tubo de papitas Progres[/color]."
	),
	(
		"Buenas noches. Quiero [color=#e4f850]una botella de Poético[/color], "
		+ "[color=#e4f850]un tubo de papitas Progres[/color]"
		+ " y [color=#e4f850]una caja de preservativos Duronga[/color]."
	),
]


func _pedido(ids: Array) -> Venta:
	var pedido := Venta.new()
	for id: Producto.Id in ids:
		pedido.agregar(Catalogo.de(id), 1)
	return pedido


func _inventario() -> Inventario:
	return Apertura.inventario_con_faltantes({}, {}, Catalogo.todos())


func _atencion(pedido: Venta, inventario: Inventario) -> Atencion:
	var comprador := Comprador.new("Fixture", pedido, pedido.total())
	comprador.personaje = DialogosDeCompradores.Personaje.CAMI
	comprador.horario = Vector2(0.0, 1000.0)
	return Atencion.new(comprador, inventario)


func _terminar_la_apertura(atencion: Atencion) -> void:
	atencion.interactuar(null)
	while not atencion.puede_abandonar():
		atencion.interactuar(null)


func test_la_apertura_nombra_uno_dos_o_tres_productos() -> void:  # AC-CTR-074
	for indice in CASOS.size():
		var ids: Array = CASOS[indice]
		var pedido := _pedido(ids)
		var atencion := _atencion(pedido, _inventario())
		atencion.interactuar(null)
		var texto := atencion.dialogo().entrada_actual()
		assert_str(texto).is_equal(TEXTOS[indice])
		assert_int(texto.count(AMARILLO)).is_equal(ids.size())
		assert_str(texto).not_contains("[b]")
		assert_str(texto).not_contains(PISTA)


func test_la_apertura_es_una_sola_entrada_y_despues_recuerda() -> void:  # AC-CTR-074
	var pedido := _pedido(CASOS[2])
	var atencion := _atencion(pedido, _inventario())
	atencion.interactuar(null)
	var apertura := atencion.dialogo().entrada_actual()
	assert_bool(atencion.puede_abandonar()).is_false()
	atencion.interactuar(null)
	assert_bool(atencion.puede_abandonar()).is_true()
	atencion.interactuar(null)
	var recordatorio := atencion.dialogo().entrada_actual()
	assert_str(apertura).is_not_equal(recordatorio)
	assert_str(apertura).is_equal("Buenas noches. " + recordatorio)


func test_la_despedida_es_una_entrada_y_retira_al_terminarla() -> void:  # AC-CTR-074
	var pedido := _pedido(CASOS[2])
	var inventario := _inventario()
	var estante := Estante.new(inventario, Catalogo.todos())
	var atencion := _atencion(pedido, inventario)
	_terminar_la_apertura(atencion)
	for producto in pedido.productos():
		assert_int(atencion.interactuar(estante.retirar(producto))).is_equal(
			RecepcionDeCompra.Resultado.ACEPTADA
		)
	assert_int(atencion.interactuar(Ticket.new(pedido.productos()))).is_equal(
		RecepcionDeCompra.Resultado.COMPLETA
	)
	assert_bool(atencion.vendida()).is_true()
	assert_str(atencion.dialogo().entrada_actual()).is_equal("Muchas gracias.")
	assert_bool(atencion.despachada()).is_false()
	atencion.interactuar(null)
	assert_bool(atencion.despachada()).is_true()


func test_repetir_la_entrega_no_vende_ni_retira_otra_vez() -> void:  # AC-CTR-074
	var pedido := _pedido(CASOS[0])
	var inventario := _inventario()
	var estante := Estante.new(inventario, Catalogo.todos())
	var atencion := _atencion(pedido, inventario)
	_terminar_la_apertura(atencion)
	atencion.interactuar(estante.retirar(pedido.productos()[0]))
	atencion.interactuar(Ticket.new(pedido.productos()))
	atencion.interactuar(null)
	var otra := estante.retirar(pedido.productos()[0])
	var vendibles := inventario.vendibles(pedido.productos()[0])
	assert_int(atencion.interactuar(otra)).is_equal(RecepcionDeCompra.Resultado.BLOQUEADA)
	assert_int(inventario.vendibles(pedido.productos()[0])).is_equal(vendibles)
	assert_bool(atencion.vendida()).is_true()


func test_la_apertura_de_las_jornadas_3_a_5_es_la_predeterminada() -> void:  # AC-CTR-070
	for jornada in range(TERCERA, QUINTA + 1):
		for comprador in Compradores.de_la_jornada(jornada, 3):
			var atencion := Atencion.new(comprador, _inventario())
			atencion.interactuar(null)
			assert_str(atencion.dialogo().entrada_actual()).starts_with("Buenas noches. Quiero ")
			assert_str(atencion.dialogo().entrada_actual()).ends_with(".")


func test_la_primera_jornada_conserva_su_guion() -> void:  # AC-CTR-070
	for comprador in Compradores.de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA):
		var atencion := Atencion.new(comprador, _inventario())
		atencion.interactuar(null)
		assert_str(atencion.dialogo().entrada_actual()).not_contains("Buenas noches")


func test_tin_de_la_tercera_no_repite_el_horario_de_la_primera() -> void:  # AC-CTR-070
	var en_primera := Compradores.de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA)[0]
	var en_tercera := Compradores.de_la_jornada(TERCERA, 3)[1]
	assert_str(en_tercera.nombre()).is_equal(en_primera.nombre())
	assert_that(en_tercera.horario).is_not_equal(en_primera.horario)
