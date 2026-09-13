## La caja del depósito: qué producto despacha y cómo lo declara.
##
## **La escena se instancia y no se entra al árbol**, igual que las otras suites de `escenas/`.
extends GdUnitTestSuite

const ESCENA := "res://src/escenas/objetos/caja_de_productos.tscn"
const SCRIPT := "res://src/escenas/objetos/caja_de_productos.gd"

## El script del nodo se preloadea para poder tiparlo: los scripts de `escenas/` son cáscara y no
## declaran `class_name`.
const CajaQueDespacha := preload("res://src/escenas/objetos/caja_de_productos.gd")

var _pedidos: Array[int] = []


func before_test() -> void:
	_pedidos = []


func test_la_caja_declara_su_producto_con_un_id_del_catalogo() -> void:  # 008-AC8
	# Es un `Producto.Id` y no un `String` suelto: el conjunto es cerrado, y un `"yerva"` no
	# rompe nada — el producto simplemente no llega nunca y nadie se entera.
	var caja := _caja()
	caja.producto = Producto.Id.JABON
	assert_object(Catalogo.de(caja.producto)).is_not_null()
	assert_int(Catalogo.de(caja.producto).id).is_equal(Producto.Id.JABON)


func test_tocar_la_caja_pide_su_producto_y_no_entrega_nada_para_levantar() -> void:  # 008-AC8
	# Devuelve `null` a propósito: de la caja no se levanta nada, y si contestara un objeto el
	# clic del 006 se lo llevaría en la mano en vez de cargar la caja de traslado.
	var caja := _caja()
	caja.producto = Producto.Id.ARROZ
	caja.producto_pedido.connect(_anotar_pedido)
	assert_object(caja.call(ReglasDeLosObjetos.METODO_INTERACTUAR)).is_null()
	assert_array(_pedidos).is_equal([Producto.Id.ARROZ])


func test_la_caja_contesta_el_contrato_de_interaccion() -> void:  # 008-AC8
	var caja := _caja()
	assert_bool(caja.has_method(ReglasDeLosObjetos.METODO_INTERACTUAR)).is_true()
	assert_bool(caja.is_in_group(ReglasDelJugador.GRUPO_INTERACTUABLE)).is_true()


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


func _caja() -> CajaQueDespacha:
	return auto_free(load(ESCENA).instantiate())


func _anotar_pedido(id: Producto.Id) -> void:
	_pedidos.append(id)
