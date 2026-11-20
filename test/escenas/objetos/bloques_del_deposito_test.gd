extends GdUnitTestSuite
## Las piezas de los bloques del depósito tienen normales consistentes y no parten bloques con
## juntas internas cerca de la jamba.

const MODELO := preload("res://assets/models/SEPT_JUEGOS_PROTOTIPO.glb")
const COLUMNAS := 6.0
const HILADAS := 18.0
const ANCHO_U := 1.0 / COLUMNAS
const MARGEN_JUNTA_U := 0.008
const ANCHO_MINIMO_FRENTE := 0.04


func _clave_vertice(punto: Vector3) -> Vector3i:
	return Vector3i(roundi(punto.x * 10000.0), roundi(punto.y * 10000.0), roundi(punto.z * 10000.0))


func _aristas_con_orientacion_opuesta(malla: Mesh) -> int:
	var vistas := {}
	var repetidas := 0
	for superficie in malla.get_surface_count():
		var arrays := malla.surface_get_arrays(superficie)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var total := indices.size() if not indices.is_empty() else vertices.size()
		for inicio in range(0, total, 3):
			var tri: Array[Vector3i] = [
				_clave_vertice(vertices[indices[inicio]]),
				_clave_vertice(vertices[indices[inicio + 1]]),
				_clave_vertice(vertices[indices[inicio + 2]]),
			]
			for paso in 3:
				var a: Vector3i = tri[paso]
				var b: Vector3i = tri[(paso + 1) % 3]
				if a == b:
					continue
				var dirigida := [a, b]
				if vistas.has(dirigida):
					repetidas += 1
				vistas[dirigida] = true
	return repetidas


func _triangulos_con_junta_interna(malla: Mesh) -> int:
	var partidos := 0
	for superficie in malla.get_surface_count():
		var arrays := malla.surface_get_arrays(superficie)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var total := indices.size() if not indices.is_empty() else vertices.size()
		for inicio in range(0, total, 3):
			var ia := indices[inicio]
			var ib := indices[inicio + 1]
			var ic := indices[inicio + 2]
			var a := vertices[ia]
			var b := vertices[ib]
			var c := vertices[ic]
			var normal := ((b - a).cross(c - a)).normalized()
			if absf(normal.y) > 0.5:
				continue
			var ancho_x := maxf(a.x, maxf(b.x, c.x)) - minf(a.x, minf(b.x, c.x))
			var ancho_z := maxf(a.z, maxf(b.z, c.z)) - minf(a.z, minf(b.z, c.z))
			var ancho := ancho_x if absf(normal.z) > 0.5 else ancho_z
			if ancho < ANCHO_MINIMO_FRENTE:
				continue
			var ua := uvs[ia].x
			var ub := uvs[ib].x
			var uc := uvs[ic].x
			var u_min := minf(ua, minf(ub, uc))
			var u_max := maxf(ua, maxf(ub, uc))
			if u_max - u_min < MARGEN_JUNTA_U * 2.0:
				continue
			var v_medio := (uvs[ia].y + uvs[ib].y + uvs[ic].y) / 3.0
			# En glTF V=0 es arriba; las hiladas de la textura crecen desde abajo.
			var hilada := clampi(int(floorf((1.0 - v_medio) * HILADAS)), 0, int(HILADAS) - 1)
			var desfase := float(hilada % 3) * ANCHO_U / 3.0
			var k_inicio := int(floorf((u_min - desfase) / ANCHO_U))
			var k_fin := int(ceilf((u_max - desfase) / ANCHO_U))
			for k in range(k_inicio, k_fin + 1):
				var u_junta := desfase + float(k) * ANCHO_U
				if u_junta > u_min + MARGEN_JUNTA_U and u_junta < u_max - MARGEN_JUNTA_U:
					partidos += 1
					break
	return partidos


func test_las_piezas_de_los_bloques_tienen_orientacion_consistente() -> void:
	var modelo: Node3D = auto_free(MODELO.instantiate())
	var piezas := modelo.find_child("deposito_esquinas_piezas", true, false) as MeshInstance3D
	assert_object(piezas).is_not_null()
	if piezas == null:
		return
	var inconsistentes := _aristas_con_orientacion_opuesta(piezas.mesh)
	(
		assert_int(inconsistentes)
		. override_failure_message(
			(
				"deposito_esquinas_piezas tiene %d aristas con orientación contradictoria"
				% inconsistentes
			)
		)
		. is_equal(0)
	)


func test_ningun_frente_de_pieza_cruza_una_junta_vertical_interna() -> void:
	var modelo: Node3D = auto_free(MODELO.instantiate())
	var piezas := modelo.find_child("deposito_esquinas_piezas", true, false) as MeshInstance3D
	assert_object(piezas).is_not_null()
	if piezas == null:
		return
	var partidos := _triangulos_con_junta_interna(piezas.mesh)
	(
		assert_int(partidos)
		. override_failure_message(
			(
				"deposito_esquinas_piezas tiene %d triángulos de frente con junta vertical interna"
				% partidos
			)
		)
		. is_equal(0)
	)
