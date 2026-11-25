## Los oclusores de las paredes macizas del local: activos en el proyecto, presentes en el
## almacén y sin invadir ningún vano de puerta.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const OclusoresDelLocal := preload("res://src/escenas/puestos/oclusores_del_local.gd")

## Centros aproximados de los vanos de puertas interiores que nunca pueden quedar tapados.
const VANOS_INTERIORES: Array[Vector3] = [
	Vector3(6.74, 1.35, -8.05),  # Puerta salón <-> depósito
	Vector3(7.98, 1.35, 1.65),  # Puerta salón <-> baño
	Vector3(7.90, 1.35, -10.18),  # Puerta depósito <-> oficina del jefe
	Vector3(7.95, 1.35, -13.96),  # Puerta depósito <-> cuartito de limpieza
]


func test_el_proyecto_activa_el_recorte_por_oclusion() -> void:
	(
		assert_bool(
			ProjectSettings.get_setting("rendering/occlusion_culling/use_occlusion_culling", false)
		)
		. is_true()
	)


func test_el_almacen_agrega_los_oclusores_sin_invadir_ningun_vano() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	var oclusores := almacen.find_children("*", "OccluderInstance3D", true, false)
	assert_array(oclusores).has_size(1)
	var instancia := oclusores[0] as OccluderInstance3D
	assert_bool(instancia.visible).is_true()
	assert_object(instancia.occluder).is_not_null()
	for caja: Array in OclusoresDelLocal.PAREDES_MACIZAS:
		var minimo := caja[0] as Vector3
		var maximo := caja[1] as Vector3
		var aabb := AABB(minimo, maximo - minimo)
		for vano: Vector3 in VANOS_INTERIORES:
			assert_bool(aabb.has_point(vano)).is_false()
