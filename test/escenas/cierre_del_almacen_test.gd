## La foto real del cierre conserva cuerpos, habitaciones y orden de registro.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const CIERRE := preload("res://src/dominio/almacen/reglas_del_cierre.gd")
const Habitaciones := preload("res://src/escenas/puestos/habitaciones_del_almacen.gd")

var _almacen: Node3D


func after_test() -> void:
	if is_instance_valid(_almacen):
		for tipo: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
			for audio: Node in _almacen.find_children("*", tipo, true, false):
				audio.call("stop")
				audio.set("stream", null)
		_almacen.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_almacen = null


func _abrir() -> Node3D:
	_almacen = ALMACEN.instantiate()
	add_child(_almacen)
	var jugador: Node3D = _almacen.get("_jugador")
	jugador.set_process(false)
	jugador.set_physics_process(false)
	return _almacen


func _foto() -> Array[CIERRE.Estado]:
	return _almacen.call("_estados_del_cierre")


func _centro(partes: Array[AABB], indice: int = 0) -> Vector3:
	var lector: Habitaciones = _almacen.get("_habitaciones")
	return lector.to_global(partes[indice].get_center())


func test_el_arranque_cabe_en_sus_habitaciones_y_no_produce_motivos() -> void:  # AC-CLN-040
	_abrir()
	var lector: Habitaciones = _almacen.get("_habitaciones")
	assert_object(lector).is_not_null()
	var cajas: Array[Node3D] = _almacen.get("_cajas_de_productos")
	var utiles: Array[Node3D] = _almacen.get("_utiles_de_limpieza")
	var bolsas: Array[Node3D] = _almacen.get("_bolsas")
	for caja: Node3D in cajas:
		assert_int(lector.de(caja.global_position)).is_equal(CIERRE.Habitacion.DEPOSITO)
	for util: Node3D in utiles:
		assert_int(lector.de(util.global_position)).is_equal(CIERRE.Habitacion.BANO)
	assert_int(lector.de(_almacen.get("_jugador").global_position)).is_equal(
		CIERRE.Habitacion.LOCAL
	)
	assert_array(_foto()).has_size(cajas.size() + utiles.size() + bolsas.size())
	assert_bool(CIERRE.hay_desorden(_foto())).is_false()
	assert_bool(CIERRE.hay_objetos_afuera(_foto())).is_false()


func test_cajas_utiles_y_bolsas_siguen_su_habitacion_y_los_pasos() -> void:  # AC-CLN-042
	_abrir()
	var lector: Habitaciones = _almacen.get("_habitaciones")
	var caja: Node3D = _almacen.get("_cajas_de_productos")[0]
	var util: Node3D = _almacen.get("_utiles_de_limpieza")[0]
	var bolsa: Node3D = _almacen.get("_bolsas")[0]
	for partes: Array[AABB] in [lector.local, lector.deposito, lector.bano]:
		caja.global_position = _centro(partes)
		util.global_position = _centro(lector.bano)
		assert_bool(CIERRE.hay_desorden(_foto())).is_equal(partes != lector.deposito)
		caja.global_position = _centro(lector.deposito)
		util.global_position = _centro(partes)
		assert_bool(CIERRE.hay_desorden(_foto())).is_equal(partes != lector.bano)
	util.global_position = _centro(lector.bano, lector.bano.size() - 1)
	caja.global_position = _centro(lector.deposito, lector.deposito.size() - 1)
	bolsa.global_position = _centro(lector.local)
	assert_bool(CIERRE.hay_desorden(_foto())).is_false()


