## Dónde se puede apoyar algo en el piso alrededor de un punto.
##
## La usan el puesto de reposición, para dejar la caja al lado del jugador, y la red de seguridad,
## para lo que rescata. Es una sola búsqueda para que las dos contesten lo mismo.
class_name LugaresDelPiso
extends RefCounted


## Los puntos de apoyo a `radio` metros de `centro`, en `lados` direcciones y empezando por
## `adelante`. Cada punto es donde un rayo que baja desde `alto` metros sobre el piso del centro
## pega en una superficie donde se puede apoyar algo, hasta `caida` metros por debajo.
static func alrededor(
	espacio: PhysicsDirectSpaceState3D,
	centro: Vector3,
	adelante: Vector3,
	radio: float,
	alto: float,
	caida: float,
	lados: int,
	mascara: int,
	excluidos: Array[RID]
) -> Array[Vector3]:
	var lugares: Array[Vector3] = []
	for lado in lados:
		var vuelta := Basis(Vector3.UP, TAU * lado / lados)
		var costado := centro + vuelta * (adelante * radio)
		var consulta := PhysicsRayQueryParameters3D.create(
			costado + Vector3.UP * alto, costado + Vector3.DOWN * caida, mascara
		)
		consulta.exclude = excluidos
		var golpe := espacio.intersect_ray(consulta)
		if golpe.is_empty() or not ReglasDeLosObjetos.se_puede_apoyar_en(golpe["normal"].y):
			continue
		lugares.append(golpe["position"])
	return lugares
