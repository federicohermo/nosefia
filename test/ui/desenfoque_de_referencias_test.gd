extends GdUnitTestSuite


class Caminante:
	extends Node3D

	func _physics_process(delta: float) -> void:
		position.z += delta * 3.0


func _escenario(interpolado: bool) -> Dictionary:
	var ventana: SubViewport = auto_free(SubViewport.new())
	ventana.own_world_3d = true
	add_child(ventana)
	var padre := Caminante.new()
	padre.physics_interpolation_mode = (
		Node.PHYSICS_INTERPOLATION_MODE_ON if interpolado else Node.PHYSICS_INTERPOLATION_MODE_OFF
	)
	ventana.add_child(padre)
	var camara := Camera3D.new()
	camara.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	padre.add_child(camara)
	camara.current = true
	var efecto := DesenfoqueDeReferencias.new()
	ventana.add_child(efecto)
	return {"padre": padre, "camara": camara, "efecto": efecto}


func test_la_mascara_sigue_la_camara_que_hereda_traslacion_interpolada() -> void:
	var escenario := _escenario(true)
	var camara: Camera3D = escenario.camara
	var efecto: DesenfoqueDeReferencias = escenario.efecto
	camara.get_global_transform_interpolated()
	var peor := 0.0
	var movimiento := 0.0
	var origen := camara.global_position
	for _cuadro in 60:
		await get_tree().process_frame
		efecto._process(0.0)
		var mascara: Camera3D = efecto.get("_camara")
		var dibujada := camara.get_global_transform_interpolated()
		peor = maxf(peor, mascara.global_position.distance_to(dibujada.origin))
		movimiento = maxf(movimiento, camara.global_position.distance_to(origen))
	assert_float(movimiento).is_greater(0.01)
	assert_float(peor).override_failure_message("desfasaje de %.2f mm" % (peor * 1000)).is_less(
		0.001
	)


func test_sin_ancestro_interpolado_la_mascara_sigue_el_giro_actual() -> void:
	var escenario := _escenario(false)
	var padre: Node3D = escenario.padre
	padre.set_physics_process(false)
	var camara: Camera3D = escenario.camara
	var efecto: DesenfoqueDeReferencias = escenario.efecto
	for cuadro in 5:
		await get_tree().process_frame
		camara.position = Vector3(cuadro, 0, 0)
		camara.rotation.y = cuadro * 0.2
		efecto._process(0.0)
		var mascara: Camera3D = efecto.get("_camara")
		assert_bool(mascara.global_transform.is_equal_approx(camara.global_transform)).is_true()


## El filtrado lineal reparte cada toma entre los cuatro píxeles que la rodean. Esto repite esa
## cuenta para saber qué peso recibe cada píxel del entorno.
func _peso_por_pixel(alcance: int) -> Dictionary:
	var pesos := {}
	for toma: Vector3 in DesenfoqueDeReferencias.tomas():
		var columna := floori(toma.x)
		var fila := floori(toma.y)
		var fx := toma.x - columna
		var fy := toma.y - fila
		for dy in 2:
			for dx in 2:
				var celda := Vector2i(columna + dx, fila + dy)
				var parte := (fx if dx == 1 else 1.0 - fx) * (fy if dy == 1 else 1.0 - fy)
				pesos[celda] = float(pesos.get(celda, 0.0)) + toma.z * parte
	for y in range(-alcance, alcance + 1):
		for x in range(-alcance, alcance + 1):
			pesos[Vector2i(x, y)] = float(pesos.get(Vector2i(x, y), 0.0))
	return pesos


func _alcance() -> int:
	return ceili(1.5 * DesenfoqueDeReferencias.RADIO)


func _dispersion(pesos: Dictionary, eje: int) -> float:
	var segundo := 0.0
	for celda: Vector2i in pesos:
		segundo += float(pesos[celda]) * celda[eje] * celda[eje]
	return sqrt(segundo)


func test_las_tomas_pesan_uno_en_total() -> void:
	var total := 0.0
	for toma: Vector3 in DesenfoqueDeReferencias.tomas():
		total += toma.z
	assert_float(total).is_equal_approx(1.0, 0.0001)


func test_el_nucleo_no_deja_pixeles_sin_peso() -> void:
	var pesos := _peso_por_pixel(_alcance())
	for y in range(-_alcance(), _alcance() + 1):
		for x in range(-_alcance(), _alcance() + 1):
			(
				assert_float(float(pesos[Vector2i(x, y)]))
				. override_failure_message("el píxel (%d, %d) queda sin peso" % [x, y])
				. is_greater(0.0)
			)


func test_la_respuesta_a_una_linea_baja_sin_picos_secundarios() -> void:
	var pesos := _peso_por_pixel(_alcance())
	for eje in 2:
		var anterior := INF
		for distancia in range(0, _alcance() + 1):
			var perfil := 0.0
			for lado in range(-_alcance(), _alcance() + 1):
				perfil += float(
					pesos[Vector2i(distancia, lado) if eje == 0 else Vector2i(lado, distancia)]
				)
			assert_float(perfil).is_less_equal(anterior)
			anterior = perfil


func test_el_nucleo_esta_centrado() -> void:
	var pesos := _peso_por_pixel(_alcance())
	var centro := Vector2.ZERO
	for celda: Vector2i in pesos:
		centro += Vector2(celda) * float(pesos[celda])
	assert_float(centro.length()).is_less(0.001)


func test_la_dispersion_es_la_misma_en_x_y_en_y_y_vale_el_radio_aparente() -> void:
	var pesos := _peso_por_pixel(_alcance())
	var esperada := DesenfoqueDeReferencias.RADIO / sqrt(2.0)
	assert_float(_dispersion(pesos, 0)).is_equal_approx(esperada, 0.05)
	assert_float(_dispersion(pesos, 1)).is_equal_approx(esperada, 0.05)
	assert_float(_dispersion(pesos, 0)).is_equal_approx(_dispersion(pesos, 1), 0.001)


func test_el_shader_declara_tantas_tomas_como_calcula_el_script() -> void:
	var declaracion := "tomas[%d]" % DesenfoqueDeReferencias.tomas().size()
	assert_bool(DesenfoqueDeReferencias.DESENFOQUE.code.contains(declaracion)).is_true()
