## Corre al importar el modelo del almacén.
##
## Todo el arte filtra pixelado, también los materiales sin textura: a esos el importador les
## pone filtro lineal, y Godot compila un shader aparte por cada filtro. En la web cada shader
## cuesta segundos de la primera carga.
@tool
extends EditorScenePostImport


func _post_import(escena: Node) -> Object:
	for malla: MeshInstance3D in escena.find_children("*", "MeshInstance3D", true, false):
		for i: int in malla.mesh.get_surface_count():
			var material := malla.mesh.surface_get_material(i) as BaseMaterial3D
			if material != null:
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	return escena
