extends GdUnitTestSuite

const OBJETOS := preload("res://src/escenas/puestos/objetos_del_almacen.tscn")
const MANCHA := preload("res://src/escenas/objetos/mancha_en_el_piso.tscn")
const ALMACEN := preload("res://src/escenas/almacen.tscn")
const Superficie := preload("res://src/escenas/objetos/superficie_liquida.gd")
const Gotas := preload("res://src/escenas/objetos/gotas_del_balde.gd")
const Ondas := preload("res://src/escenas/objetos/ondas_del_balde.gd")


func _agua() -> Superficie:
	var objetos: Node3D = auto_free(OBJETOS.instantiate())
	add_child(objetos)
	var balde := objetos.get_node("Balde") as RigidBody3D
	balde.freeze = true
	balde.top_level = true
	var agua := balde.get_node("Agua") as Superficie
	agua.set_physics_process(false)
	agua.presentar(true)
	_avanzar(agua, 1.0 / 60.0)
	return agua


func _alturas(agua: MeshInstance3D) -> Array[float]:
	var alturas: Array[float] = []
	var vertices: PackedVector3Array = agua.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for vertice: Vector3 in vertices:
		alturas.append(vertice.y)
	return alturas


func _cantidad_de_gotas(agua: Node) -> int:
	var lote := agua.get_child(0).get_child(0) as MultiMeshInstance3D
	return lote.multimesh.visible_instance_count if lote.visible else 0


func test_el_agua_tiene_superficie_curva_en_vez_de_un_hexagono() -> void:
	var objetos: Node3D = auto_free(OBJETOS.instantiate())
	add_child(objetos)
	var agua := objetos.get_node("Balde/Agua") as MeshInstance3D
	assert_bool(agua.mesh is ArrayMesh).is_true()
	assert_int(agua.mesh.surface_get_array_len(0)).is_greater(100)


func test_las_manchas_tienen_borde_irregular_dentro_del_cuerpo() -> void:
	var mancha: Node3D = auto_free(MANCHA.instantiate())
	add_child(mancha)
	var malla := mancha.get_node("Malla") as MeshInstance3D
	assert_bool(malla.mesh is ArrayMesh).is_true()
	var vertices: PackedVector3Array = malla.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var radios: Array[float] = []
	for indice: int in range(vertices.size() - 48, vertices.size()):
		var vertice := vertices[indice]
		radios.append(Vector2(vertice.x, vertice.z).length())
	assert_float(radios.max()).is_less_equal(0.6)
	assert_float(radios.max() - radios.min()).is_greater(0.03)


func test_acelerar_agita_el_agua_y_frenar_la_deja_asentarse() -> void:
	var agua := _agua()
	for paso: int in 12:
		agua.get_parent().position.x += 0.05
		_avanzar(agua, 1.0 / 60.0)
	var agitada := _alturas(agua)
	assert_float(agitada.max() - agitada.min()).is_greater(0.01)
	for paso: int in 360:
		_avanzar(agua, 1.0 / 60.0)
	var quieta := _alturas(agua)
	assert_float(quieta.max() - quieta.min()).is_less(0.001)


func test_un_movimiento_brusco_salpica_sin_crear_nodos_sin_limite() -> void:
	var agua := _agua()
	agua.reiniciar()
	_avanzar(agua, 1.0 / 60.0)
	for paso: int in 90:
		agua.get_parent().position.x += 0.04 if paso % 20 < 10 else -0.04
		_avanzar(agua, 1.0 / 60.0)
	assert_int(_cantidad_de_gotas(agua)).is_greater(0)
	var lote := agua.get_child(0).get_child(0) as MultiMeshInstance3D
	assert_int(lote.multimesh.instance_count).is_equal(24)
	assert_int(agua.get_child(0).get_child_count()).is_equal(1)
	var alturas := _alturas(agua)
	assert_float(alturas.min()).is_greater_equal(-0.100001)
	assert_float(alturas.max()).is_less_equal(0.105001)


