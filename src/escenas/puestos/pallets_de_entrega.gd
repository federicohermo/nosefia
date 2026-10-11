## Cuatro pallets con medidas propias: madera visible, pequeñas holguras y paso alrededor.
extends Node3D


func disponer(
	plantilla: MeshInstance3D, porton: MeshInstance3D, piso: CollisionShape3D
) -> Array[MeshInstance3D]:
	var puerta := porton.global_transform * porton.get_aabb()
	var madera := plantilla.get_aabb()
	var forma := piso.shape as BoxShape3D
	var suelo := (piso.global_transform * AABB(-forma.size / 2.0, forma.size)).end.y
	var pallets: Array[MeshInstance3D] = []
	# La medida del pallet es fija y no se ajusta al perímetro de cada pila de cajas.
	var escala := 1.15
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
			pallets.append(_crear(plantilla, centro, escala, giros[pallets.size()]))
	return pallets


func _crear(
	plantilla: MeshInstance3D, centro: Vector3, escala: float, giro: float
) -> MeshInstance3D:
	var limites := plantilla.get_aabb()
	var pallet := MeshInstance3D.new()
	pallet.name = "PalletDeEntrega%d" % get_child_count()
	pallet.mesh = plantilla.mesh
	pallet.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	pallet.rotation.y = PI / 2.0 + giro
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
