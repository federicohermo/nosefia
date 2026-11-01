extends GdUnitTestSuite

const TEXTOS := preload("res://assets/dialogos/compradores_jornada_1.tres")
const RESALTADO := "[color=#e4f850]"
const FIN_DEL_RESALTADO := "[/color]"


## Lo que un recordatorio dice de un producto: su subtítulo al examinar.
static func _subtitulo(producto: Producto) -> String:
	var texto := SubtitulosAlExaminar.de_producto(producto.id).trim_suffix(".")
	return texto.left(1).to_lower() + texto.substr(1)


## Lo que lee el jugador, sin las marcas de color.
static func _sin_color(texto: String) -> String:
	return texto.replace(RESALTADO, "").replace(FIN_DEL_RESALTADO, "")


## Lo que el texto deja en amarillo, en orden.
static func _en_amarillo(texto: String) -> PackedStringArray:
	var resaltado := PackedStringArray()
	for trozo: String in texto.split(RESALTADO).slice(1):
		resaltado.append(trozo.get_slice(FIN_DEL_RESALTADO, 0))
	return resaltado


static func _pedido(ids: Array, cantidad: int = 1) -> Venta:
	var pedido := Venta.new()
	for id: Producto.Id in ids:
		pedido.agregar(Catalogo.de(id), cantidad)
	return pedido


static func _nombres(pedido: Venta) -> PackedStringArray:
	var nombres := PackedStringArray()
	for producto in pedido.productos():
		nombres.append(producto.nombre)
	return nombres


## Cada producto del pedido va resaltado con color, y nada va en negrita.
func _resaltados(texto: String, cuantos: int) -> void:
	assert_str(texto).not_contains("[b]")
	assert_int(texto.count(RESALTADO)).is_greater_equal(cuantos)


func test_el_pedido_y_los_nombres_destacados_salen_de_la_ficha() -> void:  # AC-CTR-036
	var compradores := Compradores.de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA)
	var tin: Dialogo = TEXTOS.inicial(DialogosDeCompradores.Personaje.TIN)
	var entradas := ""
	for _entrada in 3:
		assert_bool(tin.terminado()).is_false()
		entradas += tin.entrada_actual()
		tin.avanzar()
	assert_bool(tin.terminado()).is_true()
	_resaltados(entradas, compradores[0].pedido().productos().size())
	var tia: Dialogo = TEXTOS.inicial(DialogosDeCompradores.Personaje.TIA)
	_resaltados(tia.entrada_actual(), compradores[1].pedido().productos().size())
	tia.avanzar()
	assert_bool(tia.terminado()).is_true()


func test_rechazo_y_recordatorio_enumeran_el_pedido() -> void:  # AC-CTR-037
	for comprador in Compradores.de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA):
		var recepcion := RecepcionDeCompra.new(comprador.pedido())
		for rechazar: bool in [false, true]:
			var dialogo := DialogosDeCompradores.recordatorio(
				comprador.pedido(), recepcion, rechazar
			)
			(
				assert_bool(dialogo.entrada_actual().begins_with(DialogosDeCompradores.RECHAZO))
				. is_equal(rechazar)
			)
			_resaltados(dialogo.entrada_actual(), comprador.pedido().productos().size())
			for producto in comprador.pedido().productos():
				assert_str(_sin_color(dialogo.entrada_actual())).contains(_subtitulo(producto))
			dialogo.avanzar()
			assert_bool(dialogo.terminado()).is_true()


