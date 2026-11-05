## Pallets de piso con medidas propias: madera visible, pequeñas holguras y paso alrededor. Cuatro
## junto al portón para la llegada de cajas, y dos contra el fondo para las cajas que sólo existen
## como caja (BR-STK-054).
extends Node3D

## Cuánto queda libre entre los pallets del fondo y la pared del cuartito, por donde se llega a su
## puerta, y entre los pallets y la pared de atrás.
const PASO_AL_CUARTITO := 0.5
const HOLGURA_CON_LA_PARED := 0.1
const ESCALA := 1.15
## Cuánto separa de la estantería del fondo al pallet que se apoya junto a ella.
const SEPARACION_CON_LA_ESTANTERIA := 0.2
const GIROS_DEL_FONDO: Array[float] = [0.012, -0.015]


func disponer(
	plantilla: MeshInstance3D, porton: MeshInstance3D, piso: CollisionShape3D
) -> Array[MeshInstance3D]:
	var puerta := porton.global_transform * porton.get_aabb()
	var madera := plantilla.get_aabb()
	var forma := piso.shape as BoxShape3D
	var suelo := (piso.global_transform * AABB(-forma.size / 2.0, forma.size)).end.y
	var pallets: Array[MeshInstance3D] = []
	# La medida del pallet es fija y no se ajusta al perímetro de cada pila de cajas.
	var escala := ESCALA
	var ancho := madera.size.z * escala
	var largo := madera.size.x * escala
	var giros: Array[float] = [-0.025, 0.018, 0.012, -0.02]
	for hilera: int in 2:
		for lugar: int in 2:
			var centro := Vector3(
				puerta.end.x + 0.65 + ancho / 2.0 + hilera * (ancho + 0.12),
				suelo,
				puerta.get_center().z + (lugar - 0.5) * (largo + 0.34)
			)
			pallets.append(_crear(plantilla, centro, escala, PI / 2.0 + giros[pallets.size()]))
	return pallets


## Dos pallets contra la pared del fondo: uno hacia la esquina del cuartito, con paso hasta su
## puerta, y el otro del otro lado de la estantería del fondo. Salen de las medidas del piso y no de
## coordenadas copiadas. Entre los dos queda el piso de la pared, con la palanca y una mancha.
func disponer_contra_el_fondo(
	plantilla: MeshInstance3D, piso: CollisionShape3D, estanteria: AABB
) -> Array[MeshInstance3D]:
	var madera := plantilla.get_aabb()
	var forma := piso.shape as BoxShape3D
	var limites := piso.global_transform * AABB(-forma.size / 2.0, forma.size)
	var largo := madera.size.x * ESCALA
	var ancho := madera.size.z * ESCALA
	var derechas: Array[float] = [
		limites.end.x - PASO_AL_CUARTITO, estanteria.position.x - SEPARACION_CON_LA_ESTANTERIA
	]
	var pallets: Array[MeshInstance3D] = []
	for lugar: int in GIROS_DEL_FONDO.size():
		var centro := Vector3(
			derechas[lugar] - largo / 2.0,
			limites.end.y,
			limites.position.z + HOLGURA_CON_LA_PARED + ancho / 2.0
		)
		pallets.append(_crear(plantilla, centro, ESCALA, GIROS_DEL_FONDO[lugar]))
	return pallets


func _crear(
	plantilla: MeshInstance3D, centro: Vector3, escala: float, giro: float
) -> MeshInstance3D:
	var limites := plantilla.get_aabb()
	var pallet := MeshInstance3D.new()
	pallet.name = "PalletDeEntrega%d" % get_child_count()
	pallet.mesh = plantilla.mesh
	pallet.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	pallet.rotation.y = giro
	pallet.scale = Vector3(escala, 1.0, escala)
	add_child(pallet)
	pallet.global_position = (
		centro
		- pallet.basis * Vector3(limites.get_center().x, limites.position.y, limites.get_center().z)
	)
	var cuerpo := StaticBody3D.new()
	cuerpo.collision_layer = 8
	cuerpo.collision_mask = 0
	pallet.add_child(cuerpo)
	var volumen := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = limites.size
	volumen.shape = caja
	volumen.position = limites.get_center()
	cuerpo.add_child(volumen)
	return pallet
