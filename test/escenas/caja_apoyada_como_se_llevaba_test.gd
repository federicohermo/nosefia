## La caja del depósito se apoya girada como se la llevaba: sigue hacia dónde mira el jugador.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")


func _abrir() -> Node3D:
	var local: Node3D = auto_free(ALMACEN.instantiate())
	add_child(local)
	local.get_node("Interfaz/PersianaDeLaNoche").terminar()
	local.get("_jugador").set_physics_process(false)
	local.get("_reloj").set_process(false)
	for _cuadro in 4:
		await get_tree().physics_frame
	return local


## Agarra la caja, gira al jugador y la suelta mirando al piso. Devuelve el giro con que se la
## llevaba.
func _llevar_y_apoyar(local: Node3D, caja: RigidBody3D, yaw: float) -> Basis:
	var jugador: Node3D = local.get("_jugador")
	var agarre: Agarre = local.get("_agarre")
	jugador.get_node("Giro").rotation.y = yaw
	jugador.get_node("Giro/Camara").rotation = Vector3(-0.7, 0.0, 0.0)
	assert_bool(agarre.pedir_agarrar(caja.get("datos"), caja)).is_true()
	var llevada: Basis = caja.global_basis.orthonormalized()
	agarre.soltar(false)
	assert_object(agarre.manos().sostenido()).is_null()
	return llevada


func _yaw(base: Basis) -> float:
	var costado := base.orthonormalized().x
	return atan2(-costado.z, costado.x)


func test_sobre_un_mueble_la_caja_queda_derecha_y_mirando_al_jugador() -> void:
	var local := await _abrir()
	var puesto: Node = local.get("_reposicion_manual")
	var cajas: Array = local.get("_cajas_de_productos")
	var caja: RigidBody3D = cajas[0]
	var otra: RigidBody3D = cajas[1]
	var tabla: Node3D = (
		local.find_children("deposito_pallet_central_derecho_1_0", "", true, false)[0]
	)
	var limites := (tabla as MeshInstance3D).get_aabb()
	var arriba := tabla.global_transform * Vector3(limites.get_center().x, limites.end.y, 0.0)
	var del_mueble := _yaw(tabla.global_basis)
	# Torcida a propósito: sin el redondeo, quedaría en diagonal sobre la tabla.
	for torcido: float in [0.5, 1.2, -2.0]:
		caja.global_basis = Basis(Vector3.UP, del_mueble + torcido)
		var sobre_la_tabla: Basis = puesto.call("_giro_sobre", caja, tabla.get_child(0), arriba)
		assert_vector(sobre_la_tabla.y).is_equal_approx(Vector3.UP, Vector3.ONE * 0.001)
		var esperado := del_mueble + snappedf(torcido, PI / 2.0)
		assert_float(angle_difference(_yaw(sobre_la_tabla), esperado)).is_equal_approx(0.0, 0.001)
	var suelo := local.get_node("Estructura/SueloSolido")
	var en_el_piso: Basis = puesto.call("_giro_sobre", caja, suelo, Vector3.ZERO)
	assert_bool(en_el_piso.is_equal_approx(caja.global_basis)).is_true()
	otra.global_basis = Basis(Vector3.UP, 0.3)
	var apilada: Basis = puesto.call("_giro_sobre", caja, otra, otra.global_position)
	assert_bool(apilada.is_equal_approx(otra.global_basis)).is_true()


func test_la_caja_apoyada_conserva_el_giro_con_que_se_llevaba() -> void:
	var local := await _abrir()
	var caja: RigidBody3D = local.get("_cajas_de_productos")[0]
	var apoyadas: Array[Basis] = []
	for yaw: float in [0.6, 2.0]:
		var llevada := _llevar_y_apoyar(local, caja, yaw)
		var apoyada := caja.global_basis.orthonormalized()
		assert_vector(apoyada.y).is_equal_approx(Vector3.UP, Vector3.ONE * 0.001)
		var costado := Vector3(llevada.x.x, 0.0, llevada.x.z).normalized()
		assert_vector(apoyada.x).is_equal_approx(costado, Vector3.ONE * 0.001)
		apoyadas.append(apoyada)
	assert_bool(apoyadas[0].is_equal_approx(apoyadas[1])).is_false()
