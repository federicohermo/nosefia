extends GdUnitTestSuite

const CUARTA := ReglasDeLaPartida.PRIMERA_JORNADA + 3
const PERSONAJE := DialogosDeCompradores.Personaje
const AMARILLO := "[color=#e4f850]"
const SEMILLAS := 120
const ENTRADAS_DE_APERTURA := 6
const ENTRADAS_DE_DESPEDIDA := 1
## Las posiciones del mensaje 3, que nombra Duronga, del 4, que nombra Durextra y el segundo
## producto, y del 5, que nombra el tercero.
const MENSAJE_3 := 2
const MENSAJE_4 := 3
const MENSAJE_5 := 4


func _fede(semilla: int = 5) -> Comprador:
	for comprador in Compradores.de_la_jornada(CUARTA, semilla):
		if comprador.personaje == PERSONAJE.FEDE:
			return comprador
	return null


func _ids(comprador: Comprador) -> Array[Producto.Id]:
	var ids: Array[Producto.Id] = []
	for producto in comprador.pedido().productos():
		ids.append(producto.id)
	return ids


func _entradas(dialogo: Dialogo) -> PackedStringArray:
	var entradas := PackedStringArray()
	while not dialogo.terminado():
		entradas.append(dialogo.entrada_actual())
		dialogo.avanzar()
	return entradas


func _apertura(comprador: Comprador) -> PackedStringArray:
	return _entradas(comprador.dialogos.inicial(comprador.personaje, comprador.pedido()))


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


func test_fede_pide_durextra_primero_y_dos_tipos_mas_de_su_grupo() -> void:  # AC-CTR-174
	var vendibles: Array[Producto.Id] = []
	for producto in Catalogo.de_la_jornada(CUARTA):
		vendibles.append(producto.id)
	var elegibles: Array = Compradores.GRUPOS[PERSONAJE.FEDE].filter(
		func(id: Producto.Id) -> bool: return id in vendibles and id != Producto.Id.DURONGA
	)
	var vistos: Dictionary = {}
	for semilla in range(1, SEMILLAS + 1):
		var fede := _fede(semilla)
		var ids := _ids(fede)
		assert_array(ids).has_size(3)
		assert_int(ids[0]).is_equal(Producto.Id.DUREXTRA)
		assert_int(ids[1]).is_not_equal(ids[2])
		for id: Producto.Id in ids.slice(1):
			assert_array(elegibles).contains([id])
			vistos[id] = true
		for producto in fede.pedido().productos():
			assert_int(fede.pedido().unidades_de(producto)).is_equal(1)
	assert_array(vistos.keys()).contains_exactly_in_any_order(elegibles)


func test_fede_de_la_cuarta_nunca_pide_duronga_aunque_se_venda() -> void:  # AC-CTR-186
	var vendibles: Array[Producto.Id] = []
	for producto in Catalogo.de_la_jornada(CUARTA):
		vendibles.append(producto.id)
	assert_array(vendibles).contains([Producto.Id.DURONGA])
	for semilla in range(1, SEMILLAS + 1):
		assert_array(_ids(_fede(semilla))).not_contains([Producto.Id.DURONGA])
	var en_la_segunda := Compradores.segunda_jornada_definida()
	var ids: Array[Producto.Id] = []
	for comprador in en_la_segunda:
		if comprador.personaje == PERSONAJE.FEDE:
			ids = _ids(comprador)
	assert_array(ids).contains([Producto.Id.DURONGA])


func test_la_misma_semilla_repite_el_pedido_de_fede() -> void:  # AC-CTR-174
	assert_array(_ids(_fede(7))).is_equal(_ids(_fede(7)))
	var firmas: Dictionary = {}
	for semilla in range(1, SEMILLAS + 1):
		firmas[str(_ids(_fede(semilla)))] = true
	assert_int(firmas.size()).is_greater(1)


func test_tia_de_la_cuarta_sigue_sin_durextra() -> void:  # AC-CTR-174
	for semilla in range(1, SEMILLAS + 1):
		var tia := Compradores.de_la_jornada(CUARTA, semilla)[0]
		assert_int(tia.personaje).is_equal(PERSONAJE.TIA)
		assert_array(_ids(tia)).not_contains([Producto.Id.DUREXTRA])
		assert_int(_ids(tia).size()).is_between(2, 3)


