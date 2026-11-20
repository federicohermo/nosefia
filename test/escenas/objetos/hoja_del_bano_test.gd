extends GdUnitTestSuite
## Cada cara grande de la hoja de entrada al baño es plana, con una sola normal y un solo material.

const MODELO := preload("res://assets/models/SEPT_JUEGOS_PROTOTIPO.glb")
const TOLERANCIA_NORMAL := 0.9999
const TOLERANCIA_PLANO := 0.0005


func _caras_grandes_de_la_hoja(malla: Mesh) -> Dictionary:
	var lados := {"frente": [], "dorso": []}
	for superficie in malla.get_surface_count():
		var material := malla.surface_get_material(superficie)
		if material != null and material.resource_name == "bano_acero":
			continue
		var arrays := malla.surface_get_arrays(superficie)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var total := indices.size() if not indices.is_empty() else vertices.size()
		for inicio in range(0, total, 3):
			var ia := indices[inicio] if not indices.is_empty() else inicio
			var ib := indices[inicio + 1] if not indices.is_empty() else inicio + 1
			var ic := indices[inicio + 2] if not indices.is_empty() else inicio + 2
			var a := vertices[ia]
			var b := vertices[ib]
			var c := vertices[ic]
			var normal := ((b - a).cross(c - a)).normalized()
			if absf(normal.z) <= 0.5:
				continue
			var clave := "frente" if normal.z > 0.0 else "dorso"
			lados[clave].append({"superficie": superficie, "normal": normal, "puntos": [a, b, c]})
	return lados


func test_las_dos_caras_grandes_de_la_hoja_son_planas_y_de_un_solo_material() -> void:
	var modelo: Node3D = auto_free(MODELO.instantiate())
	var puerta := modelo.find_child("puerta2", true, false) as MeshInstance3D
	assert_object(puerta).is_not_null()
	if puerta == null:
		return
	var lados := _caras_grandes_de_la_hoja(puerta.mesh)
	for clave: String in ["frente", "dorso"]:
		var triangulos: Array = lados[clave]
		assert_int(triangulos.size()).override_failure_message(clave).is_greater(0)
		var inclinados := 0
		var z_min := INF
		var z_max := -INF
		var superficies: Dictionary[int, bool] = {}
		for tri: Dictionary in triangulos:
			superficies[tri["superficie"]] = true
			var normal: Vector3 = tri["normal"]
			if absf(normal.z) < TOLERANCIA_NORMAL:
				inclinados += 1
			for punto: Vector3 in tri["puntos"]:
				z_min = minf(z_min, punto.z)
				z_max = maxf(z_max, punto.z)
		(
			assert_int(superficies.size())
			. override_failure_message(
				"%s se parte en %d materiales distintos" % [clave, superficies.size()]
			)
			. is_equal(1)
		)
		(
			assert_int(inclinados)
			. override_failure_message("%s tiene %d triángulos inclinados" % [clave, inclinados])
			. is_equal(0)
		)
		(
			assert_float(z_max - z_min)
			. override_failure_message(
				"%s no es coplanar: rango Z = %.5f m" % [clave, z_max - z_min]
			)
			. is_less(TOLERANCIA_PLANO)
		)
