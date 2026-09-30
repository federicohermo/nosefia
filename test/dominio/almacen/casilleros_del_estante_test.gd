## Los casilleros del estante: cuál está ocupado, en cuál se coloca, y qué pasa con la unidad
## que se agarra de la góndola.
##
## **Ni un `Node3D` en toda la suite**, igual que la del estante: es la prueba de que elegir el
## casillero y agarrar de la fila de adelante se ejercen sin levantar una escena.
##
## Los productos y sus casilleros son inventados, y no los del catálogo ni los del local: cuántos
## casilleros tiene cada fila lo mide el modelo, y ningún caso de acá se entera si cambia.
extends GdUnitTestSuite


## Un producto con el `id` que el caso necesita, sin pasar por el catálogo.
func _producto(id: Producto.Id) -> Producto:
	return Producto.new(id, "de prueba", 100)


## El estante de un solo producto, con esos casilleros en su fila de adelante y esas unidades en
## el depósito y en la góndola. La góndola se llena antes de armar el estante, como la llena la
## apertura de la jornada.
func _estante(
	producto: Producto, casilleros: int, en_deposito: int, en_gondola: int = 0
) -> Estante:
	var productos: Array[Producto] = [producto]
	var inventario := Inventario.new(productos, {producto.id: casilleros})
	inventario.ingresar(producto, Inventario.Ubicacion.DEPOSITO, en_deposito)
	inventario.ingresar(producto, Inventario.Ubicacion.GONDOLA, en_gondola)
	return Estante.new(inventario, productos)


## Los vendibles del inventario sobre el que está armado el estante: la única puerta a ellos es la
## venta, y acá se los pregunta sin cobrar nada.
func _vendibles(estante: Estante, producto: Producto) -> int:
	var inventario: Inventario = estante.get("_inventario")
	return inventario.vendibles(producto)


func _es_faltante(estante: Estante, producto: Producto) -> bool:
	var inventario: Inventario = estante.get("_inventario")
	for faltante in inventario.faltantes():
		if faltante.id == producto.id:
			return true
	return false


func test_el_casillero_ocupado_se_rechaza_sin_mover_nada() -> void:  # AC-STK-043
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var estante := _estante(actroncito, 3, 5)
	assert_int(estante.colocar(actroncito, 1)).is_equal(Estante.Rechazo.NINGUNO)
	assert_array(estante.casilleros_ocupados(actroncito)).is_equal([1])
	assert_int(estante.colocar(actroncito, 1)).is_equal(Estante.Rechazo.CASILLERO_OCUPADO)
	assert_int(estante.unidades_en_gondola(actroncito)).is_equal(1)
	assert_int(estante.unidades_en_deposito(actroncito)).is_equal(4)
	assert_int(estante.colocar(actroncito, 0)).is_equal(Estante.Rechazo.NINGUNO)
	assert_array(estante.casilleros_ocupados(actroncito)).is_equal([0, 1])
	assert_array(estante.casilleros_vacios(actroncito)).is_equal([2])


func test_ocupado_y_sin_deposito_el_motivo_es_el_casillero() -> void:  # AC-STK-043
	# El casillero es el estado del estante, y va antes que lo que trajo la noche.
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var estante := _estante(actroncito, 3, 1)
	assert_int(estante.colocar(actroncito, 1)).is_equal(Estante.Rechazo.NINGUNO)
	assert_int(estante.unidades_en_deposito(actroncito)).is_zero()
	assert_int(estante.colocar(actroncito, 1)).is_equal(Estante.Rechazo.CASILLERO_OCUPADO)
	assert_int(estante.colocar(actroncito, 0)).is_equal(Estante.Rechazo.SIN_UNIDADES_EN_DEPOSITO)


func test_con_la_fila_llena_se_rechaza_por_estante_lleno_en_cualquiera() -> void:  # AC-STK-043
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var estante := _estante(actroncito, 3, 5, 3)
	for casillero in 3:
		assert_int(estante.colocar(actroncito, casillero)).is_equal(Estante.Rechazo.ESTANTE_LLENO)
	assert_int(estante.unidades_en_deposito(actroncito)).is_equal(5)


