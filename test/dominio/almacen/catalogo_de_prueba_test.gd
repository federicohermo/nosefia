extends GdUnitTestSuite

const PRESENTES: Array[Producto.Id] = [
	Producto.Id.ACTRONCITO,
	Producto.Id.ZUCARACHAS,
	Producto.Id.MALBARDO,
	Producto.Id.PROGRES,
	Producto.Id.JORGILLO,
	Producto.Id.ARVECOR,
	Producto.Id.PEPITO,
	Producto.Id.PURA_COLA,
	Producto.Id.MAROLINI,
	Producto.Id.DON_SATURADOS,
	Producto.Id.PETISAS,
	Producto.Id.DURONGA,
	Producto.Id.FERNET_GOD,
	Producto.Id.MAYONCHIS,
	Producto.Id.TERMINATOR,
	Producto.Id.POETICO,
]


func test_las_tres_jornadas_de_prueba_tienen_sus_dieciseis_productos() -> void:  # AC-STK-095
	for jornada: int in [1, 2, 3]:
		var productos := Catalogo.de_la_jornada(jornada)
		assert_array(_ids(productos)).contains_exactly(PRESENTES)
		var otra := Catalogo.de_la_jornada(jornada)
		for indice in productos.size():
			assert_object(productos[indice]).is_not_same(otra[indice])


func test_desde_la_cuarta_jornada_se_recupera_el_catalogo_completo() -> void:  # AC-STK-095
	for jornada: int in [4, 5, 8]:
		assert_array(_ids(Catalogo.de_la_jornada(jornada))).contains_exactly(Producto.Id.values())


func test_los_pedidos_de_cada_jornada_de_prueba_solo_incluyen_presentes() -> void:  # AC-STK-099
	for jornada: int in [1, 2, 3]:
		var compradores := Compradores.de_la_jornada(jornada)
		assert_array(compradores).is_not_empty()
		for comprador in compradores:
			for producto in comprador.pedido().productos():
				assert_array(PRESENTES).contains([producto.id])


func _ids(productos: Array[Producto]) -> Array[Producto.Id]:
	var ids: Array[Producto.Id] = []
	for producto in productos:
		ids.append(producto.id)
	return ids
