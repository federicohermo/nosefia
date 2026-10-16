## La reserva comercial se mide aparte del metal que puede sostener un cuerpo.
class_name ReservaDeLaGondola
extends RefCounted


## Compara las envolventes orientadas, sin llenar con su AABB los rincones exteriores.
static func se_superponen(
	volumen: AABB, pose: Transform3D, reserva: AABB, marco: Transform3D
) -> bool:
	if not _tiene_volumen(volumen) or not _tiene_volumen(reserva):
		return false
	var unidad := _esquinas(volumen, pose)
	var mueble := _esquinas(reserva, marco)
	var propias := _aristas(pose.basis)
	var ajenas := _aristas(marco.basis)
	var ejes := _normales(propias)
	ejes.append_array(_normales(ajenas))
	for propio: Vector3 in propias:
		for otro: Vector3 in ajenas:
			ejes.append(propio.cross(otro))
	for eje: Vector3 in ejes:
		if eje.length_squared() == 0.0:
			continue
		eje = eje.normalized()
		var a := _proyectar(unidad, eje)
		var b := _proyectar(mueble, eje)
		if a.y <= b.x or b.y <= a.x:
			return false
	return true


static func _tiene_volumen(limites: AABB) -> bool:
	return limites.size.x > 0 and limites.size.y > 0 and limites.size.z > 0


static func _esquinas(limites: AABB, pose: Transform3D) -> PackedVector3Array:
	var puntos := PackedVector3Array()
	for indice in 8:
		puntos.append(pose * limites.get_endpoint(indice))
	return puntos


## Las normales por producto vectorial también conservan una base con escala no uniforme.
static func _normales(aristas: Array[Vector3]) -> Array[Vector3]:
	return [
		aristas[0].cross(aristas[1]), aristas[1].cross(aristas[2]), aristas[2].cross(aristas[0])
	]


static func _aristas(base: Basis) -> Array[Vector3]:
	return [base.x.normalized(), base.y.normalized(), base.z.normalized()]


static func _proyectar(puntos: PackedVector3Array, eje: Vector3) -> Vector2:
	var minimo := INF
	var maximo := -INF
	for punto: Vector3 in puntos:
		var medida := punto.dot(eje)
		minimo = minf(minimo, medida)
		maximo = maxf(maximo, medida)
	return Vector2(minimo, maximo)
