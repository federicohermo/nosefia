## Pilas apoyadas en la superficie real de cada pallet, sin cambiar el tamaño de la madera.
extends RefCounted


## `frente` es hacia dónde miran todas las etiquetas, que van en las caras X de la caja: al lado
## del pallet más cercano. Sin él, cada caja toma el giro de su pallet, y cada pila muestra otra
## cara.
static func poses(
	cajas: Array[Node3D], pallets: Array[MeshInstance3D], frente: Vector3 = Vector3.ZERO
) -> Dictionary[Node3D, Transform3D]:
	var por_tamano := cajas.duplicate()
	por_tamano.sort_custom(func(a: Node3D, b: Node3D) -> bool: return _lado(a) > _lado(b))
	var lado := _lado(por_tamano[0])
	var alturas: Array[float] = []
	for pallet: MeshInstance3D in pallets:
		var superficie := (pallet.global_transform * pallet.get_aabb()).end.y
		alturas.append_array([superficie, superficie])
	var resultado: Dictionary[Node3D, Transform3D] = {}
	for indice: int in por_tamano.size():
		var caja: Node3D = por_tamano[indice]
		var columna := indice % alturas.size()
		var pallet := pallets[columna / 2]
		var centro := pallet.get_aabb().get_center()
		centro.x += lado * (columna % 2 - 0.5) / pallet.scale.x
		var posicion := pallet.global_transform * centro
		var media := _lado(caja) / 2.0
		posicion.y = alturas[columna] + media
		var giro := pallet.rotation.y
		if not is_zero_approx(frente.x) or not is_zero_approx(frente.z):
			# De a cuarto de vuelta del pallet: girada en diagonal, la caja invadiría a la de al lado.
			var cuartos := roundf((atan2(-frente.z, frente.x) - giro) / (PI / 2.0))
			giro += cuartos * PI / 2.0
		resultado[caja] = Transform3D(Basis(Vector3.UP, giro), posicion)
		alturas[columna] += media * 2.0
	return resultado


static func _lado(caja: Node3D) -> float:
	var cuerpo: CollisionShape3D = caja.get_node("Cuerpo")
	return (cuerpo.transform * cuerpo.shape.get_debug_mesh().get_aabb()).size.x
