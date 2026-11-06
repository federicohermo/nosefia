## Las cinco cajas que abren vacías en la jornada del pedido al proveedor (BR-STK-055): cuáles son,
## de dónde salen y qué pasa con ellas.
extends GdUnitTestSuite

const PEDIDO := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 3
const SEMILLAS := 20

## Una fila de cuatro casilleros por producto: lo bastante para que los faltantes se sorteen.
const CASILLEROS := 4


func _vacias(semilla: int, jornada: int = PEDIDO) -> Array[Producto.Id]:
	var compradores := Compradores.de_la_jornada(jornada, semilla)
	return Apertura.cajas_vacias_de_la_jornada(jornada, compradores, semilla)


func _tandas(jornada: int) -> Dictionary[Producto.Id, Array]:
	var tandas: Dictionary[Producto.Id, Array] = {}
	for producto in Catalogo.de_la_jornada(jornada):
		tandas[producto.id] = [PackedInt32Array(range(CASILLEROS))]
	return tandas


func _faltantes(semilla: int, vacias: Array[Producto.Id]) -> Array[Producto.Id]:
	var azar := RandomNumberGenerator.new()
	azar.seed = semilla
	var compradores := Compradores.de_la_jornada(PEDIDO, semilla)
	var vacios := Apertura.vacios_de_la_jornada(
		PEDIDO, compradores, _tandas(PEDIDO), azar, {}, vacias
	)
	var ids: Array[Producto.Id] = []
	ids.assign(Apertura.faltantes_de(vacios).keys())
	return ids


func test_la_sexta_noche_abre_con_cinco_cajas_vacias_una_de_fernet() -> void:  # AC-STK-126
	for semilla in SEMILLAS:
		var vacias := _vacias(semilla + 1)
		assert_int(vacias.size()).is_equal(Apertura.CAJAS_VACIAS)
		assert_bool(vacias.has(Apertura.PRODUCTO_CON_CAJA_VACIA)).is_true()
		assert_int(Producto.Id.FERNET_GOD).is_equal(Apertura.PRODUCTO_CON_CAJA_VACIA)
		var distintas := {}
		for id in vacias:
			distintas[id] = true
		assert_int(distintas.size()).is_equal(vacias.size())


func test_el_inventario_deja_en_cero_esas_cajas_y_llena_las_demas() -> void:  # AC-STK-126
	for semilla in SEMILLAS:
		var vacias := _vacias(semilla + 1)
		var productos := Catalogo.de_la_jornada(PEDIDO)
		var inventario := Apertura.inventario_con_faltantes({}, {}, productos, vacias)
		var en_cero := 0
		for producto in productos:
			var unidades := inventario.unidades(producto, Inventario.Ubicacion.DEPOSITO)
			if vacias.has(producto.id):
				assert_int(unidades).is_zero()
				en_cero += 1
			else:
				assert_int(unidades).is_equal(ReglasDelEstante.UNIDADES_POR_CAJA)
		assert_int(en_cero).is_equal(Apertura.CAJAS_VACIAS)


func test_las_vacias_no_son_faltantes_ni_las_piden_los_compradores() -> void:  # AC-STK-127
	for semilla in SEMILLAS:
		var vacias := _vacias(semilla + 1)
		var pedidos := Apertura.pedidos_de(Compradores.de_la_jornada(PEDIDO, semilla + 1))
		var faltantes := _faltantes(semilla + 1, vacias)
		for id in vacias:
			(
				assert_bool(faltantes.has(id))
				. override_failure_message("semilla %d" % semilla)
				. is_false()
			)
			assert_bool(pedidos.has(id)).override_failure_message("semilla %d" % semilla).is_false()
		assert_bool(faltantes.has(Producto.Id.FERNET_GOD)).is_false()
		assert_bool(pedidos.has(Producto.Id.FERNET_GOD)).is_false()


func test_la_misma_semilla_da_las_mismas_cinco_y_otra_da_otras() -> void:  # AC-STK-128
	var distintas := false
	var anterior: Array[Producto.Id] = _vacias(1)
	for semilla in SEMILLAS:
		var una := _vacias(semilla + 1)
		assert_array(_vacias(semilla + 1)).is_equal(una)
		distintas = distintas or una != anterior
	assert_bool(distintas).is_true()


func test_ninguna_otra_jornada_abre_cajas_vacias() -> void:  # AC-STK-128
	for jornada in range(ReglasDeLaPartida.PRIMERA_JORNADA, PEDIDO + 2):
		if jornada == PEDIDO:
			continue
		assert_array(_vacias(1, jornada)).is_empty()
		var productos := Catalogo.de_la_jornada(jornada)
		var inventario := Apertura.inventario_con_faltantes({}, {}, productos, _vacias(1, jornada))
		for producto in productos:
			assert_int(inventario.unidades(producto, Inventario.Ubicacion.DEPOSITO)).is_equal(
				ReglasDelEstante.UNIDADES_POR_CAJA
			)


func test_una_caja_vacia_se_examina_en_cero_y_no_entrega_nada() -> void:  # AC-STK-129
	var vacias := _vacias(1)
	var productos := Catalogo.de_la_jornada(PEDIDO)
	var inventario := Apertura.inventario_con_faltantes({}, {}, productos, vacias)
	var estante := Estante.new(inventario, productos)
	var caja := ContenidoDeLaCaja.new(Catalogo.de(Producto.Id.FERNET_GOD), estante)
	var datos := caja.datos_del_examen()
	assert_int(datos.unidades).is_zero()
	assert_int(datos.entran).is_equal(ReglasDelEstante.UNIDADES_POR_CAJA)
	assert_object(caja.sacar()).is_null()
	assert_int(caja.unidades()).is_zero()
	(
		assert_int(
			inventario.unidades(Catalogo.de(Producto.Id.FERNET_GOD), Inventario.Ubicacion.DEPOSITO)
		)
		. is_zero()
	)
