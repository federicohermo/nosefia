## La última noche ninguna caja trae lo que anuncia: la etiqueta de cada una y su contenido real
## están permutados, y todo lo que la caja decide sigue al contenido.
##
## **Ni un `Node3D` en toda la suite.** Las cajas se arman con un inventario y un estante a mano.
extends GdUnitTestSuite

## Casilleros de la fila de adelante de cada producto de prueba. Sacar no los mira (BR-STK-017).
const CASILLEROS := 8


func _ultima() -> int:
	return ReglasDeLaPartida.PRIMERA_JORNADA + ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA - 1


## El inventario con todo el catálogo y cada caja llena.
func _inventario() -> Inventario:
	var productos := Catalogo.todos()
	var casilleros: Dictionary[Producto.Id, int] = {}
	for producto in productos:
		casilleros[producto.id] = CASILLEROS
	var inventario := Inventario.new(productos, casilleros)
	for producto in productos:
		inventario.ingresar(
			producto, Inventario.Ubicacion.DEPOSITO, ReglasDelEstante.UNIDADES_POR_CAJA
		)
	return inventario


## Su estante, con la permutación que declara esa jornada.
func _estante(jornada: int, inventario: Inventario = null) -> Estante:
	if inventario == null:
		inventario = _inventario()
	return Estante.new(
		inventario, Catalogo.todos(), {}, AnomaliasDeLaJornada.contenidos_de_las_cajas(jornada)
	)


func _caja(etiqueta: Producto.Id, estante: Estante) -> ContenidoDeLaCaja:
	return ContenidoDeLaCaja.new(Catalogo.de(etiqueta), estante)


## El producto que trae la caja con esa etiqueta, en la última noche.
func _real(etiqueta: Producto.Id) -> Producto.Id:
	return AnomaliasDeLaJornada.contenido_de_la_caja(etiqueta, _ultima())


func test_la_ultima_noche_cada_caja_trae_otro_producto_y_ninguno_se_repite() -> void:  # AC-ANO-005
	var etiquetas: Array[Producto.Id] = []
	var contenidos: Array[Producto.Id] = []
	for producto in Catalogo.todos():
		etiquetas.append(producto.id)
		contenidos.append(_real(producto.id))
		assert_bool(_real(producto.id) == producto.id).is_false()
	assert_array(contenidos).contains_exactly_in_any_order(etiquetas)


func test_la_permutacion_es_la_misma_en_cada_apertura() -> void:  # AC-ANO-005
	for producto in Catalogo.todos():
		var primera := AnomaliasDeLaJornada.contenido_de_la_caja(producto.id, _ultima())
		var segunda := AnomaliasDeLaJornada.contenido_de_la_caja(producto.id, _ultima())
		assert_int(primera).is_equal(segunda)
		var estante := _estante(_ultima())
		assert_int(_caja(producto.id, estante).producto.id).is_equal(primera)


func test_antes_de_la_ultima_noche_cada_caja_trae_su_etiqueta() -> void:  # AC-ANO-005
	for jornada in range(ReglasDeLaPartida.PRIMERA_JORNADA, _ultima()):
		var estante := _estante(jornada)
		for producto in Catalogo.todos():
			assert_int(AnomaliasDeLaJornada.contenido_de_la_caja(producto.id, jornada)).is_equal(
				producto.id
			)
			assert_int(_caja(producto.id, estante).producto.id).is_equal(producto.id)


func test_sacar_entrega_el_contenido_real_y_no_la_etiqueta() -> void:  # AC-ANO-006
	var etiqueta := Producto.Id.ACTRONCITO
	var real := _real(etiqueta)
	var estante := _estante(_ultima())
	var caja := _caja(etiqueta, estante)
	var unidad := caja.sacar()
	assert_object(unidad).is_not_null()
	assert_int(unidad.producto.id).is_equal(real)
	assert_int(caja.unidades()).is_equal(ReglasDelEstante.UNIDADES_POR_CAJA - 1)
	assert_int(estante.unidades_en_deposito(Catalogo.de(etiqueta))).is_equal(
		ReglasDelEstante.UNIDADES_POR_CAJA
	)
	assert_int(estante.reservadas(Catalogo.de(etiqueta))).is_zero()


