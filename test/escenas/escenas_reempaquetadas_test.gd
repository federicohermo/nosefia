## Que ninguna escena pierda lo que declara al exportarse.
##
## **El export no copia el `.tscn`: lo vuelve a empaquetar.** Un valor escrito sobre un hijo de
## una instancia sobrevive a eso sólo si la instancia está marcada editable. Sin la marca, el
## editor y los tests lo leen bien, y la web lo pierde sin un solo error: así se agrandaron las
## cajas chicas del depósito.
extends GdUnitTestSuite

const RAIZ := "res://src"


func test_ninguna_escena_cambia_al_volver_a_empaquetarla() -> void:
	var perdidos: Array[String] = []
	for ruta in _escenas(RAIZ):
		var original := (load(ruta) as PackedScene).instantiate()
		var empaquetada := PackedScene.new()
		empaquetada.pack(original)
		var copia := empaquetada.instantiate()
		for nodo in original.find_children("*", "Node3D", true, false):
			var camino := original.get_path_to(nodo)
			var gemelo := copia.get_node_or_null(camino) as Node3D
			if gemelo and not gemelo.transform.is_equal_approx((nodo as Node3D).transform):
				perdidos.append("%s: %s" % [ruta, camino])
		original.free()
		copia.free()
	assert_array(perdidos).is_empty()


func _escenas(carpeta: String) -> Array[String]:
	var rutas: Array[String] = []
	for archivo in DirAccess.get_files_at(carpeta):
		if archivo.ends_with(".tscn"):
			rutas.append(carpeta.path_join(archivo))
	for sub in DirAccess.get_directories_at(carpeta):
		rutas.append_array(_escenas(carpeta.path_join(sub)))
	return rutas
