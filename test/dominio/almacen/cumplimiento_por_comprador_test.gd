## Atención y registrar durante la noche: figuran cumplidas mientras todos los compradores que ya
## llegaron están al día, y el cierre vuelve a exigir a los dos.
extends GdUnitTestSuite

var _inventario: Inventario
var _compradores: Array[Comprador] = []
var _tarea: TareaDeAtender
var _registro: RegistroDeVentas


func before_test() -> void:
	_inventario = Apertura.inventario_con_faltantes({}, {}, Catalogo.todos())
	_compradores = Compradores.de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA)
	_tarea = TareaDeAtender.new(_compradores, _inventario)
	_registro = RegistroDeVentas.new(Catalogo.todos(), _tarea)


func _llegar(indice: int) -> Atencion:
	_tarea.avanzar(_compradores[indice].horario.x)
	var atencion := _tarea.atencion()
	while not atencion.conversacion_iniciada() or not atencion.puede_abandonar():
		atencion.interactuar(null)
	return atencion


func _sacar(producto: Producto) -> UnidadDeProducto:
	return Estante.new(_inventario, Catalogo.todos()).retirar(producto)


## Entrega todos los productos del pedido, sin el ticket, y devuelve los renglones del ticket.
func _entregar_los_productos(atencion: Atencion) -> Array[Producto]:
	var renglones: Array[Producto] = []
	var pedido := atencion.comprador().pedido()
	for producto in pedido.productos():
		for _vez in pedido.unidades_de(producto):
			atencion.interactuar(_sacar(producto))
			renglones.append(producto)
	return renglones


func _vender(atencion: Atencion) -> void:
	var renglones := _entregar_los_productos(atencion)
	assert_int(atencion.interactuar(Ticket.new(renglones))).is_equal(
		RecepcionDeCompra.Resultado.COMPLETA
	)


func _anotar(indice: int) -> void:
	var pedido := _compradores[indice].pedido()
	for producto in pedido.productos():
		for _vez in pedido.unidades_de(producto):
			_registro.sumar(producto)


func _comprobar_que_el_primero_no_cuenta(primero: Atencion) -> void:
	assert_bool(primero.vendida()).is_false()
	assert_int(_tarea.mal_atendidos()).is_equal(1)
	for producto in _compradores[0].pedido().productos():
		assert_int(_tarea.vendidas_de(producto)).is_zero()


## Con el primero perdido y el segundo vendido y anotado: registrar cumple y atención no, también
## al cierre. Una unidad del primero en la planilla descumple registrar.
func _comprobar_los_veredictos_con_el_primero_perdido() -> void:
	assert_bool(_tarea.cumplida()).is_false()
	assert_bool(_tarea.cumplida(true)).is_false()
	assert_bool(_registro.completada()).is_true()
	assert_bool(_registro.completada(true)).is_true()
	var del_primero := _compradores[0].pedido().productos()[0]
	_registro.sumar(del_primero)
	assert_bool(_registro.completada()).is_false()
	assert_bool(_registro.completada(true)).is_false()
	_registro.restar(del_primero)
	assert_bool(_registro.completada()).is_true()


func test_vender_al_primero_cumple_hasta_que_llega_el_segundo() -> void:  # AC-CTR-143
	assert_bool(_tarea.cumplida()).is_false()
	assert_bool(_registro.completada()).is_false()
	var primero := _llegar(0)
	assert_bool(_tarea.cumplida()).is_false()
	assert_bool(_registro.completada()).is_false()
	_vender(primero)
	assert_bool(primero.despachada()).is_false()
	assert_bool(_tarea.cumplida()).is_true()
	assert_bool(_registro.completada()).is_false()
	_anotar(0)
	assert_bool(_registro.completada()).is_true()
	_llegar(1)
	assert_bool(_tarea.cumplida()).is_false()
	assert_bool(_registro.completada()).is_false()


