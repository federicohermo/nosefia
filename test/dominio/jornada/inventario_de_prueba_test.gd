extends GdUnitTestSuite


func test_ausentes_no_tienen_stock_ni_cupo_aunque_la_escena_los_declare() -> void:  # AC-STK-095
	var casilleros := _casilleros()
	for jornada: int in [1, 2, 3]:
		for semilla in 200:
			var azar := RandomNumberGenerator.new()
			azar.seed = semilla
			var inventario := Apertura.inventario_de_la_jornada(
				jornada, Compradores.de_la_jornada(jornada), casilleros, casilleros, azar
			)
			for producto in Catalogo.todos():
				var presente := producto.id in Catalogo.PRODUCTOS_DE_PRUEBA
				assert_int(inventario.casilleros(producto)).is_equal(8 if presente else 0)
				assert_int(inventario.unidades(producto, Inventario.Ubicacion.DEPOSITO)).is_equal(
					ReglasDelEstante.UNIDADES_POR_CAJA if presente else 0
				)
				if not presente:
					(
						assert_int(inventario.unidades(producto, Inventario.Ubicacion.GONDOLA))
						. is_zero()
					)
					if inventario.casilleros(producto) > 0:
						return
			for producto in inventario.faltantes():
				assert_array(Catalogo.PRODUCTOS_DE_PRUEBA).contains([producto.id])


func test_las_compras_y_reposicion_de_prueba_caben_en_una_caja() -> void:  # AC-STK-099
	var casilleros := _casilleros()
	for jornada: int in [1, 2, 3]:
		for semilla in 200:
			var azar := RandomNumberGenerator.new()
			azar.seed = semilla
			var compradores := Compradores.de_la_jornada(jornada)
			var inventario := Apertura.inventario_de_la_jornada(
				jornada, compradores, casilleros, casilleros, azar
			)
			for comprador in compradores:
				assert_bool(inventario.cobrar(comprador.pedido())).is_true()
			var estante := Estante.new(inventario, Catalogo.de_la_jornada(jornada))
			for producto in inventario.faltantes():
				for indice in estante.casilleros_vacios(producto):
					assert_int(estante.colocar(producto, indice)).is_equal(Estante.Rechazo.NINGUNO)
			assert_bool(estante.completada()).is_true()


func test_jornadas_completas_recuperan_todas_las_cajas_y_cupos() -> void:  # AC-STK-095
	for jornada: int in [4, 8]:
		var inventario := Apertura.inventario_de_la_jornada(
			jornada,
			Compradores.de_la_jornada(jornada),
			_casilleros(),
			_casilleros(),
			RandomNumberGenerator.new()
		)
		for producto in Catalogo.todos():
			assert_int(inventario.casilleros(producto)).is_equal(8)
			assert_int(inventario.unidades(producto, Inventario.Ubicacion.DEPOSITO)).is_equal(
				ReglasDelEstante.UNIDADES_POR_CAJA
			)


func _casilleros() -> Dictionary[Producto.Id, int]:
	var casilleros: Dictionary[Producto.Id, int] = {}
	for producto in Catalogo.todos():
		casilleros[producto.id] = 8
	return casilleros
