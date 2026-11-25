## Los exhibidos repetidos del freezer se agrupan en `MultiMeshInstance3D` sin perder su visibilidad
## ni su respuesta al mapa de prueba.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.gd")
const ESTRUCTURA := preload("res://src/escenas/puestos/estructura_del_almacen.tscn")
const LOTES := preload("res://src/escenas/puestos/lotes_de_exhibidos.gd")


func test_consolida_los_exhibidos_repetidos_del_freezer_y_conserva_instancias() -> void:
	var estructura: Node = auto_free(ESTRUCTURA.instantiate())
	var freezer := estructura.get_node("freezer_helados") as Node3D
	var antes := freezer.find_children("exhibido_*", "MeshInstance3D", true, false).size()
	assert_int(antes).is_greater_equal(20)

	var ahorrados: int = LOTES.consolidar(estructura)
	assert_int(ahorrados).is_greater_equal(16)

	var lotes := freezer.find_children("exhibido_*", "MultiMeshInstance3D", true, false)
	assert_int(lotes.size()).is_equal(4)
	var instancias := 0
	for lote_var: Variant in lotes:
		var lote := lote_var as MultiMeshInstance3D
		instancias += lote.multimesh.instance_count
	assert_int(instancias).is_equal(20)


func test_mostrar_el_freezer_alterna_los_lotes_consolidados() -> void:
	var estructura: Node = auto_free(ESTRUCTURA.instantiate())
	LOTES.consolidar(estructura)
	var freezer := estructura.get_node("freezer_helados") as Node3D

	ALMACEN.mostrar_el_freezer(estructura, true)
	for nodo: Node in freezer.find_children("exhibido_*", "Node3D", true, false):
		assert_bool((nodo as Node3D).visible).is_false()

	ALMACEN.mostrar_el_freezer(estructura, false)
	for nodo: Node in freezer.find_children("exhibido_*", "Node3D", true, false):
		assert_bool((nodo as Node3D).visible).is_true()
