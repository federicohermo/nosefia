extends GdUnitTestSuite

const ALMACEN := "res://src/escenas/almacen.tscn"
const HOJAS := ["puertaentrada", "puertaentrada_derecha"]


func test_cada_vidrio_acompana_el_marco_al_abrir() -> void:  # AC-SHF-043
	var estructura := await _crear()
	for nombre: String in HOJAS:
		var hoja: MeshInstance3D = estructura.get_node(nombre)
		var cuerpo: Node3D = hoja.get_node("CuerpoDeLaHoja")
		var vidrio: MeshInstance3D = estructura.find_child(
			(
				"local_vidrio_puerta_entrada_derecha"
				if nombre == HOJAS[1]
				else "local_vidrio_puerta_entrada"
			),
			true,
			false
		)
		var centro := vidrio.get_aabb().get_center()
		var en_el_marco := hoja.to_local(vidrio.to_global(centro))
		var cerrada := vidrio.to_global(centro)
		cuerpo.call("abrir_para_salida")
		for _paso in 8:
			cuerpo.call("_physics_process", Puerta.ANGULO_ABIERTA / Puerta.VELOCIDAD_DEL_GIRO / 8.0)
			assert_vector(vidrio.to_global(centro)).is_equal_approx(
				hoja.to_global(en_el_marco), Vector3.ONE * 0.0001
			)
		assert_float(vidrio.to_global(centro).distance_to(cerrada)).is_greater(0.0)


func test_ninguna_hoja_atraviesa_el_vidrio_fijo() -> void:  # AC-SHF-043
	var estructura := await _crear()
	var vidrios: Array[MeshInstance3D] = []
	var lugares: Array[Transform3D] = []
	for nombre: String in [
		"local_vidrio_frente_0", "local_vidrio_frente_1", "local_vidrio_sobre_entrada"
	]:
		var vidrio: MeshInstance3D = estructura.get_node(nombre)
		vidrios.append(vidrio)
		lugares.append(vidrio.global_transform)
	for nombre: String in HOJAS:
		var cuerpo: Node3D = estructura.get_node(nombre + "/CuerpoDeLaHoja")
		cuerpo.call("abrir_para_salida")
		for _paso in 16:
			cuerpo.call(
				"_physics_process", Puerta.ANGULO_ABIERTA / Puerta.VELOCIDAD_DEL_GIRO / 16.0
			)
			for malla: MeshInstance3D in cuerpo.get("mallas"):
				for triangulo: PackedVector3Array in _triangulos(malla):
					for vidrio: MeshInstance3D in vidrios:
						for fijo: PackedVector3Array in _triangulos(vidrio):
							assert_bool(_se_cruzan(triangulo, fijo, vidrio)).is_false()
		for indice: int in vidrios.size():
			assert_bool(vidrios[indice].global_transform.is_equal_approx(lugares[indice])).is_true()


func _crear() -> Node3D:
	var almacen: Node3D = auto_free(load(ALMACEN).instantiate())
	almacen.set("compradores_de_la_apertura", func(_n: int) -> Array[Comprador]: return [])
	add_child(almacen)
	almacen.get("_reloj").set_process(false)
	almacen.get("_jugador").set_physics_process(false)
	var estructura: Node3D = almacen.get_node("Estructura")
	for cuerpo: Node in estructura.find_children("*", "AnimatableBody3D", true, false):
		cuerpo.set_physics_process(false)
	await get_tree().process_frame
	return estructura


func _triangulos(malla: MeshInstance3D) -> Array[PackedVector3Array]:
	var triangulos: Array[PackedVector3Array] = []
	for superficie: int in malla.mesh.get_surface_count():
		var datos: Array = malla.mesh.surface_get_arrays(superficie)
		var vertices: PackedVector3Array = datos[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = datos[Mesh.ARRAY_INDEX]
		for indice: int in range(0, indices.size(), 3):
			triangulos.append(
				PackedVector3Array(
					[
						malla.to_global(vertices[indices[indice]]),
						malla.to_global(vertices[indices[indice + 1]]),
						malla.to_global(vertices[indices[indice + 2]])
					]
				)
			)
	return triangulos


func _se_cruzan(a: PackedVector3Array, b: PackedVector3Array, vidrio: MeshInstance3D) -> bool:
	for indice in 3:
		var ida: Variant = Geometry3D.segment_intersects_triangle(
			a[indice], a[(indice + 1) % 3], b[0], b[1], b[2]
		)
		if ida != null and _dentro_del_vidrio(vidrio, ida):
			return true
		var vuelta: Variant = Geometry3D.segment_intersects_triangle(
			b[indice], b[(indice + 1) % 3], a[0], a[1], a[2]
		)
		if vuelta != null and _dentro_del_vidrio(vidrio, vuelta):
			return true
	return false


func _dentro_del_vidrio(vidrio: MeshInstance3D, punto: Vector3) -> bool:
	var local := vidrio.to_local(punto)
	var caja := vidrio.get_aabb()
	return (
		local.x > caja.position.x + 0.0001
		and local.x < caja.end.x - 0.0001
		and local.y > caja.position.y + 0.0001
		and local.y < caja.end.y - 0.0001
	)
