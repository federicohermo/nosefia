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
	lectura.append(Catalogo.de(Producto.Id.CORACOLA))
	assert_array(ticket.renglones()).contains_exactly([producto])