func test_la_caja_vacia_no_da_aunque_otra_caja_traiga_su_etiqueta() -> void:  # AC-ANO-006
	var etiqueta := Producto.Id.ACTRONCITO
	var estante := _estante(_ultima())
	var caja := _caja(etiqueta, estante)
	for vez in ReglasDelEstante.UNIDADES_POR_CAJA:
		assert_object(caja.sacar()).is_not_null()
	assert_int(estante.unidades_en_deposito(Catalogo.de(etiqueta))).is_equal(
		ReglasDelEstante.UNIDADES_POR_CAJA
	)
	assert_int(caja.unidades()).is_zero()
	assert_object(caja.sacar()).is_null()


func test_antes_de_la_ultima_noche_sacar_entrega_la_etiqueta() -> void:  # AC-ANO-006
	for jornada in range(ReglasDeLaPartida.PRIMERA_JORNADA, _ultima()):
		var unidad := _caja(Producto.Id.ACTRONCITO, _estante(jornada)).sacar()
		assert_int(unidad.producto.id).is_equal(Producto.Id.ACTRONCITO)


func test_meter_rechaza_la_etiqueta_y_acepta_el_contenido_real() -> void:  # AC-ANO-007
	var etiqueta := Producto.Id.ACTRONCITO
	var estante := _estante(_ultima())
	var caja := _caja(etiqueta, estante)
	var del_contenido := caja.sacar()
	var de_la_etiqueta := UnidadDeProducto.new(Catalogo.de(etiqueta))
	var sacadas := ReglasDelEstante.UNIDADES_POR_CAJA - 1
	assert_bool(caja.meter(de_la_etiqueta)).is_false()
	assert_int(caja.unidades()).is_equal(sacadas)
	assert_int(caja.uso(de_la_etiqueta, true)).is_equal(ContenidoDeLaCaja.Gesto.NADA)
	var contexto := ReferenciaDeControles.contexto_de_la_caja(caja, de_la_etiqueta)
	assert_int(contexto.primario).is_equal(ReferenciaDeControles.Linea.NINGUNA)
	contexto = ReferenciaDeControles.contexto_de_la_caja(caja, del_contenido)
	assert_int(contexto.primario).is_equal(ReferenciaDeControles.Linea.METER_PRODUCTO)
	assert_bool(caja.meter(del_contenido)).is_true()
	assert_int(caja.unidades()).is_equal(ReglasDelEstante.UNIDADES_POR_CAJA)


func test_la_caja_llena_no_recibe_ni_ofrece_meter() -> void:  # AC-ANO-007
	var etiqueta := Producto.Id.ACTRONCITO
	var caja := _caja(etiqueta, _estante(_ultima()))
	var del_contenido := UnidadDeProducto.new(Catalogo.de(_real(etiqueta)))
	assert_bool(caja.meter(del_contenido)).is_false()
	assert_int(caja.unidades()).is_equal(ReglasDelEstante.UNIDADES_POR_CAJA)
	var contexto := ReferenciaDeControles.contexto_de_la_caja(caja, del_contenido)
	assert_int(contexto.primario).is_equal(ReferenciaDeControles.Linea.NINGUNA)


