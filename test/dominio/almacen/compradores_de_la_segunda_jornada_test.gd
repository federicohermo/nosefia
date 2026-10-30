extends GdUnitTestSuite


func _fabrica() -> Array[Comprador]:
	var fabrica: GDScript = load("res://src/dominio/almacen/compradores.gd")
	if not fabrica.has_method("segunda_jornada_definida"):
		return []
	return fabrica.call("segunda_jornada_definida")


func test_identidades_horarios_y_seis_productos_en_orden() -> void:  # AC-CTR-050, AC-CTR-051
	var compradores := _fabrica()
	assert_array(compradores).has_size(2)
	if compradores.size() != 2:
		return
	var pedidos: Array[Array] = [
		[Producto.Id.POETICO, Producto.Id.PROGRES, Producto.Id.DURONGA],
		[Producto.Id.TERMINATOR, Producto.Id.FERNET_GOD, Producto.Id.ACTRONCITO]
	]
	for indice in 2:
		assert_str(compradores[indice].nombre()).is_equal(["Fede", "Mía"][indice])
		assert_that(compradores[indice].horario).is_equal(
			[Vector2(4500, 13500), Vector2(18000, 27000)][indice]
		)
		assert_int(compradores[indice].personaje).is_equal(indice + 3)
		assert_int(compradores[indice].pedido().productos().size()).is_equal(3)
		for linea in 3:
			var producto := compradores[indice].pedido().productos()[linea]
			assert_int(producto.id).is_equal(pedidos[indice][linea])
			assert_int(compradores[indice].pedido().unidades_de(producto)).is_equal(1)
	assert_int(DialogosDeCompradores.Personaje.TIN).is_equal(1)
	assert_int(DialogosDeCompradores.Personaje.TIA).is_equal(2)


func test_cada_llamada_y_cada_apertura_tienen_estado_propio() -> void:  # AC-CTR-051
	var primera := _fabrica()
	var segunda := _fabrica()
	assert_array(primera).has_size(2)
	if primera.size() != 2:
		return
	for indice in 2:
		assert_object(primera[indice]).is_not_same(segunda[indice])
		assert_object(primera[indice].pedido()).is_not_same(segunda[indice].pedido())
		assert_int(primera[indice].pedido().total()).is_equal(segunda[indice].pedido().total())
	var tarea := TareaDeAtender.new(primera, Inventario.new(Catalogo.todos()))
	tarea.avanzar(Reglas.DURACION_DEL_TURNO)
	assert_bool(tarea.completada()).is_false()
	var nueva := TareaDeAtender.new(segunda, Inventario.new(Catalogo.todos()))
	assert_object(nueva.atencion()).is_null()
	assert_bool(nueva.compras_cerradas()).is_false()
	for jornada in range(6, AnomaliasDeLaJornada.JORNADA_DEL_CORTE):
		assert_str(Compradores.de_la_jornada(jornada)[0].nombre()).is_equal("Marta")


func test_un_id_ausente_rechaza_el_pedido_completo() -> void:  # AC-CTR-051
	var rechazados: Array[Comprador] = []
	var intentar := func() -> void:
		rechazados.append(
			Compradores._comprador_de(["Inválido", [[Producto.Id.POETICO, 1], [999, 1]], 0])
		)
	await assert_error(intentar).is_push_error("El pedido requiere un producto sin catálogo: 999")
	assert_array(rechazados).has_size(1)
	assert_object(rechazados[0]).is_null()


func _comun(lineas: Array) -> Atencion:
	var pedido := Venta.new()
	for linea: Array in lineas:
		pedido.agregar(Catalogo.de(linea[0]), linea[1])
	var comprador := Comprador.new("Fixture Fede", pedido, pedido.total())
	comprador.personaje = 3
	comprador.horario = Vector2(4500, 13500)
	comprador.dialogos = DialogosDeCompradores.new()
	# Antes de la implementación el legado permite llegar al recordatorio; ese texto debe fallar.
	comprador.dialogos.tin = PackedStringArray(["Inicial"])
	comprador.dialogos.set("fede", PackedStringArray(["Inicial"]))
	var inventario := Inventario.new(Catalogo.todos())
	for producto in Catalogo.todos():
		inventario.ingresar(producto, Inventario.Ubicacion.DEPOSITO, 12)
	var atencion := Atencion.new(comprador, inventario)
	atencion.interactuar(null)
	atencion.interactuar(null)
	return atencion