func test_fede_dice_seis_entradas_y_nombra_sus_productos_resaltados() -> void:  # AC-CTR-175
	for semilla in range(1, 11):
		var fede := _fede(semilla)
		assert_object(fede.dialogos).is_not_null()
		var apertura := _apertura(fede)
		assert_int(apertura.size()).is_equal(ENTRADAS_DE_APERTURA)
		for entrada: String in apertura:
			assert_str(entrada).not_contains("{").not_contains("}")
		var productos := fede.pedido().productos()
		var durextra := AMARILLO + productos[0].nombre + "[/color]"
		assert_str(apertura[MENSAJE_4]).contains(durextra).contains(_presentado(productos[1]))
		assert_int(apertura[MENSAJE_4].count(AMARILLO)).is_equal(2)
		assert_str(apertura[MENSAJE_5]).contains(_presentado(productos[2]))
		assert_int(apertura[MENSAJE_5].count(AMARILLO)).is_equal(1)


func test_los_demas_mensajes_de_fede_no_resaltan_nada() -> void:  # AC-CTR-175
	var apertura := _apertura(_fede())
	for indice in apertura.size():
		if indice != MENSAJE_4 and indice != MENSAJE_5:
			assert_int(apertura[indice].count(AMARILLO)).is_zero()


func test_la_tercera_entrada_de_fede_nombra_duronga_sin_resaltarlo() -> void:  # AC-CTR-175
	var duronga := Catalogo.de(Producto.Id.DURONGA).nombre
	var tercera := _apertura(_fede())[MENSAJE_3]
	assert_str(tercera).contains(duronga)
	assert_int(tercera.count(AMARILLO)).is_zero()


func test_fede_rechaza_un_ajeno_y_el_recordatorio_nombra_lo_que_falta() -> void:  # AC-CTR-159
	var fede := _fede()
	var pedido := fede.pedido().productos()
	var inventario := Apertura.inventario_con_faltantes({}, {}, Catalogo.todos())
	var estante := Estante.new(inventario, Catalogo.todos())
	fede.horario = Vector2(0.0, 1000.0)
	var atencion := Atencion.new(fede, inventario)
	atencion.interactuar(null)
	while not atencion.puede_abandonar():
		atencion.interactuar(null)
	assert_int(atencion.interactuar(estante.retirar(pedido[0]))).is_equal(
		RecepcionDeCompra.Resultado.ACEPTADA
	)
	var ajeno: Producto = null
	for producto in Catalogo.todos():
		if not _ids(fede).has(producto.id):
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


func test_fede_vende_una_vez_y_se_retira_tras_su_despedida() -> void:  # AC-CTR-175
	var fede := _fede()
	var despedida := _entradas(fede.dialogos.despedida(fede.personaje, fede.pedido()))
	assert_int(despedida.size()).is_equal(ENTRADAS_DE_DESPEDIDA)
	var inventario := Apertura.inventario_con_faltantes({}, {}, Catalogo.todos())
	var estante := Estante.new(inventario, Catalogo.todos())
	fede.horario = Vector2(0.0, 1000.0)
	var atencion := Atencion.new(fede, inventario)
	atencion.interactuar(null)
	while not atencion.puede_abandonar():
		atencion.interactuar(null)
	for producto in fede.pedido().productos():
		atencion.interactuar(estante.retirar(producto))
	assert_int(atencion.interactuar(Ticket.new(fede.pedido().productos()))).is_equal(
		RecepcionDeCompra.Resultado.COMPLETA
	)
	assert_bool(atencion.vendida()).is_true()
	var entradas := 0
	while not atencion.despachada() and entradas <= ENTRADAS_DE_DESPEDIDA:
		entradas += 1
		atencion.interactuar(null)
	assert_int(entradas).is_equal(ENTRADAS_DE_DESPEDIDA)
	assert_bool(atencion.despachada()).is_true()
