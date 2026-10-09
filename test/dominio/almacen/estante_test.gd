## El estante: qué acepta, cuánto le entra y qué pasa con la unidad que se coloca.
##
## **Ni un `Node3D` en toda la suite.** Es la prueba de que la regla de reponer se puede ejercer
## sin levantar una escena, que es el criterio entero para que algo viva en `dominio/`.
##
## El inventario se arma con productos y casilleros inventados, y no con `Catalogo.todos()` ni
## con el local, en los casos que miden aritmética: así ni rebalancear el catálogo ni mover una
## fila en el modelo pone en rojo un solo caso de acá. Los que miden el catálogo lo dicen en su
## nombre.
extends GdUnitTestSuite

## Una fila chica para que llenar el estante en un caso sean dos llamadas y no seis.
const CUPO_DE_PRUEBA := 2

## Más de las que entran en el estante, para separar «se llenó» de «se acabó el depósito».
const EN_DEPOSITO := 5


func test_tirar_la_unidad_de_gondola_conserva_la_caja_y_el_hueco() -> void:  # AC-STK-053
	var producto := _producto(Producto.Id.ACTRONCITO)
	var inventario := Inventario.new([producto], {producto.id: 2})
	inventario.ingresar(producto, Inventario.Ubicacion.DEPOSITO, 8)
	inventario.ingresar(producto, Inventario.Ubicacion.GONDOLA, 2)
	var estante := Estante.new(inventario, [producto])
	var unidad := estante.agarrar(producto, 1)
	assert_object(unidad).is_not_null()
	assert_int(estante.disponibles_para_retirar(producto)).is_equal(8)
	assert_bool(estante.desechar(unidad)).is_true()
	assert_int(estante.disponibles_para_retirar(producto)).is_equal(8)
	assert_int(estante.unidades_en_deposito(producto)).is_equal(8)
	assert_array(estante.casilleros_vacios(producto)).contains_exactly([1])
	assert_bool(estante.completada()).is_false()
	assert_bool(inventario.esta_afuera(unidad)).is_false()
	assert_bool(estante.devolver(unidad)).is_false()
	assert_int(estante.colocar_unidad(unidad)).is_equal(Estante.Rechazo.PRODUCTO_NO_ACEPTADO)


func test_tirar_la_unidad_de_caja_descuenta_sin_devolverla() -> void:  # AC-STK-053
	var producto := _producto(Producto.Id.ACTRONCITO)
	var estante := _estante([producto], 8)
	var unidad := estante.retirar(producto)
	assert_int(estante.disponibles_para_retirar(producto)).is_equal(7)
	assert_bool(estante.desechar(unidad)).is_true()
	assert_int(estante.disponibles_para_retirar(producto)).is_equal(7)
	assert_int(estante.unidades_en_deposito(producto)).is_equal(7)
	assert_int(estante.reservadas(producto)).is_zero()
	for desconocida: UnidadDeProducto in [unidad, null, UnidadDeProducto.new(producto)]:
		assert_bool(estante.desechar(desconocida)).is_false()
	assert_int(estante.unidades_en_deposito(producto)).is_equal(7)
	assert_int(estante.unidades_en_gondola(producto)).is_zero()


## Un producto con el `id` que el caso necesita, sin pasar por el catálogo.
func _producto(id: Producto.Id) -> Producto:
	return Producto.new(id, "de prueba", 100)


## Un estante que acepta esos productos, con el depósito ya cargado, la góndola en cero y la
## misma cantidad de casilleros en la fila de adelante de cada uno.
func _estante(
	aceptados: Array[Producto], en_deposito: int = EN_DEPOSITO, casilleros: int = CUPO_DE_PRUEBA
) -> Estante:
	var por_producto: Dictionary[Producto.Id, int] = {}
	for producto in aceptados:
		por_producto[producto.id] = casilleros
	var inventario := Inventario.new(aceptados, por_producto)
	for producto in aceptados:
		inventario.ingresar(producto, Inventario.Ubicacion.DEPOSITO, en_deposito)
	return Estante.new(inventario, aceptados)


