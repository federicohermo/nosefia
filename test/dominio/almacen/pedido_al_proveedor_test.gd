## El pedido que el jugador le hace a Hernán: la lista que marca, lo que envía con o sin wifi, lo
## que le contesta el proveedor y cuál de los pedidos cuenta.
extends GdUnitTestSuite

const PEDIDO := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 3
const PROVEEDOR := Conversacion.Interlocutor.PROVEEDOR

## Una fracción de segundo: lo que falta para que una respuesta todavía no llegue.
const UN_INSTANTE := 0.125


func _pedido() -> PedidoAlProveedor:
	var pedido := PedidoAlProveedor.new(PEDIDO)
	pedido.abrir_lista()
	return pedido


func _marcar(pedido: PedidoAlProveedor, ids: Array[Producto.Id]) -> void:
	for id in ids:
		pedido.marcar(id)


func test_la_lista_ofrece_los_pedibles_todos_desmarcados_y_exige_uno() -> void:  # AC-INV-170
	var pedido := _pedido()
	assert_int(pedido.productos_de_la_lista().size()).is_equal(Producto.Id.size())
	for producto in pedido.productos_de_la_lista():
		assert_bool(pedido.esta_marcado(producto.id)).is_false()
	assert_bool(pedido.puede_enviar()).is_false()
	assert_object(pedido.enviar(true, "20:00")).is_null()
	pedido.marcar(Producto.Id.POETICO)
	assert_bool(pedido.puede_enviar()).is_true()
	pedido.desmarcar(Producto.Id.POETICO)
	assert_bool(pedido.puede_enviar()).is_false()


func test_cerrar_y_reabrir_deja_la_lista_sin_marcados_y_sin_mensajes() -> void:  # AC-INV-170
	var pedido := _pedido()
	pedido.marcar(Producto.Id.POETICO)
	pedido.marcar(Producto.Id.GRINGO)
	pedido.cerrar_lista()
	assert_bool(pedido.lista_abierta()).is_false()
	pedido.abrir_lista()
	assert_array(pedido.marcados()).is_empty()
	assert_int(pedido.cantidad_de_enviados()).is_zero()
	assert_array(pedido.avanzar(100.0, "20:00")).is_empty()


func test_enviar_con_wifi_deja_un_mensaje_y_dos_respuestas_a_su_tiempo() -> void:  # AC-INV-171
	var pedido := _pedido()
	_marcar(pedido, [Producto.Id.POETICO, Producto.Id.FERNET_GOD, Producto.Id.SEI_TUQUI])
	var mensaje := pedido.enviar(true, "20:10")
	assert_bool(mensaje.propio).is_true()
	assert_bool(mensaje.con_error).is_false()
	assert_str(mensaje.texto).starts_with(PedidoAlProveedor.SALUDO)
	for id: Producto.Id in [Producto.Id.POETICO, Producto.Id.FERNET_GOD, Producto.Id.SEI_TUQUI]:
		assert_str(mensaje.texto).contains(Catalogo.de(id).nombre)
	assert_bool(pedido.lista_abierta()).is_false()
	var primera := PedidoAlProveedor.SEGUNDOS_HASTA_LA_PRIMERA
	assert_array(pedido.avanzar(primera - UN_INSTANTE, "20:10")).is_empty()
	var llegan := pedido.avanzar(UN_INSTANTE, "20:10")
	assert_int(llegan.size()).is_equal(1)
	assert_str(llegan[0].texto).is_equal(PedidoAlProveedor.RESPUESTAS[0])
	var entre := PedidoAlProveedor.SEGUNDOS_ENTRE_RESPUESTAS
	assert_array(pedido.avanzar(entre - UN_INSTANTE, "20:11")).is_empty()
	var ultima := pedido.avanzar(UN_INSTANTE, "20:11")
	assert_int(ultima.size()).is_equal(1)
	assert_str(ultima[0].texto).is_equal(PedidoAlProveedor.RESPUESTAS[1])
	assert_array(pedido.avanzar(100.0, "20:12")).is_empty()


func test_sin_tiempo_positivo_no_llega_nada() -> void:  # AC-INV-171
	var pedido := _pedido()
	pedido.marcar(Producto.Id.POETICO)
	pedido.enviar(true, "20:10")
	assert_array(pedido.avanzar(0.0, "20:10")).is_empty()
	assert_array(pedido.avanzar(-5.0, "20:10")).is_empty()
	(
		assert_int(pedido.avanzar(PedidoAlProveedor.SEGUNDOS_HASTA_LA_PRIMERA, "20:10").size())
		. is_equal(1)
	)


