## Los exhibidos repetidos del freezer se agrupan en `MultiMeshInstance3D` conservando sus
## transforms, respetando overrides de material y respondiendo al mapa de prueba.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.gd")
const ESTRUCTURA := preload("res://src/escenas/puestos/estructura_del_almacen.tscn")
const LOTES := preload("res://src/escenas/puestos/lotes_de_exhibidos.gd")


func test_consolida_los_exhibidos_repetidos_del_freezer_y_conserva_transforms() -> void:
	var estructura: Node = auto_free(ESTRUCTURA.instantiate())
	var freezer := estructura.get_node("freezer_helados") as Node3D
	estructura.remove_child(freezer)
	freezer.owner = null
	var contenedor: Node3D = auto_free(Node3D.new())
	add_child(contenedor)
	contenedor.add_child(freezer)

	var por_malla: Dictionary = {}
	for nodo: Node in freezer.find_children("exhibido_*", "MeshInstance3D", true, false):
		var mi := nodo as MeshInstance3D
		if mi == null or mi.mesh == null or mi.gi_mode == GeometryInstance3D.GI_MODE_STATIC:
			continue
		if not por_malla.has(mi.mesh):
			por_malla[mi.mesh] = []
		var relativo: Transform3D = freezer.global_transform.affine_inverse() * mi.global_transform
		(por_malla[mi.mesh] as Array).append(relativo)

	var esperados_por_malla: Dictionary = {}
	var instancias_esperadas := 0
	var ahorrados_esperados := 0
	for malla_var: Variant in por_malla:
		var transforms: Array = por_malla[malla_var]
		if transforms.size() >= 2:
			esperados_por_malla[malla_var] = transforms
			instancias_esperadas += transforms.size()
			ahorrados_esperados += transforms.size() - 1
	assert_int(ahorrados_esperados).is_greater(0)

	var ahorrados: int = LOTES.consolidar(contenedor)
	assert_int(ahorrados).is_equal(ahorrados_esperados)

	var lotes := freezer.find_children("exhibido_*", "MultiMeshInstance3D", true, false)
	var reales_por_malla: Dictionary = {}
	var instancias := 0
	for lote_var: Variant in lotes:
		var lote := lote_var as MultiMeshInstance3D
		var mm := lote.multimesh
		instancias += mm.instance_count
		if not reales_por_malla.has(mm.mesh):
			reales_por_malla[mm.mesh] = []
		for i: int in mm.instance_count:
			(reales_por_malla[mm.mesh] as Array).append(_transform_de_instancia(mm, i))
	assert_int(instancias).is_equal(instancias_esperadas)

	for malla_var: Variant in esperados_por_malla:
		assert_bool(reales_por_malla.has(malla_var)).is_true()
		var esperados: Array = esperados_por_malla[malla_var]
		var pendientes: Array = (reales_por_malla[malla_var] as Array).duplicate()
		assert_int(pendientes.size()).is_equal(esperados.size())
		for t_var: Variant in esperados:
			var t_esperado: Transform3D = t_var
			var indice := _buscar_transform(pendientes, t_esperado)
			assert_int(indice).is_greater_equal(0)
			pendientes.remove_at(indice)

	var restantes_por_malla: Dictionary = {}
	for nodo: Node in freezer.find_children("exhibido_*", "MeshInstance3D", true, false):
		var mi := nodo as MeshInstance3D
		if mi.mesh != null:
			restantes_por_malla[mi.mesh] = int(restantes_por_malla.get(mi.mesh, 0)) + 1
	for cantidad_var: Variant in restantes_por_malla.values():
		assert_int(int(cantidad_var)).is_less(2)


func test_conserva_el_transform_relativo_con_padres_intermedios() -> void:
	var contenedor: Node3D = auto_free(Node3D.new())
	add_child(contenedor)
	var freezer := Node3D.new()
	freezer.name = "freezer_helados"
	freezer.transform = Transform3D(Basis(Vector3.UP, 0.4), Vector3(1.5, 0.8, -2.0))
	contenedor.add_child(freezer)

	var bandeja := Node3D.new()
	bandeja.transform = Transform3D(
		Basis(Vector3.UP, 0.7).scaled(Vector3(1.2, 0.9, 1.1)), Vector3(0.2, -0.1, 0.3)
	)
	freezer.add_child(bandeja)

	var malla := BoxMesh.new()
	var esperados: Array[Transform3D] = []
	for i: int in 2:
		var mi := MeshInstance3D.new()
		mi.name = "exhibido_anidado_%d" % i
		mi.mesh = malla
		mi.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
		mi.transform = Transform3D(
			Basis(Vector3.RIGHT, 0.25 * float(i)), Vector3(0.1 * i, 0.05, 0.0)
		)
		bandeja.add_child(mi)
		esperados.append(freezer.global_transform.affine_inverse() * mi.global_transform)

	var ahorrados: int = LOTES.consolidar(contenedor)
	assert_int(ahorrados).is_equal(1)

	var lotes := freezer.find_children("exhibido_*", "MultiMeshInstance3D", true, false)
	assert_int(lotes.size()).is_equal(1)
	var mm := (lotes[0] as MultiMeshInstance3D).multimesh
	var pendientes: Array = []
	for i: int in mm.instance_count:
		pendientes.append(_transform_de_instancia(mm, i))
	for esperado: Transform3D in esperados:
		var indice := _buscar_transform(pendientes, esperado)
		assert_int(indice).is_greater_equal(0)
		pendientes.remove_at(indice)