func test_lo_que_el_estante_no_acepta_se_rechaza_sin_mover_una_unidad() -> void:  # AC-STK-009
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var estante := _estante([actroncito])
	var malbardo := _producto(Producto.Id.MALBARDO)
	assert_int(estante.colocar(malbardo)).is_equal(Estante.Rechazo.PRODUCTO_NO_ACEPTADO)
	assert_int(estante.unidades_en_gondola(actroncito)).is_equal(0)
	assert_int(estante.unidades_en_gondola(malbardo)).is_equal(0)


func test_con_el_estante_lleno_se_rechaza_sin_mover_una_unidad() -> void:  # AC-STK-008
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var estante := _estante([actroncito])
	for _unidad in range(CUPO_DE_PRUEBA):
		assert_int(estante.colocar(actroncito)).is_equal(Estante.Rechazo.NINGUNO)
	assert_int(estante.colocar(actroncito)).is_equal(Estante.Rechazo.ESTANTE_LLENO)
	# La góndola quedó en el cupo y el depósito no bajó una unidad de más: el rechazo no cobra.
	assert_int(estante.unidades_en_gondola(actroncito)).is_equal(CUPO_DE_PRUEBA)
	assert_int(estante.unidades_en_deposito(actroncito)).is_equal(EN_DEPOSITO - CUPO_DE_PRUEBA)


func test_sin_unidades_en_el_deposito_se_rechaza_sin_mover_una_unidad() -> void:  # AC-STK-009
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var estante := _estante([actroncito], 0)
	assert_int(estante.colocar(actroncito)).is_equal(Estante.Rechazo.SIN_UNIDADES_EN_DEPOSITO)
	assert_int(estante.unidades_en_gondola(actroncito)).is_equal(0)
	assert_int(estante.unidades_en_deposito(actroncito)).is_equal(0)


func test_con_los_tres_rechazos_a_la_vez_gana_el_primero_del_orden() -> void:  # AC-STK-009
	# Lleno y sin depósito a la vez: el cupo entero pasó del depósito a la góndola.
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var estante := _estante([actroncito], CUPO_DE_PRUEBA)
	for _unidad in range(CUPO_DE_PRUEBA):
		estante.colocar(actroncito)
	assert_int(estante.unidades_en_deposito(actroncito)).is_equal(0)
	var malbardo := _producto(Producto.Id.MALBARDO)
	assert_int(estante.colocar(malbardo)).is_equal(Estante.Rechazo.PRODUCTO_NO_ACEPTADO)
	assert_int(estante.colocar(actroncito)).is_equal(Estante.Rechazo.ESTANTE_LLENO)
	var con_lugar := _estante([actroncito], 0)
	assert_int(con_lugar.colocar(actroncito)).is_equal(Estante.Rechazo.SIN_UNIDADES_EN_DEPOSITO)


func test_colocar_mueve_la_unidad_en_vez_de_crearla() -> void:
	# El total es la aserción que importa: un `ingresar()` en la góndola dejaría la góndola
	# igual de bien y el almacén con una unidad que nadie compró.
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var estante := _estante([actroncito])
	var total_antes := (
		estante.unidades_en_gondola(actroncito) + estante.unidades_en_deposito(actroncito)
	)
	assert_int(estante.colocar(actroncito)).is_equal(Estante.Rechazo.NINGUNO)
	assert_int(estante.unidades_en_gondola(actroncito)).is_equal(1)
	assert_int(estante.unidades_en_deposito(actroncito)).is_equal(EN_DEPOSITO - 1)
	(
		assert_int(
			estante.unidades_en_gondola(actroncito) + estante.unidades_en_deposito(actroncito)
		)
		. is_equal(total_antes)
	)


