extends GdUnitTestSuite


func test_el_papel_se_levanta_y_suena_como_papel() -> void:  # AC-PLY-075
	var ticket := Ticket.new()
	assert_str(String(ticket.id)).is_equal("ticket")
	assert_str(ticket.nombre).is_equal("Ticket")
	assert_bool(ticket.es_levantable()).is_true()
	assert_int(ticket.sonoridad).is_equal(EntradaSonora.Sonoridad.PAPEL)


func test_el_papel_copia_los_productos_recibidos() -> void:  # AC-CTR-023
	var producto := Catalogo.de(Producto.Id.MAROLINI)
	var productos: Array[Producto] = [producto]
	var ticket := Ticket.new(productos)
	productos.clear()
	assert_array(ticket.renglones()).contains_exactly([producto])


func test_leer_el_papel_no_permite_reescribirlo() -> void:  # AC-CTR-023
	var producto := Catalogo.de(Producto.Id.MAROLINI)
	var ticket := Ticket.new([producto])
	var lectura := ticket.renglones()
	lectura.append(Catalogo.de(Producto.Id.PURA_COLA))
	assert_array(ticket.renglones()).contains_exactly([producto])


func test_solo_el_tipo_ticket_se_desecha_en_inodoro() -> void:  # AC-CTR-031, AC-CTR-032
	var ticket := Ticket.new([Catalogo.de(Producto.Id.MAROLINI)])
	assert_bool(Ticket.se_desecha_en(ticket, ReglasDeLaLimpieza.ID_DEL_INODORO)).is_true()
	var impostor := ObjetoDelAlmacen.new()
	impostor.id = Ticket.ID
	var objetos: Array[ObjetoDelAlmacen] = [
		null, impostor, UnidadDeProducto.new(Catalogo.de(Producto.Id.MAROLINI))
	]
	for objeto in objetos:
		assert_bool(Ticket.se_desecha_en(objeto, ReglasDeLaLimpieza.ID_DEL_INODORO)).is_false()
	for destino: StringName in [
		ReglasDeLaLimpieza.ID_DEL_LAVATORIO, &"", ReglasDeLaLimpieza.ID_DEL_BALDE, &"otro"
	]:
		assert_bool(Ticket.se_desecha_en(ticket, destino)).is_false()
	assert_int(ticket.renglones().size()).is_equal(1)
	assert_int(ticket.renglones()[0].id).is_equal(Producto.Id.MAROLINI)


func test_el_ticket_dice_que_productos_tiene_en_el_orden_de_sus_renglones() -> void:  # AC-SUB-014
	var m := Producto.Id.MAROLINI
	var c := Producto.Id.PURA_COLA
	var b := Producto.Id.MALBARDO
	var casos := [
		[[m], {m: 1}],
		[[m, m, c], {m: 2, c: 1}],
		[[m, c, b], {m: 1, c: 1, b: 1}],
		[[b, b, b], {b: 3}],
		[[c, m, c], {c: 2, m: 1}],
		[[], {}],
	]
	for caso: Array in casos:
		var productos: Array[Producto] = []
		for id: Producto.Id in caso[0]:
			productos.append(Catalogo.de(id))
		var ticket := Ticket.new(productos)
		assert_str(String(ticket.id)).is_equal(String(Ticket.ID))
		assert_dict(ticket.resumen()).is_equal(caso[1])
		assert_array(ticket.resumen().keys()).contains_exactly(caso[1].keys())
		assert_str(ticket.texto_al_examinar()).is_not_empty()