func test_vaciar_y_teletransportar_no_dejan_gotas_ni_inventan_impulso() -> void:
	var agua := _agua()
	agua.reiniciar()
	_avanzar(agua, 1.0 / 60.0)
	for paso: int in 30:
		agua.get_parent().position.x += 0.04 if paso % 10 < 5 else -0.04
		_avanzar(agua, 1.0 / 60.0)
	assert_int(_cantidad_de_gotas(agua)).is_greater(0)
	agua.presentar(false)
	assert_int(_cantidad_de_gotas(agua)).is_equal(0)
	(agua.get_parent() as Node3D).rotation = Vector3.ZERO
	agua.get_parent().position.x += 20.0
	agua.presentar(true)
	_avanzar(agua, 1.0 / 60.0)
	var alturas := _alturas(agua)
	assert_float(alturas.max() - alturas.min()).is_less(0.001)
	assert_int(_cantidad_de_gotas(agua)).is_equal(0)


func test_el_agua_inclinada_compensa_la_orientacion_del_balde() -> void:
	var agua := _agua()
	(agua.get_parent() as Node3D).rotation.x = PI / 6.0
	assert_float(agua.global_basis.y.angle_to(Vector3.UP)).is_greater(0.5)
	agua.reiniciar()
	_avanzar(agua, 1.0 / 60.0)
	var vertices: PackedVector3Array = agua.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var alturas: Array[float] = []
	for vertice: Vector3 in vertices:
		alturas.append(agua.to_global(vertice).y)
	assert_float(alturas.max() - alturas.min()).is_less(0.001)
	assert_int(_cantidad_de_gotas(agua)).is_equal(0)


func test_el_charco_se_deforma_y_luego_deja_de_ondular() -> void:
	var mancha: Node3D = auto_free(MANCHA.instantiate())
	add_child(mancha)
	var superficie := mancha.get_node("Malla") as Superficie
	superficie.set_physics_process(false)
	var antes: PackedVector3Array = superficie.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	_avanzar(superficie, 0.1)
	var despues: PackedVector3Array = superficie.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_bool(antes == despues).is_false()
	for paso: int in 80:
		_avanzar(superficie, 0.1)
	var asentada: PackedVector3Array = superficie.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	_avanzar(superficie, 0.1)
	assert_bool(asentada == superficie.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]).is_true()
	superficie.tocar_en(mancha.global_position + Vector3(0.2, 0.0, 0.0))
	_avanzar(superficie, 0.1)
	assert_bool(asentada == superficie.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]).is_false()


func test_el_moho_de_la_pared_no_ondula_como_un_charco() -> void:
	var mancha: Node3D = auto_free(MANCHA.instantiate())
	mancha.rotation.x = PI / 2.0
	add_child(mancha)
	var superficie := mancha.get_node("Malla") as Superficie
	var antes: PackedVector3Array = superficie.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	superficie.perturbar()
	_avanzar(superficie, 0.1)
	assert_bool(antes == superficie.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]).is_true()


func test_las_gotas_caen_en_el_mundo_y_expiran() -> void:
	var gotas: Gotas = auto_free(Gotas.new())
	add_child(gotas)
	gotas.preparar(StandardMaterial3D.new())
	gotas.emitir(Vector3(0.0, 100.0, 0.0), Vector3.RIGHT)
	gotas.position.x += 10.0
	gotas._physics_process(0.1)
	var lote := gotas.get_child(0) as MultiMeshInstance3D
	# El servidor sin pantalla no conserva transforms de MultiMesh; la caída es física visual.
	var posiciones: PackedVector3Array = gotas.get("_posiciones")
	var gota := posiciones[0]
	assert_bool(lote.global_transform.is_equal_approx(Transform3D.IDENTITY)).is_true()
	assert_float(gota.x).is_between(0.05, 0.15)
	assert_float(gota.y).is_less(100.0)
	gotas._physics_process(1.0)
	assert_bool(lote.visible).is_false()
	assert_bool(gotas.is_physics_processing()).is_false()


func test_las_gotas_se_extinguen_al_tocar_un_solido() -> void:
	var suelo: StaticBody3D = auto_free(StaticBody3D.new())
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(2.0, 0.1, 2.0)
	forma.shape = caja
	suelo.add_child(forma)
	suelo.position.y = 99.5
	add_child(suelo)
	var gotas: Gotas = auto_free(Gotas.new())
	add_child(gotas)
	gotas.preparar(StandardMaterial3D.new())
	await get_tree().physics_frame
	var rayo := PhysicsRayQueryParameters3D.create(Vector3(0, 100, 0), Vector3(0, 99, 0), 9)
	assert_bool(gotas.get_world_3d().direct_space_state.intersect_ray(rayo).is_empty()).is_false()
	gotas.emitir(Vector3(0.0, 100.0, 0.0), Vector3.DOWN)
	gotas._physics_process(0.3)
	assert_bool((gotas.get_child(0) as MultiMeshInstance3D).visible).is_false()


