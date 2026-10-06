extends GdUnitTestSuite

const OBJETOS := preload("res://src/escenas/puestos/objetos_del_almacen.tscn")
const CONTORNO := preload("res://src/escenas/objetos/contorno_del_util.gdshader")


func test_las_variantes_de_los_utiles_reales_se_calientan_y_no_quedan_dibujando() -> void:
	var objetos: Node3D = auto_free(OBJETOS.instantiate())
	add_child(objetos)
	for cuerpo: RigidBody3D in objetos.find_children("*", "RigidBody3D", true, false):
		cuerpo.freeze = true
	var mopa := objetos.get_node("Mopa/Malla") as MeshInstance3D
	var balde := objetos.get_node("Balde/Malla") as MeshInstance3D
	var calentamiento: CalentamientoDeShaders = auto_free(CalentamientoDeShaders.new())
	add_child(calentamiento)
	var vistos: Dictionary[int, bool] = {}
	calentamiento.avanzo.connect(
		func(_progreso: float) -> void:
			for malla: MeshInstance3D in [mopa, balde]:
				if not malla.visible:
					continue
				for superficie: int in malla.mesh.get_surface_count():
					var material := malla.get_active_material(superficie)
					var pase := material.next_pass as ShaderMaterial
					if pase != null and pase.shader == CONTORNO:
						var modo: Variant = pase.get_shader_parameter("deformacion")
						if modo != null:
							vistos[int(modo)] = true
	)
	# Se empieza antes de los preparar() diferidos de las mallas, como hace el menú real.
	calentamiento.calentar(objetos)
	await assert_signal(calentamiento).wait_until(5000).is_emitted("terminado")
	for modo: int in [0, 1, 2]:
		(
			assert_bool(vistos.has(modo))
			. override_failure_message("Modo %d del contorno compartido sin dibujar" % modo)
			. is_true()
		)
	for malla: MeshInstance3D in [mopa, balde]:
		for superficie: int in malla.mesh.get_surface_count():
			assert_object(malla.get_active_material(superficie).next_pass).is_null()