func test_las_unidades_en_gondola_salen_del_inventario_y_no_de_un_contador_propio() -> void:
	# Se mueve el inventario por fuera del estante y se le vuelve a preguntar: con un contador
	# propio, el estante contestaría el número viejo y ningún error lo diría.
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var inventario := Inventario.new([actroncito], {Producto.Id.ACTRONCITO: CUPO_DE_PRUEBA})
	inventario.ingresar(actroncito, Inventario.Ubicacion.DEPOSITO, EN_DEPOSITO)
	var estante := Estante.new(inventario, [actroncito])
	assert_int(estante.unidades_en_gondola(actroncito)).is_equal(0)
	inventario.mover(actroncito, Inventario.Ubicacion.DEPOSITO, Inventario.Ubicacion.GONDOLA, 1)
	assert_int(estante.unidades_en_gondola(actroncito)).is_equal(1)


func test_a_mitad_del_cupo_el_estante_no_esta_completo() -> void:  # AC-STK-013
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var estante := _estante([actroncito], EN_DEPOSITO, 4)
	assert_bool(estante.completada()).is_false()
	estante.colocar(actroncito)
	estante.colocar(actroncito)
	assert_bool(estante.completada()).is_false()


func test_al_llegar_al_cupo_de_todos_los_aceptados_el_estante_esta_completo() -> void:  # AC-STK-013
	# Con dos productos: llenar uno solo no alcanza, y ésa es la mitad que un `completada()`
	# escrito sobre el último producto colocado daría por buena.
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var malbardo := _producto(Producto.Id.MALBARDO)
	var estante := _estante([actroncito, malbardo])
	for _unidad in range(CUPO_DE_PRUEBA):
		estante.colocar(actroncito)
	assert_bool(estante.completada()).is_false()
	for _unidad in range(CUPO_DE_PRUEBA):
		estante.colocar(malbardo)
	assert_bool(estante.completada()).is_true()


func test_con_menos_unidades_que_el_cupo_colocarlas_todas_no_completa() -> void:
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var estante := _estante([actroncito], CUPO_DE_PRUEBA - 1)
	for _unidad in range(CUPO_DE_PRUEBA):
		estante.colocar(actroncito)
	assert_int(estante.unidades_en_gondola(actroncito)).is_equal(CUPO_DE_PRUEBA - 1)
	assert_bool(estante.completada()).is_false()


func test_acepta_compara_por_id_y_no_por_instancia() -> void:
	# `Catalogo.de()` construye un producto nuevo en cada llamada, así que dos con el mismo `id`
	# son objetos distintos: comparando por instancia, reponer el del catálogo sobre un estante
	# armado con el otro contestaría «eso no va acá».
	var estante := _estante([_producto(Producto.Id.ACTRONCITO)])
	assert_bool(estante.acepta(_producto(Producto.Id.ACTRONCITO))).is_true()
	assert_bool(estante.acepta(Catalogo.de(Producto.Id.ACTRONCITO))).is_true()
	assert_bool(estante.acepta(_producto(Producto.Id.MALBARDO))).is_false()


func test_un_producto_nulo_o_desconocido_se_rechaza_en_vez_de_reventar() -> void:
	# Es la forma en que un `id` sin fila llega hasta acá: `Catalogo.de()` contesta `null`,
	# medido. Sin este camino el rechazo sería un error del motor, y gdUnit4 cuenta un error
	# como *error* y no como *failure* — el archivo sigue diciendo `PASSED`.
	var estante := _estante([_producto(Producto.Id.ACTRONCITO)])
	assert_bool(estante.acepta(null)).is_false()
	assert_int(estante.colocar(null)).is_equal(Estante.Rechazo.PRODUCTO_NO_ACEPTADO)
	assert_int(estante.unidades_en_gondola(null)).is_equal(0)
	# Sin caja en este estante no sale nada: ni del nulo ni de uno que no acepta.
	for producto: Producto in [null, _producto(Producto.Id.MALBARDO)]:
		assert_int(estante.disponibles_para_retirar(producto)).is_zero()
		assert_object(estante.retirar(producto)).is_null()


