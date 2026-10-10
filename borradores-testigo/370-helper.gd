## Abre la segunda jornada y usa sus tachos para preparar bolsas físicas en los fixtures.
extends RefCounted

const RUTAS: Array[NodePath] = [
	^"Estructura/tachitobasura/StaticBody3D",
	^"Estructura/tachitobasura_001/StaticBody3D",
	^"Estructura/tachitobasura_002/StaticBody3D",
]


static func abrir(almacen: Node3D) -> void:
	var partida: Partida = almacen.get("_partida")
	while partida.jornada() < 2:
		partida.cerrar_la_jornada(partida.obligatorias().size())
		almacen.get("_ciclo").abrir_la_jornada()


static func sacar(almacen: Node3D, numero: int = 0) -> ObjetoAgarrable:
	abrir(almacen)
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set("_enfocado", almacen.get_node(RUTAS[numero]))
	var evento := InputEventAction.new()
	evento.action = ReglasDelJugador.ACCION_USAR
	evento.pressed = true
	jugador.call("_unhandled_input", evento)
	return (almacen.get("_agarre") as Agarre).cuerpo_sostenido() as ObjetoAgarrable


static func preparar(almacen: Node3D, numero: int = 0) -> ObjetoAgarrable:
	var bolsa := sacar(almacen, numero)
	if bolsa == null:
		return null
	var agarre: Agarre = almacen.get("_agarre")
	agarre.soltar(false)
	bolsa.global_transform = bolsa.lugar_de_origen()
	return bolsa


## Reusa las colisiones y altura del jugador real; ningún punto se inventa por decoración.
static func sitios(almacen: Node3D, objetivo: PhysicsBody3D) -> Array[Vector3]:
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var cuerpo: CollisionShape3D = jugador.get_node("Cuerpo")
	var malla := objetivo.get_parent() as MeshInstance3D
	var bounds := malla.global_transform * malla.get_aabb()
	var centro := bounds.get_center()
	var espacio := almacen.get_world_3d().direct_space_state
	var salida: Array[Vector3] = []
	for radio: float in [0.8, 1.1, 1.5, 1.8]:
		for angulo in range(0, 360, 15):
			var direccion := Vector3(cos(deg_to_rad(angulo)), 0, sin(deg_to_rad(angulo)))
			var alrededor := centro + direccion * radio
			var consulta := PhysicsRayQueryParameters3D.create(
				Vector3(alrededor.x, bounds.position.y + 0.8, alrededor.z),
				Vector3(alrededor.x, bounds.position.y - 0.5, alrededor.z),
				jugador.collision_mask
			)
			consulta.exclude = [jugador.get_rid()]
			var piso := espacio.intersect_ray(consulta)
			if piso.is_empty() or piso.normal.y < 0.9:
				continue
			var apoyo := piso.collider as StaticBody3D
			if apoyo == null:
				continue
			var forma_del_piso := (
				apoyo.shape_owner_get_owner(apoyo.shape_find_owner(piso.shape)) as Node
			)
			if not (
				apoyo.name == "SueloSolido"
				or str(apoyo.get_path()).ends_with("/almacen/StaticBody3D")
				or forma_del_piso.name == "VolumenDelPisoDelBano"
			):
				continue
			var posicion: Vector3 = piso.position + Vector3.UP * 0.005
			var volumen := PhysicsShapeQueryParameters3D.new()
			volumen.shape = cuerpo.shape
			volumen.transform = Transform3D(Basis.IDENTITY, posicion) * cuerpo.transform
			volumen.collision_mask = jugador.collision_mask
			volumen.exclude = [jugador.get_rid()]
			volumen.margin = 0.0
			if not espacio.intersect_shape(volumen).is_empty():
				continue
			var ojo := posicion + Vector3.UP * ReglasDelJugador.ALTURA_DE_LA_CAMARA
			var rayo := PhysicsRayQueryParameters3D.create(ojo, centro, 3)
			rayo.exclude = [jugador.get_rid()]
			var golpe := espacio.intersect_ray(rayo)
			if golpe.get("collider") == objetivo:
				if ojo.distance_to(golpe.position) <= ReglasDelJugador.ALCANCE_DE_LA_MIRA:
					salida.append(posicion)
	return salida


static func enfocar(almacen: Node3D, objetivo: PhysicsBody3D) -> bool:
	var jugador: CharacterBody3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	jugador.set_process(false)
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	var malla := objetivo.get_parent() as MeshInstance3D
	var centro := malla.to_global(malla.get_aabb().get_center())
	for sitio in sitios(almacen, objetivo):
		jugador.global_position = sitio
		jugador.reset_physics_interpolation()
		camara.look_at(centro)
		camara.reset_physics_interpolation()
		for _cuadro in 3:
			await almacen.get_tree().physics_frame
		jugador.call("_leer_la_mira")
		if jugador.get("_enfocado") == objetivo:
			return true
	return false
