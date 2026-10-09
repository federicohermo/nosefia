extends SceneTree


func _initialize() -> void:
	var escena: PackedScene = load("res://src/escenas/almacen.tscn")
	var almacen: Node3D = escena.instantiate()
	var cajas: Array[Dictionary] = []
	for nodo: Node in almacen.find_children("*", "CollisionShape3D", true, false):
		var forma := nodo as CollisionShape3D
		if forma.shape is BoxShape3D:
			var caja := forma.shape as BoxShape3D
			var local := AABB(-caja.size * 0.5, caja.size)
			var pose := _pose(almacen, forma)
			cajas.append(
				{
					"ruta": str(almacen.get_path_to(forma)),
					"pose": str(pose),
					"local": str(local),
					"mundo": str(pose * local),
					"disabled": forma.disabled
				}
			)
	var cuerpos: Dictionary = {}
	for campo: String in ["_cajas_de_productos", "_utiles_de_limpieza", "_bolsas"]:
		var filas: Array[Dictionary] = []
		for cuerpo: Node3D in almacen.get(campo):
			filas.append(
				{
					"ruta": str(almacen.get_path_to(cuerpo)),
					"posicion": str(_pose(almacen, cuerpo).origin)
				}
			)
		cuerpos[campo] = filas
	var exterior: Node3D = load("res://src/escenas/puestos/exterior_del_almacen.gd").new()
	exterior.call("_ready")
	var pavimentos: Array[Dictionary] = []
	for hijo: Node in exterior.get_children():
		if str(hijo.name).begins_with("Pavimento"):
			var malla := hijo as MeshInstance3D
			pavimentos.append(
				{
					"nombre": str(hijo.name),
					"aabb": str(malla.mesh.get_aabb()),
					"caras": str(malla.mesh.get_faces()),
					"hijos": malla.get_child_count()
				}
			)
	var estructura := almacen.get_node("Estructura") as Node3D
	print(
		"B306_MEDIDAS=",
		JSON.stringify(
			{
				"estructura_pose": str(_pose(almacen, estructura)),
				"cajas_solidas": cajas,
				"cuerpos": cuerpos,
				"jugador": str(_pose(almacen, almacen.get("_jugador")).origin),
				"hueco": str(_pose(almacen, almacen.get_node("Estructura/HuecoDeLaVentanilla"))),
				"pavimentos": pavimentos
			}
		)
	)
	exterior.free()
	almacen.free()
	quit()


func _pose(raiz: Node, nodo: Node3D) -> Transform3D:
	var pose := Transform3D.IDENTITY
	var actual: Node = nodo
	while actual != raiz and actual != null:
		if actual is Node3D:
			pose = (actual as Node3D).transform * pose
		actual = actual.get_parent()
	return pose
