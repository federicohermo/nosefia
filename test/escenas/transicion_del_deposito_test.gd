## Las cajas del depósito no se preparan en la carga de la primera noche: la transición a la
## segunda las calienta con la persiana baja, y una segunda noche retomada ya las trae preparadas.
extends GdUnitTestSuite

const AvanceDeDevolucion := preload("res://test/avance_de_devolucion.gd")
const RelojDePrueba := preload("res://test/reloj_de_prueba.gd")
const ESCENA_DEL_ALMACEN := "res://src/escenas/almacen.tscn"


func before_test() -> void:
	Guardado.new().borrar()


func after_test() -> void:
	Guardado.new().borrar()


func _abrir(jornada: int) -> Node3D:
	var almacen: Node3D = auto_free(load(ESCENA_DEL_ALMACEN).instantiate())
	almacen.set("_partida", Partida.desde({"jornada": jornada}))
	almacen.set("compradores_de_la_apertura", func(_n: int) -> Array[Comprador]: return [])
	add_child(almacen)
	await get_tree().process_frame
	return almacen


func _cerrar_y_continuar(almacen: Node3D) -> bool:
	var reloj: RelojDelTurno = almacen.get_node("Servicios/RelojDelTurno")
	var pantalla: PantallaDeDevolucion = almacen.get_node("Interfaz/PantallaDeDevolucion")
	for tarea: Tarea in (almacen.get("_partida") as Partida).obligatorias():
		tarea.completar()
	RelojDePrueba.avanzar_turno(reloj, Reglas.DURACION_DEL_TURNO)
	AvanceDeDevolucion.entregar(pantalla)
	pantalla.elegir()
	AvanceDeDevolucion.pasar_la_reflexion(pantalla)
	AvanceDeDevolucion.terminar_movimiento(pantalla)
	return await AvanceDeDevolucion.esperar_la_noche_siguiente(almacen)


func test_la_carga_de_la_primera_noche_deja_las_cajas_sin_copias() -> void:
	var almacen := await _abrir(ReglasDeLaPartida.PRIMERA_JORNADA)
	var cajas: Array[Node3D] = []
	cajas.assign(almacen.get("_cajas_de_productos"))
	assert_array(cajas).is_not_empty()
	assert_array(almacen.call("cuerpos_sin_copias")).contains(cajas)


func test_una_segunda_noche_retomada_carga_las_cajas_con_copias() -> void:
	var almacen := await _abrir(ReglasDeLaPartida.PRIMERA_JORNADA + 1)
	var cajas: Array[Node3D] = []
	cajas.assign(almacen.get("_cajas_de_productos"))
	assert_array(cajas).is_not_empty()
	assert_array(almacen.call("cuerpos_sin_copias")).not_contains(cajas)


# AC-PLY-040
func test_la_transicion_a_la_segunda_noche_calienta_las_cajas_con_la_persiana_baja() -> void:
	var almacen := await _abrir(ReglasDeLaPartida.PRIMERA_JORNADA)
	var cuerpo: Node = almacen.get_node("Estructura/puerta/CuerpoDeLaHoja")
	assert_bool(cuerpo.call("puerta").trabada()).is_true()
	var cajas: Array[Node3D] = []
	cajas.assign(almacen.get("_cajas_de_productos"))
	var persiana: PersianaDeLaNoche = almacen.get_node("Interfaz/PersianaDeLaNoche")
	var calentadas := [[]]
	var con_persiana := [true]
	almacen.child_entered_tree.connect(
		func(nodo: Node) -> void:
			if nodo is CalentamientoDeShaders:
				(nodo as CalentamientoDeShaders).avanzo.connect(
					func(_progreso: float) -> void:
						calentadas[0] = (nodo as CalentamientoDeShaders).get("_solo_de")
						con_persiana[0] = con_persiana[0] and persiana.en_pantalla()
				)
	)
	assert_bool(await _cerrar_y_continuar(almacen)).is_true()
	assert_array(calentadas[0]).contains(cajas)
	assert_bool(con_persiana[0]).is_true()
	assert_array(almacen.call("cuerpos_sin_copias")).not_contains(cajas)
	assert_int((almacen.get("_partida") as Partida).jornada()).is_equal(
		ReglasDeLaPartida.PRIMERA_JORNADA + 1
	)
	assert_bool(cuerpo.call("puerta").trabada()).is_false()
	assert_bool(cuerpo.call("puerta").abierta()).is_false()
	cuerpo.call("accionar")
	assert_bool(cuerpo.call("puerta").abierta()).is_true()
