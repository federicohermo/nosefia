extends GdUnitTestSuite

const TEXTOS := preload("res://assets/dialogos/compradores_jornada_1.tres")
const RESALTADO := "[color=#e4f850]"


## Lo que un recordatorio dice de un producto: su subtítulo al examinar.
static func _subtitulo(producto: Producto) -> String:
	return SubtitulosAlExaminar.de_producto(producto.id).trim_suffix(".").substr(1)


## Cada producto del pedido va resaltado con color, y nada va en negrita.
func _resaltados(texto: String, cuantos: int) -> void:
	assert_str(texto).not_contains("[b]")
	assert_int(texto.count(RESALTADO)).is_greater_equal(cuantos)


func test_el_pedido_y_los_nombres_destacados_salen_de_la_ficha() -> void:  # AC-CTR-036
	var compradores := Compradores.de_la_jornada(4)
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
	for comprador in Compradores.de_la_jornada(4):
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
				assert_str(dialogo.entrada_actual()).contains(_subtitulo(producto))
			dialogo.avanzar()
			assert_bool(dialogo.terminado()).is_true()


func test_el_recordatorio_nombra_lo_que_falta_y_el_rechazo_todo_el_pedido() -> void:  # AC-CTR-066
	var tia: Comprador = Compradores.de_la_jornada(4)[1]
	var recepcion := RecepcionDeCompra.new(tia.pedido())
	var primero := tia.pedido().productos()[0]
	var segundo := tia.pedido().productos()[1]
	recepcion.recibir(UnidadDeProducto.new(primero), true)
	var recordatorio := DialogosDeCompradores.recordatorio(tia.pedido(), recepcion)
	assert_str(recordatorio.entrada_actual()).not_contains(_subtitulo(primero))
	assert_str(recordatorio.entrada_actual()).contains(_subtitulo(segundo))
	var rechazo := DialogosDeCompradores.recordatorio(tia.pedido(), recepcion, true)
	assert_str(rechazo.entrada_actual()).contains(_subtitulo(primero))
	assert_str(rechazo.entrada_actual()).contains(_subtitulo(segundo))
	recepcion.recibir(UnidadDeProducto.new(segundo), true)
	(
		assert_str(DialogosDeCompradores.recordatorio(tia.pedido(), recepcion).entrada_actual())
		. is_equal(DialogosDeCompradores.PIDE_EL_RECIBO)
	)


func test_las_despedidas_y_tin_conservan_sus_entradas() -> void:  # AC-CTR-036 AC-CTR-039
	assert_int(TEXTOS.tin.size()).is_equal(3)
	assert_int(TEXTOS.despedida_tin.size()).is_equal(1)
	var dialogo: Dialogo = TEXTOS.despedida(DialogosDeCompradores.Personaje.TIA)
	for _entrada in 4:
		assert_bool(dialogo.terminado()).is_false()
		dialogo.avanzar()
	assert_bool(dialogo.terminado()).is_true()