func test_examinar_dice_el_contenido_real_con_8_5_y_0() -> void:  # AC-ANO-008
	var etiqueta := Producto.Id.ACTRONCITO
	var real := Catalogo.de(_real(etiqueta))
	var rotulada := Catalogo.de(etiqueta)
	var estante := _estante(_ultima())
	var caja := _caja(etiqueta, estante)
	var esperados := [[8, 0], [5, 3], [0, 8]]
	for caso: Array in esperados:
		while caja.unidades() > caso[0]:
			caja.sacar()
		var datos := caja.datos_del_examen()
		assert_int(datos.producto).is_equal(real.id)
		assert_int(datos.unidades).is_equal(caso[0])
		assert_int(datos.entran).is_equal(caso[1])
		var texto := caja.texto_del_examen()
		assert_str(texto).contains(real.nombre)
		assert_str(texto).contains(str(caso[0]))
		assert_bool(texto.contains(rotulada.nombre)).is_false()
	assert_int(caja.unidades()).is_zero()


func test_antes_de_la_ultima_noche_examinar_dice_la_etiqueta() -> void:  # AC-ANO-008
	var caja := _caja(Producto.Id.ACTRONCITO, _estante(ReglasDeLaPartida.PRIMERA_JORNADA))
	assert_str(caja.texto_del_examen()).contains(Catalogo.de(Producto.Id.ACTRONCITO).nombre)


func test_la_venta_resta_de_la_caja_que_trae_el_producto() -> void:  # AC-ANO-009
	var vendido := Catalogo.de(Producto.Id.ACTRONCITO)
	var inventario := _inventario()
	inventario.ingresar(vendido, Inventario.Ubicacion.GONDOLA, 1)
	var estante := _estante(_ultima(), inventario)
	var etiqueta_que_lo_trae := Producto.Id.ACTRONCITO
	for producto in Catalogo.todos():
		if _real(producto.id) == vendido.id:
			etiqueta_que_lo_trae = producto.id
	assert_bool(etiqueta_que_lo_trae == vendido.id).is_false()
	var venta := Venta.new()
	venta.agregar(vendido, 1)
	var con_su_etiqueta := _caja(vendido.id, estante)
	var con_su_contenido := _caja(etiqueta_que_lo_trae, estante)
	var propias_antes := con_su_etiqueta.unidades()
	assert_bool(inventario.cobrar(venta)).is_true()
	assert_int(con_su_contenido.unidades()).is_equal(ReglasDelEstante.UNIDADES_POR_CAJA - 1)
	assert_int(con_su_etiqueta.unidades()).is_equal(propias_antes)


func test_la_unidad_sacada_se_coloca_en_la_gondola_de_su_producto() -> void:  # AC-ANO-009
	var etiqueta := Producto.Id.ACTRONCITO
	var real := Catalogo.de(_real(etiqueta))
	var estante := _estante(_ultima())
	var unidad := _caja(etiqueta, estante).sacar()
	assert_int(estante.colocar_unidad(unidad)).is_equal(Estante.Rechazo.NINGUNO)
	assert_int(estante.unidades_en_gondola(real)).is_equal(1)
	assert_int(estante.unidades_en_gondola(Catalogo.de(etiqueta))).is_zero()


func test_la_apertura_deja_cada_caja_llena_y_el_catalogo_intacto() -> void:  # AC-ANO-009
	var casilleros: Dictionary[Producto.Id, int] = {}
	for producto in Catalogo.todos():
		casilleros[producto.id] = CASILLEROS
	var jornada := _ultima()
	var productos := Catalogo.de_la_jornada(jornada)
	var inventario := Apertura.inventario_de_la_jornada(
		jornada,
		Compradores.de_la_jornada(jornada),
		casilleros,
		casilleros,
		RandomNumberGenerator.new()
	)
	var estante := Estante.new(
		inventario, productos, {}, AnomaliasDeLaJornada.contenidos_de_las_cajas(jornada)
	)
	var ids: Array[Producto.Id] = []
	for producto in Catalogo.todos():
		ids.append(producto.id)
		assert_int(_caja(producto.id, estante).unidades()).is_equal(
			ReglasDelEstante.UNIDADES_POR_CAJA
		)
	var contenidos: Array[Producto.Id] = []
	for id in ids:
		contenidos.append(_real(id))
	assert_array(contenidos).contains_exactly_in_any_order(ids)
