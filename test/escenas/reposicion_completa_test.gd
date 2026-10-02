extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")


func test_reponer_todos_los_huecos_de_la_apertura_cumple_la_tarea() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	almacen.get("_jugador").set_physics_process(false)
	var puesto: Node3D = almacen.get("_reposicion_manual")
	var repositor: Repositor = almacen.get("_repositor")
	var reloj: RelojDelTurno = almacen.get("_reloj")
	reloj.set_process(false)
	var tarea := reloj.obligatoria(Tarea.Tipo.REPONER)
	assert_object(tarea).is_not_null()
	assert_bool(tarea.completada()).is_false()
	var colocadas := 0
	for producto in Catalogo.todos():
		var vacios := repositor.estante().casilleros_vacios(producto)
		for indice in vacios:
			var casillero: Node3D = puesto.call("casillero", producto.id, indice)
			puesto.call("retirar", producto.id)
			assert_object(repositor.agarre.manos().sostenido() as UnidadDeProducto).is_not_null()
			assert_int(casillero.get("papel")).is_equal(1)
			puesto.call("pedir_colocar", producto.id, indice)
			assert_object(repositor.agarre.manos().sostenido()).is_null()
			colocadas += 1
	assert_int(colocadas).is_greater(0)
	assert_bool(repositor.estante().completada()).is_true()
	assert_bool(tarea.completada()).is_true()
