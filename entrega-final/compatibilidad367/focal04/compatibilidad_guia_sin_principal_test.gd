extends GdUnitTestSuite

const HASTA_EL_PASILLO := 1.5
const PASO_HACIA_EL_PASILLO := 0.05
const HOLGURA_DEL_PISO := 0.02


## Fixture genérico: no redefine la exhibición real de Poético ni la de Duronga.
func test_guia_sin_principal_es_interactiva() -> void:  # AC-STK-033 AC-STK-028 AC-STK-044
	var almacen: Node3D = auto_free(load("res://src/escenas/almacen.tscn").instantiate())
	var puesto: Node3D = almacen.get_node("ReposicionManual")
	var original: DisposicionDeLaGondola = puesto.get("disposicion")
	var disposicion := original.duplicate(true) as DisposicionDeLaGondola
	var producto := Catalogo.de(Producto.Id.POETICO)
	assert_int(original.filas_de_adelante[producto.id]).is_greater(0)
	disposicion.principales[producto.id] = PackedFloat32Array()
	disposicion.filas_de_adelante[producto.id] = 0
	assert_int(original.filas_de_adelante[producto.id]).is_greater(0)
	puesto.set("disposicion", disposicion)
	almacen.set("_partida", Partida.desde({"jornada": 2, "medios": 0}))
	add_child(almacen)
	almacen.get("_reloj").set_process(false)
	var jugador: CharacterBody3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	for cuadro in 4:
		await get_tree().physics_frame
	var total: int = puesto.call("casilleros")[producto.id]
	assert_int(total).is_greater(0)
	assert_int(puesto.call("casilleros_reponibles")[producto.id]).is_zero()
	var estante: Estante = almacen.get("_repositor").estante()
	assert_int(estante.cupo(producto)).is_equal(total)
	assert_int(estante.unidades_en_gondola(producto)).is_equal(total)
	var frente := Vector3.BACK
	var elegido: Node3D = null
	var pie := Vector3.INF
	for indice in total:
		var zona: Node3D = puesto.call("casillero", producto.id, indice)
		var candidato := _lugar_en_el_pasillo(almacen, zona.global_position, frente)
		if candidato != Vector3.INF:
			elegido = zona
			pie = candidato
			break
	assert_object(elegido).is_not_null()
	if elegido == null:
		return
	jugador.global_position = pie + Vector3.UP * HOLGURA_DEL_PISO
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	camara.position = Vector3.UP * ReglasDelJugador.ALTURA_DE_LA_CAMARA
	camara.look_at(elegido.global_position)
	for cuadro in 4:
		await get_tree().physics_frame
	jugador.call("_leer_la_mira")
	assert_object(jugador.get("_enfocado")).is_same(elegido)
	_clic(jugador)
	var agarre: Agarre = almacen.get("_agarre")
	var unidad := agarre.manos().sostenido() as UnidadDeProducto
	assert_object(unidad).is_not_null()
	if unidad == null:
		return
	assert_int(unidad.producto.id).is_equal(producto.id)
	assert_int(estante.unidades_en_gondola(producto)).is_equal(total - 1)
	assert_array(estante.casilleros_vacios(producto)).is_equal([elegido.get("casillero")])
	for cuadro in 4:
		await get_tree().physics_frame
	jugador.call("_leer_la_mira")
	assert_object(jugador.get("_enfocado")).is_same(elegido)
	_clic(jugador)
	assert_object(agarre.manos().sostenido()).is_null()
	assert_int(estante.unidades_en_gondola(producto)).is_equal(total)
	assert_array(estante.casilleros_vacios(producto)).is_empty()
	assert_int(disposicion.filas_de_adelante[Producto.Id.DURONGA]).is_greater(0)


func _clic(jugador: Node3D) -> void:
	var clic := InputEventAction.new()
	clic.action = ReglasDeLosObjetos.ACCION_AGARRAR
	clic.pressed = true
	jugador.call("_unhandled_input", clic)
	clic.pressed = false
	jugador.call("_unhandled_input", clic)


func _lugar_en_el_pasillo(almacen: Node3D, delante: Vector3, frente: Vector3) -> Vector3:
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var cuerpo: CollisionShape3D = jugador.get_node("Cuerpo")
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = cuerpo.shape
	consulta.collision_mask = jugador.collision_mask
	consulta.exclude = [jugador.get_rid()]
	var espacio := almacen.get_world_3d().direct_space_state
	var lateral := frente.cross(Vector3.UP).normalized()
	var distancia := 0.0
	while distancia <= HASTA_EL_PASILLO:
		# Una hoja abierta ocupa el borde del pasillo; se puede apuntar desde un costado.
		for costado: float in [0.0, -0.2, 0.2, -0.4, 0.4]:
			var punto := Vector3(delante.x, 0.0, delante.z) + frente * distancia
			punto += lateral * costado
			var piso := espacio.intersect_ray(
				PhysicsRayQueryParameters3D.create(punto + Vector3.UP, punto + Vector3.DOWN, 1)
			)
			if piso.is_empty():
				continue
			var pie: Vector3 = piso["position"]
			consulta.transform = Transform3D(
				Basis.IDENTITY, pie + cuerpo.position + Vector3.UP * HOLGURA_DEL_PISO
			)
			if espacio.intersect_shape(consulta, 1).is_empty():
				var ojos := pie + Vector3.UP * ReglasDelJugador.ALTURA_DE_LA_CAMARA
				var vista := PhysicsRayQueryParameters3D.create(ojos, delante, 1)
				vista.exclude = [jugador.get_rid()]
				if espacio.intersect_ray(vista).is_empty():
					return pie
		distancia += PASO_HACIA_EL_PASILLO
	return Vector3.INF