func test_el_cupo_de_cada_producto_son_los_casilleros_de_su_fila() -> void:  # AC-STK-008
	# Dos filas distintas en el mismo estante: el cupo es el de la fila de cada uno, y no uno
	# solo para el estante.
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var malbardo := _producto(Producto.Id.MALBARDO)
	var aceptados: Array[Producto] = [actroncito, malbardo]
	var inventario := Inventario.new(
		aceptados, {Producto.Id.ACTRONCITO: 4, Producto.Id.MALBARDO: 2}
	)
	var estante := Estante.new(inventario, aceptados)
	assert_int(estante.cupo(actroncito)).is_equal(4)
	assert_int(estante.cupo(malbardo)).is_equal(2)
	assert_int(estante.cupo(_producto(Producto.Id.LAYSNTT))).is_zero()


func test_el_estante_no_lleva_el_cupo_ni_el_stock_escritos_adentro() -> void:
	# El estante del dominio tampoco: la fuente es el inventario, con los casilleros que le pasó
	# quien armó el local, y una cuenta propia acá daría verde en los dos gates mientras
	# contradice al inventario.
	var texto := FileAccess.get_file_as_string("res://src/dominio/almacen/estante.gd")
	assert_str(texto).is_not_empty()
	for patron: String in ["get_child_count", "_unidades", "_stock"]:
		(
			assert_bool(texto.contains(patron))
			. override_failure_message("`estante.gd` de `dominio/` nombra `%s`" % patron)
			. is_false()
		)


func test_retirar_reserva_la_unidad_sin_duplicar_el_stock() -> void:
	var producto := Catalogo.todos()[0]
	var inventario := Inventario.new([producto], {producto.id: CUPO_DE_PRUEBA})
	inventario.ingresar(producto, Inventario.Ubicacion.DEPOSITO, 1)
	var estante := Estante.new(inventario, [producto])
	var unidad := estante.retirar(producto)
	assert_object(unidad).is_not_null()
	assert_object(estante.retirar(producto)).is_null()
	assert_int(estante.unidades_en_gondola(producto)).is_zero()
	assert_int(estante.unidades_en_deposito(producto)).is_equal(1)
	assert_int(estante.colocar(producto)).is_equal(Estante.Rechazo.SIN_UNIDADES_EN_DEPOSITO)
	assert_int(estante.colocar_unidad(unidad)).is_equal(Estante.Rechazo.NINGUNO)
	assert_int(estante.unidades_en_deposito(producto)).is_zero()
	assert_int(estante.unidades_en_gondola(producto)).is_equal(1)
	assert_int(estante.colocar_unidad(unidad)).is_equal(Estante.Rechazo.PRODUCTO_NO_ACEPTADO)


func test_el_estante_lleno_conserva_la_unidad_rechazada() -> void:
	var producto := Producto.new(Producto.Id.ACTRONCITO, "Actroncito", 1)
	var inventario := Inventario.new([producto], {Producto.Id.ACTRONCITO: 1})
	inventario.ingresar(producto, Inventario.Ubicacion.DEPOSITO, 2)
	var estante := Estante.new(inventario, [producto])
	var primera := estante.retirar(producto)
	inventario.mover(producto, Inventario.Ubicacion.DEPOSITO, Inventario.Ubicacion.GONDOLA, 1)
	assert_int(estante.colocar_unidad(primera)).is_equal(Estante.Rechazo.ESTANTE_LLENO)
	assert_int(estante.disponibles_para_retirar(producto)).is_zero()
	assert_int(estante.unidades_en_gondola(producto)).is_equal(1)


