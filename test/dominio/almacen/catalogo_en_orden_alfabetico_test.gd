## El orden alfabético de los productos es uno: el de la planilla y el de los menús del programa.
extends GdUnitTestSuite


func _con_nombres(nombres: Array[String]) -> Array[Producto]:
	var productos: Array[Producto] = []
	for indice in nombres.size():
		productos.append(Producto.new(Producto.Id.values()[indice], nombres[indice], 100))
	return productos


func _nombres(productos: Array[Producto]) -> Array[String]:
	var nombres: Array[String] = []
	for producto in productos:
		nombres.append(producto.nombre)
	return nombres


func test_ordena_por_nombre_aunque_se_declaren_al_reves() -> void:  # AC-CTR-030
	var ordenados := Catalogo.en_orden_alfabetico(_con_nombres(["Zeta", "Alfa"]))
	assert_array(_nombres(ordenados)).is_equal(["Alfa", "Zeta"])


func test_la_enie_va_entre_la_n_y_la_o_sin_mayuscula_ni_tilde() -> void:  # AC-CTR-030
	var ordenados := Catalogo.en_orden_alfabetico(
		_con_nombres(
			["bota", "Árbol", "alfa", "Ñandú", "Ñame", "nube", "Zeta", "Éxito", "Ómnibus", "oso"]
		)
	)
	assert_array(_nombres(ordenados)).is_equal(
		["alfa", "Árbol", "bota", "Éxito", "nube", "Ñame", "Ñandú", "Ómnibus", "oso", "Zeta"]
	)


func test_la_tilde_sola_no_desempata_y_rige_el_orden_recibido() -> void:  # AC-CTR-030
	var ordenados := Catalogo.en_orden_alfabetico(_con_nombres(["Poético", "Poetico"]))
	assert_array(_nombres(ordenados)).is_equal(["Poético", "Poetico"])
	ordenados = Catalogo.en_orden_alfabetico(_con_nombres(["Poetico", "Poético"]))
	assert_array(_nombres(ordenados)).is_equal(["Poetico", "Poético"])


func test_devuelve_una_copia_y_no_toca_el_arreglo_recibido() -> void:  # AC-CTR-030
	var recibidos := _con_nombres(["Zeta", "Alfa"])
	var ordenados := Catalogo.en_orden_alfabetico(recibidos)
	assert_array(_nombres(recibidos)).is_equal(["Zeta", "Alfa"])
	ordenados.clear()
	assert_int(recibidos.size()).is_equal(2)


func test_ordenar_el_catalogo_completo_conserva_los_mismos_productos() -> void:  # AC-CTR-030
	var todos := Catalogo.todos()
	var ordenados := Catalogo.en_orden_alfabetico(todos)
	assert_int(ordenados.size()).is_equal(todos.size())
	for producto in todos:
		(
			assert_int(
				ordenados.filter(func(otro: Producto) -> bool: return otro.id == producto.id).size()
			)
			. is_equal(1)
		)
	for indice in range(1, ordenados.size()):
		(
			assert_bool(
				ordenados[indice - 1].nombre.to_lower() <= ordenados[indice].nombre.to_lower()
			)
			. is_true()
		)
