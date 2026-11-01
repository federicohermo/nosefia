## Dónde abre cada caja del depósito: donde el jugador la dejó, o en un lugar libre (BR-STK-051).
##
## La geometría entra como datos, y por eso se prueba sin escena. Una caja que cerró apoyada en
## una estantería, o sobre otra caja que lo está, abre en esa misma pose. La que cerró afuera abre
## en el primer hueco libre donde entra, y si no hay, encima de una caja de las estanterías.
class_name OrganizacionDelDeposito
extends RefCounted

## La física deja una caja a milímetros de su apoyo, no exactamente sobre él.
const TOLERANCIA_DE_APOYO := 0.03
## Apoyarse en algo no es superponerse con ello.
const HOLGURA := 0.01
const MARGEN_DE_TAMANO := 0.001


class Caja:
	extends RefCounted
	var producto: Producto.Id
	var media: float
	var fabrica: Transform3D
	var presente: bool

	func _init(id: Producto.Id, lado_medio: float, lugar: Transform3D, esta: bool) -> void:
		producto = id
		media = lado_medio
		fabrica = lugar
		presente = esta


## `repisas` son las superficies de los pallets de las tres estanterías. `fijas` son las cajas
## que la noche ubica por su cuenta, como la pila de la llegada: se respetan y nadie las pisa.
## Devuelve la pose de apertura de todas las cajas; las ausentes abren en su lugar de fábrica.
static func abrir(
	cajas: Array[Caja],
	guardadas: Dictionary[Producto.Id, Transform3D],
	repisas: Array[AABB],
	fijas: Dictionary[Producto.Id, Transform3D] = {}
) -> Dictionary[Producto.Id, Transform3D]:
	var poses: Dictionary[Producto.Id, Transform3D] = {}
	var ocupado: Array[AABB] = []
	var por_acomodar: Array[Caja] = []
	var alturas: Dictionary[Producto.Id, float] = {}
	for caja in cajas:
		if fijas.has(caja.producto):
			poses[caja.producto] = fijas[caja.producto]
			ocupado.append(_limites(fijas[caja.producto], caja.media))
			continue
		poses[caja.producto] = caja.fabrica
		if caja.presente:
			por_acomodar.append(caja)
			alturas[caja.producto] = guardadas.get(caja.producto, caja.fabrica).origin.y
	# De abajo hacia arriba: una caja se apoya en otra sólo si esa ya quedó aceptada.
	por_acomodar.sort_custom(
		func(a: Caja, b: Caja) -> bool:
			if not is_equal_approx(alturas[a.producto], alturas[b.producto]):
				return alturas[a.producto] < alturas[b.producto]
			return a.producto < b.producto
	)
	var apoyos: Array[AABB] = repisas.duplicate()
	var en_estanteria: Array[Caja] = []
	var afuera: Array[Caja] = []
	for caja in por_acomodar:
		var pose: Transform3D = guardadas.get(caja.producto, caja.fabrica)
		var limites := _limites(pose, caja.media)
		var firme := (
			not guardadas.has(caja.producto)
			or pose.is_equal_approx(caja.fabrica)
			or _se_apoya(limites, apoyos)
		)
		if firme and _libre(limites, ocupado, repisas):
			poses[caja.producto] = pose
			ocupado.append(limites)
			apoyos.append(limites)
			en_estanteria.append(caja)
		else:
			afuera.append(caja)
	afuera.sort_custom(
		func(a: Caja, b: Caja) -> bool:
			if not is_equal_approx(a.media, b.media):
				return a.media > b.media
			return a.producto < b.producto
	)
	for caja in afuera:
		var pose := caja.fabrica
		for candidata in _candidatas(caja, cajas, en_estanteria, poses):
			if _libre(_limites(candidata, caja.media), ocupado, repisas):
				pose = candidata
				break
		poses[caja.producto] = pose
		ocupado.append(_limites(pose, caja.media))
		en_estanteria.append(caja)
	return poses


## Primero los huecos de las estanterías, en el orden de las cajas; después, el techo de cada
## caja que ya está en ellas, las más grandes primero y las más bajas dentro de cada tamaño.
static func _candidatas(
	caja: Caja, cajas: Array[Caja], bases: Array[Caja], poses: Dictionary[Producto.Id, Transform3D]
) -> Array[Transform3D]:
	var candidatas: Array[Transform3D] = []
	var huecos := cajas.duplicate()
	huecos.sort_custom(func(a: Caja, b: Caja) -> bool: return a.producto < b.producto)
	for hueco: Caja in huecos:
		if caja.media <= hueco.media + MARGEN_DE_TAMANO:
			var lugar := hueco.fabrica
			lugar.origin.y += caja.media - hueco.media
			candidatas.append(lugar)
	var techos := bases.duplicate()
	techos.sort_custom(
		func(a: Caja, b: Caja) -> bool:
			if not is_equal_approx(a.media, b.media):
				return a.media > b.media
			var altura_a := poses[a.producto].origin.y
			var altura_b := poses[b.producto].origin.y
			if not is_equal_approx(altura_a, altura_b):
				return altura_a < altura_b
			return a.producto < b.producto
	)
	for base: Caja in techos:
		var lugar: Transform3D = poses[base.producto]
		lugar.origin.y += base.media + caja.media
		candidatas.append(lugar)
	return candidatas


static func _limites(pose: Transform3D, media: float) -> AABB:
	var mitad := (pose.basis.x.abs() + pose.basis.y.abs() + pose.basis.z.abs()) * media
	return AABB(pose.origin - mitad, mitad * 2.0)


## Apoyada: su cara de abajo toca el techo de un apoyo y su centro cae dentro de él.
static func _se_apoya(limites: AABB, apoyos: Array[AABB]) -> bool:
	var centro := limites.get_center()
	for apoyo in apoyos:
		if (
			absf(limites.position.y - apoyo.end.y) <= TOLERANCIA_DE_APOYO
			and centro.x >= apoyo.position.x
			and centro.x <= apoyo.end.x
			and centro.z >= apoyo.position.z
			and centro.z <= apoyo.end.z
		):
			return true
	return false


static func _libre(limites: AABB, ocupado: Array[AABB], repisas: Array[AABB]) -> bool:
	var nucleo := limites.grow(-HOLGURA)
	for otro in ocupado:
		if nucleo.intersects(otro):
			return false
	for repisa in repisas:
		if nucleo.intersects(repisa):
			return false
	return true