func test_los_comunes_reemplazan_uno_dos_y_tres_marcadores() -> void:  # AC-CTR-053
	var casos: Array[Array] = [
		[[Producto.Id.POETICO, 3]],
		[[Producto.Id.POETICO, 2], [Producto.Id.PROGRES, 1]],
		[[Producto.Id.POETICO, 1], [Producto.Id.PROGRES, 1], [Producto.Id.DURONGA, 1]],
	]
	for caso: Array in casos:
		var atencion := _comun(caso)
		var original := atencion.comprador().pedido()
		atencion.interactuar(null)
		var texto := atencion.dialogo().entrada_actual()
		assert_int(texto.count("[color=#e4f850]")).is_equal(original.productos().size())
		assert_str(texto).not_contains("[b]")
		assert_str(texto).not_contains("#e7a1f4")
		atencion.interactuar(null)
		atencion.interactuar(Ticket.new([]))
		assert_str(atencion.dialogo().entrada_actual()).is_equal(
			DialogosDeCompradores.RECHAZO + texto
		)
		assert_object(atencion.comprador().pedido()).is_same(original)


# AC-CTR-053, AC-CTR-051, AC-CTR-066
func test_el_recordatorio_nombra_lo_que_falta_y_pide_ticket_al_completar_productos() -> void:
	var atencion := _comun(
		[[Producto.Id.POETICO, 1], [Producto.Id.PROGRES, 1], [Producto.Id.DURONGA, 1]]
	)
	var pedido := atencion.comprador().pedido()
	var inventario: Inventario = atencion.get("_inventario")
	var estante := Estante.new(inventario, Catalogo.todos())
	var primero := estante.retirar(pedido.productos()[0])
	assert_int(atencion.interactuar(primero)).is_equal(RecepcionDeCompra.Resultado.ACEPTADA)
	atencion.interactuar(null)
	atencion.interactuar(null)
	var texto := atencion.dialogo().entrada_actual()
	assert_int(texto.count("[color=#e4f850]")).is_equal(pedido.productos().size() - 1)
	atencion.interactuar(null)
	for producto: Producto in pedido.productos().slice(1):
		assert_int(atencion.interactuar(estante.retirar(producto))).is_equal(
			RecepcionDeCompra.Resultado.ACEPTADA
		)
	atencion.interactuar(null)
	atencion.interactuar(null)
	assert_str(atencion.dialogo().entrada_actual()).is_equal(DialogosDeCompradores.PIDE_EL_TICKET)
	assert_object(atencion.comprador().pedido()).is_same(pedido)
	assert_bool(atencion.vendida()).is_false()


func test_cada_identidad_elige_su_guion_sin_caer_en_tin() -> void:  # AC-CTR-051
	var textos := DialogosDeCompradores.new()
	textos.tin = PackedStringArray(["Tin legado"])
	textos.tia = PackedStringArray(["Tia legado"])
	textos.set("fede", PackedStringArray(["Inicial Fede fixture"]))
	textos.set("mia", PackedStringArray(["Inicial Mía fixture"]))
	textos.set("despedida_fede", PackedStringArray(["Despedida Fede fixture"]))
	textos.set("despedida_mia", PackedStringArray(["Despedida Mía fixture"]))
	for indice in 2:
		assert_str(textos.inicial(indice + 3).entrada_actual()).is_equal(
			["Inicial Fede fixture", "Inicial Mía fixture"][indice]
		)
		assert_str(textos.despedida(indice + 3).entrada_actual()).is_equal(
			["Despedida Fede fixture", "Despedida Mía fixture"][indice]
		)
		var cursor := textos.inicial(indice + 3)
		cursor.avanzar()
		assert_bool(textos.inicial(indice + 3).terminado()).is_false()
