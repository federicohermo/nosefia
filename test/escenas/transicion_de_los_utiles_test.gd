## Una partida seguida no vuelve a cargar entre noches: los útiles que la carga de «Nuevo juego»
## no preparó se calientan en la transición hacia la primera noche que limpia, con la persiana
## baja y el turno detenido. Las anteriores no los tocan: el cuartito sigue trabado.
extends GdUnitTestSuite

const AvanceDeDevolucion := preload("res://test/avance_de_devolucion.gd")
const RelojDePrueba := preload("res://test/reloj_de_prueba.gd")
const ESCENA_DEL_ALMACEN := "res://src/escenas/almacen.tscn"


func before_test() -> void:
	Guardado.new().borrar()


func after_test() -> void:
	Guardado.new().borrar()


func _primera_que_limpia() -> int:
	var jornada := ReglasDeLaPartida.PRIMERA_JORNADA
	while not Apertura.pide(jornada, Tarea.Tipo.LIMPIAR):
		jornada += 1
	return jornada


func _cerrar_y_continuar(almacen: Node3D) -> bool:
	var reloj: RelojDelTurno = almacen.get_node("Servicios/RelojDelTurno")
	var pantalla: PantallaDeDevolucion = almacen.get_node("Interfaz/PantallaDeDevolucion")
	# Con las obligatorias cumplidas, el cierre no despide y la partida sigue.
	for tarea: Tarea in (almacen.get("_partida") as Partida).obligatorias():
		tarea.completar()
	RelojDePrueba.avanzar_turno(reloj, Reglas.DURACION_DEL_TURNO)
	AvanceDeDevolucion.entregar(pantalla)
	pantalla.elegir()
	AvanceDeDevolucion.pasar_la_reflexion(pantalla)
	AvanceDeDevolucion.terminar_movimiento(pantalla)
	return await AvanceDeDevolucion.esperar_la_noche_siguiente(almacen)


func test_la_transicion_a_la_primera_que_limpia_prepara_los_utiles_con_la_persiana_baja() -> void:
	var almacen: Node3D = auto_free(load(ESCENA_DEL_ALMACEN).instantiate())
	add_child(almacen)
	await get_tree().process_frame
	var partida: Partida = almacen.get("_partida")
	assert_int(partida.jornada()).is_equal(ReglasDeLaPartida.PRIMERA_JORNADA)
	var jugador: Node = almacen.get_node("Jugador")
	var reloj: RelojDelTurno = almacen.get_node("Servicios/RelojDelTurno")
	var persiana: PersianaDeLaNoche = almacen.get_node("Interfaz/PersianaDeLaNoche")
	var transiciones := _primera_que_limpia() - ReglasDeLaPartida.PRIMERA_JORNADA
	var transicion := [0]
	var calentadas: Array[Array] = []
	calentadas.resize(transiciones)
	calentadas.fill([])
	var durante: Array[Array] = []
	almacen.child_entered_tree.connect(
		func(nodo: Node) -> void:
			if nodo is CalentamientoDeShaders:
				(nodo as CalentamientoDeShaders).avanzo.connect(
					func(_progreso: float) -> void:
						calentadas[transicion[0]] = (nodo as CalentamientoDeShaders).get("_solo_de")
						durante.append(
							[jugador.call("suspendido"), reloj.corriendo(), persiana.en_pantalla()]
						)
				)
	)
	for indice: int in transiciones:
		transicion[0] = indice
		assert_bool(await _cerrar_y_continuar(almacen)).is_true()
		assert_int(almacen.get("_jornada_preparada")).is_equal(partida.jornada())
		AvanceDeDevolucion.leer_las_instrucciones(almacen)
		persiana.terminar()
		await get_tree().process_frame
	assert_int(partida.jornada()).is_equal(_primera_que_limpia())
	var utiles: Array[Node3D] = []
	utiles.assign(almacen.get("_utiles_de_limpieza"))
	assert_array(utiles).is_not_empty()
	for anterior: int in transiciones - 1:
		assert_array(calentadas[anterior]).not_contains(utiles)
	assert_array(calentadas[transiciones - 1]).contains(utiles)
	assert_array(durante).is_not_empty()
	for estado: Array in durante:
		assert_array(estado).is_equal([true, false, true])
