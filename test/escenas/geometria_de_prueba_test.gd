extends GdUnitTestSuite

const ALMACEN := "res://src/escenas/almacen.tscn"


func _abrir() -> Node3D:
	var escena := load(ALMACEN) as PackedScene
	var local: Node3D = auto_free(escena.instantiate())
	local.set("_partida", Partida.desde({"jornada": 1, "medios": 0}))
	add_child(local)
	local.get("_jugador").set_physics_process(false)
	local.get("_reloj").set_process(false)
	return local


func test_las_tandas_dibujadas_conservan_el_frente_real_de_las_mallas() -> void:  # AC-STK-096
	var local := _abrir()
	var puesto: Node3D = local.get("_reposicion_manual")
	var disposicion: DisposicionDeLaGondola = puesto.get("disposicion")
	var contenido: Node3D = puesto.get("contenido")
	for producto in Catalogo.de_la_jornada(1):
		var modelo := contenido.get_child(producto.id) as MeshInstance3D
		var frente_local: Vector3 = modelo.get_meta("frente_del_modelo")
		var frente_horneado := modelo.global_basis * frente_local
		var frente := DisposicionDeLaGondola.frente(
			disposicion.principales[producto.id], disposicion.filas_de_adelante[producto.id]
		)
		var grupo: MultiMeshInstance3D = puesto.get_node("ProductosDe" + producto.nombre)
		for indice in grupo.multimesh.instance_count:
			var copia := DisposicionDeLaGondola.copia(grupo.multimesh.buffer, indice)
			var real := (copia.basis * frente_horneado).normalized()
			assert_float(real.dot(frente)).override_failure_message(producto.nombre).is_greater(
				0.98
			)
			if real.dot(frente) <= 0.98:
				print(
					(
						"Base original %s, principal %s, buffer %s, modo %s"
						% [
							modelo.global_basis,
							DisposicionDeLaGondola.copia(disposicion.principales[producto.id], 0),
							copia,
							disposicion.base_de_guias
						]
					)
				)
				print(
					(
						"Frente %s, copia %d: real %s, esperado %s"
						% [producto.nombre, indice, real, frente]
					)
				)
				return


func test_los_productos_movidos_conservan_su_orientacion_en_la_mano() -> void:  # AC-STK-098
	var local := _abrir()
	var puesto: Node3D = local.get("_reposicion_manual")
	var agarre: Agarre = local.get("_agarre")
	for id: Producto.Id in [Producto.Id.TERMINATOR, Producto.Id.POETICO]:
		local.call("_al_abrir_la_jornada", 1)
		await get_tree().process_frame
		puesto.call("retirar", id)
		var unidad := agarre.cuerpo_sostenido()
		var orientacion: Basis = unidad.get("orientacion_en_mano")
		assert_object(agarre.manos().sostenido()).is_not_null()
		local.call("_al_abrir_la_jornada", 8)
		await get_tree().process_frame
		puesto.call("retirar", id)
		unidad = agarre.cuerpo_sostenido()
		assert_bool(orientacion.is_equal_approx(unidad.get("orientacion_en_mano"))).is_true()


func test_cada_unidad_dibujada_tiene_el_apoyo_de_la_malla_real() -> void:  # AC-STK-096
	var local := _abrir()
	var puesto: Node3D = local.get("_reposicion_manual")
	var modelos: Array = puesto.get("_modelos")
	var chapas: Array[PackedVector3Array] = []
	for nombre: String in [
		"gondolanueva", "gondolanueva2", "gondolanueva_001", "heladeranueva", "heladeranueva_001"
	]:
		var mueble: MeshInstance3D = local.get_node("Estructura/" + nombre)
		var caras := mueble.mesh.get_faces()
		for i in caras.size():
			caras[i] = mueble.to_global(caras[i])
		chapas.append(caras)
	for producto in Catalogo.de_la_jornada(1):
		var grupo: MultiMeshInstance3D = puesto.get_node("ProductosDe" + producto.nombre)
		var modelo: Mesh = modelos[producto.id]
		for indice in grupo.multimesh.instance_count:
			var copia := DisposicionDeLaGondola.copia(grupo.multimesh.buffer, indice)
			var limites := copia * modelo.get_aabb()
			var pie := limites.get_center() - Vector3.UP * limites.size.y / 2.0
			var error := _distancia_al_apoyo(chapas, pie)
			(
				assert_float(error)
				. override_failure_message("%s/%d en %s" % [producto.nombre, indice, pie])
				. is_less(0.006)
			)
			if error >= 0.006:
				return


func _distancia_al_apoyo(chapas: Array[PackedVector3Array], pie: Vector3) -> float:
	var menor := INF
	for caras in chapas:
		for i in range(0, caras.size(), 3):
			var golpe: Variant = Geometry3D.segment_intersects_triangle(
				pie + Vector3.UP * 0.03,
				pie + Vector3.DOWN * 0.03,
				caras[i],
				caras[i + 1],
				caras[i + 2]
			)
			if golpe != null:
				menor = minf(menor, absf((golpe as Vector3).y - pie.y))
	return menor