func test_enviar_sin_wifi_queda_en_rojo_y_nadie_contesta() -> void:  # AC-INV-172
	var pedido := _pedido()
	pedido.marcar(Producto.Id.POETICO)
	var mensaje := pedido.enviar(false, "20:10")
	assert_bool(mensaje.con_error).is_true()
	assert_bool(mensaje.propio).is_true()
	assert_array(pedido.avanzar(100.0, "20:10")).is_empty()
	assert_bool(pedido.hubo_pedido_con_wifi()).is_false()
	assert_int(pedido.cantidad_de_enviados()).is_equal(1)


func test_se_puede_enviar_mas_de_un_pedido_y_cada_uno_se_contesta() -> void:  # AC-INV-173
	var pedido := _pedido()
	pedido.marcar(Producto.Id.POETICO)
	var primero := pedido.enviar(false, "20:10")
	pedido.abrir_lista()
	pedido.marcar(Producto.Id.GRINGO)
	var segundo := pedido.enviar(true, "20:20")
	pedido.abrir_lista()
	pedido.marcar(Producto.Id.COFLOCO)
	var tercero := pedido.enviar(true, "20:30")
	assert_int(pedido.cantidad_de_enviados()).is_equal(3)
	assert_bool(primero.con_error).is_true()
	assert_bool(segundo.con_error).is_false()
	assert_bool(tercero.con_error).is_false()
	var respuestas := pedido.avanzar(100.0, "20:31")
	assert_int(respuestas.size()).is_equal(PedidoAlProveedor.RESPUESTAS.size() * 2)
	var todos: Array[Mensaje] = [primero, segundo, tercero]
	todos.append_array(respuestas)
	var identidades := {}
	for mensaje in todos:
		identidades[mensaje.identidad] = true
	assert_int(identidades.size()).is_equal(todos.size())


func test_el_chat_ordena_los_mensajes_del_pedido_y_los_olvida_al_reabrir() -> void:  # AC-INV-173
	var bandeja := Bandeja.new(Conversacion.desde_disco())
	bandeja.abrir_jornada(PEDIDO)
	var pedido := _pedido()
	pedido.marcar(Producto.Id.POETICO)
	var enviado := pedido.enviar(true, "20:10")
	var respuestas := pedido.avanzar(100.0, "20:11")
	bandeja.recibir(PROVEEDOR, enviado)
	for respuesta in respuestas:
		bandeja.recibir(PROVEEDOR, respuesta)
	var esperados: Array[Mensaje] = [enviado]
	esperados.append_array(respuestas)
	assert_array(bandeja.mensajes_de(PROVEEDOR)).is_equal(esperados)
	bandeja.abrir_jornada(PEDIDO)
	assert_array(bandeja.mensajes_de(PROVEEDOR)).is_empty()


func test_cuenta_el_ultimo_enviado_con_wifi_y_ni_uno_mas_ni_uno_menos() -> void:  # AC-SHF-032
	var vacias: Array[Producto.Id] = [
		Producto.Id.FERNET_GOD, Producto.Id.ARVECOR, Producto.Id.GRINGO
	]
	var pedido := _pedido()
	assert_bool(pedido.cumplido(vacias)).is_false()
	assert_bool(pedido.equivocado(vacias)).is_false()
	_marcar(pedido, [Producto.Id.GRINGO, Producto.Id.FERNET_GOD, Producto.Id.ARVECOR])
	pedido.enviar(true, "20:10")
	assert_bool(pedido.cumplido(vacias)).is_true()
	assert_bool(pedido.equivocado(vacias)).is_false()
	pedido.abrir_lista()
	_marcar(pedido, [Producto.Id.GRINGO, Producto.Id.FERNET_GOD])
	pedido.enviar(false, "20:20")
	assert_bool(pedido.cumplido(vacias)).is_true()
	pedido.abrir_lista()
	_marcar(
		pedido,
		[Producto.Id.GRINGO, Producto.Id.FERNET_GOD, Producto.Id.ARVECOR, Producto.Id.POETICO]
	)
	pedido.enviar(true, "20:30")
	assert_bool(pedido.cumplido(vacias)).is_false()
	assert_bool(pedido.equivocado(vacias)).is_true()