func test_dos_cajas_con_los_mismos_datos_no_comparten_la_exclusion_de_mano() -> void:  # AC-CLN-043
	_abrir()
	var lector: Habitaciones = _almacen.get("_habitaciones")
	var agarre: Agarre = _almacen.get("_agarre")
	var una: Node3D = _almacen.get("_cajas_de_productos")[0]
	var otra: Node3D = _almacen.get("_cajas_de_productos")[1]
	otra.set("datos", una.get("datos"))
	assert_object(otra.get("datos")).is_same(una.get("datos"))
	assert_bool(agarre.pedir_agarrar(una.get("datos"), una)).is_true()
	assert_object(agarre.cuerpo_sostenido()).is_same(una)
	otra.global_position = _centro(lector.local)
	assert_bool(CIERRE.hay_desorden(_foto())).is_true()
	otra.global_position = _centro(lector.local) + Vector3.UP * lector.local[0].size.y
	assert_int(lector.de(otra.global_position)).is_equal(CIERRE.Habitacion.AFUERA)
	assert_bool(CIERRE.hay_objetos_afuera(_foto())).is_true()


func test_examen_real_cuenta_el_cuerpo_y_terminar_vuelve_a_excluirlo() -> void:  # AC-CLN-043
	_abrir()
	var lector: Habitaciones = _almacen.get("_habitaciones")
	var agarre: Agarre = _almacen.get("_agarre")
	var caja: Node3D = _almacen.get("_cajas_de_productos")[0]
	var examen: Examen = _almacen.get("_jugador").examen
	assert_bool(agarre.pedir_agarrar(caja.get("datos"), caja)).is_true()
	assert_bool(CIERRE.hay_desorden(_foto())).is_false()
	assert_bool(examen.iniciar()).is_true()
	caja.global_position = _centro(lector.local)
	assert_object(agarre.cuerpo_sostenido()).is_same(caja)
	assert_bool(CIERRE.hay_desorden(_foto())).is_true()
	examen.terminar()
	assert_bool(CIERRE.hay_desorden(_foto())).is_false()


func test_bolsa_afuera_recuperada_o_tirada_sale_del_motivo() -> void:  # AC-CLN-044, AC-CLN-046
	_abrir()
	var lector: Habitaciones = _almacen.get("_habitaciones")
	var agarre: Agarre = _almacen.get("_agarre")
	var bolsa: Node3D = _almacen.get("_bolsas")[0]
	bolsa.global_position = _centro(lector.local) + Vector3.UP * lector.local[0].size.y
	assert_bool(CIERRE.hay_objetos_afuera(_foto())).is_true()
	assert_bool(agarre.pedir_agarrar(bolsa.get("datos"), bolsa)).is_true()
	assert_bool(CIERRE.hay_objetos_afuera(_foto())).is_false()
	var contenedor: Node3D = _almacen.get("_contenedor")
	assert_bool(contenedor.get("tapa").recibe_objetos()).is_true()
	contenedor.call("interactuar")
	assert_array(contenedor.call("tirados")).contains_exactly([bolsa])
	assert_bool(CIERRE.hay_objetos_afuera(_foto())).is_false()
	assert_array(_foto()).has_size(
		(
			_almacen.get("_cajas_de_productos").size()
			+ _almacen.get("_utiles_de_limpieza").size()
			+ _almacen.get("_bolsas").size()
			- 1
		)
	)
	_almacen.call("_al_abrir_la_jornada", 2)
	assert_array(contenedor.call("tirados")).is_empty()
	assert_array(_foto()).has_size(
		(
			_almacen.get("_cajas_de_productos").size()
			+ _almacen.get("_utiles_de_limpieza").size()
			+ _almacen.get("_bolsas").size()
		)
	)
	assert_bool(CIERRE.hay_objetos_afuera(_foto())).is_false()


