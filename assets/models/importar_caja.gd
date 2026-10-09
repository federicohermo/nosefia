@tool
extends "res://assets/models/importar_modelo.gd"


func _post_import(escena: Node) -> Object:
	super._post_import(escena)
	var nombre := get_source_file().get_file().get_basename()
	var mallas := escena.find_children("*", "MeshInstance3D", true, false)
	assert(mallas.size() == 1, "Cada pieza de la caja debe traer una sola malla")
	var malla := mallas[0] as MeshInstance3D
	if nombre == "ticket_impreso":
		for superficie in malla.mesh.get_surface_count():
			var material := malla.mesh.surface_get_material(superficie) as BaseMaterial3D
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var guardado := ResourceSaver.save(malla.mesh, "res://assets/models/" + nombre + ".res")
	assert(guardado == OK, "No se pudo guardar la malla de " + nombre)
	if nombre != "ticket_impreso":
		var forma := malla.mesh.create_trimesh_shape()
		guardado = ResourceSaver.save(forma, "res://assets/models/" + nombre + "_colision.res")
		assert(guardado == OK, "No se pudo guardar la colisión de " + nombre)
	return escena
