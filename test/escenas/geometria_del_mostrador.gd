## Las formas del mostrador pueden cambiar de orden y de tipo al reimportar el arte.
extends RefCounted


static func brazo(mostrador: MeshInstance3D) -> AABB:
	var elegido := AABB()
	for forma: CollisionShape3D in mostrador.get_node("StaticBody3D").get_children():
		if forma.disabled:
			continue
		var caja := forma.global_transform * forma.shape.get_debug_mesh().get_aabb()
		if caja.size.x > elegido.size.x:
			elegido = caja
	return elegido


static func rincon(mostrador: MeshInstance3D) -> Vector3:
	var limites := mostrador.global_transform * mostrador.get_aabb()
	var transversal := brazo(mostrador)
	var otro := AABB()
	for forma: CollisionShape3D in mostrador.get_node("StaticBody3D").get_children():
		if forma.disabled:
			continue
		var caja := forma.global_transform * forma.shape.get_debug_mesh().get_aabb()
		if caja.size.z > otro.size.z:
			otro = caja
	var x := (limites.position.x + otro.position.x) / 2
	if otro.get_center().x < limites.get_center().x:
		x = (otro.end.x + limites.end.x) / 2
	var z := (transversal.end.z + limites.end.z) / 2
	if transversal.get_center().z > limites.get_center().z:
		z = (limites.position.z + transversal.position.z) / 2
	return Vector3(x, limites.get_center().y, z)