func test_vendidos_y_anotados_los_dos_siguen_cumplidos_al_cierre() -> void:  # AC-CTR-143
	_vender(_llegar(0))
	_anotar(0)
	_vender(_llegar(1))
	assert_bool(_tarea.cumplida()).is_true()
	assert_bool(_registro.completada()).is_false()
	_anotar(1)
	assert_bool(_tarea.cumplida()).is_true()
	assert_bool(_tarea.cumplida(true)).is_true()
	assert_bool(_registro.completada()).is_true()
	assert_bool(_registro.completada(true)).is_true()


func test_con_el_segundo_sin_llegar_el_cierre_deja_las_dos_pendientes() -> void:  # AC-CTR-143
	_vender(_llegar(0))
	_anotar(0)
	assert_bool(_tarea.cumplida()).is_true()
	assert_bool(_registro.completada()).is_true()
	assert_bool(_tarea.cumplida(true)).is_false()
	assert_bool(_registro.completada(true)).is_false()


func test_la_entrega_incompleta_que_se_va_no_cuenta_como_venta() -> void:  # AC-CTR-144
	var primero := _llegar(0)
	var producto := primero.comprador().pedido().productos()[0]
	var entregada := _sacar(producto)
	assert_int(primero.interactuar(entregada)).is_equal(RecepcionDeCompra.Resultado.ACEPTADA)
	_tarea.avanzar(_compradores[0].horario.y)
	assert_bool(_inventario.esta_afuera(entregada)).is_true()
	_comprobar_que_el_primero_no_cuenta(primero)
	_vender(_llegar(1))
	_anotar(1)
	_comprobar_los_veredictos_con_el_primero_perdido()


func test_el_pedido_completo_sin_ticket_que_se_va_no_cuenta_como_venta() -> void:  # AC-CTR-145
	var primero := _llegar(0)
	var renglones := _entregar_los_productos(primero)
	assert_array(renglones).is_not_empty()
	_tarea.avanzar(_compradores[0].horario.y)
	_comprobar_que_el_primero_no_cuenta(primero)
	_vender(_llegar(1))
	_anotar(1)
	_comprobar_los_veredictos_con_el_primero_perdido()


func test_la_compra_vendida_no_vence_mientras_se_despide() -> void:  # AC-CTR-146
	var primero := _llegar(0)
	_vender(primero)
	var eventos := _tarea.avanzar(_compradores[0].horario.y)
	for evento in eventos:
		assert_int(evento.tipo).is_not_equal(AgendaDeCompradores.Tipo.VENCIO)
	assert_bool(primero.vendida()).is_true()
	assert_bool(primero.despachada()).is_false()
	assert_int(_tarea.mal_atendidos()).is_zero()
	assert_bool(_tarea.cumplida()).is_true()
	for producto in _compradores[0].pedido().productos():
		assert_int(_tarea.vendidas_de(producto)).is_equal(
			_compradores[0].pedido().unidades_de(producto)
		)


func test_sin_horarios_atencion_se_cumple_al_despachar_a_todos() -> void:  # AC-CTR-009
	var pedido := Venta.new()
	pedido.agregar(Catalogo.de(Producto.Id.ACTRONCITO), 1)
	var inventario := Inventario.new(Catalogo.todos())
	inventario.ingresar(Catalogo.de(Producto.Id.ACTRONCITO), Inventario.Ubicacion.DEPOSITO, 9)
	var lista: Array[Comprador] = []
	for _vez in 2:
		lista.append(Comprador.new("Comprador", pedido, pedido.total()))
	var tarea := TareaDeAtender.new(lista, inventario)
	assert_bool(tarea.fisica()).is_false()
	tarea.atender()
	tarea.atencion().cobrar()
	assert_bool(tarea.cumplida()).is_false()
	tarea.atender()
	tarea.atencion().despachar_sin_vender()
	assert_bool(tarea.cumplida()).is_true()
	assert_bool(tarea.cumplida(true)).is_true()