func test_el_casillero_de_otro_producto_es_producto_no_aceptado() -> void:  # AC-STK-043 AC-STK-045
	# Dos productos en el mismo estante: la unidad de uno, puesta en un casillero vacío del otro.
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var malbardo := _producto(Producto.Id.MALBARDO)
	var productos: Array[Producto] = [actroncito, malbardo]
	var inventario := Inventario.new(
		productos, {Producto.Id.ACTRONCITO: 2, Producto.Id.MALBARDO: 2}
	)
	for producto in productos:
		inventario.ingresar(producto, Inventario.Ubicacion.DEPOSITO, 4)
	var estante := Estante.new(inventario, productos)
	var unidad := estante.retirar(actroncito)
	assert_int(estante.colocar_unidad(unidad, malbardo, 0)).is_equal(
		Estante.Rechazo.PRODUCTO_NO_ACEPTADO
	)
	assert_int(estante.unidades_en_gondola(malbardo)).is_zero()
	assert_int(estante.reservadas(actroncito)).is_equal(1)
	assert_int(estante.colocar_unidad(unidad, actroncito, 1)).is_equal(Estante.Rechazo.NINGUNO)
	assert_array(estante.casilleros_ocupados(actroncito)).is_equal([1])
	# Un producto que el estante no acepta se rechaza en cualquier casillero.
	var laysntt := _producto(Producto.Id.LAYSNTT)
	assert_int(estante.colocar(laysntt, 0)).is_equal(Estante.Rechazo.PRODUCTO_NO_ACEPTADO)


func test_agarrar_el_del_medio_deja_vacio_solo_ese() -> void:  # AC-STK-044
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var estante := _estante(actroncito, 5, 3, 5)
	assert_bool(_es_faltante(estante, actroncito)).is_false()
	var unidad := estante.agarrar(actroncito, 2)
	assert_object(unidad).is_not_null()
	assert_int(unidad.producto.id).is_equal(Producto.Id.ACTRONCITO)
	assert_array(estante.casilleros_vacios(actroncito)).is_equal([2])
	assert_array(estante.casilleros_ocupados(actroncito)).is_equal([0, 1, 3, 4])
	assert_bool(_es_faltante(estante, actroncito)).is_true()
	assert_int(estante.colocar_unidad(unidad, actroncito, 2)).is_equal(Estante.Rechazo.NINGUNO)
	assert_array(estante.casilleros_vacios(actroncito)).is_empty()
	assert_array(estante.casilleros_ocupados(actroncito)).is_equal([0, 1, 2, 3, 4])
	assert_bool(_es_faltante(estante, actroncito)).is_false()


func test_agarrar_un_casillero_vacio_no_da_nada() -> void:  # AC-STK-045
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var estante := _estante(actroncito, 3, 5, 1)
	assert_object(estante.agarrar(actroncito, 1)).is_null()
	# Tampoco lo que no es un casillero de su fila, ni un producto que el estante no acepta.
	assert_object(estante.agarrar(actroncito, 3)).is_null()
	assert_object(estante.agarrar(actroncito, -2)).is_null()
	assert_object(estante.agarrar(_producto(Producto.Id.MALBARDO), 0)).is_null()
	assert_object(estante.agarrar(null, 0)).is_null()
	assert_int(estante.unidades_en_gondola(actroncito)).is_equal(1)
	assert_int(estante.unidades_en_deposito(actroncito)).is_equal(5)
	assert_int(estante.reservadas(actroncito)).is_zero()


func test_la_unidad_agarrada_se_coloca_en_cualquier_vacio_de_su_producto() -> void:  # AC-STK-045
	# Tres de cuatro ocupados: agarrar el segundo deja dos vacíos, y la unidad va al otro.
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var estante := _estante(actroncito, 4, 2, 3)
	assert_array(estante.casilleros_vacios(actroncito)).is_equal([3])
	var unidad := estante.agarrar(actroncito, 1)
	assert_array(estante.casilleros_vacios(actroncito)).is_equal([1, 3])
	assert_int(estante.colocar_unidad(unidad, actroncito, 0)).is_equal(
		Estante.Rechazo.CASILLERO_OCUPADO
	)
	assert_int(estante.colocar_unidad(unidad, actroncito, 3)).is_equal(Estante.Rechazo.NINGUNO)
	assert_array(estante.casilleros_vacios(actroncito)).is_equal([1])
	assert_int(estante.unidades_en_gondola(actroncito)).is_equal(3)
	assert_int(estante.reservadas(actroncito)).is_zero()


