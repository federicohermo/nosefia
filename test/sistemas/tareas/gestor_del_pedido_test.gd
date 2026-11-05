extends GdUnitTestSuite

const PEDIDO := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 3

var _reloj: RelojDelTurno
var _gestor: GestorDelPedido
var _turno: Turno
var _pedido: PedidoAlProveedor
var _vacias: Array[Producto.Id]


func before_test() -> void:
	_reloj = auto_free(RelojDelTurno.new())
	_gestor = auto_free(GestorDelPedido.new())
	_gestor.reloj = _reloj
	var tareas := Apertura.obligatorias(PEDIDO)
	_turno = Turno.new(1.0, tareas)
	_reloj.arrancar(_turno, tareas)
	_vacias = Apertura.cajas_vacias_de_la_jornada(PEDIDO, Compradores.de_la_jornada(PEDIDO, 1), 1)
	_pedido = PedidoAlProveedor.new(PEDIDO)


func _enviar(ids: Array[Producto.Id], con_wifi: bool) -> void:
	_pedido.abrir_lista()
	for id in ids:
		_pedido.marcar(id)
	_pedido.enviar(con_wifi, "20:10")
	_gestor.revisar(_pedido, _vacias)


func _cumplido() -> bool:
	return _reloj.obligatoria(Tarea.Tipo.PEDIR_AL_PROVEEDOR).completada()


func _otro_producto() -> Producto.Id:
	for producto in Catalogo.todos():
		if not _vacias.has(producto.id):
			return producto.id
	return Producto.Id.ACTRONCITO


func test_el_pedido_exacto_con_wifi_cumple_en_cualquier_orden() -> void:  # AC-SHF-083
	_enviar(_vacias, true)
	assert_bool(_cumplido()).is_true()
	assert_int(_turno.tareas_cumplidas()).is_equal(1)
	var al_reves: Array[Producto.Id] = _vacias.duplicate()
	al_reves.reverse()
	_enviar(al_reves, true)
	assert_bool(_cumplido()).is_true()
	assert_int(_turno.tareas_cumplidas()).is_equal(1)


func test_uno_de_menos_de_mas_o_cambiado_no_cumple() -> void:  # AC-SHF-084
	assert_bool(_cumplido()).is_false()
	var de_menos: Array[Producto.Id] = _vacias.slice(1)
	_enviar(de_menos, true)
	assert_bool(_cumplido()).is_false()
	var de_mas: Array[Producto.Id] = _vacias.duplicate()
	de_mas.append(_otro_producto())
	_enviar(de_mas, true)
	assert_bool(_cumplido()).is_false()
	var cambiado: Array[Producto.Id] = _vacias.slice(1)
	cambiado.append(_otro_producto())
	_enviar(cambiado, true)
	assert_bool(_cumplido()).is_false()
	assert_int(_turno.tareas_cumplidas()).is_zero()


func test_sin_wifi_no_cumple_ni_deshace() -> void:  # AC-SHF-085
	_enviar(_vacias, false)
	assert_bool(_cumplido()).is_false()
	_enviar(_vacias, true)
	assert_bool(_cumplido()).is_true()
	var otro: Array[Producto.Id] = [_otro_producto()]
	_enviar(otro, false)
	assert_bool(_cumplido()).is_true()


func test_cuenta_el_ultimo_con_wifi_y_el_cierre_no_cambia() -> void:  # AC-SHF-086
	var otro: Array[Producto.Id] = [_otro_producto()]
	_enviar(_vacias, true)
	_enviar(otro, true)
	assert_bool(_cumplido()).is_false()
	assert_int(_turno.tareas_cumplidas()).is_zero()
	_enviar(_vacias, true)
	assert_bool(_cumplido()).is_true()
	assert_int(_turno.tareas_cumplidas()).is_equal(1)
	_reloj.avanzar(1.0)
	_enviar(otro, true)
	assert_bool(_cumplido()).is_true()
	assert_int(_turno.tareas_cumplidas()).is_equal(1)
