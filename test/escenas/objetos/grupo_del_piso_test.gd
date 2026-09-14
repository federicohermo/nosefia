## El grupo dibuja cada cuerpo del piso una sola vez, y en el lugar donde el motor lo dibuja.
##
## La referencia es `get_global_transform_interpolated()` y no el `transform` físico. Con la
## interpolación del spec 044 encendida, el motor dibuja entre el paso anterior y el actual.
## Medido: los dos difieren hasta 63,65 mm en caída libre. Comparar contra el físico haría
## insatisfacible el criterio.
##
## Los casos de caída llaman `grupo._process(0.0)` a mano después de cada cuadro. La señal
## `process_frame` llega antes que el `_process` de los nodos, así que leer justo después del
## `await` compara la escritura del cuadro anterior contra la fracción de interpolación de éste.
## Medido: 30,98 mm de desfasaje aparente con el arreglo ya puesto.
extends GdUnitTestSuite

const GrupoDelPiso := preload("res://src/escenas/objetos/grupo_del_piso.gd")

## Alto del cuerpo de prueba, en metros. Es el del producto que se mide en el research.
const ALTO := 0.16

## Desde dónde cae. Alcanza para pasar de la velocidad cero al impacto en pocos cuadros.
const CAIDA := 1.1

## El techo del desfasaje, en metros. Un milímetro sobre un objeto de 160 mm.
const TOLERANCIA := 0.001


func _mundo() -> Node3D:
	var mundo: Node3D = auto_free(Node3D.new())
	add_child(mundo)
	return mundo


func _cuerpo(mundo: Node3D, donde: Vector3, cae: bool) -> RigidBody3D:
	var cuerpo := RigidBody3D.new()
	cuerpo.freeze = not cae
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(ALTO, ALTO, ALTO)
	forma.shape = caja
	cuerpo.add_child(forma)
	var vista := MeshInstance3D.new()
	vista.name = "Malla"
	vista.mesh = BoxMesh.new()
	mundo.add_child(cuerpo)
	cuerpo.add_child(vista)
	cuerpo.global_position = donde
	return cuerpo


func _piso(mundo: Node3D) -> void:
	var piso := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(8, 0.2, 8)
	forma.shape = caja
	piso.add_child(forma)
	mundo.add_child(piso)
	piso.global_position = Vector3(0, -0.1, 0)


func _grupo(mundo: Node3D, capacidad: int) -> MultiMeshInstance3D:
	var grupo: MultiMeshInstance3D = GrupoDelPiso.new()
	grupo.preparar(BoxMesh.new(), capacidad)
	mundo.add_child(grupo)
	return grupo


## Dónde dibuja el motor la malla individual, en el espacio del grupo. Es contra esto que se
## compara lo que el grupo escribe.
func _dibujo(grupo: MultiMeshInstance3D, cuerpo: RigidBody3D) -> Transform3D:
	var vista: MeshInstance3D = cuerpo.get_node("Malla")
	return grupo.global_transform.affine_inverse() * vista.get_global_transform_interpolated()


func test_mover_enfocar_y_recoger_conserva_el_dibujo_de_cada_cuerpo() -> void:  # 042-AC7
	var mundo := _mundo()
	var grupo := _grupo(mundo, 3)
	grupo.position = Vector3(4, 0, 0)
	var cuerpos: Array[RigidBody3D] = []
	for indice in 3:
		var cuerpo := _cuerpo(mundo, Vector3(indice, 2, -3), false)
		var suya: MeshInstance3D = cuerpo.get_node("Malla")
		suya.position = Vector3(0, -0.2, 0.1)
		grupo.agregar(cuerpo)
		cuerpos.append(cuerpo)
	var vista: MeshInstance3D = cuerpos[1].get_node("Malla")
	cuerpos[1].rotation = Vector3(-0.3, 0.7, 0.2)
	grupo._process(0.0)
	var esperado := _dibujo(grupo, cuerpos[1])
	assert_bool(grupo.get("_matrices")[1].is_equal_approx(esperado)).is_true()
	if DisplayServer.get_name() != "headless":
		assert_bool(grupo.multimesh.get_instance_transform(1).is_equal_approx(esperado)).is_true()
	vista.material_overlay = StandardMaterial3D.new()
	await get_tree().process_frame
	grupo._process(0.0)
	assert_bool(vista.visible).is_true()
	assert_float(grupo.get("_matrices")[1].basis.determinant()).is_zero()
	assert_bool(cuerpos[0].get_node("Malla").visible).is_false()
	vista.material_overlay = null
	await get_tree().process_frame
	grupo._process(0.0)
	assert_bool(vista.visible).is_false()
	assert_bool(grupo.get("_matrices")[1].is_equal_approx(_dibujo(grupo, cuerpos[1]))).is_true()
	grupo.quitar(cuerpos[1])
	assert_bool(vista.visible).is_true()
	assert_int(grupo.multimesh.visible_instance_count).is_equal(2)
	assert_object(grupo.cuerpos[1]).is_same(cuerpos[2])
	assert_bool(grupo.get("_matrices")[1].is_equal_approx(_dibujo(grupo, cuerpos[2]))).is_true()
	grupo.quitar(cuerpos[0])
	grupo.quitar(cuerpos[2])
	assert_int(grupo.multimesh.visible_instance_count).is_zero()
	assert_array(grupo.cuerpos).is_empty()