func test_un_paso_sobre_el_charco_lo_agita_sin_cambiar_la_limpieza() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var jugador: CharacterBody3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	var limpieza: Node3D = almacen.get("_limpieza")
	var mancha: Node3D = limpieza.call("manchas")[0]
	var superficie := mancha.get_node("Malla") as Superficie
	superficie.set_physics_process(false)
	for paso: int in 80:
		_avanzar(superficie, 0.1)
	var antes: PackedVector3Array = superficie.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	jugador.global_position = mancha.global_position + Vector3.UP
	jugador.emit_signal("paso_dado")
	_avanzar(superficie, 0.1)
	assert_bool(antes == superficie.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]).is_false()
	var piso: PisoDelLocal = (almacen.get("_limpiador") as Limpiador).piso()
	assert_bool(piso.mancha_de(PisoDelLocal.Lugar.ENTRADA).esta_limpia()).is_false()
	assert_bool(piso.balde().tiene_agua()).is_false()


func test_el_agua_no_atraviesa_ninguna_de_las_seis_paredes() -> void:
	var agua := _agua()
	for paso: int in 60:
		agua.get_parent().position.x += 0.04 if paso % 10 < 5 else -0.04
		_avanzar(agua, 1.0 / 60.0)
	var vertices: PackedVector3Array = agua.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for vertice: Vector3 in vertices:
		for pared: int in 12:
			var normal := Vector2(cos(pared * PI / 6.0), sin(pared * PI / 6.0))
			assert_float(normal.dot(Vector2(vertice.x, vertice.z))).is_less(0.17194)


func test_las_ondas_se_propagan_y_no_son_un_solo_plano_inclinado() -> void:
	var ondas := Ondas.new()
	ondas.avanzar(0.1, Vector2(20.0, 0.0))
	for paso: int in 20:
		ondas.avanzar(1.0 / 60.0, Vector2.ZERO)
	var centro := ondas.altura_en(Vector2.ZERO)
	var cerca := ondas.altura_en(Vector2(0.3, 0.0))
	var lejos := ondas.altura_en(Vector2(0.6, 0.0))
	assert_float(absf(cerca - (centro + lejos) * 0.5)).is_greater(0.0005)
	for paso: int in 360:
		ondas.avanzar(1.0 / 60.0, Vector2.ZERO)
	assert_float(absf(ondas.altura_en(Vector2(0.3, 0.0)))).is_less(0.0001)


func test_el_balde_no_inventa_anillos_sin_ondas_del_movimiento() -> void:
	var agua := _agua()
	# Un residual visual no debe agregar ondas ajenas al movimiento del recipiente.
	agua.set("_onda", 1.0)
	agua.set("_tiempo", 0.3)
	agua.call("_dibujar")
	var alturas := _alturas(agua)
	assert_float(alturas.max() - alturas.min()).is_less(0.0001)