func test_la_unidad_agarrada_se_cuenta_una_sola_vez() -> void:  # AC-STK-046
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var estante := _estante(actroncito, 8, 5, 8)
	var caja := ContenidoDeLaCaja.new(actroncito, estante)
	assert_int(caja.unidades()).is_equal(5)
	assert_int(_vendibles(estante, actroncito)).is_equal(5)
	var unidad := estante.agarrar(actroncito, 6)
	assert_int(estante.unidades_en_gondola(actroncito)).is_equal(7)
	assert_int(caja.unidades()).is_equal(5)
	assert_int(_vendibles(estante, actroncito)).is_equal(5)
	assert_bool(_es_faltante(estante, actroncito)).is_true()
	# La caja no la da otra vez: el casillero que dejó ya la espera a ella (BR-STK-017).
	assert_int(estante.disponibles_para_retirar(actroncito)).is_zero()
	assert_bool(caja.meter(unidad)).is_true()
	assert_int(caja.unidades()).is_equal(6)
	assert_int(estante.unidades_en_gondola(actroncito)).is_equal(7)
	assert_int(_vendibles(estante, actroncito)).is_equal(5)
	var otra := caja.sacar()
	assert_object(otra).is_not_null()
	assert_int(estante.colocar_unidad(otra, actroncito, 6)).is_equal(Estante.Rechazo.NINGUNO)
	assert_int(estante.unidades_en_gondola(actroncito)).is_equal(8)
	assert_int(caja.unidades()).is_equal(5)
	assert_int(_vendibles(estante, actroncito)).is_equal(5)


func test_con_la_caja_en_ocho_la_unidad_de_la_gondola_no_entra() -> void:  # AC-STK-047
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var estante := _estante(actroncito, 8, ReglasDelEstante.UNIDADES_POR_CAJA, 8)
	var caja := ContenidoDeLaCaja.new(actroncito, estante)
	var unidad := estante.agarrar(actroncito, 0)
	assert_int(caja.unidades()).is_equal(ReglasDelEstante.UNIDADES_POR_CAJA)
	assert_bool(caja.meter(unidad)).is_false()
	assert_int(caja.unidades()).is_equal(ReglasDelEstante.UNIDADES_POR_CAJA)
	assert_int(estante.reservadas(actroncito)).is_equal(1)
	assert_array(estante.casilleros_vacios(actroncito)).is_equal([0])
	# Sigue siendo una unidad afuera: colocarla la vuelve a poner.
	assert_int(estante.colocar_unidad(unidad, actroncito, 0)).is_equal(Estante.Rechazo.NINGUNO)


func test_dos_colocaciones_seguidas_en_el_mismo_casillero_ponen_una() -> void:  # AC-STK-043
	# La misma unidad dos veces ya no está afuera la segunda; y del depósito, el casillero ya está
	# ocupado. La góndola sube una sola.
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var estante := _estante(actroncito, 4, 5)
	var unidad := estante.retirar(actroncito)
	assert_int(estante.colocar_unidad(unidad, actroncito, 2)).is_equal(Estante.Rechazo.NINGUNO)
	assert_int(estante.colocar_unidad(unidad, actroncito, 2)).is_equal(
		Estante.Rechazo.PRODUCTO_NO_ACEPTADO
	)
	assert_int(estante.colocar(actroncito, 2)).is_equal(Estante.Rechazo.CASILLERO_OCUPADO)
	assert_int(estante.unidades_en_gondola(actroncito)).is_equal(1)


func test_sin_casillero_se_coloca_en_el_primero_vacio() -> void:
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var estante := _estante(actroncito, 4, 5)
	assert_int(estante.colocar(actroncito, 2)).is_equal(Estante.Rechazo.NINGUNO)
	assert_int(estante.colocar(actroncito)).is_equal(Estante.Rechazo.NINGUNO)
	assert_array(estante.casilleros_ocupados(actroncito)).is_equal([0, 2])
	var unidad := estante.retirar(actroncito)
	assert_int(estante.colocar_unidad(unidad)).is_equal(Estante.Rechazo.NINGUNO)
	assert_array(estante.casilleros_ocupados(actroncito)).is_equal([0, 1, 2])


