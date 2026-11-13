## Los lados de un mueble, leídos de la escena y no de un eje del mundo.
##
## Un test que dice «a la izquierda de la góndola» con `Vector3.LEFT` fija la planta: si el mueble
## se mueve o se espeja, falla sin que nada esté roto. Acá un lado es un eje local del mueble
## llevado al mundo con su `global_basis`, y el punto junto a él sale de su caja global. Un lado
## sin lugar para pararse —contra una pared, tapado por otro mueble o sobre el vacío de afuera del
## local— no entra en `libres`.
extends RefCounted

## Los pies del jugador sobre el piso, en metros de alto.
const PIES_SOBRE_EL_PISO := 0.11
## Lo que se levanta el cuerpo del jugador para no contar el roce con el piso como choque.
const HOLGURA_DEL_PISO := 0.02


## Un lado horizontal de un mueble.
class Lado:
	extends RefCounted
	## Hacia dónde da, en el mundo.
	var hacia := Vector3.ZERO
	## Lo que mide el mueble del centro a esa cara, en metros.
	var mitad := 0.0
	## Si da a un extremo del largo del mueble, y no a un costado.
	var de_cabecera := false


static func caja(mueble: MeshInstance3D) -> AABB:
	return mueble.global_transform * mueble.get_aabb()


## La caja local de la pieza más larga del mueble. Un mueble de varias piezas, como la góndola alta
## contra dos paredes, no tiene lados en la caja que las envuelve a todas: los tiene cada pieza.
static func pieza_local(mueble: MeshInstance3D) -> AABB:
	var mayor := AABB()
	for pieza: AABB in PiezasDeUnMueble.de_la_malla(mueble.mesh):
		if pieza.size.z > mayor.size.z:
			mayor = pieza
	return mayor


## La caja global de esa pieza.
static func pieza(mueble: MeshInstance3D) -> AABB:
	return mueble.global_transform * pieza_local(mueble)


## Los cuatro lados horizontales de su pieza más larga, con el largo leído de su malla.
static func lados(mueble: MeshInstance3D) -> Array[Lado]:
	var local := pieza_local(mueble)
	var largo_en_x := local.size.x >= local.size.z
	var limites := pieza(mueble)
	var salida: Array[Lado] = []
	for eje: Vector3 in [Vector3.RIGHT, Vector3.BACK]:
		for signo: float in [1.0, -1.0]:
			var lado := Lado.new()
			lado.hacia = (mueble.global_basis * (eje * signo)).normalized()
			lado.mitad = limites.size.dot(lado.hacia.abs()) / 2.0
			lado.de_cabecera = (eje == Vector3.RIGHT) == largo_en_x
			salida.append(lado)
	return salida


## Dónde se paran los pies junto a un lado, a `distancia` de su cara.
static func pie_junto_a(mueble: MeshInstance3D, lado: Lado, distancia: float) -> Vector3:
	var pie := pieza(mueble).get_center() + lado.hacia * (lado.mitad + distancia)
	pie.y = PIES_SOBRE_EL_PISO
	return pie


## Los lados donde el cuerpo del jugador cabe parado a `distancia` de la cara.
static func libres(
	almacen: Node3D, mueble: MeshInstance3D, distancia: float, de_cabecera: bool
) -> Array[Lado]:
	var salida: Array[Lado] = []
	for lado in lados(mueble):
		if (
			lado.de_cabecera == de_cabecera
			and cabe_parado(almacen, pie_junto_a(mueble, lado, distancia))
		):
			salida.append(lado)
	return salida


static func cabe_parado(almacen: Node3D, pie: Vector3) -> bool:
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var estado := almacen.get_world_3d().direct_space_state
	# Sin piso debajo, el lugar es el vacío de afuera del local y no un lugar para pararse.
	var suelo := PhysicsRayQueryParameters3D.create(
		pie + Vector3.UP * HOLGURA_DEL_PISO, pie + Vector3.DOWN * HOLGURA_DEL_PISO
	)
	suelo.collision_mask = jugador.collision_mask
	suelo.exclude = [jugador.get_rid()]
	if estado.intersect_ray(suelo).is_empty():
		return false
	var cuerpo: CollisionShape3D = jugador.get_node("Cuerpo")
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = cuerpo.shape
	consulta.transform = Transform3D(
		Basis.IDENTITY, pie + cuerpo.position + Vector3.UP * HOLGURA_DEL_PISO
	)
	consulta.collision_mask = jugador.collision_mask
	consulta.exclude = [jugador.get_rid()]
	return estado.intersect_shape(consulta, 1).is_empty()
