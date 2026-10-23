extends GdUnitTestSuite

const TERCERA := ReglasDeLaPartida.PRIMERA_JORNADA + 2
const CUARTA := ReglasDeLaPartida.PRIMERA_JORNADA + 3
const QUINTA := ReglasDeLaPartida.PRIMERA_JORNADA + 4
const SEMILLA := 5
const CASILLEROS := 8
const JORNADAS: Array[int] = [TERCERA, CUARTA, QUINTA]


## Una noche armada como la apertura: la mercadería completa y los compradores de la jornada.
class Noche:
	extends RefCounted
	var compradores: Array[Comprador]
	var inventario: Inventario
	var estante: Estante
	var tarea: TareaDeAtender
	var registro: RegistroDeVentas


func _noche(jornada: int) -> Noche:
	var noche := Noche.new()
	var productos := Catalogo.de_la_jornada(jornada)
	var casilleros: Dictionary[Producto.Id, int] = {}
	for producto in productos:
		casilleros[producto.id] = CASILLEROS
	noche.compradores = Compradores.de_la_jornada(jornada, SEMILLA)
	noche.inventario = Apertura.inventario_con_faltantes({}, casilleros, productos)
	noche.estante = Estante.new(noche.inventario, productos)
	noche.tarea = TareaDeAtender.new(noche.compradores, noche.inventario)
	noche.registro = RegistroDeVentas.new(Catalogo.todos(), noche.tarea)
	return noche


## Llega el comprador `indice` y se termina su apertura, que es lo que habilita recibir.
func _llegar(noche: Noche, indice: int) -> Atencion:
	noche.tarea.avanzar(noche.compradores[indice].horario.x)
	var atencion := noche.tarea.atencion()
	atencion.interactuar(null)
	while not atencion.puede_abandonar():
		atencion.interactuar(null)
	return atencion


func _unidad(noche: Noche, producto: Producto, de_la_gondola: bool) -> UnidadDeProducto:
	var ocupados := noche.estante.casilleros_ocupados(producto)
	if de_la_gondola and not ocupados.is_empty():
		return noche.estante.agarrar(producto, ocupados[0])
	return noche.estante.retirar(producto)


func _completar(noche: Noche, atencion: Atencion) -> int:
	var pedido := atencion.comprador().pedido()
	for producto in pedido.productos():
		atencion.interactuar(_unidad(noche, producto, false))
	return atencion.interactuar(Ticket.new(pedido.productos()))


func _vender(noche: Noche, indice: int) -> Atencion:
	var atencion := _llegar(noche, indice)
	assert_int(_completar(noche, atencion)).is_equal(RecepcionDeCompra.Resultado.COMPLETA)
	assert_bool(atencion.vendida()).is_true()
	return atencion


## Las unidades de un producto que hay entre la caja y la góndola: lo que una venta resta una vez.
func _en_el_local(noche: Noche, producto: Producto) -> int:
	return (
		noche.inventario.unidades(producto, Inventario.Ubicacion.DEPOSITO)
		+ noche.inventario.unidades(producto, Inventario.Ubicacion.GONDOLA)
	)


func _anotar_lo_vendido(noche: Noche, indice: int) -> void:
	for producto in noche.compradores[indice].pedido().productos():
		noche.registro.sumar(producto)


func test_el_ticket_exacto_antes_de_los_productos_se_acepta_y_completa() -> void:  # AC-CTR-075
	for jornada: int in JORNADAS:
		var noche := _noche(jornada)
		var atencion := _llegar(noche, 0)
		var productos := atencion.comprador().pedido().productos()
		assert_int(atencion.interactuar(Ticket.new(productos))).is_equal(
			RecepcionDeCompra.Resultado.ACEPTADA
		)
		assert_bool(atencion.vendida()).is_false()
		for indice in productos.size() - 1:
			assert_int(atencion.interactuar(_unidad(noche, productos[indice], false))).is_equal(
				RecepcionDeCompra.Resultado.ACEPTADA
			)
		assert_int(atencion.interactuar(_unidad(noche, productos[-1], false))).is_equal(
			RecepcionDeCompra.Resultado.COMPLETA
		)
		assert_bool(atencion.vendida()).is_true()


func test_una_unidad_de_mas_o_un_ticket_inexacto_se_rechazan() -> void:  # AC-CTR-075
	for jornada: int in JORNADAS:
		var noche := _noche(jornada)
		var atencion := _llegar(noche, 0)
		var primero := atencion.comprador().pedido().productos()[0]
		atencion.interactuar(_unidad(noche, primero, false))
		assert_int(atencion.interactuar(_unidad(noche, primero, false))).is_equal(
			RecepcionDeCompra.Resultado.RECHAZADA
		)
		# El rechazo retiene el clic siguiente: se lo cierra antes de ofrecer otra cosa.
		atencion.interactuar(null)
		assert_int(atencion.interactuar(Ticket.new([primero]))).is_equal(
			RecepcionDeCompra.Resultado.RECHAZADA
		)
		assert_bool(atencion.vendida()).is_false()


