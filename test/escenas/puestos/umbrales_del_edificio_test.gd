## Los pisos visibles cubren los pasos. Una colisión invisible no cierra un agujero en la malla.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const AMBIENTE := preload("res://src/escenas/puestos/ambiente_del_almacen.tscn")


func test_el_exterior_no_es_fuente_global_de_reflejos_del_interior() -> void:
	var ambiente: Node3D = auto_free(AMBIENTE.instantiate())
	var entorno: WorldEnvironment = ambiente.get_node("Entorno")
	assert_int(entorno.environment.reflected_light_source).is_equal(
		Environment.REFLECTION_SOURCE_DISABLED
	)


static func _tiene_piso_visible(caras: PackedVector3Array, punto: Vector3) -> bool:
	for i: int in range(0, caras.size(), 3):
		var normal := (caras[i + 1] - caras[i]).cross(caras[i + 2] - caras[i]).normalized()
		if absf(normal.y) < 0.9:
			continue
		var encuentro: Variant = Geometry3D.ray_intersects_triangle(
			punto + Vector3.UP * 0.3, Vector3.DOWN, caras[i], caras[i + 1], caras[i + 2]
		)
		if encuentro is Vector3 and absf(encuentro.y - punto.y) < 0.001:
			return true
	return false


func _caras_del_edificio() -> PackedVector3Array:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	var edificio: MeshInstance3D = almacen.get_node("Estructura/almacen")
	var caras: PackedVector3Array = edificio.mesh.get_faces()
	assert_int(caras.size()).is_greater(0)
	return edificio.global_transform * caras


func test_el_paso_al_bano_tiene_piso_visible_de_ambos_lados() -> void:
	var caras := _caras_del_edificio()
	for x: float in [7.82, 7.90, 7.94, 8.02, 8.12]:
		for z: float in [0.1, 0.55, 1.0, 1.45]:
			var punto := Vector3(x, 0.10223747, z)
			(
				assert_bool(_tiene_piso_visible(caras, punto))
				. override_failure_message("Falta piso visible en el umbral del baño: %v" % punto)
				. is_true()
			)


func test_el_paso_al_deposito_tiene_piso_visible_de_ambos_lados() -> void:
	var caras := _caras_del_edificio()
	for x: float in [6.04, 6.5, 7.0, 7.46]:
		for z: float in [-7.82, -7.94, -8.02, -8.18, -8.32]:
			var punto := Vector3(x, 0.10223747, z)
			(
				assert_bool(_tiene_piso_visible(caras, punto))
				. override_failure_message(
					"Falta piso visible en el umbral del depósito: %v" % punto
				)
				. is_true()
			)
