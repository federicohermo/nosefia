extends SceneTree


func _initialize() -> void:
	var escena: PackedScene = load("res://src/escenas/almacen.tscn")
	var almacen: Node3D = escena.instantiate()
	var medidas: Array[Dictionary] = []
	for nodo: Node in almacen.find_children("*", "CollisionShape3D", true, false):
		var forma := nodo as CollisionShape3D
		if not forma.shape is ConvexPolygonShape3D:
			continue
		var poligono := forma.shape as ConvexPolygonShape3D
		var pose := _pose(almacen, forma)
		var puntos: Array[Array] = []
		for local: Vector3 in poligono.points:
			var mundo := pose * local
			puntos.append([mundo.x, mundo.y, mundo.z])
		medidas.append(
			{"ruta": str(almacen.get_path_to(forma)), "disabled": forma.disabled, "puntos": puntos}
		)
	print("B306_CONVEX=", JSON.stringify(medidas))
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