func test_en_caida_libre_la_copia_dibuja_donde_el_motor_dibuja_el_cuerpo() -> void:  # 045-AC1
	# El atraso viejo era de un paso entero de física. Medido antes del arreglo: 69,32 mm en el
	# cuadro del impacto, el 43 % del alto del objeto.
	var mundo := _mundo()
	_piso(mundo)
	var grupo := _grupo(mundo, 1)
	var cuerpo := _cuerpo(mundo, Vector3(0, CAIDA, 0), true)
	grupo.agregar(cuerpo)
	var peor := 0.0
	for _cuadro in 90:
		await get_tree().process_frame
		grupo._process(0.0)
		var copia: Transform3D = grupo.get("_matrices")[0]
		peor = maxf(peor, copia.origin.distance_to(_dibujo(grupo, cuerpo).origin))
	(
		assert_float(peor)
		. override_failure_message("la copia se dibuja %.2f mm del cuerpo" % (peor * 1000.0))
		. is_less(TOLERANCIA)
	)


func test_al_aterrizar_la_copia_no_salta_mas_que_el_dibujo_del_cuerpo() -> void:  # 045-AC2
	# El borde es el cuadro posterior al impacto. Antes del arreglo el cuerpo avanzaba 9,9 mm y
	# la copia saltaba los 69,3 que traía de atrás. Ese salto es el parpadeo al tocar el suelo.
	var mundo := _mundo()
	_piso(mundo)
	var grupo := _grupo(mundo, 1)
	var cuerpo := _cuerpo(mundo, Vector3(0, CAIDA, 0), true)
	grupo.agregar(cuerpo)
	var peor := 0.0
	var primera: Transform3D = grupo.get("_matrices")[0]
	var copia_antes := primera.origin
	var dibujo_antes := _dibujo(grupo, cuerpo).origin
	for _cuadro in 90:
		await get_tree().process_frame
		grupo._process(0.0)
		var actual: Transform3D = grupo.get("_matrices")[0]
		var copia := actual.origin
		var dibujo := _dibujo(grupo, cuerpo).origin
		peor = maxf(peor, copia.distance_to(copia_antes) - dibujo.distance_to(dibujo_antes))
		copia_antes = copia
		dibujo_antes = dibujo
	(
		assert_float(peor)
		. override_failure_message("la copia se movió %.2f mm más que el dibujo" % (peor * 1000.0))
		. is_less(TOLERANCIA)
	)


func test_cada_cuerpo_agrupado_se_dibuja_exactamente_una_vez() -> void:  # 045-AC3
	# Las dos fallas posibles se ven igual de mal y ninguna da error: el producto duplicado y el
	# producto que desaparece. Los cuadros que importan son aquél en que el foco entra y aquél
	# en que sale, porque ahí las dos mitades cambian a la vez.
	var mundo := _mundo()
	var grupo := _grupo(mundo, 2)
	var cuerpos: Array[RigidBody3D] = []
	for indice in 2:
		var cuerpo := _cuerpo(mundo, Vector3(indice, 0.5, 0), false)
		grupo.agregar(cuerpo)
		cuerpos.append(cuerpo)
	var enfocada: MeshInstance3D = cuerpos[0].get_node("Malla")
	for cuadro in 6:
		if cuadro == 2:
			enfocada.material_overlay = StandardMaterial3D.new()
		if cuadro == 4:
			enfocada.material_overlay = null
		await get_tree().process_frame
		for indice in 2:
			var vista: MeshInstance3D = cuerpos[indice].get_node("Malla")
			var instancia: Transform3D = grupo.get("_matrices")[indice]
			var dibuja_la_instancia := not is_zero_approx(instancia.basis.determinant())
			(
				assert_bool(vista.visible != dibuja_la_instancia)
				. override_failure_message(
					(
						"cuadro %d, cuerpo %d: malla visible %s e instancia con escala %s"
						% [cuadro, indice, vista.visible, dibuja_la_instancia]
					)
				)
				. is_true()
			)


func test_quitar_del_medio_deja_el_indice_reutilizado_en_su_cuerpo_nuevo() -> void:  # 045-AC4
	# `quitar()` mueve el último cuerpo al índice liberado. Si esa instancia no se reescribe en
	# el mismo cuadro, se dibuja viajando desde donde estaba el cuerpo anterior.
	var mundo := _mundo()
	var grupo := _grupo(mundo, 3)
	grupo.position = Vector3(4, 0, 0)
	var cuerpos: Array[RigidBody3D] = []
	for indice in 3:
		cuerpos.append(_cuerpo(mundo, Vector3(indice * 3, 0.5, -indice), false))
		grupo.agregar(cuerpos[indice])
	await get_tree().process_frame
	grupo.quitar(cuerpos[0])
	assert_object(grupo.cuerpos[0]).is_same(cuerpos[2])
	(
		assert_bool(grupo.get("_matrices")[0].is_equal_approx(_dibujo(grupo, cuerpos[2])))
		. override_failure_message("el índice reutilizado quedó en la posición del anterior")
		. is_true()
	)
	assert_bool(cuerpos[0].get_node("Malla").visible).is_true()

	# Quitar el último no reordena nada, así que no hay ninguna instancia que reescribir.
	var antes: Array = grupo.get("_matrices").duplicate()
	grupo.quitar(cuerpos[1])
	assert_object(grupo.cuerpos[0]).is_same(cuerpos[2])
	assert_bool(grupo.get("_matrices")[0].is_equal_approx(antes[0])).is_true()
	assert_int(grupo.multimesh.visible_instance_count).is_equal(1)
