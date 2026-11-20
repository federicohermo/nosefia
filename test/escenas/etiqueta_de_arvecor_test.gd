extends GdUnitTestSuite
## La etiqueta de Arvecor envuelve el cuerpo cilíndrico de forma continua hasta el hombro, sin
## cortes de material ni saltos de UV, y el cuello superior mapea una franja con área real.

const CONTENIDO := preload("res://src/escenas/puestos/contenido_del_estante.tscn")
const TOLERANCIA_RADIO := 0.002
const TOLERANCIA_NORMAL_VERTICAL := 0.15
const TOLERANCIA_POSICION := 0.0005
const TOLERANCIA_UV := 0.005


func _malla_de_arvecor() -> Mesh:
	var contenido: Node3D = auto_free(CONTENIDO.instantiate())
	var nodo := contenido.get_child(Producto.Id.ARVECOR) as MeshInstance3D
	return nodo.mesh


func _centro_y_radio_exterior(malla: Mesh) -> Dictionary:
	var suma := Vector2.ZERO
	var total := 0
	for s: int in malla.get_surface_count():
		var verts: PackedVector3Array = malla.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		for v: Vector3 in verts:
			suma += Vector2(v.x, v.z)
			total += 1
	var centro := suma / float(total)
	var radio_max := 0.0
	for s: int in malla.get_surface_count():
		var verts: PackedVector3Array = malla.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		for v: Vector3 in verts:
			radio_max = maxf(radio_max, Vector2(v.x, v.z).distance_to(centro))
	return {"centro": centro, "radio": radio_max}


func _triangulos_del_cuerpo(malla: Mesh) -> Array[Dictionary]:
	var med := _centro_y_radio_exterior(malla)
	var centro: Vector2 = med["centro"]
	var radio_max: float = med["radio"]
	var resultado: Array[Dictionary] = []
	for s: int in malla.get_surface_count():
		var arreglos: Array = malla.surface_get_arrays(s)
		var verts: PackedVector3Array = arreglos[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arreglos[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arreglos[Mesh.ARRAY_INDEX]
		var paso := indices.size() if not indices.is_empty() else verts.size()
		for i: int in range(0, paso, 3):
			var ia := indices[i] if not indices.is_empty() else i
			var ib := indices[i + 1] if not indices.is_empty() else i + 1
			var ic := indices[i + 2] if not indices.is_empty() else i + 2
			var p: Array[Vector3] = [verts[ia], verts[ib], verts[ic]]
			var en_borde := true
			for v: Vector3 in p:
				if absf(Vector2(v.x, v.z).distance_to(centro) - radio_max) > TOLERANCIA_RADIO:
					en_borde = false
					break
			if not en_borde:
				continue
			var normal: Vector3 = ((p[1] - p[0]).cross(p[2] - p[0])).normalized()
			if absf(normal.y) > TOLERANCIA_NORMAL_VERTICAL:
				continue
			var uv: Array[Vector2] = [uvs[ia], uvs[ib], uvs[ic]]
			resultado.append({"superficie": s, "p": p, "uv": uv})
	return resultado


func _clave_vertice(v: Vector3) -> Vector3i:
	return Vector3i(
		roundi(v.x / TOLERANCIA_POSICION),
		roundi(v.y / TOLERANCIA_POSICION),
		roundi(v.z / TOLERANCIA_POSICION)
	)


func test_el_cuerpo_cilindrico_de_arvecor_usa_un_solo_material() -> void:
	var malla := _malla_de_arvecor()
	var triangulos := _triangulos_del_cuerpo(malla)
	assert_int(triangulos.size()).is_greater(0)
	var superficies: Dictionary[int, bool] = {}
	for tri: Dictionary in triangulos:
		superficies[tri["superficie"]] = true
	(
		assert_int(superficies.size())
		. override_failure_message(
			"el cuerpo cilíndrico de Arvecor se parte en %d superficies" % superficies.size()
		)
		. is_equal(1)
	)


func test_las_uv_del_cuerpo_de_arvecor_son_continuas_a_traves_de_aristas_horizontales() -> void:
	var malla := _malla_de_arvecor()
	var triangulos := _triangulos_del_cuerpo(malla)
	assert_int(triangulos.size()).is_greater(0)
	var por_arista := {}
	for tri: Dictionary in triangulos:
		var p: Array = tri["p"]
		var uv: Array = tri["uv"]
		for a: int in 3:
			var b := (a + 1) % 3
			if absf((p[a] as Vector3).y - (p[b] as Vector3).y) > TOLERANCIA_POSICION:
				continue
			var ka := _clave_vertice(p[a])
			var kb := _clave_vertice(p[b])
			var clave := [ka, kb] if ka < kb else [kb, ka]
			var par := {ka: uv[a], kb: uv[b]}
			if not por_arista.has(clave):
				por_arista[clave] = []
			por_arista[clave].append(par)
	var saltos := 0
	for clave: Array in por_arista:
		var lados: Array = por_arista[clave]
		if lados.size() != 2:
			continue
		for k: Vector3i in clave:
			var u0: Vector2 = lados[0][k]
			var u1: Vector2 = lados[1][k]
			if u0.distance_to(u1) > TOLERANCIA_UV:
				saltos += 1
	(
		assert_int(saltos)
		. override_failure_message(
			"hay %d saltos de UV en aristas horizontales del cuerpo" % saltos
		)
		. is_equal(0)
	)


func test_el_cuello_superior_de_arvecor_tiene_uv_con_area() -> void:
	var malla := _malla_de_arvecor()
	var med := _centro_y_radio_exterior(malla)
	var centro: Vector2 = med["centro"]
	var radio_max: float = med["radio"]
	var vistos := 0
	var degenerados := 0
	for s: int in malla.get_surface_count():
		var arreglos: Array = malla.surface_get_arrays(s)
		var verts: PackedVector3Array = arreglos[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arreglos[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arreglos[Mesh.ARRAY_INDEX]
		var paso := indices.size() if not indices.is_empty() else verts.size()
		for i: int in range(0, paso, 3):
			var ia := indices[i] if not indices.is_empty() else i
			var ib := indices[i + 1] if not indices.is_empty() else i + 1
			var ic := indices[i + 2] if not indices.is_empty() else i + 2
			var p0 := verts[ia]
			var p1 := verts[ib]
			var p2 := verts[ic]
			var normal := ((p1 - p0).cross(p2 - p0)).normalized()
			if absf(normal.y) > TOLERANCIA_NORMAL_VERTICAL:
				continue
			var r0 := Vector2(p0.x, p0.z).distance_to(centro)
			var r1 := Vector2(p1.x, p1.z).distance_to(centro)
			var r2 := Vector2(p2.x, p2.z).distance_to(centro)
			if maxf(r0, maxf(r1, r2)) >= radio_max - TOLERANCIA_RADIO:
				continue
			vistos += 1
			var area := absf((uvs[ib] - uvs[ia]).cross(uvs[ic] - uvs[ia])) * 0.5
			if area < 1e-8:
				degenerados += 1
	assert_int(vistos).is_greater(0)
	(
		assert_int(degenerados)
		. override_failure_message("%d triángulos del cuello tienen UV de área cero" % degenerados)
		. is_equal(0)
	)