func test_la_mopa_encoge_el_charco_antes_de_ocultarlo() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	var limpiador: Limpiador = almacen.get("_limpiador")
	var limpieza: Node3D = almacen.get("_limpieza")
	var mancha: Node3D = limpieza.call("manchas")[0]
	var superficie := mancha.get_node("Malla") as Superficie
	var centro := superficie.global_position
	limpiador.usar(ReglasDeLaLimpieza.ID_DEL_BALDE, ReglasDeLaLimpieza.ID_DEL_LAVATORIO)
	limpiador.usar(ReglasDeLaLimpieza.ID_DE_LA_MOPA, ReglasDeLaLimpieza.ID_DEL_BALDE)
	limpiador.pasar(ReglasDeLaLimpieza.ID_DE_LA_MOPA, PisoDelLocal.Lugar.ENTRADA)
	assert_bool(superficie.esta_encogiendo()).is_false()
	limpiador.usar(&"jabon_amarillo", ReglasDeLaLimpieza.ID_DEL_BALDE)
	limpiador.usar(ReglasDeLaLimpieza.ID_DE_LA_MOPA, ReglasDeLaLimpieza.ID_DEL_BALDE)
	var resultado := limpiador.pasar(ReglasDeLaLimpieza.ID_DE_LA_MOPA, PisoDelLocal.Lugar.ENTRADA)
	assert_int(resultado).is_equal(ReglasDeLaLimpieza.Resultado.MANCHA_BORRADA)
	assert_bool(mancha.is_visible_in_tree()).is_true()
	assert_bool((mancha.get_node("Cuerpo") as CollisionShape3D).disabled).is_true()
	await get_tree().create_timer(0.15).timeout
	assert_float(superficie.scale.x / superficie.escala_de_reposo.x).is_between(0.05, 0.95)
	assert_float(superficie.global_position.distance_to(centro)).is_less(0.001)
	limpieza.call("repintar")
	assert_bool(mancha.is_visible_in_tree()).is_true()
	await get_tree().create_timer(0.45).timeout
	assert_bool(mancha.is_visible_in_tree()).is_false()
	assert_bool(limpiador.piso().mancha_de(PisoDelLocal.Lugar.ENTRADA).esta_limpia()).is_true()


func test_reaparecer_una_mancha_cancela_el_encogimiento_anterior() -> void:
	var mancha: Node3D = auto_free(MANCHA.instantiate())
	add_child(mancha)
	mancha.call("mostrar", false, Color.BLUE)
	mancha.call("encoger")
	await get_tree().create_timer(0.15).timeout
	var superficie := mancha.get_node("Malla") as Superficie
	assert_float(superficie.scale.x).is_less(0.95)
	mancha.call("mostrar", true, Color.BLUE)
	await get_tree().create_timer(0.5).timeout
	assert_bool(mancha.is_visible_in_tree()).is_true()
	assert_bool(superficie.scale.is_equal_approx(Vector3.ONE)).is_true()
	assert_bool((mancha.get_node("Cuerpo") as CollisionShape3D).disabled).is_false()


func test_la_pared_no_fija_la_altura_del_agua_a_cero() -> void:
	var ondas := Ondas.new()
	ondas.perturbar(Vector2(0.9, 0.0), 0.5)
	ondas.avanzar(1.0 / 60.0, Vector2.ZERO)
	var junto := ondas.altura_en(Vector2(11.0 / 12.0, 0.0))
	assert_float(absf(junto)).is_greater(0.0001)
	assert_float(ondas.altura_en(Vector2(0.97, 0.0))).is_equal_approx(junto, 0.00001)


func _avanzar(superficie: Superficie, delta: float) -> void:
	superficie._physics_process(delta)
	superficie._process(delta)


func test_recuperar_la_fisica_no_reconstruye_la_malla_hasta_dibujar() -> void:
	var agua := _agua()
	var antes: PackedVector3Array = agua.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for paso: int in 8:
		agua.get_parent().position.x += 0.04
		agua._physics_process(1.0 / 60.0)
	assert_bool(antes == agua.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]).is_true()
	agua._process(1.0 / 60.0)
	assert_bool(antes == agua.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]).is_false()
	var normales: PackedVector3Array = agua.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	for normal: Vector3 in normales:
		assert_float(normal.length()).is_equal_approx(1.0, 0.0001)
		assert_float(normal.y).is_greater(0.0)


func test_el_muestreo_preparado_conserva_las_ondas_del_centro_y_de_la_pared() -> void:
	var ondas := Ondas.new()
	var puntos := PackedVector2Array(
		[Vector2.ZERO, Vector2(0.31, -0.24), Vector2(0.97, 0.0), Vector2(-0.9, 0.3)]
	)
	ondas.preparar_muestras(puntos)
	ondas.perturbar(Vector2(0.8, 0.0), 0.5)
	for paso: int in 20:
		ondas.avanzar(1.0 / 60.0, Vector2(5.0, -2.0))
		var alturas := ondas.alturas_muestreadas()
		for indice: int in puntos.size():
			assert_float(alturas[indice]).is_equal_approx(ondas.altura_en(puntos[indice]), 0.000001)
