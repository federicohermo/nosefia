extends GdUnitTestSuite


func test_la_unidad_se_puede_llevar_y_conserva_el_producto() -> void:  # 006-AC1
	var producto := Catalogo.todos()[0]
	var unidad := UnidadDeProducto.new(producto)
	assert_object(unidad.producto).is_same(producto)
	assert_str(unidad.nombre).is_equal(producto.nombre)
	assert_bool(unidad.es_levantable()).is_true()
	var manos := Manos.new()
	assert_bool(manos.agarrar(unidad)).is_true()
	assert_object(manos.sostenido()).is_same(unidad)


func test_las_unidades_del_mismo_producto_tienen_la_misma_identidad() -> void:  # 006-AC1
	var primera := UnidadDeProducto.new(Catalogo.todos()[0])
	var segunda := UnidadDeProducto.new(Catalogo.todos()[0])
	assert_str(String(primera.id)).is_equal(String(segunda.id))
	assert_str(String(primera.id)).is_not_empty()
