## El pavimento debe tocar el edificio y dejar libre su piso interior.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")


func _almacen() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	almacen.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(almacen)
	return almacen


func _caras_del_pavimento(almacen: Node3D) -> PackedVector3Array:
	var caras := PackedVector3Array()
	for malla: MeshInstance3D in almacen.get_node("Exterior").get_children():
		if malla.name.begins_with("Pavimento") or malla.name.begins_with("Vereda"):
			caras.append_array(malla.global_transform * malla.mesh.get_faces())
	assert_int(caras.size()).is_greater(0)
	return caras


func _altura(caras: PackedVector3Array, punto: Vector2) -> float:
	var altura := -INF
	for i: int in range(0, caras.size(), 3):
		var golpe: Variant = Geometry3D.ray_intersects_triangle(
			Vector3(punto.x, 2, punto.y), Vector3.DOWN, caras[i], caras[i + 1], caras[i + 2]
		)
		if golpe is Vector3:
			altura = maxf(altura, golpe.y)
	return altura


func test_el_pavimento_alcanza_el_umbral_sin_desnivel() -> void:
	var almacen := _almacen()
	var edificio: MeshInstance3D = almacen.get_node("Estructura/almacen")
	var caras := edificio.global_transform * edificio.mesh.get_faces()
	var pavimento := _caras_del_pavimento(almacen)
	# Ambos pares cruzan el límite real del edificio: ventanales y entrada del frente.
	for par: Array in [
		[Vector2(-2.3, -1.3), Vector2(-2.50, -1.3)],
		[Vector2(5.7, 6.1), Vector2(5.7, 6.30)],
	]:
		var interior := _altura(caras, par[0])
		assert_float(interior).is_between(0.0, 0.2)
		assert_float(_altura(pavimento, par[1])).is_equal_approx(interior, 0.0001)


func test_el_pavimento_no_se_superpone_con_el_piso_del_local() -> void:
	var pavimento := _caras_del_pavimento(_almacen())
	for punto: Vector2 in [Vector2(0, 0), Vector2(5.7, 5.8), Vector2(10, -10)]:
		assert_float(_altura(pavimento, punto)).is_equal(-INF)


func test_la_vereda_y_la_playa_no_entran_al_deposito_ni_al_bano() -> void:
	var almacen := _almacen()
	var edificio: MeshInstance3D = almacen.get_node("Estructura/almacen")
	var interior := edificio.global_transform * edificio.mesh.get_faces()
	var exterior := _caras_del_pavimento(almacen)
	# El fondo del edificio sobresale hacia el oeste del salón, junto al portón.
	for punto: Vector2 in [
		Vector2(-3.0, -10.5),
		Vector2(-3.0, -14.0),
		Vector2(-4.4, -11.0),
		Vector2(-3.0, -8.5),
		Vector2(10.0, 3.0),
	]:
		assert_float(_altura(interior, punto)).is_between(0.10, 0.11)
		assert_float(_altura(exterior, punto)).is_equal(-INF)


func test_los_objetos_de_la_foto_descansan_sobre_el_pavimento() -> void:
	var almacen := _almacen()
	var pavimento := _caras_del_pavimento(almacen)
	for nombre: String in ["Estacion", "Auto", "Poste"]:
		var objeto: MeshInstance3D = almacen.get_node("Exterior/" + nombre)
		var caras := objeto.global_transform * objeto.mesh.get_faces()
		assert_int(caras.size()).is_greater(0)
		var pie := Vector3(0, INF, 0)
		for vertice: Vector3 in caras:
			if vertice.y < pie.y:
				pie = vertice
		assert_float(pie.y).is_equal_approx(_altura(pavimento, Vector2(pie.x, pie.z)), 0.0001)


func test_el_local_de_la_foto_no_se_duplica_afuera_del_almacen() -> void:
	assert_bool(_almacen().has_node("Exterior/EdificioDelFondo")).is_false()
