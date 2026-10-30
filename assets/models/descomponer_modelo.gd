## Separa en cuerpos convexos los muebles cóncavos para integrar_modelo.py.
extends SceneTree


func _initialize() -> void:
	_descomponer.call_deferred()


func _descomponer() -> void:
	var escena: PackedScene = load("res://assets/models/SEPT_JUEGOS_PROTOTIPO.glb")
	var modelo: Node3D = escena.instantiate()
	var resultado: Dictionary = {}
	var ajustes := MeshConvexDecompositionSettings.new()
	ajustes.max_concavity = 0.001
	ajustes.resolution = 1000000
	ajustes.max_convex_hulls = 128
	ajustes.max_num_vertices_per_convex_hull = 64
	ajustes.plane_downsampling = 1
	ajustes.convex_hull_downsampling = 1
	for nombre: String in [
		"heladeranueva",
		"heladeranueva_001",
		"heladera_fuera_de_servicio",
		"local_marco_frente",
		"local_marco_ventanal",
		"puerta/marco_puerta_deposito",
		"freezer_helados",
		"salon_mesa_1",
		"salon_mesa_2",
		"salon_mesa_3",
		"salon_silla_1a",
		"salon_silla_1b",
		"salon_silla_2a",
		"salon_silla_2b",
		"salon_silla_3a",
		"salon_silla_3b",
	]:
		var malla: MeshInstance3D = modelo.get_node(nombre)
		var inicio := Time.get_ticks_msec()
		print("DESCOMPONER ", nombre)
		var partes: Array = []
		var antes := malla.get_child_count()
		malla.create_multiple_convex_collisions(ajustes)
		var cuerpo := malla.get_child(antes)
		for volumen: CollisionShape3D in cuerpo.get_children():
			var forma := volumen.shape as ConvexPolygonShape3D
			var puntos: Array = []
			for punto: Vector3 in forma.points:
				puntos.append([punto.x, punto.y, punto.z])
			partes.append(puntos)
		resultado[nombre] = partes
		print("DESCOMPUESTO ", nombre, " ", partes.size(), " ", Time.get_ticks_msec() - inicio)
	var archivo := FileAccess.open("res://build/volumenes_descompuestos.json", FileAccess.WRITE)
	archivo.store_string(JSON.stringify(resultado))
	modelo.free()
	quit()