func test_dos_motivos_entregan_seis_medios_antes_del_parte_y_guardado() -> void:  # AC-CLN-046
	_abrir()
	var lector: Habitaciones = _almacen.get("_habitaciones")
	var partida: Partida = _almacen.get("_partida")
	var reloj: RelojDelTurno = _almacen.get("_reloj")
	var caja: Node3D = _almacen.get("_cajas_de_productos")[0]
	caja.global_position = _centro(lector.local)
	_almacen.get("_reposicion_manual").call("retirar", Producto.Id.ACTRONCITO)
	var unidad: Node3D = _almacen.get("_agarre").soltar(true)
	unidad.global_position = _centro(lector.local) + Vector3.UP * lector.local[0].size.y
	assert_bool(CIERRE.hay_desorden(_foto())).is_true()
	assert_bool(CIERRE.hay_objetos_afuera(_foto())).is_true()
	var observado: Array[int] = []
	_almacen.get("_ciclo").jornada_cerrada.connect(
		func(_jornada: int, _cumplidas: int) -> void: observado.append(partida.medios())
	)
	# Sin ventas, registrar se cumple al cierre: las otras cuatro dejan la banda GRAVE.
	reloj.call("avanzar", Reglas.DURACION_DEL_TURNO / Ritmo.SEGUNDOS_DE_TURNO_POR_SEGUNDO_REAL)
	assert_int(partida.medios()).is_equal(6)
	assert_array(observado).contains_exactly([6])
	assert_int(Partida.desde(Guardado.new().cargar()).medios()).is_equal(6)


func test_un_producto_en_el_piso_muestra_el_llamado_al_terminar() -> void:  # AC-EMP-023
	_abrir()
	_almacen.get("_reposicion_manual").call("retirar", Producto.Id.ACTRONCITO)
	var unidad: Node3D = _almacen.get("_agarre").soltar(true)
	for cuadro in 120:
		await get_tree().physics_frame
	assert_bool(CIERRE.hay_desorden(_foto())).is_true()
	assert_object(unidad).is_not_null()
	var reloj: RelojDelTurno = _almacen.get("_reloj")
	reloj.call("avanzar", Reglas.DURACION_DEL_TURNO / Ritmo.SEGUNDOS_DE_TURNO_POR_SEGUNDO_REAL)
	var partida: Partida = _almacen.get("_partida")
	assert_int(partida.medios()).is_equal(5)
	var lineas: VBoxContainer = _almacen.get_node("Interfaz/PantallaDeCierre/Fondo/Panel/Lineas")
	var textos: Array[String] = []
	for etiqueta: Label in lineas.get_children():
		textos.append(etiqueta.text)
	assert_str("\n".join(textos)).contains("Local desordenado (+0,5 puntos)")


func test_las_partes_reales_respetan_techo_y_laterales_de_los_pasos() -> void:  # AC-CLN-040
	_abrir()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var lector: Habitaciones = _almacen.get("_habitaciones")
	var espacio := _almacen.get_world_3d().direct_space_state
	for partes: Array[AABB] in [lector.local, lector.deposito, lector.bano]:
		for parte: AABB in partes:
			var bajo := parte.get_center()
			bajo.y = parte.end.y - 0.005
			var sobre := bajo + Vector3.UP * 0.01
			assert_int(lector.de(lector.to_global(bajo))).is_not_equal(CIERRE.Habitacion.AFUERA)
			assert_int(lector.de(lector.to_global(sobre))).is_equal(CIERRE.Habitacion.AFUERA)
			var rayo := PhysicsRayQueryParameters3D.create(
				lector.to_global(bajo), lector.to_global(sobre + Vector3.UP * 0.2)
			)
			var techo := espacio.intersect_ray(rayo)
			assert_dict(techo).is_not_empty()
			if not techo.is_empty():
				assert_float(lector.to_local(techo.position).y).is_equal_approx(parte.end.y, 0.01)
	# La última parte del depósito y las dos últimas del baño son pasos estrechos.
	for paso: AABB in [lector.deposito[-1], lector.bano[-2], lector.bano[-1]]:
		var lateral := paso.get_center()
		lateral.z = paso.end.z + 0.01 if paso.size.x < paso.size.z else lateral.z
		lateral.x = paso.end.x + 0.01 if paso.size.x >= paso.size.z else lateral.x
		assert_bool(paso.has_point(lateral)).is_false()
		assert_int(lector.de(lector.to_global(lateral))).is_equal(CIERRE.Habitacion.AFUERA)
