## El repositor, al iniciar el cierre de la noche, cuenta como puesta la unidad que el jugador
## lleva en la mano.
##
## Va aparte de `repositor_test.gd` por el tope de métodos públicos por archivo. Ningún nodo entra
## al árbol y ninguno hace correr `_process`: el cierre se pide con `terminar()`.
extends GdUnitTestSuite

## Una fila de dos casilleros: con uno ya lleno, la unidad en la mano completa la góndola.
const CUPO_DE_PRUEBA := 2

var _turno: Turno = null


class UnidadFisica:
	extends RigidBody3D
	var datos: ObjetoDelAlmacen


## Un repositor con la góndola a un casillero de estar completa y reponer pedida.
func _repositor() -> Repositor:
	var actroncito := Catalogo.de(Producto.Id.ACTRONCITO)
	var inventario := Inventario.new([actroncito], {Producto.Id.ACTRONCITO: CUPO_DE_PRUEBA})
	inventario.ingresar(
		actroncito, Inventario.Ubicacion.DEPOSITO, ReglasDelEstante.UNIDADES_POR_CAJA
	)
	inventario.ingresar(actroncito, Inventario.Ubicacion.GONDOLA, CUPO_DE_PRUEBA - 1)
	var obligatorias := Apertura.obligatorias(4)
	_turno = Turno.new(Reglas.DURACION_DEL_TURNO, obligatorias)
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	reloj.arrancar(_turno, obligatorias)
	var agarre: Agarre = auto_free(Agarre.new())
	agarre.punto_de_carga = auto_free(Node3D.new())
	var repositor: Repositor = auto_free(Repositor.new())
	repositor.reloj = reloj
	repositor.agarre = agarre
	repositor.arrancar(Estante.new(inventario, [actroncito]))
	return repositor


func test_al_cerrar_la_unidad_en_la_mano_cumple_reponer_y_antes_no() -> void:  # AC-STK-117
	var repositor := _repositor()
	var nodo: UnidadFisica = auto_free(UnidadFisica.new())
	assert_bool(repositor.pedir_retirar(Producto.Id.ACTRONCITO, nodo)).is_true()
	assert_int(_turno.tareas_cumplidas()).is_zero()
	repositor.reloj.terminar()
	assert_int(_turno.tareas_cumplidas()).is_equal(1)


func test_al_cerrar_con_la_unidad_soltada_reponer_sigue_sin_cumplir() -> void:  # AC-STK-117
	var repositor := _repositor()
	var nodo: UnidadFisica = auto_free(UnidadFisica.new())
	repositor.pedir_retirar(Producto.Id.ACTRONCITO, nodo)
	repositor.agarre.soltar(true)
	repositor.reloj.terminar()
	assert_int(_turno.tareas_cumplidas()).is_zero()
