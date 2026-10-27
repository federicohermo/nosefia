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


func _ticket_de(ids: Array[Producto.Id]) -> Ticket:
	var productos: Array[Producto] = []
	for id in ids:
		productos.append(Catalogo.de(id))
	return Ticket.new(productos)


func _precio(id: Producto.Id) -> int:
	return Catalogo.de(id).precio


func test_un_producto_repetido_va_en_un_renglon_con_el_precio_sumado() -> void:  # AC-PLY-105
	var ticket := _ticket_de([Producto.Id.MAROLINI, Producto.Id.PURA_COLA, Producto.Id.MAROLINI])
	var lineas := ticket.lineas_impresas()
	assert_int(lineas.size()).is_equal(2)
	assert_bool(lineas[0].begins_with("2x %s" % Catalogo.de(Producto.Id.MAROLINI).nombre)).is_true()
	(
		assert_bool(lineas[0].ends_with("%s$" % _con_miles(2 * _precio(Producto.Id.MAROLINI))))
		. is_true()
	)
	(
		assert_bool(lineas[1].begins_with("1x %s" % Catalogo.de(Producto.Id.PURA_COLA).nombre))
		. is_true()
	)
	assert_bool(lineas[1].ends_with("%s$" % _con_miles(_precio(Producto.Id.PURA_COLA)))).is_true()


func test_el_total_es_la_suma_de_los_precios_de_lista() -> void:  # AC-PLY-105
	var ids: Array[Producto.Id] = [
		Producto.Id.MAROLINI, Producto.Id.PURA_COLA, Producto.Id.MAROLINI
	]
	var esperado := 0
	for id in ids:
		esperado += _precio(id)
	var ticket := _ticket_de(ids)
	assert_int(ticket.total()).is_equal(esperado)
	assert_str(ticket.texto_del_total()).is_equal("%s$" % _con_miles(esperado))


func test_uno_dos_y_tres_productos_dan_uno_dos_y_tres_renglones() -> void:  # AC-PLY-105
	var distintos: Array[Producto.Id] = [
		Producto.Id.MAROLINI, Producto.Id.PURA_COLA, Producto.Id.MALBARDO
	]
	var suma := 0
	for cantidad in range(1, distintos.size() + 1):
		suma += _precio(distintos[cantidad - 1])
		var ticket := _ticket_de(distintos.slice(0, cantidad))
		assert_int(ticket.lineas_impresas().size()).is_equal(cantidad)
		assert_int(ticket.total()).is_equal(suma)


func test_los_renglones_siguen_el_orden_del_programa() -> void:  # AC-PLY-105
	var ticket := _ticket_de([Producto.Id.MALBARDO, Producto.Id.MAROLINI, Producto.Id.PURA_COLA])
	var nombres: Array[String] = []
	for producto: Producto.Id in [
		Producto.Id.MALBARDO, Producto.Id.MAROLINI, Producto.Id.PURA_COLA
	]:
		nombres.append(Catalogo.de(producto).nombre)
	var lineas := ticket.lineas_impresas()
	for indice in nombres.size():
		assert_bool(lineas[indice].contains(nombres[indice])).is_true()


func test_el_precio_lleva_punto_de_miles_y_signo() -> void:  # AC-PLY-105
	assert_str(Ticket.con_precio(900)).is_equal("900$")
	assert_str(Ticket.con_precio(1050)).is_equal("1.050$")
	assert_str(Ticket.con_precio(12500)).is_equal("12.500$")
	assert_str(Ticket.con_precio(1234567)).is_equal("1.234.567$")


func test_el_precio_queda_alineado_a_la_derecha() -> void:  # AC-PLY-106
	var ticket := _ticket_de([Producto.Id.MAROLINI, Producto.Id.FLIM_POF, Producto.Id.MALBARDO])
	var columnas := ticket.columnas()
	for linea in ticket.lineas_impresas():
		assert_int(linea.length()).is_equal(columnas)
		assert_bool(linea.ends_with("$")).is_true()
		assert_bool(linea.contains(".")).is_true()


func test_el_renglon_mas_largo_del_catalogo_con_tres_unidades_entra() -> void:  # AC-PLY-106
	var ticket := _ticket_de(
		[Producto.Id.FEEL_RICKY_FORT, Producto.Id.FEEL_RICKY_FORT, Producto.Id.FEEL_RICKY_FORT]
	)
	var lineas := ticket.lineas_impresas()
	assert_int(lineas.size()).is_equal(1)
	var linea := lineas[0]
	(
		assert_bool(linea.begins_with("3x %s" % Catalogo.de(Producto.Id.FEEL_RICKY_FORT).nombre))
		. is_true()
	)
	(
		assert_bool(linea.ends_with("%s$" % _con_miles(3 * _precio(Producto.Id.FEEL_RICKY_FORT))))
		. is_true()
	)
	assert_int(linea.length()).is_equal(ticket.columnas())
	var nombre := Catalogo.de(Producto.Id.FEEL_RICKY_FORT).nombre
	assert_bool(linea.contains("%s." % nombre)).is_true()


func test_toda_linea_de_todo_producto_cabe_en_las_columnas_del_papel() -> void:  # AC-PLY-106
	for producto in Catalogo.todos():
		var triple := _ticket_de([producto.id, producto.id, producto.id])
		assert_int(triple.lineas_impresas()[0].length()).is_equal(triple.columnas())


func test_el_numero_la_jornada_y_la_hora_quedan_escritos() -> void:  # AC-PLY-107
	var ticket := Ticket.new([Catalogo.de(Producto.Id.MAROLINI)], 887, 4, "22:21")
	assert_str(ticket.texto_del_numero()).is_equal("N°0887")
	assert_str(ticket.texto_de_la_fecha()).is_equal("Día: 4 Hora:22:21")
	var otro := Ticket.new([Catalogo.de(Producto.Id.MAROLINI)], 7, 1, "20:00")
	assert_str(otro.texto_del_numero()).is_equal("N°0007")
	assert_str(ticket.texto_del_numero()).is_equal("N°0887")


func _con_miles(valor: int) -> String:
	var texto := str(valor)
	if texto.length() > 3:
		texto = texto.left(texto.length() - 3) + "." + texto.right(3)
	return texto
