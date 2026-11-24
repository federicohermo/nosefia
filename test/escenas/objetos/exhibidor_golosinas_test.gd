extends GdUnitTestSuite
## Los dos laterales del exhibidor de golosinas tienen espesor real y caras sin área nula.

const MODELO := preload("res://assets/models/SEPT_JUEGOS_PROTOTIPO.glb")
const AREA_MINIMA := 1e-6
const ESPESOR_MINIMO := 0.005
const TOLERANCIA_SIMETRIA := 0.001
const TOLERANCIA_NORMAL := 0.99


func _laterales_del_exhibidor(malla: Mesh) -> Dictionary:
	var nulos := 0
	var caras_x: Array[Dictionary] = []
	for superficie in malla.get_surface_count():
		var material := malla.surface_get_material(superficie)
		if material != null and material.resource_name != "blanco mate":
			continue
		var arrays := malla.surface_get_arrays(superficie)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normales: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var total := indices.size() if not indices.is_empty() else vertices.size()
		for inicio in range(0, total, 3):
			var ia := indices[inicio] if not indices.is_empty() else inicio
			var ib := indices[inicio + 1] if not indices.is_empty() else inicio + 1
			var ic := indices[inicio + 2] if not indices.is_empty() else inicio + 2
			var a := vertices[ia]
			var b := vertices[ib]
			var c := vertices[ic]
			var area := (b - a).cross(c - a).length() * 0.5
			if area <= AREA_MINIMA:
				nulos += 1
				continue
			var normal := ((normales[ia] + normales[ib] + normales[ic]) / 3.0).normalized()
			if absf(normal.x) < TOLERANCIA_NORMAL:
				continue
			var centro_x := (a.x + b.x + c.x) / 3.0
			var altura := maxf(a.y, maxf(b.y, c.y)) - minf(a.y, minf(b.y, c.y))
			caras_x.append({"x": centro_x, "nx": normal.x, "altura": altura})
	return {"nulos": nulos, "caras_x": caras_x}


func test_ambos_laterales_del_exhibidor_tienen_espesor_y_sin_caras_nulas() -> void:
	var modelo: Node3D = auto_free(MODELO.instantiate())
	var exhibidor := modelo.find_child("exhibidor_golosinas", true, false) as MeshInstance3D
	assert_object(exhibidor).is_not_null()
	if exhibidor == null:
		return
	var datos := _laterales_del_exhibidor(exhibidor.mesh)
	var nulos: int = datos["nulos"]
	(
		assert_int(nulos)
		. override_failure_message("exhibidor_golosinas tiene %d triángulos de área nula" % nulos)
		. is_equal(0)
	)
	var caras_x: Array = datos["caras_x"]
	var altura_max := 0.0
	for cara: Dictionary in caras_x:
		altura_max = maxf(altura_max, cara["altura"])
	var grandes: Array[Dictionary] = []
	for cara: Dictionary in caras_x:
		if cara["altura"] >= altura_max * 0.9:
			grandes.append(cara)
	var x_min := INF
	var x_max := -INF
	for cara: Dictionary in grandes:
		x_min = minf(x_min, cara["x"])
		x_max = maxf(x_max, cara["x"])
	var centro := (x_min + x_max) * 0.5
	var der_ext := INF
	var der_int := -INF
	var izq_int := INF
	var izq_ext := -INF
	for cara: Dictionary in grandes:
		var x: float = cara["x"]
		var nx: float = cara["nx"]
		if x < centro:
			if nx < 0.0:
				der_ext = minf(der_ext, x)
			else:
				der_int = maxf(der_int, x)
		else:
			if nx < 0.0:
				izq_int = minf(izq_int, x)
			else:
				izq_ext = maxf(izq_ext, x)
	var espesor_der := der_int - der_ext
	var espesor_izq := izq_ext - izq_int
	(
		assert_float(espesor_der)
		. override_failure_message("espesor derecho = %.5f m" % espesor_der)
		. is_greater(ESPESOR_MINIMO)
	)
	(
		assert_float(espesor_izq)
		. override_failure_message("espesor izquierdo = %.5f m" % espesor_izq)
		. is_greater(ESPESOR_MINIMO)
	)
	(
		assert_float(absf(espesor_izq - espesor_der))
		. override_failure_message(
			"espesores distintos: izq=%.5f m, der=%.5f m" % [espesor_izq, espesor_der]
		)
		. is_less(TOLERANCIA_SIMETRIA)
	)
