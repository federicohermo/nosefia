## Límites locales de las formas finitas del juego, sin construir mallas de depuración.
class_name LimitesDeForma
extends RefCounted


static func de(forma: Shape3D) -> AABB:
	var tamano := Vector3.ZERO
	if forma is BoxShape3D:
		tamano = (forma as BoxShape3D).size
	elif forma is SphereShape3D:
		tamano = Vector3.ONE * (forma as SphereShape3D).radius * 2.0
	elif forma is CapsuleShape3D:
		var capsula := forma as CapsuleShape3D
		tamano = Vector3(capsula.radius * 2.0, capsula.height, capsula.radius * 2.0)
	elif forma is CylinderShape3D:
		var cilindro := forma as CylinderShape3D
		tamano = Vector3(cilindro.radius * 2.0, cilindro.height, cilindro.radius * 2.0)
	elif forma is ConvexPolygonShape3D:
		return _de_puntos((forma as ConvexPolygonShape3D).points)
	elif forma is ConcavePolygonShape3D:
		return _de_puntos((forma as ConcavePolygonShape3D).get_faces())
	else:
		push_error("Forma sin límites físicos implementados: %s" % forma.get_class())
		assert(false, "La forma debe pertenecer a las seis familias finitas del juego")
		return AABB()
	return AABB(-tamano / 2.0, tamano)


static func _de_puntos(puntos: PackedVector3Array) -> AABB:
	if puntos.is_empty():
		return AABB()
	var limites := AABB(puntos[0], Vector3.ZERO)
	for punto: Vector3 in puntos:
		limites = limites.expand(punto)
	return limites
