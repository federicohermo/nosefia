## Las filas de la planilla de registrar van en orden alfabético por nombre.
extends GdUnitTestSuite


func _atender_sin_ventas() -> TareaDeAtender:
	var inventario := Inventario.new(Catalogo.todos())
	var compradores: Array[Comprador] = []
	return TareaDeAtender.new(compradores, inventario)


func _con_nombres(nombres: Array[String]) -> RegistroDeVentas:
	var productos: Array[Producto] = []
	for indice in nombres.size():
		productos.append(Producto.new(Producto.Id.values()[indice], nombres[indice], 100))
	return RegistroDeVentas.new(productos, _atender_sin_ventas())


func _nombres(registro: RegistroDeVentas) -> Array[String]:
	var nombres: Array[String] = []
	for producto in registro.productos():
		nombres.append(producto.nombre)
	return nombres


func test_las_filas_van_en_orden_aunque_el_catalogo_las_declare_al_reves() -> void:  # AC-STK-123
	assert_array(_nombres(_con_nombres(["Zeta", "Alfa"]))).is_equal(["Alfa", "Zeta"])


func test_la_mayuscula_y_la_tilde_no_separan_los_nombres() -> void:  # AC-STK-123
	var registro := _con_nombres(
		["bota", "Árbol", "alfa", "Ñandú", "Ñame", "nube", "Zeta", "Éxito", "Ómnibus", "oso"]
	)
	assert_array(_nombres(registro)).is_equal(
		["alfa", "Árbol", "bota", "Éxito", "nube", "Ñame", "Ñandú", "Ómnibus", "oso", "Zeta"]
	)


func test_la_tilde_sola_no_desempata_y_rige_el_catalogo() -> void:  # AC-STK-123
	assert_array(_nombres(_con_nombres(["Poético", "Poetico"]))).is_equal(["Poético", "Poetico"])
	assert_array(_nombres(_con_nombres(["Poetico", "Poético"]))).is_equal(["Poetico", "Poético"])


func test_las_noches_de_prueba_y_las_completas_van_en_orden() -> void:  # AC-STK-123
	for jornada: int in [2, ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA]:
		var productos := Catalogo.de_la_jornada(jornada)
		var filas := RegistroDeVentas.new(productos, _atender_sin_ventas()).productos()
		assert_int(filas.size()).is_equal(productos.size())
		for indice in range(1, filas.size()):
			(
				assert_bool(filas[indice - 1].nombre.to_lower() <= filas[indice].nombre.to_lower())
				. is_true()
			)


func test_ordenar_no_cambia_lo_anotado_ni_el_total() -> void:  # AC-STK-123
	var registro := _con_nombres(["Zeta", "Alfa"])
	var alfa := registro.productos()[0]
	registro.sumar(alfa)
	registro.sumar(alfa)
	assert_int(registro.unidades_de(alfa)).is_equal(2)
	assert_int(registro.total()).is_equal(alfa.precio * 2)