func test_al_abrir_los_vacios_son_los_ultimos_de_la_fila() -> void:
	# La apertura llena la góndola con una cantidad, y el estante la pone desde el primero: lo que
	# falta queda al final de la fila, que es lo que la noche dibuja al abrir.
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var estante := _estante(actroncito, 6, 8, 2)
	assert_array(estante.casilleros_ocupados(actroncito)).is_equal([0, 1])
	assert_array(estante.casilleros_vacios(actroncito)).is_equal([2, 3, 4, 5])


func test_los_casilleros_cuentan_con_la_gondola_del_inventario() -> void:
	# El estante no lleva un contador: cuántos casilleros están ocupados sale de la góndola del
	# inventario, así que moverla por fuera también se ve acá.
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var productos: Array[Producto] = [actroncito]
	var inventario := Inventario.new(productos, {Producto.Id.ACTRONCITO: 3})
	inventario.ingresar(actroncito, Inventario.Ubicacion.DEPOSITO, 3)
	var estante := Estante.new(inventario, productos)
	assert_int(estante.colocar(actroncito, 2)).is_equal(Estante.Rechazo.NINGUNO)
	inventario.mover(actroncito, Inventario.Ubicacion.DEPOSITO, Inventario.Ubicacion.GONDOLA, 1)
	assert_int(estante.casilleros_ocupados(actroncito).size()).is_equal(2)
	assert_array(estante.casilleros_ocupados(actroncito)).contains([2])
	assert_int(estante.casilleros_vacios(actroncito).size()).is_equal(1)


func test_con_una_unidad_en_la_mano_se_colocan_sus_vacios() -> void:  # AC-PLY-045
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var malbardo := _producto(Producto.Id.MALBARDO)
	var productos: Array[Producto] = [actroncito, malbardo]
	var inventario := Inventario.new(
		productos, {Producto.Id.ACTRONCITO: 4, Producto.Id.MALBARDO: 3}
	)
	for producto in productos:
		inventario.ingresar(producto, Inventario.Ubicacion.DEPOSITO, 4)
	inventario.ingresar(actroncito, Inventario.Ubicacion.GONDOLA, 2)
	var estante := Estante.new(inventario, productos)
	var unidad := estante.retirar(actroncito)
	assert_array(estante.casilleros_para_colocar(actroncito, unidad)).is_equal([2, 3])
	assert_array(estante.casilleros_para_colocar(malbardo, unidad)).is_empty()
	# Con la mano vacía, con otra cosa o con una caja, ningún casillero se ve.
	for sostenido: ObjetoDelAlmacen in [null, ObjetoDelAlmacen.new()]:
		for producto in productos:
			assert_array(estante.casilleros_para_colocar(producto, sostenido)).is_empty()
	# Con la fila completa, tampoco.
	estante.colocar_unidad(unidad, actroncito, 2)
	estante.colocar(actroncito, 3)
	var otra := UnidadDeProducto.new(actroncito)
	assert_array(estante.casilleros_para_colocar(actroncito, otra)).is_empty()


func test_con_las_manos_vacias_se_agarran_los_ocupados() -> void:  # AC-PLY-049
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var estante := _estante(actroncito, 4, 4, 3)
	assert_array(estante.casilleros_para_agarrar(actroncito, null)).is_equal([0, 1, 2])
	var unidad := estante.agarrar(actroncito, 1)
	assert_array(estante.casilleros_para_agarrar(actroncito, null)).is_equal([0, 2])
	# Con cualquier cosa en la mano, ninguno: agarrar es una cosa más por vez.
	assert_array(estante.casilleros_para_agarrar(actroncito, unidad)).is_empty()
	assert_array(estante.casilleros_para_agarrar(actroncito, ObjetoDelAlmacen.new())).is_empty()


func test_el_clic_sobre_un_casillero_lo_decide_la_mano() -> void:  # AC-PLY-048 AC-PLY-049
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var estante := _estante(actroncito, 4, 4)
	assert_int(estante.uso(null)).is_equal(Estante.Gesto.AGARRAR)
	assert_int(estante.uso(UnidadDeProducto.new(actroncito))).is_equal(Estante.Gesto.COLOCAR)
	assert_int(estante.uso(ObjetoDelAlmacen.new())).is_equal(Estante.Gesto.NADA)
