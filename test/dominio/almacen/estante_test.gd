## El estante: qué acepta, cuánto le entra y qué pasa con la unidad que se coloca.
##
## **Ni un `Node3D` en toda la suite.** Es la prueba de que la regla de reponer se puede ejercer
## sin levantar una escena, que es el criterio entero para que algo viva en `dominio/`.
##
## El inventario se arma con productos inventados y no con `Catalogo.todos()` en los casos que
## miden aritmética: así rebalancear un umbral no pone en rojo un solo caso de acá. Los que
## miden el catálogo lo dicen en su nombre.
extends GdUnitTestSuite

## Un umbral chico para que llenar el estante en un caso sean dos llamadas y no seis.
const CUPO_DE_PRUEBA := 2

## Más de las que entran en el estante, para separar «se llenó» de «se acabó el depósito».
const EN_DEPOSITO := 5


## Un producto con el `id` y el umbral que el caso necesita, sin pasar por el catálogo.
func _producto(id: Producto.Id, umbral: int = CUPO_DE_PRUEBA) -> Producto:
	return Producto.new(id, "de prueba", 100, umbral)


## Un estante que acepta esos productos, con el depósito ya cargado y la góndola en cero.
func _estante(aceptados: Array[Producto], en_deposito: int = EN_DEPOSITO) -> Estante:
	var inventario := Inventario.new(aceptados)
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
	var inventario := Inventario.new([actroncito])
	inventario.ingresar(actroncito, Inventario.Ubicacion.DEPOSITO, EN_DEPOSITO)
	var estante := Estante.new(inventario, [actroncito])
	assert_int(estante.unidades_en_gondola(actroncito)).is_equal(0)
	inventario.mover(actroncito, Inventario.Ubicacion.DEPOSITO, Inventario.Ubicacion.GONDOLA, 1)
	assert_int(estante.unidades_en_gondola(actroncito)).is_equal(1)


func test_a_mitad_del_cupo_el_estante_no_esta_completo() -> void:  # AC-STK-013
	var actroncito := _producto(Producto.Id.ACTRONCITO, 4)
	var estante := _estante([actroncito])
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


func test_un_producto_nulo_se_rechaza_en_vez_de_reventar() -> void:
	# Es la forma en que un `id` sin fila llega hasta acá: `Catalogo.de()` contesta `null`,
	# medido. Sin este camino el rechazo sería un error del motor, y gdUnit4 cuenta un error
	# como *error* y no como *failure* — el archivo sigue diciendo `PASSED`.
	var estante := _estante([_producto(Producto.Id.ACTRONCITO)])
	assert_bool(estante.acepta(null)).is_false()
	assert_int(estante.colocar(null)).is_equal(Estante.Rechazo.PRODUCTO_NO_ACEPTADO)
	assert_int(estante.unidades_en_gondola(null)).is_equal(0)


func test_el_cupo_de_cada_producto_es_su_umbral_y_no_un_numero_propio() -> void:  # AC-STK-008
	# El 005 ya le puso un umbral a cada producto y `faltantes()` lo usa: un `cupo` propio acá
	# sería el mismo número escrito dos veces, y la copia se desincroniza sin que nadie avise.
	var actroncito := _producto(Producto.Id.ACTRONCITO, 4)
	var malbardo := _producto(Producto.Id.MALBARDO, 2)
	var estante := _estante([actroncito, malbardo])
	assert_int(estante.cupo(actroncito)).is_equal(actroncito.umbral)
	assert_int(estante.cupo(malbardo)).is_equal(malbardo.umbral)


func test_el_estante_no_lleva_el_cupo_ni_el_stock_escritos_adentro() -> void:
	# El estante del dominio tampoco: la fuente es el inventario y el umbral del producto, y una
	# cuenta propia acá daría verde en los dos gates mientras contradice al inventario.
	var texto := FileAccess.get_file_as_string("res://src/dominio/almacen/estante.gd")
	assert_str(texto).is_not_empty()
	for patron in ["get_child_count", "_unidades", "_stock"]:
		(
			assert_bool(texto.contains(patron))
			. override_failure_message("`estante.gd` de `dominio/` nombra `%s`" % patron)
			. is_false()
		)


func test_retirar_reserva_la_unidad_sin_duplicar_el_stock() -> void:
	var producto := Catalogo.todos()[0]
	var inventario := Inventario.new([producto])
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
	var producto := Producto.new(Producto.Id.ACTRONCITO, "Actroncito", 1, 1)
	var inventario := Inventario.new([producto])
	inventario.ingresar(producto, Inventario.Ubicacion.DEPOSITO, 2)
	var estante := Estante.new(inventario, [producto])
	var primera := estante.retirar(producto)
	inventario.mover(producto, Inventario.Ubicacion.DEPOSITO, Inventario.Ubicacion.GONDOLA, 1)
	assert_int(estante.colocar_unidad(primera)).is_equal(Estante.Rechazo.ESTANTE_LLENO)
	assert_int(estante.disponibles_para_retirar(producto)).is_zero()
	assert_int(estante.unidades_en_gondola(producto)).is_equal(1)


func test_no_retira_mas_que_los_lugares_libres_incluidas_las_reservas() -> void:  # AC-STK-018
	var producto := _producto(Producto.Id.ACTRONCITO)
	var estante := _estante([producto])
	var primera := estante.retirar(producto)
	var segunda := estante.retirar(producto)
	assert_object(primera).is_not_null()
	assert_object(segunda).is_not_null()
	assert_object(estante.retirar(producto)).is_null()
	estante.colocar_unidad(primera)
	assert_object(estante.retirar(producto)).is_null()
	estante.colocar_unidad(segunda)
	assert_object(estante.retirar(producto)).is_null()
	assert_int(estante.unidades_en_deposito(producto)).is_equal(EN_DEPOSITO - CUPO_DE_PRUEBA)


func test_la_caja_de_la_jornada_entrega_ocho_y_la_novena_no() -> void:  # AC-STK-016
	# Mide el catálogo y la apertura de verdad. Vender las 8 es lo que separa «la caja se vació»
	# de «la góndola se llenó»: con la góndola otra vez vacía, sólo la caja puede negar la novena.
	var inventario := Apertura.inventario_de_la_jornada()
	var producto := Catalogo.todos()[0]
	var estante := Estante.new(inventario, [producto])
	var por_caja := ReglasDelEstante.UNIDADES_POR_CAJA_DEL_DEPOSITO
	for indice in por_caja:
		var unidad := estante.retirar(producto)
		assert_object(unidad).is_not_null()
		assert_int(estante.colocar_unidad(unidad)).is_equal(Estante.Rechazo.NINGUNO)
	var venta := Venta.new()
	venta.agregar(producto, por_caja)
	assert_bool(inventario.cobrar(venta)).is_true()
	assert_int(estante.cupo(producto) - estante.unidades_en_gondola(producto)).is_equal(por_caja)
	assert_object(estante.retirar(producto)).is_null()
