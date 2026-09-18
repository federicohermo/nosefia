## La caja del depósito: qué producto declara, con qué cuerpo se lleva y qué dejó de hacer.
##
## **La escena se instancia y no se entra al árbol**, igual que las otras suites de `escenas/`.
extends GdUnitTestSuite

const ESCENA := "res://src/escenas/objetos/caja_de_productos.tscn"
const SCRIPT := "res://src/escenas/objetos/caja_de_productos.gd"
const CABLEADO := "res://src/escenas/almacen.gd"

## El script del nodo se preloadea para poder tiparlo: los scripts de `escenas/` son cáscara y no
## declaran `class_name`.
const CajaQueSeLleva := preload("res://src/escenas/objetos/caja_de_productos.gd")


func test_la_caja_declara_su_producto_con_un_id_del_catalogo() -> void:  # 008-AC8
	# Es un `Producto.Id` y no un `String` suelto: el conjunto es cerrado, y uno mal escrito no
	# rompe nada — el producto simplemente no llega nunca y nadie se entera.
	var caja := _caja()
	caja.producto = Producto.Id.JABON
	assert_object(Catalogo.de(caja.producto)).is_not_null()
	assert_int(Catalogo.de(caja.producto).id).is_equal(Producto.Id.JABON)


func test_tocar_la_caja_la_entrega_para_levantarla() -> void:  # 008-AC8 047-AC4
	# Antes devolvía `null` y el clic sacaba una unidad. Ahora contesta sus propios datos, que es
	# lo que `Agarre` necesita para llevársela, y no son los de una unidad de producto: quien
	# mire lo que hay en la mano tiene que poder distinguir la caja de lo que sale de ella.
	var caja := _caja()
	var datos := caja.call(ReglasDeLosObjetos.METODO_INTERACTUAR) as ObjetoDelAlmacen
	assert_object(datos).is_not_null()
	assert_bool(datos is UnidadDeProducto).is_false()
	assert_bool(datos.es_levantable()).is_true()


func test_la_caja_contesta_el_contrato_de_interaccion() -> void:  # 008-AC8
	var caja := _caja()
	assert_bool(caja.has_method(ReglasDeLosObjetos.METODO_INTERACTUAR)).is_true()
	assert_bool(caja.is_in_group(ReglasDelJugador.GRUPO_INTERACTUABLE)).is_true()


func test_el_cuerpo_de_la_caja_se_puede_llevar() -> void:  # 047-AC5
	# Unos `datos` en `null` los rechaza `Manos` como «no es levantable»: la escena carga sin un
	# solo error y el clic no hace nada.
	#
	# **El cuerpo es rígido y arranca congelado**, y las dos mitades importan. El spec lo pedía
	# estático —«una caja se apoya, no rebota ni rueda»—, y eso sigue siendo cierto mientras
	# descansa: congelada es un cuerpo estático, y el puesto le escribe el lugar derecho. Rígido
	# es lo que la deja caer cuando le sacan lo que la sostenía, que es lo que desarma una pila.
	var caja := _caja()
	assert_object(caja).is_instanceof(RigidBody3D)
	(
		assert_bool(caja.freeze)
		. override_failure_message("la caja arranca viva: se acomoda sola antes de que la toquen")
		. is_true()
	)
	(
		assert_object(caja.datos)
		. override_failure_message("`caja_de_productos.tscn` no le asignó `datos`: no se levanta")
		. is_not_null()
	)
	assert_str(caja.datos.nombre).is_not_empty()


func test_la_caja_no_decide_nada_sobre_el_cupo() -> void:  # 008-AC10
	# El criterio pide que este archivo no tenga un solo `if`, `match` ni `cupo`: cuántas entran
	# y por qué se rechaza son preguntas de `CajaDeTraslado`, que es donde tienen test.
	var texto := FileAccess.get_file_as_string(SCRIPT)
	assert_str(texto).is_not_empty()
	for patron in ["if", "match", "cupo"]:
		(
			assert_bool(texto.contains(patron))
			. override_failure_message("`caja_de_productos.gd` nombra `%s`" % patron)
			. is_false()
		)


func test_la_caja_ya_no_despacha_por_su_cuenta() -> void:  # 047-AC9
	# La señal se fue con el clic izquierdo, y mientras exista el cableado se le puede volver a
	# colgar: quedarían dos rutas hacia la misma unidad y ninguna daría rojo.
	for ruta in [SCRIPT, CABLEADO]:
		var texto := FileAccess.get_file_as_string(ruta)
		assert_str(texto).is_not_empty()
		(
			assert_str(texto)
			. override_failure_message("`%s` todavía nombra `producto_pedido`" % ruta)
			. not_contains("producto_pedido")
		)


func _caja() -> CajaQueSeLleva:
	return auto_free(load(ESCENA).instantiate())
