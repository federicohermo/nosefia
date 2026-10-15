## Corre fuera del checkout con --main-pack: el menú puede cargar aunque el almacén no cargue.
extends SceneTree


func _initialize() -> void:
	var escena: PackedScene = load("res://assets/models/SEPT_JUEGOS_PROTOTIPO.glb")
	if escena == null:
		push_error("El paquete no puede cargar el modelo con sus texturas.")
		quit(1)
		return
	var modelo := escena.instantiate()
	var requeridos: Array[String] = [
		"almacen",
		"cajaregistradora",
		"EscritorioComputadora/lector de productos",
		"puerta",
		"puerta2",
		"deposito_contenedor_grande_soporte/deposito_contenedor_grande_cuerpo",
	]
	for ruta: String in requeridos:
		if modelo.get_node_or_null(ruta) == null:
			push_error("El modelo exportado no contiene " + ruta)
			modelo.free()
			quit(1)
			return
	modelo.free()
	print("Modelo exportado: carga con sus texturas, caja, lector, puertas y contenedor.")
	quit()
