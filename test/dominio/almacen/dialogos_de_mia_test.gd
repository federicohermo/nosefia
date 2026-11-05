extends GdUnitTestSuite

const QUINTA := ReglasDeLaPartida.PRIMERA_JORNADA + 4
const PERSONAJE := DialogosDeCompradores.Personaje
const AMARILLO := "[color=#e4f850]"
const ENTRADAS_DE_APERTURA := 4
const ENTRADAS_DE_DESPEDIDA := 2
## Las posiciones del mensaje 2, que nombra dos productos sin pedirlos, y del mensaje 4, que
## nombra el pedido.
const MENSAJE_2 := 1
const MENSAJE_4 := 3


func _mia(semilla: int = 5) -> Comprador:
	for comprador in Compradores.de_la_jornada(QUINTA, semilla):
		if comprador.personaje == PERSONAJE.MIA:
			return comprador
	return null


func _entradas(dialogo: Dialogo) -> PackedStringArray:
	var entradas := PackedStringArray()
	while not dialogo.terminado():
		entradas.append(dialogo.entrada_actual())
		dialogo.avanzar()
	return entradas


func _apertura(comprador: Comprador) -> PackedStringArray:
	return _entradas(comprador.dialogos.inicial(comprador.personaje, comprador.pedido()))


func _despedida(comprador: Comprador) -> PackedStringArray:
	return _entradas(comprador.dialogos.despedida(comprador.personaje, comprador.pedido()))


func _presentado(producto: Producto) -> String:
	var venta := Venta.new()
	venta.agregar(producto, 1)
	return (
		DialogosDeCompradores
		. apertura_predeterminada(venta)
		. entrada_actual()
		. trim_prefix(DialogosDeCompradores.SALUDO + "Quiero ")
		. trim_suffix(".")
	)


func test_mia_dice_cuatro_entradas_y_la_cuarta_nombra_sus_tres_productos() -> void:  # AC-CTR-173
	for semilla in range(1, 11):
		var mia := _mia(semilla)
		assert_object(mia.dialogos).is_not_null()
		var apertura := _apertura(mia)
		assert_int(apertura.size()).is_equal(ENTRADAS_DE_APERTURA)
		for entrada: String in apertura:
			assert_str(entrada).not_contains("{").not_contains("}")
		for producto in mia.pedido().productos():
			assert_str(apertura[MENSAJE_4]).contains(_presentado(producto))
		assert_int(apertura[MENSAJE_4].count(AMARILLO)).is_equal(3)


func test_el_mensaje_2_de_mia_no_resalta_nada() -> void:  # AC-CTR-173
	var apertura := _apertura(_mia())
	for indice in apertura.size():
		if indice != MENSAJE_4:
			assert_int(apertura[indice].count(AMARILLO)).is_zero()


func test_mia_rechaza_un_ajeno_y_el_recordatorio_nombra_lo_que_falta() -> void:  # AC-CTR-159
	var mia := _mia()
	var pedido := mia.pedido().productos()
	var inventario := Apertura.inventario_con_faltantes({}, {}, Catalogo.todos())
	var estante := Estante.new(inventario, Catalogo.todos())
	mia.horario = Vector2(0.0, 1000.0)
	var atencion := Atencion.new(mia, inventario)
	atencion.interactuar(null)
	while not atencion.puede_abandonar():
		atencion.interactuar(null)
	assert_int(atencion.interactuar(estante.retirar(pedido[0]))).is_equal(
		RecepcionDeCompra.Resultado.ACEPTADA
	)
	var del_pedido: Array[Producto.Id] = []
	for producto in pedido:
		del_pedido.append(producto.id)
	var ajeno: Producto = null
	for producto in Catalogo.todos():
		if not del_pedido.has(producto.id):
			ajeno = producto
			break
	assert_object(ajeno).is_not_null()
	assert_int(atencion.interactuar(estante.retirar(ajeno))).is_equal(
		RecepcionDeCompra.Resultado.RECHAZADA
	)
	var rechazo := atencion.dialogo().entrada_actual()
	assert_str(rechazo).not_contains(_presentado(pedido[0]))
	for producto: Producto in pedido.slice(1):
		assert_str(rechazo).contains(_presentado(producto))


func test_mia_vende_una_vez_y_se_retira_tras_dos_entradas_de_despedida() -> void:  # AC-CTR-173
	var mia := _mia()
	assert_int(_despedida(mia).size()).is_equal(ENTRADAS_DE_DESPEDIDA)
	var inventario := Apertura.inventario_con_faltantes({}, {}, Catalogo.todos())
	var estante := Estante.new(inventario, Catalogo.todos())
	mia.horario = Vector2(0.0, 1000.0)
	var atencion := Atencion.new(mia, inventario)
	atencion.interactuar(null)
	while not atencion.puede_abandonar():
		atencion.interactuar(null)
	for producto in mia.pedido().productos():
		atencion.interactuar(estante.retirar(producto))
	assert_int(atencion.interactuar(Ticket.new(mia.pedido().productos()))).is_equal(
		RecepcionDeCompra.Resultado.COMPLETA
	)
	assert_bool(atencion.vendida()).is_true()
	var entradas := 0
	while not atencion.despachada() and entradas <= ENTRADAS_DE_DESPEDIDA:
		entradas += 1
		atencion.interactuar(null)
	assert_int(entradas).is_equal(ENTRADAS_DE_DESPEDIDA)
	assert_bool(atencion.despachada()).is_true()