func test_con_la_fila_completa_la_caja_entrega_hasta_vaciarse() -> void:  # AC-STK-017 AC-STK-018
	# Ningún casillero espera una unidad, y la caja las da igual, de a una, hasta quedar en 0. La
	# que no tiene casillero se rechaza al colocarla y sigue afuera; devueltas, la caja se llena.
	# Con las 8 afuera no se vende ninguna, y devueltas se venden las 8.
	var casilleros := 8
	var producto := _producto(Producto.Id.ACTRONCITO)
	var inventario := Inventario.new([producto], {producto.id: casilleros})
	inventario.ingresar(producto, Inventario.Ubicacion.GONDOLA, casilleros)
	inventario.ingresar(producto, Inventario.Ubicacion.DEPOSITO, casilleros)
	var estante := Estante.new(inventario, [producto])
	assert_array(estante.casilleros_vacios(producto)).is_empty()
	var afuera: Array[UnidadDeProducto] = []
	for en_la_caja in range(casilleros, 0, -1):
		assert_int(estante.disponibles_para_retirar(producto)).is_equal(en_la_caja)
		var unidad := estante.retirar(producto)
		assert_object(unidad).is_not_null()
		afuera.append(unidad)
	assert_int(estante.disponibles_para_retirar(producto)).is_zero()
	assert_object(estante.retirar(producto)).is_null()
	assert_int(estante.colocar_unidad(afuera[0])).is_equal(Estante.Rechazo.ESTANTE_LLENO)
	assert_int(estante.reservadas(producto)).is_equal(casilleros)
	assert_int(inventario.vendibles(producto)).is_zero()
	for unidad in afuera:
		assert_bool(estante.devolver(unidad)).is_true()
	assert_int(estante.disponibles_para_retirar(producto)).is_equal(casilleros)
	assert_int(inventario.vendibles(producto)).is_equal(casilleros)
	assert_int(estante.unidades_en_deposito(producto)).is_equal(casilleros)
	assert_int(estante.unidades_en_gondola(producto)).is_equal(casilleros)


func test_devolver_anula_la_reserva_y_no_mueve_mercaderia() -> void:  # AC-STK-039
	# La unidad nunca salió del depósito: devolverla sólo la deja de contar afuera. La segunda
	# vez ya no está afuera, y no anula nada.
	var producto := _producto(Producto.Id.ACTRONCITO)
	var estante := _estante([producto])
	var disponibles := estante.disponibles_para_retirar(producto)
	var unidad := estante.retirar(producto)
	assert_int(estante.disponibles_para_retirar(producto)).is_equal(disponibles - 1)
	assert_bool(estante.devolver(unidad)).is_true()
	assert_int(estante.disponibles_para_retirar(producto)).is_equal(disponibles)
	assert_int(estante.unidades_en_deposito(producto)).is_equal(EN_DEPOSITO)
	assert_int(estante.unidades_en_gondola(producto)).is_zero()
	assert_bool(estante.devolver(unidad)).is_false()
	assert_int(estante.disponibles_para_retirar(producto)).is_equal(disponibles)
	# Una unidad devuelta no se coloca: ya no es una que salió.
	assert_int(estante.colocar_unidad(unidad)).is_equal(Estante.Rechazo.PRODUCTO_NO_ACEPTADO)
	assert_int(estante.unidades_en_gondola(producto)).is_zero()


func test_las_reservadas_son_las_que_salieron_y_no_se_colocaron() -> void:
	# Por producto: la que salió de una caja no cuenta contra la de al lado.
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var malbardo := _producto(Producto.Id.MALBARDO)
	var estante := _estante([actroncito, malbardo])
	var primera := estante.retirar(actroncito)
	estante.retirar(actroncito)
	assert_int(estante.reservadas(actroncito)).is_equal(2)
	assert_int(estante.reservadas(malbardo)).is_zero()
	assert_int(estante.colocar_unidad(primera)).is_equal(Estante.Rechazo.NINGUNO)
	assert_int(estante.reservadas(actroncito)).is_equal(1)
	assert_int(estante.reservadas(null)).is_zero()
	assert_bool(estante.devolver(null)).is_false()
