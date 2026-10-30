extends GdUnitTestSuite

var _inventario: Inventario
var _estante: Estante


func before_test() -> void:
	_inventario = Apertura.inventario_con_faltantes({}, {}, Catalogo.todos())
	_estante = Estante.new(_inventario, Catalogo.todos())


func test_la_inicial_y_la_despedida_abren_la_ventanilla() -> void:  # AC-CTR-097
	var atencion := Atencion.new(_comprador(), _inventario)
	assert_bool(atencion.abre_la_ventanilla()).is_false()
	atencion.interactuar(null)
	assert_bool(atencion.abre_la_ventanilla()).is_true()
	assert_str(atencion.tomar_aviso()).is_empty()
	while atencion.abre_la_ventanilla():
		atencion.interactuar(null)
	atencion.interactuar(_unidad(Producto.Id.ZUCARACHAS))
	atencion.interactuar(_unidad(Producto.Id.PEPITO))
	assert_int(atencion.interactuar(_ticket())).is_equal(RecepcionDeCompra.Resultado.COMPLETA)
	assert_bool(atencion.abre_la_ventanilla()).is_true()
	assert_str(atencion.tomar_aviso()).is_empty()
	while atencion.abre_la_ventanilla():
		atencion.interactuar(null)
	assert_bool(atencion.despachada()).is_true()


func test_vencer_cierra_la_inicial_a_medias_sin_abrir_otra_ventanilla() -> void:  # AC-CTR-097
	var atencion := Atencion.new(_comprador(), _inventario)
	atencion.interactuar(null)
	assert_bool(atencion.abre_la_ventanilla()).is_true()
	atencion.vencer()
	assert_bool(atencion.abre_la_ventanilla()).is_false()
	assert_str(atencion.tomar_aviso()).is_empty()


func test_entregar_no_abre_la_ventanilla_y_el_texto_se_toma_una_vez() -> void:  # AC-CTR-096
	var atencion := _atencion_atendida()
	var primero := _unidad(Producto.Id.ZUCARACHAS)
	assert_int(atencion.interactuar(primero)).is_equal(RecepcionDeCompra.Resultado.ACEPTADA)
	assert_bool(atencion.abre_la_ventanilla()).is_false()
	assert_bool(atencion.puede_abandonar()).is_true()
	assert_str(atencion.tomar_aviso()).starts_with(DialogosDeCompradores.FALTA)
	assert_str(atencion.tomar_aviso()).is_empty()
	assert_int(atencion.interactuar(primero)).is_equal(RecepcionDeCompra.Resultado.RECHAZADA)
	assert_bool(atencion.abre_la_ventanilla()).is_false()
	assert_str(atencion.tomar_aviso()).is_equal(DialogosDeCompradores.YA_ENTREGADO)
	var ajeno := _unidad(Producto.Id.MALBARDO)
	assert_int(atencion.interactuar(ajeno)).is_equal(RecepcionDeCompra.Resultado.RECHAZADA)
	assert_bool(atencion.abre_la_ventanilla()).is_false()
	assert_str(atencion.tomar_aviso()).starts_with(DialogosDeCompradores.RECHAZO)
	assert_int(atencion.interactuar(null)).is_equal(RecepcionDeCompra.Resultado.DIALOGO)
	assert_bool(atencion.abre_la_ventanilla()).is_false()
	assert_str(atencion.tomar_aviso()).is_not_empty()
	assert_bool(atencion.puede_abandonar()).is_true()


func test_el_texto_de_entrega_no_retiene_el_clic_siguiente() -> void:  # AC-CTR-098
	var atencion := _atencion_atendida()
	var ajeno := _unidad(Producto.Id.MALBARDO)
	for _i in 2:
		assert_int(atencion.interactuar(ajeno)).is_equal(RecepcionDeCompra.Resultado.RECHAZADA)
		assert_str(atencion.tomar_aviso()).starts_with(DialogosDeCompradores.RECHAZO)
	atencion.interactuar(_unidad(Producto.Id.ZUCARACHAS))
	var agradecimiento := atencion.tomar_aviso()
	# La mano vacía justo después de recibir ya es un recordatorio: no gasta un clic en cerrar el
	# agradecimiento.
	assert_int(atencion.interactuar(null)).is_equal(RecepcionDeCompra.Resultado.DIALOGO)
	var recordatorio := atencion.tomar_aviso()
	assert_str(recordatorio).is_not_empty()
	assert_str(recordatorio).is_not_equal(agradecimiento)


func _comprador() -> Comprador:
	return Compradores.de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA)[1]


func _atencion_atendida() -> Atencion:
	var atencion := Atencion.new(_comprador(), _inventario)
	atencion.interactuar(null)
	while atencion.abre_la_ventanilla():
		atencion.interactuar(null)
	return atencion


func _unidad(id: Producto.Id) -> UnidadDeProducto:
	return _estante.retirar(Catalogo.de(id))


func _ticket() -> Ticket:
	var productos: Array[Producto] = [
		Catalogo.de(Producto.Id.ZUCARACHAS), Catalogo.de(Producto.Id.PEPITO)
	]
	return Ticket.new(productos)
