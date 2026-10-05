## Mide el disco libre sobre las tapas del suelo registrado, sin crear colisiones nuevas.
extends RefCounted

const MARGEN_NUMERICO := 0.00001


static func admite(
	golpe: Dictionary,
	suelo: StaticBody3D,
	sectores: Array[Node3D],
	excluidos: Array[RID] = [],
	casco: StaticBody3D = null
) -> bool:
	if golpe.is_empty() or suelo == null or not _es_suelo(golpe, suelo, casco):
		return false
	var punto: Vector3 = golpe.position
	var radio := ReglasDeLaLimpieza.RADIO_DEL_CHARCO
	if not _disco_apoyado(punto, suelo, radio):
		return false
	for sector in sectores:
		for forma: CollisionShape3D in sector.find_children("*", "CollisionShape3D", false, false):
			var limites := forma.global_transform * forma.shape.get_debug_mesh().get_aabb()
			var centro := limites.get_center()
			var distancia := Vector2(punto.x - centro.x, punto.z - centro.z).length()
			if distancia <= maxf(limites.size.x, limites.size.z) * 0.5 + radio:
				return false
	var espacio := suelo.get_world_3d().direct_space_state
	for lado in 8:
		var borde := punto + Vector3(cos(TAU * lado / 8), 0, sin(TAU * lado / 8)) * radio
		var consulta := PhysicsRayQueryParameters3D.create(
			borde + Vector3.UP * 0.04, borde - Vector3.UP * 0.04, 1
		)
		consulta.exclude = excluidos
		if not _es_suelo(espacio.intersect_ray(consulta), suelo, casco):
			return false
	var disco := CylinderShape3D.new()
	disco.radius = radio
	disco.height = 0.008
	var volumen := PhysicsShapeQueryParameters3D.new()
	volumen.shape = disco
	volumen.transform.origin = punto + Vector3.UP * 0.012
	volumen.margin = 0.001
	volumen.collision_mask = 1 | ReglasDeLosObjetos.CAPA_DEL_CONTORNO
	volumen.exclude = excluidos.duplicate()
	volumen.exclude.append(suelo.get_rid())
	return espacio.intersect_shape(volumen, 1).is_empty()


static func _disco_apoyado(punto: Vector3, suelo: StaticBody3D, radio: float) -> bool:
	var tapas: Array[Rect2] = []
	var cortes: Array[float] = [punto.x - radio, punto.x + radio]
	for forma: CollisionShape3D in suelo.find_children("*", "CollisionShape3D", false, false):
		var caja := forma.shape as BoxShape3D
		if caja == null or forma.disabled:
			continue
		var base := forma.global_basis.orthonormalized()
		# Las tapas del suelo son rectángulos horizontales alineados con los ejes mundiales.
		# Una AABB de una caja oblicua incluiría esquinas que no pertenecen a su tapa.
		if (
			absf(base.y.dot(Vector3.UP)) < 0.999999
			or maxf(absf(base.x.x), absf(base.x.z)) < 0.999999
		):
			continue
		var limites := forma.global_transform * AABB(-caja.size * .5, caja.size)
		if absf(limites.end.y - punto.y) >= .015:
			continue
		var tapa := Rect2(limites.position.x, limites.position.z, limites.size.x, limites.size.z)
		if tapa.end.x < cortes[0] or tapa.position.x > cortes[1]:
			continue
		tapas.append(tapa)
		cortes.append(clampf(tapa.position.x, punto.x - radio, punto.x + radio))
		cortes.append(clampf(tapa.end.x, punto.x - radio, punto.x + radio))
	cortes.sort()
	for indice in range(cortes.size() - 1):
		var desde := cortes[indice]
		var hasta := cortes[indice + 1]
		if hasta - desde <= MARGEN_NUMERICO:
			continue
		var centro := (desde + hasta) * .5
		var intervalos: Array[Vector2] = []
		for tapa in tapas:
			if centro >= tapa.position.x and centro <= tapa.end.x:
				intervalos.append(Vector2(tapa.position.y, tapa.end.y))
		# Dentro de una franja la unión de rectángulos no cambia. El corte del círculo más
		# ancho queda en el X de la franja más cercano a su centro, no en una muestra angular.
		var distancia := clampf(punto.x, desde, hasta) - punto.x
		var alcance := sqrt(maxf(0.0, radio * radio - distancia * distancia))
		if not _intervalo_cubierto(intervalos, punto.z - alcance, punto.z + alcance):
			return false
	return not tapas.is_empty()


static func _intervalo_cubierto(intervalos: Array[Vector2], desde: float, hasta: float) -> bool:
	intervalos.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var cubierto := desde
	for intervalo in intervalos:
		if intervalo.x > cubierto + MARGEN_NUMERICO:
			return false
		cubierto = maxf(cubierto, intervalo.y)
		if cubierto >= hasta - MARGEN_NUMERICO:
			return true
	return false


static func _es_suelo(golpe: Dictionary, suelo: StaticBody3D, casco: StaticBody3D) -> bool:
	if golpe.is_empty() or golpe.collider not in [suelo, casco]:
		return false
	var punto: Vector3 = golpe.position
	var normal: Vector3 = golpe.normal
	if not punto.is_finite() or normal.y < 0.98:
		return false
	for forma: CollisionShape3D in suelo.find_children("*", "CollisionShape3D", false, false):
		var caja := forma.shape as BoxShape3D
		if caja == null or forma.disabled:
			continue
		var local := forma.to_local(punto)
		var mitad := caja.size * 0.5
		if (
			absf(local.y - mitad.y) < 0.015
			and absf(local.x) <= mitad.x
			and absf(local.z) <= mitad.z
		):
			return true
	return false
