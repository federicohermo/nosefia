## El repositor avisa cuando la caja recibe de vuelta la unidad de la mano, y sólo entonces: es lo
## que hace sonar devolver.
##
## Va aparte de `repositor_test.gd` por el tope de métodos públicos por archivo: aquella suite ya
## tiene veinte, sus diecinueve casos y `before_test()`. Como allá, ningún nodo entra al árbol y
## ninguno hace correr `_process`.
extends GdUnitTestSuite

## Una fila de dos casilleros, vacía: sacar una unidad siempre tiene lugar.
const CUPO_DE_PRUEBA := 2

## Cada aviso de una unidad devuelta, en orden: `[cuerpo, producto]`.
var _devueltas: Array[Array] = []


class UnidadFisica:
	extends RigidBody3D
	var datos: ObjetoDelAlmacen


func before_test() -> void:
	_devueltas = []


## Un repositor con el estante de Actroncito y `en_deposito` unidades en el depósito. Devolver no
## le pregunta nada al reloj, así que no se le cablea uno.
func _repositor(en_deposito: int) -> Repositor:
	var actroncito := Catalogo.de(Producto.Id.ACTRONCITO)
	var inventario := Inventario.new([actroncito], {Producto.Id.ACTRONCITO: CUPO_DE_PRUEBA})
	inventario.ingresar(actroncito, Inventario.Ubicacion.DEPOSITO, en_deposito)
	var agarre: Agarre = auto_free(Agarre.new())
	agarre.punto_de_carga = auto_free(Node3D.new())
	var repositor: Repositor = auto_free(Repositor.new())
	repositor.agarre = agarre
	repositor.arrancar(Estante.new(inventario, [actroncito]))
	repositor.unidad_devuelta.connect(_anotar)
	return repositor


func _anotar(nodo: Node3D, producto: Producto) -> void:
	_devueltas.append([nodo, producto])


func test_la_caja_que_recibe_la_unidad_avisa_una_vez_con_el_cuerpo() -> void:  # AC-AMB-026
	var repositor := _repositor(ReglasDelEstante.UNIDADES_POR_CAJA)
	var nodo: UnidadFisica = auto_free(UnidadFisica.new())
	assert_bool(repositor.pedir_retirar(Producto.Id.ACTRONCITO, nodo)).is_true()
	assert_array(_devueltas).is_empty()
	assert_object(repositor.pedir_devolver(Producto.Id.ACTRONCITO)).is_same(nodo)
	assert_int(_devueltas.size()).is_equal(1)
	if _devueltas.size() != 1:
		return
	assert_object(_devueltas[0][0]).is_same(nodo)
	assert_int((_devueltas[0][1] as Producto).id).is_equal(Producto.Id.ACTRONCITO)


func test_si_la_caja_no_recibe_la_unidad_no_avisa() -> void:  # AC-AMB-027
	# Devuelta una vez, la mano queda vacía y la segunda no le da nada a la caja.
	var repositor := _repositor(ReglasDelEstante.UNIDADES_POR_CAJA)
	var nodo: UnidadFisica = auto_free(UnidadFisica.new())
	assert_bool(repositor.pedir_retirar(Producto.Id.ACTRONCITO, nodo)).is_true()
	assert_object(repositor.pedir_devolver(Producto.Id.ACTRONCITO)).is_same(nodo)
	assert_object(repositor.pedir_devolver(Producto.Id.ACTRONCITO)).is_null()
	assert_int(_devueltas.size()).is_equal(1)
	# Nueve en el depósito: con una afuera, la caja tiene las de una caja entera y no recibe.
	var llena := _repositor(ReglasDelEstante.UNIDADES_POR_CAJA + 1)
	var otra: UnidadFisica = auto_free(UnidadFisica.new())
	assert_bool(llena.pedir_retirar(Producto.Id.ACTRONCITO, otra)).is_true()
	assert_object(llena.pedir_devolver(Producto.Id.ACTRONCITO)).is_null()
	# La caja de otro producto tampoco la recibe.
	assert_object(llena.pedir_devolver(Producto.Id.MALBARDO)).is_null()
	assert_int(_devueltas.size()).is_equal(1)
