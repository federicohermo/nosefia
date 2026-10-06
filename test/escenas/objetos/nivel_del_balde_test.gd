extends GdUnitTestSuite

const Agua := preload("res://src/escenas/objetos/superficie_liquida.gd")
const OBJETOS := preload("res://src/escenas/puestos/objetos_del_almacen.tscn")
const LIMPIA := Color(.25, .45, .65, .8)
const JABON := Color(.9, .15, .55, .8)


func _agua() -> Agua:
	var objetos: Node3D = auto_free(OBJETOS.instantiate())
	add_child(objetos)
	var balde := objetos.get_node("Balde") as RigidBody3D
	balde.freeze = true
	var agua := balde.get_node("Agua") as Agua
	agua.set_process(false)
	agua.set_physics_process(false)
	agua.pintar(LIMPIA)
	return agua


func test_llenar_sube_desde_el_fondo_y_repintar_no_lo_interrumpe() -> void:
	var agua := _agua()
	var reposo := agua.position.y
	agua.llenar()
	agua.set_process(false)
	agua.set_physics_process(false)
	assert_bool(agua.visible).is_true()
	assert_float(agua.position.y).is_between(-.138, -.13)
	agua.call("_process", 0.0)
	var vertices: PackedVector3Array = agua.get("_vertices")
	for vertice in vertices:
		assert_float(Vector2(vertice.x, vertice.z).length()).is_less(.16)
	agua.call("_physics_process", .125)
	var intermedio := agua.position.y
	assert_float(intermedio).is_greater(-.13)
	assert_float(intermedio).is_less(reposo)
	agua.presentar(true)
	agua.pintar(LIMPIA)
	assert_float(agua.position.y).is_equal(intermedio)
	agua.call("_physics_process", .125)
	assert_float(agua.position.y).is_equal_approx(reposo, .00001)
	assert_bool(agua.visible).is_true()


func test_vaciar_baja_con_el_ultimo_color_y_se_oculta_al_terminar() -> void:
	var agua := _agua()
	agua.presentar(true)
	var reposo := agua.position.y
	agua.mezclar(JABON)
	agua.call("_physics_process", .1)
	agua.vaciar()
	agua.set_process(false)
	agua.set_physics_process(false)
	agua.presentar(false)
	agua.pintar(ReglasDeLaLimpieza.COLOR_DEL_AGUA[ReglasDeLaLimpieza.Agua.NINGUNA])
	assert_bool(agua.visible).is_true()
	assert_float(agua.position.y).is_equal(reposo)
	assert_bool(agua.color_de_la_superficie() == JABON).is_true()
	(
		assert_float(
			(agua.material_override as ShaderMaterial).get_shader_parameter("progreso_de_mezcla")
		)
		. is_equal(1.0)
	)
	agua.call("_physics_process", .125)
	assert_float(agua.position.y).is_less(reposo)
	assert_bool(agua.visible).is_true()
	agua.presentar(false)
	agua.call("_physics_process", .125)
	assert_bool(agua.visible).is_false()


func test_invertir_la_transicion_conserva_el_nivel_actual_sin_salto() -> void:
	var agua := _agua()
	var reposo := agua.position.y
	agua.llenar()
	agua.call("_physics_process", .1)
	var intermedio := agua.position.y
	assert_float(intermedio).is_less(reposo)
	agua.vaciar()
	agua.call("_physics_process", 0.0)
	assert_float(agua.position.y).is_equal(intermedio)
	agua.call("_physics_process", .05)
	var bajando := agua.position.y
	assert_float(bajando).is_less(intermedio)
	agua.llenar()
	agua.call("_physics_process", 0.0)
	assert_float(agua.position.y).is_equal(bajando)
	agua.call("_physics_process", .25)
	assert_float(agua.position.y).is_equal_approx(reposo, .00001)
	assert_bool(agua.visible).is_true()


func test_reiniciar_cancela_el_nivel_y_la_mezcla_anteriores() -> void:
	var agua := _agua()
	var reposo := agua.position.y
	agua.llenar()
	agua.call("_physics_process", .1)
	agua.mezclar(JABON)
	assert_float(agua.position.y).is_less(reposo)
	agua.reiniciar()
	agua.presentar(false)
	agua.pintar(Color.TRANSPARENT)
	agua.call("_physics_process", .3)
	assert_float(agua.position.y).is_equal_approx(reposo, .00001)
	assert_bool(agua.visible).is_false()
	agua.pintar(LIMPIA)
	agua.llenar()
	assert_float(agua.position.y).is_between(-.138, -.13)
	assert_bool(agua.color_de_la_superficie() == LIMPIA).is_true()
	(
		assert_float(
			(agua.material_override as ShaderMaterial).get_shader_parameter("progreso_de_mezcla")
		)
		. is_equal(1.0)
	)


func test_llenar_y_vaciar_no_mueven_los_liquidos_ajenos_al_balde() -> void:
	var recipiente: Node3D = auto_free(Recipiente.new())
	add_child(recipiente)
	var agua := Agua.new()
	agua.mesh = CylinderMesh.new()
	agua.material_override = StandardMaterial3D.new()
	agua.position = Vector3(.1, .04, .3)
	recipiente.add_child(agua)
	agua.set_process(false)
	agua.set_physics_process(false)
	var anterior := agua.transform
	agua.llenar()
	agua.vaciar()
	assert_bool(agua.transform.is_equal_approx(anterior)).is_true()
	assert_bool(agua.visible).is_true()


func test_los_niveles_quedan_dentro_de_las_paredes_del_modelo_real() -> void:
	var agua := _agua()
	var balde := agua.get_parent() as RigidBody3D
	var malla := balde.get_node("Malla") as MeshInstance3D
	assert_str(malla.mesh.surface_get_material(0).resource_name).is_equal("util_plastico_azul")
	var paredes := _paredes_interiores(malla.mesh)
	assert_int(paredes.size()).is_greater(0)
	agua.llenar()
	agua.set_physics_process(false)
	agua.set_process(false)
	var margen := INF
	for paso in 5:
		if paso > 0:
			agua.call("_physics_process", .0625)
		agua.call("_process", 0.0)
		for vertice: Vector3 in agua.get("_vertices"):
			var punto := agua.transform * vertice
			assert_float(punto.y).is_greater(-.138054)
			for pared in paredes:
				var alturas: Vector2 = pared.alturas
				if punto.y >= alturas.x - .00001 and punto.y <= alturas.y + .00001:
					var plano: Plane = pared.plano
					margen = minf(margen, plano.distance_to(punto))
	assert_float(margen).is_greater(.0001)


func _paredes_interiores(malla: Mesh) -> Array[Dictionary]:
	var arrays := malla.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normales: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var paredes: Array[Dictionary] = []
	for inicio in range(0, indices.size(), 3):
		var a := vertices[indices[inicio]]
		var b := vertices[indices[inicio + 1]]
		var c := vertices[indices[inicio + 2]]
		var inferior := minf(a.y, minf(b.y, c.y))
		var superior := maxf(a.y, maxf(b.y, c.y))
		if superior - inferior < .00001:
			continue
		var original := normales[indices[inicio]]
		if original.dot(Vector3(-a.x, 0, -a.z)) <= .01:
			continue
		var normal := (b - a).cross(c - a).normalized()
		if normal.dot(original) < 0.0:
			normal = -normal
		paredes.append(
			{"plano": Plane(normal, normal.dot(a)), "alturas": Vector2(inferior, superior)}
		)
	return paredes


class Recipiente:
	extends Node3D
	var lugar := 0
