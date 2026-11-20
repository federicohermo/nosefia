extends GdUnitTestSuite
## La etiqueta de Arvecor envuelve el cuerpo cilíndrico de forma continua hasta el hombro, sin
## cortes de material ni saltos de UV, y el cuello superior mapea una franja con área real.

const CONTENIDO := preload("res://src/escenas/puestos/contenido_del_estante.tscn")
const REGLAS_UV_ARVECOR := "res://.claude/scripts/lib/uv_de_arvecor.py"
const MANIFIESTO_ATLAS := "res://assets/source/atlas/atlas.json"
const CLAVE_ARVECOR := "source/products-textured/Arvejas/arvecor.png"
const TOLERANCIA_RADIO := 0.002
const TOLERANCIA_NORMAL_VERTICAL := 0.15
const TOLERANCIA_POSICION := 0.0005
const TOLERANCIA_UV := 0.005
const SALTO_RADIO_HOMBRO := 0.005
const TOLERANCIA_FRANJA := 0.0002


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


func _leer_rango_por_nombre(texto: String, nombre: String) -> Vector2:
	var expresion := RegEx.new()
	expresion.compile("%s\\s*=\\s*\\(\\s*([0-9.]+)\\s*,\\s*([0-9.]+)\\s*\\)" % nombre)
	var coincidencia := expresion.search(texto)
	(
		assert_object(coincidencia)
		. override_failure_message("falta %s en %s" % [nombre, REGLAS_UV_ARVECOR])
		. is_not_null()
	)
	return Vector2(float(coincidencia.get_string(1)), float(coincidencia.get_string(2)))


func _celda_de_arvecor_en_el_atlas() -> Dictionary:
	var manifiesto: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFIESTO_ATLAS))
	for hoja: Dictionary in manifiesto["atlas"]:
		for entrada: Dictionary in hoja["entradas"]:
			if entrada["ruta"] == CLAVE_ARVECOR:
				return {
					"atlas_ancho": float(hoja["ancho"]),
					"atlas_alto": float(hoja["alto"]),
					"x": float(entrada["x"]),
					"y": float(entrada["y"]),
					"ancho": float(entrada["ancho"]),
					"alto": float(entrada["alto"]),
				}
	return {}


func test_el_hombro_de_arvecor_cae_dentro_de_la_franja_plateada_limpia() -> void:
	var texto_reglas := FileAccess.get_file_as_string(REGLAS_UV_ARVECOR)
	var u_plateado := _leer_rango_por_nombre(texto_reglas, "U_PLATEADO")
	var v_plateado := _leer_rango_por_nombre(texto_reglas, "V_PLATEADO")
	var celda := _celda_de_arvecor_en_el_atlas()
	assert_bool(celda.is_empty()).is_false()

	var malla := _malla_de_arvecor()
	var med := _centro_y_radio_exterior(malla)
	var centro: Vector2 = med["centro"]
	var vistos := 0
	var fuera := 0
	var peor_u := Vector2(INF, -INF)
	var peor_v := Vector2(INF, -INF)
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
			var y_min := minf(p0.y, minf(p1.y, p2.y))
			var y_max := maxf(p0.y, maxf(p1.y, p2.y))
			if y_min <= 0.0 or y_max - y_min <= TOLERANCIA_POSICION:
				continue
			var r0 := Vector2(p0.x, p0.z).distance_to(centro)
			var r1 := Vector2(p1.x, p1.z).distance_to(centro)
			var r2 := Vector2(p2.x, p2.z).distance_to(centro)
			if maxf(r0, maxf(r1, r2)) - minf(r0, minf(r1, r2)) <= SALTO_RADIO_HOMBRO:
				continue
			vistos += 1
			for idx: int in [ia, ib, ic]:
				var uv := uvs[idx]
				var u_local: float = (uv.x * celda["atlas_ancho"] - celda["x"]) / celda["ancho"]
				var v_local: float = 1.0 - (uv.y * celda["atlas_alto"] - celda["y"]) / celda["alto"]
				peor_u = Vector2(minf(peor_u.x, u_local), maxf(peor_u.y, u_local))
				peor_v = Vector2(minf(peor_v.x, v_local), maxf(peor_v.y, v_local))
				if (
					u_local < u_plateado.x - TOLERANCIA_FRANJA
					or u_local > u_plateado.y + TOLERANCIA_FRANJA
					or v_local < v_plateado.x - TOLERANCIA_FRANJA
					or v_local > v_plateado.y + TOLERANCIA_FRANJA
				):
					fuera += 1
	assert_int(vistos).is_greater(0)
	var mensaje := (
		(
			"%d vértices del hombro salen de la franja plateada "
			+ "(U=%.4f..%.4f vs %.4f..%.4f, V=%.4f..%.4f vs %.4f..%.4f)"
		)
		% [
			fuera,
			peor_u.x,
			peor_u.y,
			u_plateado.x,
			u_plateado.y,
			peor_v.x,
			peor_v.y,
			v_plateado.x,
			v_plateado.y,
		]
	)
	assert_int(fuera).override_failure_message(mensaje).is_equal(0)