func test_no_consolida_un_exhibido_con_material_override() -> void:
	var estructura: Node = auto_free(ESTRUCTURA.instantiate())
	var freezer := estructura.get_node("freezer_helados") as Node3D
	var repetidos := _exhibidos_con_malla_repetida(freezer)
	assert_int(repetidos.size()).is_greater_equal(2)

	var objetivo := repetidos[0]
	var material := StandardMaterial3D.new()
	objetivo.material_override = material
	var nombre := objetivo.name

	LOTES.consolidar(estructura)

	assert_bool(is_instance_valid(objetivo)).is_true()
	assert_object(freezer.find_child(nombre, true, false)).is_same(objetivo)
	assert_object(objetivo.material_override).is_same(material)


func test_no_consolida_un_exhibido_con_material_overlay_ni_transparencia() -> void:
	var estructura: Node = auto_free(ESTRUCTURA.instantiate())
	var freezer := estructura.get_node("freezer_helados") as Node3D
	var repetidos := _exhibidos_con_malla_repetida(freezer)
	assert_int(repetidos.size()).is_greater_equal(2)

	var con_overlay := repetidos[0]
	var overlay := StandardMaterial3D.new()
	con_overlay.material_overlay = overlay
	var con_transparencia := repetidos[1]
	con_transparencia.transparency = 0.5

	LOTES.consolidar(estructura)

	assert_bool(is_instance_valid(con_overlay)).is_true()
	assert_object(con_overlay.material_overlay).is_same(overlay)
	assert_bool(is_instance_valid(con_transparencia)).is_true()
	assert_float(con_transparencia.transparency).is_equal_approx(0.5, 0.001)


func test_mostrar_el_freezer_alterna_los_lotes_consolidados() -> void:
	var estructura: Node = auto_free(ESTRUCTURA.instantiate())
	LOTES.consolidar(estructura)
	var freezer := estructura.get_node("freezer_helados") as Node3D
	var exhibidos := freezer.find_children("exhibido_*", "Node3D", true, false)
	assert_bool(exhibidos.is_empty()).is_false()

	ALMACEN.mostrar_el_freezer(estructura, true)
	for nodo: Node in exhibidos:
		assert_bool((nodo as Node3D).visible).is_false()

	ALMACEN.mostrar_el_freezer(estructura, false)
	for nodo: Node in exhibidos:
		assert_bool((nodo as Node3D).visible).is_true()


static func _transform_de_instancia(mm: MultiMesh, indice: int) -> Transform3D:
	# El renderizador dummy de headless no implementa `get_instance_transform`, pero conserva `buffer`.
	if DisplayServer.get_name() != "headless":
		return mm.get_instance_transform(indice)
	var valores := mm.buffer
	var inicio := indice * 12
	return Transform3D(
		Basis(
			Vector3(valores[inicio], valores[inicio + 4], valores[inicio + 8]),
			Vector3(valores[inicio + 1], valores[inicio + 5], valores[inicio + 9]),
			Vector3(valores[inicio + 2], valores[inicio + 6], valores[inicio + 10])
		),
		Vector3(valores[inicio + 3], valores[inicio + 7], valores[inicio + 11])
	)


static func _buscar_transform(lista: Array, objetivo: Transform3D) -> int:
	for i: int in lista.size():
		var candidato: Transform3D = lista[i]
		if candidato.is_equal_approx(objetivo):
			return i
	return -1


static func _exhibidos_con_malla_repetida(freezer: Node3D) -> Array[MeshInstance3D]:
	var conteo: Dictionary = {}
	var todos: Array[MeshInstance3D] = []
	for nodo: Node in freezer.find_children("exhibido_*", "MeshInstance3D", true, false):
		var mi := nodo as MeshInstance3D
		if mi != null and mi.mesh != null:
			conteo[mi.mesh] = int(conteo.get(mi.mesh, 0)) + 1
			todos.append(mi)
	var resultado: Array[MeshInstance3D] = []
	for mi: MeshInstance3D in todos:
		if int(conteo.get(mi.mesh, 0)) >= 2:
			resultado.append(mi)
	return resultado
