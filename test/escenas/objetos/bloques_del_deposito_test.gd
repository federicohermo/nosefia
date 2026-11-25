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


func _componentes_conexas(malla: Mesh) -> int:
	var adyacencia := {}
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
				if not adyacencia.has(a):
					adyacencia[a] = {}
				if not adyacencia.has(b):
					adyacencia[b] = {}
				adyacencia[a][b] = true
				adyacencia[b][a] = true
	var visitados := {}
	var componentes := 0
	for inicio: Vector3i in adyacencia.keys():
		if visitados.has(inicio):
			continue
		componentes += 1
		var pila: Array[Vector3i] = [inicio]
		while not pila.is_empty():
			var actual: Vector3i = pila.pop_back()
			if visitados.has(actual):
				continue
			visitados[actual] = true
			for vecino: Vector3i in adyacencia[actual].keys():
				if not visitados.has(vecino):
					pila.append(vecino)
	return componentes


func _saltos_de_uv2_en_vertices_compartidos(malla: Mesh) -> int:
	var uv2_por_vertice := {}
	var saltos := 0
	for superficie in malla.get_surface_count():
		var arrays := malla.surface_get_arrays(superficie)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uv2_raw: Variant = arrays[Mesh.ARRAY_TEX_UV2]
		if not (uv2_raw is PackedVector2Array):
			return -1
		var uv2: PackedVector2Array = uv2_raw
		for i in vertices.size():
			var clave := _clave_vertice(vertices[i])
			if uv2_por_vertice.has(clave):
				var previa: Vector2 = uv2_por_vertice[clave]
				if previa.distance_to(uv2[i]) > 1e-4:
					saltos += 1
			else:
				uv2_por_vertice[clave] = uv2[i]
	return saltos


func test_el_revestimiento_del_cuartito_es_una_sola_isla_de_mapa_de_luz() -> void:
	var modelo: Node3D = auto_free(MODELO.instantiate())
	var rev := modelo.find_child("cuartito_revestimiento", true, false) as MeshInstance3D
	assert_object(rev).is_not_null()
	if rev == null:
		return
	var componentes := _componentes_conexas(rev.mesh)
	(
		assert_int(componentes)
		. override_failure_message(
			"cuartito_revestimiento tiene %d componentes desconectadas" % componentes
		)
		. is_equal(1)
	)
	var saltos := _saltos_de_uv2_en_vertices_compartidos(rev.mesh)
	(
		assert_int(saltos)
		. override_failure_message(
			"cuartito_revestimiento tiene %d saltos de UV2 en vértices compartidos" % saltos
		)
		. is_equal(0)
	)


func test_las_piezas_del_cuartito_cubren_jambas_y_rincones_sin_juntas_internas() -> void:
	var modelo: Node3D = auto_free(MODELO.instantiate())
	var piezas := modelo.find_child("deposito_esquinas_cuartito", true, false) as MeshInstance3D
	assert_object(piezas).is_not_null()
	if piezas == null:
		return
	assert_int(piezas.gi_mode).is_equal(GeometryInstance3D.GI_MODE_DYNAMIC)
	var inconsistentes := _aristas_con_orientacion_opuesta(piezas.mesh)
	(
		assert_int(inconsistentes)
		. override_failure_message(
			(
				"deposito_esquinas_cuartito tiene %d aristas con orientación contradictoria"
				% inconsistentes
			)
		)
		. is_equal(0)
	)
	var partidos := _triangulos_con_junta_interna(piezas.mesh)
	(
		assert_int(partidos)
		. override_failure_message(
			(
				"deposito_esquinas_cuartito tiene %d triángulos de frente con junta vertical interna"
				% partidos
			)
		)
		. is_equal(0)
	)
	var caja := piezas.mesh.get_aabb()
	var rev := modelo.find_child("cuartito_revestimiento", true, false) as MeshInstance3D
	assert_object(rev).is_not_null()
	if rev == null:
		return
	var caja_rev := rev.mesh.get_aabb()
	assert_float(caja.position.z).is_less_equal(caja_rev.position.z + 0.05)
	assert_float(caja.end.z).is_greater_equal(caja_rev.end.z - 0.05)
	assert_float(caja.position.x).is_less_equal(caja_rev.position.x + 0.05)
	assert_float(caja.size.x).is_greater(2.5)


func _triangulos_verticales_con_uv_o_tangente_degenerada(malla: Mesh) -> Dictionary:
	var uv_colapsada := 0
	var tangente_colineal := 0
	for superficie in malla.get_surface_count():
		var arrays := malla.surface_get_arrays(superficie)
		var normales: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var tangentes: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var total := indices.size() if not indices.is_empty() else normales.size()
		for inicio in range(0, total, 3):
			var ia := indices[inicio]
			var ib := indices[inicio + 1]
			var ic := indices[inicio + 2]
			var normal := normales[ia].normalized()
			if absf(normal.y) > 0.5:
				continue
			var u_min := minf(uvs[ia].x, minf(uvs[ib].x, uvs[ic].x))
			var u_max := maxf(uvs[ia].x, maxf(uvs[ib].x, uvs[ic].x))
			if u_max - u_min < 1e-5:
				uv_colapsada += 1
			var tangente := Vector3(tangentes[ia * 4], tangentes[ia * 4 + 1], tangentes[ia * 4 + 2])
			if tangente.length_squared() < 0.01 or absf(normal.dot(tangente.normalized())) > 0.5:
				tangente_colineal += 1
	return {"uv_colapsada": uv_colapsada, "tangente_colineal": tangente_colineal}


func test_los_cantos_de_las_piezas_tienen_uv_sin_colapsar_y_tangente_ortogonal() -> void:
	var modelo: Node3D = auto_free(MODELO.instantiate())
	for nombre: String in ["deposito_esquinas_piezas", "deposito_esquinas_cuartito"]:
		var piezas := modelo.find_child(nombre, true, false) as MeshInstance3D
		assert_object(piezas).is_not_null()
		if piezas == null:
			continue
		var resultado := _triangulos_verticales_con_uv_o_tangente_degenerada(piezas.mesh)
		(
			assert_int(resultado["uv_colapsada"])
			. override_failure_message(
				(
					"%s tiene %d triángulos verticales con UV horizontal colapsada"
					% [nombre, resultado["uv_colapsada"]]
				)
			)
			. is_equal(0)
		)
		(
			assert_int(resultado["tangente_colineal"])
			. override_failure_message(
				(
					"%s tiene %d triángulos verticales con tangente colineal a la normal"
					% [nombre, resultado["tangente_colineal"]]
				)
			)
			. is_equal(0)
		)