func test_el_recordatorio_y_el_rechazo_nombran_lo_que_falta() -> void:  # AC-CTR-066
	var tia: Comprador = Compradores.de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA)[1]
	var recepcion := RecepcionDeCompra.new(tia.pedido())
	var primero := tia.pedido().productos()[0]
	var segundo := tia.pedido().productos()[1]
	recepcion.recibir(UnidadDeProducto.new(primero), true)
	var recordatorio := DialogosDeCompradores.recordatorio(tia.pedido(), recepcion)
	assert_str(_sin_color(recordatorio.entrada_actual())).not_contains(_subtitulo(primero))
	assert_str(_sin_color(recordatorio.entrada_actual())).contains(_subtitulo(segundo))
	var rechazo := DialogosDeCompradores.recordatorio(tia.pedido(), recepcion, true)
	assert_str(rechazo.entrada_actual()).starts_with(DialogosDeCompradores.RECHAZO)
	assert_str(_sin_color(rechazo.entrada_actual())).not_contains(_subtitulo(primero))
	assert_str(_sin_color(rechazo.entrada_actual())).contains(_subtitulo(segundo))
	recepcion.recibir(UnidadDeProducto.new(segundo), true)
	(
		assert_str(DialogosDeCompradores.recordatorio(tia.pedido(), recepcion).entrada_actual())
		. is_equal(DialogosDeCompradores.PIDE_EL_TICKET)
	)
	(
		assert_str(
			DialogosDeCompradores.recordatorio(tia.pedido(), recepcion, true).entrada_actual()
		)
		. is_equal(DialogosDeCompradores.RECHAZO + DialogosDeCompradores.PEDIDO_DEL_TICKET)
	)


func test_las_despedidas_y_tin_conservan_sus_entradas() -> void:  # AC-CTR-036 AC-CTR-039
	assert_int(TEXTOS.tin.size()).is_equal(3)
	assert_int(TEXTOS.despedida_tin.size()).is_equal(1)
	var dialogo: Dialogo = TEXTOS.despedida(DialogosDeCompradores.Personaje.TIA)
	for _entrada in 4:
		assert_bool(dialogo.terminado()).is_false()
		dialogo.avanzar()
	assert_bool(dialogo.terminado()).is_true()


func test_con_una_unidad_solo_el_nombre_va_en_amarillo() -> void:  # AC-CTR-133
	var pedido := _pedido([Producto.Id.MAROLINI])
	var dialogo := DialogosDeCompradores.recordatorio(pedido, RecepcionDeCompra.new(pedido))
	var texto := dialogo.entrada_actual()
	assert_array(_en_amarillo(texto)).is_equal(["Marolini"])
	assert_str(_sin_color(texto)).is_equal("Quiero " + _subtitulo(pedido.productos()[0]) + ".")
	assert_str(texto).not_contains(RESALTADO + "una")


func test_con_dos_o_tres_unidades_la_cantidad_queda_sin_color() -> void:  # AC-CTR-133
	var cantidades := {2: "dos", 3: "tres"}
	for cantidad: int in cantidades:
		var pedido := _pedido([Producto.Id.MAROLINI], cantidad)
		var dialogo := DialogosDeCompradores.recordatorio(pedido, RecepcionDeCompra.new(pedido))
		assert_str(dialogo.entrada_actual()).is_equal(
			"Quiero %s %sMarolini%s." % [cantidades[cantidad], RESALTADO, FIN_DEL_RESALTADO]
		)


func test_la_enumeracion_deja_sin_color_el_subtitulo_las_comas_y_la_y() -> void:  # AC-CTR-133
	var pedido := _pedido([Producto.Id.POETICO, Producto.Id.PROGRES, Producto.Id.DURONGA])
	var texto := DialogosDeCompradores.apertura_predeterminada(pedido).entrada_actual()
	assert_array(_en_amarillo(texto)).is_equal(_nombres(pedido))
	var productos := pedido.productos()
	assert_str(_sin_color(texto)).is_equal(
		(
			"Buenas noches. Quiero %s, %s y %s."
			% [_subtitulo(productos[0]), _subtitulo(productos[1]), _subtitulo(productos[2])]
		)
	)


func test_el_rechazo_y_el_agradecimiento_resaltan_solo_lo_que_falta() -> void:  # AC-CTR-133
	var pedido := _pedido([Producto.Id.POETICO, Producto.Id.PROGRES])
	var recepcion := RecepcionDeCompra.new(pedido)
	recepcion.recibir(UnidadDeProducto.new(pedido.productos()[0]), true)
	var rechazo := DialogosDeCompradores.recordatorio(pedido, recepcion, true)
	var gracias := DialogosDeCompradores.agradecimiento(pedido, recepcion)
	for texto: String in [rechazo.entrada_actual(), gracias.entrada_actual()]:
		assert_array(_en_amarillo(texto)).is_equal([pedido.productos()[1].nombre])
		assert_str(_sin_color(texto)).contains(_subtitulo(pedido.productos()[1]))
