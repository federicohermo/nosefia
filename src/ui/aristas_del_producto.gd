class_name AristasDelProducto
extends RefCounted

## Une las esquinas repetidas por normales o UV distintos antes de buscar caras vecinas.
const PRECISION := 0.00001
const CARAS_COPLANARES := 0.99999


static func preparar(original: Mesh) -> ArrayMesh:
	var normales: Dictionary[Array, Array] = {}
	var superficies: Array[Array] = []
	for superficie in original.get_surface_count():
		var herramienta := SurfaceTool.new()
		herramienta.create_from(original, superficie)
		herramienta.deindex()
		var arreglos := herramienta.commit_to_arrays()
		superficies.append(arreglos)
		var vertices: PackedVector3Array = arreglos[Mesh.ARRAY_VERTEX]
		for inicio in range(0, vertices.size(), 3):
			var normal := (
				(vertices[inicio + 1] - vertices[inicio])
				. cross(vertices[inicio + 2] - vertices[inicio])
				. normalized()
			)
			for esquina in 3:
				var clave := _clave(
					vertices[inicio + (esquina + 1) % 3], vertices[inicio + (esquina + 2) % 3]
				)
				if not normales.has(clave):
					normales[clave] = []
				normales[clave].append(normal)
	var resultado := ArrayMesh.new()
	for superficie in superficies.size():
		var arreglos := superficies[superficie]
		var vertices: PackedVector3Array = arreglos[Mesh.ARRAY_VERTEX]
		var coordenadas := PackedFloat32Array()
		for inicio in range(0, vertices.size(), 3):
			var mascara := 0
			for esquina in 3:
				var clave := _clave(
					vertices[inicio + (esquina + 1) % 3], vertices[inicio + (esquina + 2) % 3]
				)
				var vecinas: Array = normales[clave]
				if (
					vecinas.size() != 2
					or (vecinas[0] as Vector3).dot(vecinas[1]) < CARAS_COPLANARES
				):
					mascara |= 1 << esquina
			for esquina in 3:
				for componente in 3:
					coordenadas.append(1.0 if componente == esquina else 0.0)
				coordenadas.append(float(mascara))
		arreglos[Mesh.ARRAY_CUSTOM0] = coordenadas
		resultado.add_surface_from_arrays(
			Mesh.PRIMITIVE_TRIANGLES,
			arreglos,
			[],
			{},
			Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
		)
		resultado.surface_set_material(superficie, original.surface_get_material(superficie))
	return resultado


## La clave conserva ambos extremos; un centro solo confundiría diagonales que se cruzan.
static func _clave(desde: Vector3, hasta: Vector3) -> Array[Vector3]:
	var primero := desde.snapped(Vector3.ONE * PRECISION)
	var segundo := hasta.snapped(Vector3.ONE * PRECISION)
	if (
		primero.x > segundo.x
		or (primero.x == segundo.x and primero.y > segundo.y)
		or (primero.x == segundo.x and primero.y == segundo.y and primero.z > segundo.z)
	):
		return [segundo, primero]
	return [primero, segundo]
