extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const ESPERA_MS := 10000


## Las mallas que recortan por alfa, con el estado en que están ahora.
func _recortes_por_alfa(raiz: Node3D) -> Array[MeshInstance3D]:
	var mallas: Array[MeshInstance3D] = []
	for malla: MeshInstance3D in raiz.find_children("*", "MeshInstance3D", true, false):
		if malla.mesh == null:
			continue
		for superficie: int in malla.mesh.get_surface_count():
			var material := malla.get_active_material(superficie) as BaseMaterial3D
			if (
				material != null
				and material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			):
				mallas.append(malla)
				break
	return mallas


func test_el_calentamiento_dibuja_el_recorte_por_alfa_del_papel_y_lo_deja_oculto() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().process_frame
	var puesto: Node3D = almacen.get_node("Estructura/cajaregistradora")
	var ocultas: Array[MeshInstance3D] = []
	for malla: MeshInstance3D in _recortes_por_alfa(puesto):
		if not malla.visible:
			ocultas.append(malla)
	assert_array(ocultas).is_not_empty()
	var calentamiento: CalentamientoDeShaders = auto_free(CalentamientoDeShaders.new())
	add_child(calentamiento)
	var dibujadas: Array[bool] = [false]
	calentamiento.avanzo.connect(
		func(_progreso: float) -> void:
			for malla: MeshInstance3D in ocultas:
				if malla.visible:
					dibujadas[0] = true
	)
	calentamiento.calentar(puesto)
	await assert_signal(calentamiento).wait_until(ESPERA_MS).is_emitted("terminado")
	assert_bool(dibujadas[0]).is_true()
	for malla: MeshInstance3D in ocultas:
		assert_bool(malla.visible).is_false()


func test_el_calentamiento_dibuja_el_papel_con_el_contorno_de_foco_y_se_lo_saca() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().process_frame
	var puesto: Node3D = almacen.get_node("Estructura/cajaregistradora")
	var papeles: Array[MeshInstance3D] = []
	for malla: MeshInstance3D in _recortes_por_alfa(puesto):
		if not malla.visible and malla.get_parent() is RigidBody3D:
			papeles.append(malla)
	assert_array(papeles).is_not_empty()
	var calentamiento: CalentamientoDeShaders = auto_free(CalentamientoDeShaders.new())
	add_child(calentamiento)
	var con_contorno: Array[bool] = [false]
	calentamiento.avanzo.connect(
		func(_progreso: float) -> void:
			for malla: MeshInstance3D in papeles:
				if malla.visible and malla.material_overlay != null:
					con_contorno[0] = true
	)
	calentamiento.calentar(puesto)
	await assert_signal(calentamiento).wait_until(ESPERA_MS).is_emitted("terminado")
	assert_bool(con_contorno[0]).is_true()
	for malla: MeshInstance3D in papeles:
		assert_object(malla.material_overlay).is_null()
