## La obligatoria de atender en una noche con horarios: el nodo la cuenta con cada venta, la
## descuenta cuando llega el siguiente, y el cierre deja sólo lo que se cumplió con todos.
extends GdUnitTestSuite

const RelojDePrueba := preload("res://test/reloj_de_prueba.gd")

var _turno: Turno = null
var _cierres: Array[int] = []


func before_test() -> void:
	_turno = null
	_cierres.clear()


## Una ventanilla sin árbol, con la noche de Tin y Tia y un reloj sobre un turno entero.
func _ventanilla(inventario: Inventario) -> Ventanilla:
	var obligatorias := Apertura.obligatorias(4)
	_turno = Turno.new(Reglas.DURACION_DEL_TURNO, obligatorias)
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	reloj.arrancar(_turno, obligatorias)
	reloj.turno_cerrado.connect(func(cumplidas: int) -> void: _cierres.append(cumplidas))
	var ventanilla: Ventanilla = auto_free(Ventanilla.new())
	ventanilla.reloj = reloj
	ventanilla.arrancar(
		TareaDeAtender.new(Compradores.de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA), inventario)
	)
	return ventanilla


func _vender(ventanilla: Ventanilla, inventario: Inventario) -> void:
	var estante := Estante.new(inventario, Catalogo.todos())
	ventanilla.pedir_interaccion(null)
	while not ventanilla.puede_abandonar():
		ventanilla.pedir_interaccion(null)
	var renglones: Array[Producto] = []
	var pedido := ventanilla.atencion().comprador().pedido()
	for producto in pedido.productos():
		for _unidad in pedido.unidades_de(producto):
			ventanilla.pedir_interaccion(estante.retirar(producto))
			renglones.append(producto)
	assert_int(ventanilla.pedir_interaccion(Ticket.new(renglones))).is_equal(
		RecepcionDeCompra.Resultado.COMPLETA
	)


func test_cada_venta_cuenta_y_la_llegada_siguiente_descuenta() -> void:  # AC-CTR-143
	var inventario := Apertura.inventario_con_faltantes({}, {}, Catalogo.todos())
	var ventanilla := _ventanilla(inventario)
	var reloj := ventanilla.reloj
	var caja := reloj.obligatoria(Tarea.Tipo.CAJA)
	RelojDePrueba.avanzar_hasta(reloj, Vector2i(20, 30))
	assert_bool(caja.completada()).is_false()
	_vender(ventanilla, inventario)
	assert_bool(caja.completada()).is_true()
	assert_int(_turno.tareas_cumplidas()).is_equal(1)
	RelojDePrueba.avanzar_hasta(reloj, Vector2i(23, 30))
	assert_bool(caja.completada()).is_false()
	assert_int(_turno.tareas_cumplidas()).is_zero()
	_vender(ventanilla, inventario)
	assert_bool(caja.completada()).is_true()
	RelojDePrueba.avanzar_turno(reloj, Reglas.DURACION_DEL_TURNO)
	assert_bool(caja.completada()).is_true()
	assert_array(_cierres).is_equal([1])


func test_el_cierre_no_cuenta_la_obligatoria_si_falta_un_comprador() -> void:  # AC-CTR-143
	var inventario := Apertura.inventario_con_faltantes({}, {}, Catalogo.todos())
	var ventanilla := _ventanilla(inventario)
	var reloj := ventanilla.reloj
	var caja := reloj.obligatoria(Tarea.Tipo.CAJA)
	RelojDePrueba.avanzar_hasta(reloj, Vector2i(20, 30))
	_vender(ventanilla, inventario)
	assert_bool(caja.completada()).is_true()
	RelojDePrueba.avanzar_turno(reloj, Reglas.DURACION_DEL_TURNO)
	assert_bool(caja.completada()).is_false()
	assert_array(_cierres).is_equal([0])
