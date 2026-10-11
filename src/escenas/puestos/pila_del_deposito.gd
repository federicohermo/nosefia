## Poses de apertura derivadas del portón, el primer rack y los cuerpos de las cajas.
extends RefCounted


static func poses(
	cajas: Array[Node3D], porton: MeshInstance3D, pallet: MeshInstance3D, piso: CollisionShape3D
) -> Dictionary[Node3D, Transform3D]:
	var puerta := porton.global_transform * porton.get_aabb()
	var rack := pallet.global_transform * pallet.get_aabb()
	var forma := piso.shape as BoxShape3D
	var suelo := (piso.global_transform * AABB(-forma.size / 2.0, forma.size)).end.y
	var por_tamano := cajas.duplicate()
	por_tamano.sort_custom(func(a: Node3D, b: Node3D) -> bool: return _lado(a) > _lado(b))
	var lado := _lado(por_tamano[0])
	# Dos hileras separadas por un pasillo; cuatro columnas distribuyen la altura de 31 cajas.
	var alturas: Array[float] = []
	alturas.resize(8)
	alturas.fill(suelo)
	var resultado: Dictionary[Node3D, Transform3D] = {}
	for indice in por_tamano.size():
		var caja: Node3D = por_tamano[indice]
		var columna := indice % alturas.size()
		var hilera := columna / 4
		var lugar := columna % 4
		var x := (
			puerta.end.x + lado / 2.0 if hilera == 0 else lerpf(puerta.end.x, rack.position.x, 0.5)
		)
		# El hueco entre la columna del fondo y las tres delanteras deja pasar a las bolsas.
		var z := (
			puerta.position.z + lado
			if lugar == 0
			else puerta.get_center().z + lado * (1.25 + (lugar - 1) * 1.5)
		)
		var media := _lado(caja) / 2.0
		resultado[caja] = Transform3D(Basis.IDENTITY, Vector3(x, alturas[columna] + media, z))
		alturas[columna] += media * 2.0
	return resultado


static func _lado(caja: Node3D) -> float:
	var cuerpo: CollisionShape3D = caja.get_node("Cuerpo")
	return (cuerpo.transform * cuerpo.shape.get_debug_mesh().get_aabb()).size.x
