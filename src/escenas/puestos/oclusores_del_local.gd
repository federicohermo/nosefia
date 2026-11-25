## Oclusores estáticos en las paredes interiores macizas del local para recortar habitaciones
## tapadas (salón, depósito, baño y cuartito) sin atravesar ningún vano ni vidrio.
extends Node3D

## Cada entrada es `[minimo, maximo]` en metros del almacén, retraída 4 cm respecto de las caras
## de colisión macizas de `Estructura/almacen/StaticBody3D` para no invadir marcos ni aberturas.
const PAREDES_MACIZAS: Array[Array] = [
	# Salón <-> Depósito (a la izquierda de la puerta del depósito).
	[Vector3(-4.55, 0.14, -8.21), Vector3(5.88, 4.80, -7.91)],
	# Dintel sobre la puerta del depósito.
	[Vector3(5.97, 2.76, -8.21), Vector3(8.04, 4.80, -7.91)],
	# Salón <-> Baño (al norte de la puerta del baño).
	[Vector3(7.91, 0.14, -7.83), Vector3(8.04, 3.46, 0.84)],
	# Salón <-> Baño (al sur de la puerta del baño).
	[Vector3(7.91, 0.14, 2.45), Vector3(8.25, 3.46, 6.24)],
	# Pared norte del baño.
	[Vector3(8.12, 0.14, -0.48), Vector3(13.60, 3.70, -0.37)],
	# Depósito <-> Oficina del jefe (al sur del vano de `puertajefe`).
	[Vector3(7.96, 0.14, -9.40), Vector3(8.05, 4.80, -8.29)],
	# Depósito <-> Oficina del jefe (al norte del vano de `puertajefe`).
	[Vector3(7.96, 0.14, -13.10), Vector3(8.05, 4.80, -11.00)],
]


func _ready() -> void:
	var instancia := OccluderInstance3D.new()
	instancia.name = "ParedesDivisorias"
	instancia.occluder = _armar_oclusor()
	add_child(instancia)


static func _armar_oclusor() -> ArrayOccluder3D:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for caja: Array in PAREDES_MACIZAS:
		_agregar_caja(vertices, indices, caja[0] as Vector3, caja[1] as Vector3)
	var oclusor := ArrayOccluder3D.new()
	oclusor.set_arrays(vertices, indices)
	return oclusor


static func _agregar_caja(
	vertices: PackedVector3Array, indices: PackedInt32Array, minimo: Vector3, maximo: Vector3
) -> void:
	var base := vertices.size()
	(
		vertices
		. append_array(
			PackedVector3Array(
				[
					Vector3(minimo.x, minimo.y, minimo.z),
					Vector3(maximo.x, minimo.y, minimo.z),
					Vector3(maximo.x, maximo.y, minimo.z),
					Vector3(minimo.x, maximo.y, minimo.z),
					Vector3(minimo.x, minimo.y, maximo.z),
					Vector3(maximo.x, minimo.y, maximo.z),
					Vector3(maximo.x, maximo.y, maximo.z),
					Vector3(minimo.x, maximo.y, maximo.z),
				]
			)
		)
	)
	var caras: Array[int] = [
		0,
		2,
		1,
		0,
		3,
		2,
		4,
		5,
		6,
		4,
		6,
		7,
		0,
		1,
		5,
		0,
		5,
		4,
		3,
		7,
		6,
		3,
		6,
		2,
		0,
		4,
		7,
		0,
		7,
		3,
		1,
		2,
		6,
		1,
		6,
		5,
	]
	for indice: int in caras:
		indices.append(base + indice)
