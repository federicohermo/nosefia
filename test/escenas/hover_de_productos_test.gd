extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const AperturaConLugar := preload("res://test/escenas/apertura_con_lugar.gd")


func test_pasarse_por_los_productos_no_reemplaza_ni_reordena_sus_superficies() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	almacen.get("_jugador").set_physics_process(false)
	var faltantes: Dictionary[Producto.Id, int] = {}
	AperturaConLugar.abrir_con_faltantes(almacen, faltantes)
	var puesto: Node3D = almacen.get("_reposicion_manual")
	for producto in Catalogo.todos():
		var grupo: MultiMeshInstance3D = puesto.get_node("ProductosDe" + producto.nombre)
		var copias := grupo.multimesh
		var antes := copias.buffer
		var visibles := copias.visible_instance_count
		var zonas: Array[Node] = puesto.get_node("ZonaDe" + producto.nombre).get_children()
		assert_int(zonas.size()).is_greater(0)
		for zona in zonas:
			assert_int(zona.get("papel")).is_equal(2)
			puesto.call("_al_enfocar", zona, 0.5)
			var vista: MeshInstance3D = zona.get("vista")
			assert_bool(vista.visible).is_true()
			assert_object(vista.material_override).is_same(zona.get("sin_superficie"))
			assert_bool(copias.buffer == antes).is_true()
			assert_int(copias.visible_instance_count).is_equal(visibles)
			puesto.call("_al_perder_el_foco")
			assert_bool(vista.visible).is_false()
			assert_bool(copias.buffer == antes).is_true()
