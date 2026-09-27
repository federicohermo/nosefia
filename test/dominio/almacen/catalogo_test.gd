## Qué productos existen en el almacén y con qué valores.
##
## Los AC de acá son el único lugar del repo que se pone en rojo cuando el catálogo y el
## `enum Id` se desincronizan: agregar un producto al enum y olvidarse de su fila deja un
## `Catalogo.de(id)` que devuelve `null`, y nada más lo caza.
extends GdUnitTestSuite


func test_hay_exactamente_una_fila_por_cada_valor_del_enum() -> void:  # AC-STK-002
	# Mira `FILAS` y no `todos()` porque es la aserción que sobrevive a la desincronización que
	# viene a cazar: medido el 2026-09-01, un enum con un valor de más hacía reventar a `de()`
	# adentro del test y la aserción no llegaba a correr.
	assert_int(Catalogo.FILAS.size()).is_equal(Producto.Id.size())
	for id in Producto.Id.values():
		assert_bool(Catalogo.FILAS.has(id)).is_true()


func test_hay_exactamente_un_producto_por_cada_valor_del_enum() -> void:  # AC-STK-002
	# El AC que se pone en rojo el día que alguien agregue un producto al enum sin darle fila.
	assert_array(Catalogo.todos()).has_size(Producto.Id.size())


func test_el_catalogo_lista_los_productos_en_el_orden_del_enum() -> void:
	# El orden no es adorno: es el que lista la pantalla de la caja, y sin afirmarlo un `todos()`
	# que barajara la lista entre dos cuadros pasaría los otros AC sin despeinarse.
	var ids: Array[int] = []
	for producto in Catalogo.todos():
		ids.append(producto.id)
	assert_array(ids).contains_exactly(Producto.Id.values())


func test_cada_producto_del_catalogo_esta_completo() -> void:  # AC-STK-002
	# Recorre el enum entero y no una muestra: una fila a medio llenar en cualquiera de ellos
	# pasaría desapercibida si el test mirara un solo producto.
	for id in Producto.Id.values():
		var producto := Catalogo.de(id)
		# Sin este corte, un `id` sin fila desreferencia `null` y aborta la función: el caso se
		# reporta sin haber afirmado nada, que es justo el modo de falla que este archivo cierra.
		assert_object(producto).is_not_null()
		if producto == null:
			continue
		assert_int(producto.id).is_equal(id)
		assert_str(producto.nombre).is_not_empty()
		assert_int(producto.precio).is_greater(0)
		assert_int(producto.umbral).is_greater_equal(1)


func test_dos_llamadas_al_catalogo_dan_objetos_distintos_con_el_mismo_id() -> void:
	# La decisión escrita como test: la identidad de un producto es su `id`, nunca la
	# instancia. Quien indexe por instancia va a encontrar ausente lo que guardó la otra.
	var una := Catalogo.de(Producto.Id.ACTRONCITO)
	var otra := Catalogo.de(Producto.Id.ACTRONCITO)
	assert_object(una).is_not_same(otra)
	assert_int(una.id).is_equal(otra.id)


func test_ningun_producto_queda_sin_sonoridad() -> void:  # AC-STK-027
	for id: Producto.Id in Producto.Id.values():
		(
			assert_int(Catalogo.sonoridad_de(id))
			. override_failure_message("%s no tiene sonoridad" % Producto.Id.find_key(id))
			. is_not_equal(EntradaSonora.Sonoridad.NINGUNA)
		)
	for id in [Producto.Id.ARVEJAS, Producto.Id.CORACOLA, Producto.Id.PRONGLES]:
		assert_int(Catalogo.sonoridad_de(id)).is_equal(EntradaSonora.Sonoridad.LATA)