func test_atencion_se_cumple_solo_con_las_dos_compras_completas() -> void:  # AC-CTR-075
	for jornada: int in JORNADAS:
		var ambas := _noche(jornada)
		_vender(ambas, 0)
		assert_bool(ambas.tarea.completada()).is_false()
		_vender(ambas, 1)
		assert_bool(ambas.tarea.completada()).is_true()
		var perdida_la_primera := _noche(jornada)
		_llegar(perdida_la_primera, 0)
		perdida_la_primera.tarea.avanzar(perdida_la_primera.compradores[0].horario.y)
		_vender(perdida_la_primera, 1)
		assert_bool(perdida_la_primera.tarea.completada()).is_false()
		var perdida_la_segunda := _noche(jornada)
		_vender(perdida_la_segunda, 0)
		_llegar(perdida_la_segunda, 1)
		perdida_la_segunda.tarea.avanzar(perdida_la_segunda.compradores[1].horario.y)
		assert_bool(perdida_la_segunda.tarea.completada()).is_false()


func test_una_compra_vencida_deja_las_unidades_afuera_sin_venta() -> void:  # AC-CTR-075, AC-STK-109
	for jornada: int in JORNADAS:
		var noche := _noche(jornada)
		var atencion := _llegar(noche, 0)
		var productos := atencion.comprador().pedido().productos()
		var recibidas: Array[UnidadDeProducto] = []
		for indice in 2:
			var unidad := _unidad(noche, productos[indice], indice == 0)
			atencion.interactuar(unidad)
			recibidas.append(unidad)
		var antes: Array[int] = []
		for producto in productos:
			antes.append(noche.inventario.unidades(producto, Inventario.Ubicacion.DEPOSITO))
			antes.append(noche.inventario.unidades(producto, Inventario.Ubicacion.GONDOLA))
		noche.tarea.avanzar(noche.compradores[0].horario.y)
		noche.tarea.avanzar(noche.compradores[0].horario.y)
		var despues: Array[int] = []
		for producto in productos:
			despues.append(noche.inventario.unidades(producto, Inventario.Ubicacion.DEPOSITO))
			despues.append(noche.inventario.unidades(producto, Inventario.Ubicacion.GONDOLA))
		assert_array(despues).is_equal(antes)
		for unidad in recibidas:
			assert_bool(noche.inventario.esta_afuera(unidad)).is_true()
		assert_bool(atencion.vendida()).is_false()
		assert_int(noche.tarea.vendidas_de(productos[0])).is_zero()


func test_registrar_espera_a_que_terminen_las_dos_compras() -> void:  # AC-STK-108
	for jornada: int in JORNADAS:
		var noche := _noche(jornada)
		_vender(noche, 0)
		_anotar_lo_vendido(noche, 0)
		assert_bool(noche.registro.completada()).is_false()
		noche.tarea.avanzar(noche.compradores[1].horario.x)
		assert_bool(noche.registro.completada()).is_false()
		noche.tarea.avanzar(noche.compradores[1].horario.y)
		assert_bool(noche.registro.completada()).is_true()


func test_dos_compras_vencidas_con_la_planilla_en_cero_cumplen_al_cerrar() -> void:  # AC-STK-108
	for jornada: int in JORNADAS:
		var noche := _noche(jornada)
		noche.tarea.avanzar(Reglas.DURACION_DEL_TURNO)
		assert_bool(noche.registro.completada()).is_false()
		assert_bool(noche.registro.completada(true)).is_true()
		noche.registro.sumar(noche.compradores[0].pedido().productos()[0])
		assert_bool(noche.registro.completada(true)).is_false()


func test_la_venta_retira_cada_unidad_una_sola_vez() -> void:  # AC-STK-109
	for jornada: int in JORNADAS:
		var noche := _noche(jornada)
		var atencion := _llegar(noche, 0)
		var productos := atencion.comprador().pedido().productos()
		var unidades: Array[UnidadDeProducto] = []
		var totales: Array[int] = []
		for indice in productos.size():
			totales.append(_en_el_local(noche, productos[indice]))
			var unidad := _unidad(noche, productos[indice], indice == 0)
			unidades.append(unidad)
			atencion.interactuar(unidad)
		var gondola := noche.inventario.unidades(productos[0], Inventario.Ubicacion.GONDOLA)
		atencion.interactuar(Ticket.new(productos))
		for indice in productos.size():
			assert_bool(noche.inventario.esta_afuera(unidades[indice])).is_false()
			assert_int(noche.tarea.vendidas_de(productos[indice])).is_equal(1)
			assert_int(_en_el_local(noche, productos[indice])).is_equal(totales[indice] - 1)
		assert_int(noche.inventario.unidades(productos[0], Inventario.Ubicacion.GONDOLA)).is_equal(
			gondola
		)
		atencion.interactuar(null)
		assert_int(atencion.interactuar(_unidad(noche, productos[0], false))).is_equal(
			RecepcionDeCompra.Resultado.BLOQUEADA
		)
		assert_int(noche.tarea.vendidas_de(productos[0])).is_equal(1)
