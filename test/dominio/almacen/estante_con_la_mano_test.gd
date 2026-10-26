## Qué pasa con reponer cuando el jugador cierra la noche con una unidad en la mano.
##
## Va aparte de `estante_test.gd` por el tope de métodos públicos por archivo: aquella suite ya
## tiene veinte. Ningún caso levanta una escena.
extends GdUnitTestSuite

## Una fila chica para que vaciar o llenar un producto sean pocas llamadas.
const CUPO_DE_PRUEBA := 2

const EN_DEPOSITO := 5


func _producto(id: Producto.Id) -> Producto:
	return Producto.new(id, "de prueba", 100)


func _estante(aceptados: Array[Producto]) -> Estante:
	var por_producto: Dictionary[Producto.Id, int] = {}
	for producto in aceptados:
		por_producto[producto.id] = CUPO_DE_PRUEBA
	var inventario := Inventario.new(aceptados, por_producto)
	for producto in aceptados:
		inventario.ingresar(producto, Inventario.Ubicacion.DEPOSITO, EN_DEPOSITO)
	return Estante.new(inventario, aceptados)


## Llena de la fila de `producto` todo menos `vacios` casilleros.
func _llenar_salvo(estante: Estante, producto: Producto, vacios: int) -> void:
	for _unidad in range(CUPO_DE_PRUEBA - vacios):
		estante.colocar(producto)


func test_la_unidad_en_la_mano_ocupa_el_unico_casillero_vacio() -> void:  # AC-STK-117
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var estante := _estante([actroncito])
	_llenar_salvo(estante, actroncito, 1)
	var unidad := estante.retirar(actroncito)
	assert_bool(estante.completada()).is_false()
	assert_bool(estante.completada(unidad)).is_true()
	assert_int(estante.unidades_en_gondola(actroncito)).is_equal(CUPO_DE_PRUEBA - 1)


func test_la_unidad_agarrada_de_la_gondola_tambien_cuenta_en_la_mano() -> void:  # AC-STK-117
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var estante := _estante([actroncito])
	_llenar_salvo(estante, actroncito, 0)
	var unidad := estante.agarrar(actroncito, 0)
	assert_bool(estante.completada()).is_false()
	assert_bool(estante.completada(unidad)).is_true()


func test_la_mano_no_alcanza_con_dos_casilleros_vacios_del_producto() -> void:  # AC-STK-117
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var estante := _estante([actroncito])
	_llenar_salvo(estante, actroncito, 2)
	assert_bool(estante.completada(estante.retirar(actroncito))).is_false()


func test_la_mano_no_completa_el_faltante_de_otro_producto() -> void:  # AC-STK-117
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var malbardo := _producto(Producto.Id.MALBARDO)
	var estante := _estante([actroncito, malbardo])
	_llenar_salvo(estante, actroncito, 1)
	var unidad := estante.retirar(actroncito)
	assert_bool(estante.completada(unidad)).is_false()
	_llenar_salvo(estante, malbardo, 0)
	assert_bool(estante.completada(unidad)).is_true()


func test_lo_que_no_es_una_unidad_afuera_no_cuenta_como_puesto() -> void:  # AC-STK-117
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var estante := _estante([actroncito])
	_llenar_salvo(estante, actroncito, 1)
	assert_bool(estante.completada(ObjetoDelAlmacen.new())).is_false()
	assert_bool(estante.completada(UnidadDeProducto.new(actroncito))).is_false()
	var devuelta := estante.retirar(actroncito)
	estante.devolver(devuelta)
	assert_bool(estante.completada(devuelta)).is_false()
