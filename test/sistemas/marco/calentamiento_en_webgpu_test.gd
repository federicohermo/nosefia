## En WebGPU el motor compila cada variante en segundo plano y dibuja con el sombreador general
## hasta que está lista: el calentamiento no tiene nada que evitar, y termina sin tocar la escena.
extends GdUnitTestSuite

const CUANTOS := 6
const ESPERA_MS := 5000


func _escena() -> Node3D:
	var escena: Node3D = auto_free(Node3D.new())
	for i: int in CUANTOS:
		var malla := MeshInstance3D.new()
		malla.mesh = BoxMesh.new()
		malla.material_override = StandardMaterial3D.new()
		escena.add_child(malla)
	add_child(escena)
	return escena


func _visibles(escena: Node3D) -> int:
	return (
		escena
		. find_children("*", "GeometryInstance3D", true, false)
		. filter(func(objeto: GeometryInstance3D) -> bool: return objeto.visible)
		. size()
	)


func _calentamiento_en_webgpu() -> CalentamientoDeShaders:
	var calentamiento: CalentamientoDeShaders = auto_free(CalentamientoDeShaders.new())
	calentamiento.driver_actual = func() -> String: return "webgpu"
	add_child(calentamiento)
	return calentamiento


func test_termina_sin_ocultar_nada() -> void:
	var escena := _escena()
	var calentamiento := _calentamiento_en_webgpu()
	assert_int(_visibles(escena)).is_equal(CUANTOS)

	calentamiento.calentar(escena)

	assert_int(_visibles(escena)).is_equal(CUANTOS)
	await assert_signal(calentamiento).wait_until(ESPERA_MS).is_emitted("terminado")
	assert_int(_visibles(escena)).is_equal(CUANTOS)


func test_a_oscuras_tampoco_cambia_la_luz() -> void:
	var escena := _escena()
	var calentamiento := _calentamiento_en_webgpu()
	var pedidos: Array[bool] = []

	calentamiento.calentar_a_oscuras(
		escena, func(a_oscuras: bool) -> void: pedidos.append(a_oscuras)
	)

	await assert_signal(calentamiento).wait_until(ESPERA_MS).is_emitted("terminado")
	assert_array(pedidos).is_empty()


func test_con_otro_driver_si_calienta() -> void:
	assert_bool(CalentamientoDeShaders.compila_sin_frenar("opengl3")).is_false()
	assert_bool(CalentamientoDeShaders.compila_sin_frenar("vulkan")).is_false()
	assert_bool(CalentamientoDeShaders.compila_sin_frenar("webgpu")).is_true()
