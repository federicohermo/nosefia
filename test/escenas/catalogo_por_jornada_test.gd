extends GdUnitTestSuite

const ALMACEN := "res://src/escenas/almacen.tscn"
const Caja := preload("res://src/escenas/objetos/caja_de_productos.gd")


func _abrir(jornada: int) -> Node3D:
	var escena := load(ALMACEN) as PackedScene
	var local: Node3D = auto_free(escena.instantiate())
	local.set("_partida", Partida.desde({"jornada": jornada, "medios": 0}))
	add_child(local)
	local.get("_jugador").set_physics_process(false)
	local.get("_reloj").set_process(false)
	local.get_node("Interfaz/PersianaDeLaNoche").terminar()
	return local


func test_el_local_de_prueba_solo_dibuja_y_ofrece_sus_dieciseis_productos() -> void:  # AC-STK-095
	var local := _abrir(1)
	var puesto: Node3D = local.get("_reposicion_manual")
	for producto in Catalogo.todos():
		var grupo: MultiMeshInstance3D = puesto.get_node("ProductosDe" + producto.nombre)
		var presente := producto.id in Catalogo.PRODUCTOS_DE_PRUEBA
		assert_bool(grupo.multimesh.instance_count > 0).is_equal(presente)
		assert_bool(puesto.call("casillero", producto.id, 0) != null).is_equal(presente)
		if not presente and grupo.multimesh.instance_count > 0:
			return


func test_cambiar_de_etapa_y_repetir_apertura_renueva_cupos_sin_duplicados() -> void:  # AC-STK-098
	var local := _abrir(3)
	var puesto: Node3D = local.get("_reposicion_manual")
	var nodos_por_etapa: Dictionary[bool, int] = {}
	var conexiones: int = local.get("_jugador").uso_pedido.get_connections().size()
	for jornada: int in [4, 4, 5, 8, 1, 1, 3, 4]:
		local.call("_al_abrir_la_jornada", jornada)
		await get_tree().process_frame
		var productos := Catalogo.de_la_jornada(jornada)
		var repositor: Repositor = local.get("_repositor")
		assert_int(repositor.estante().productos_aceptados()).is_equal(productos.size())
		var completa := jornada >= ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA
		if nodos_por_etapa.has(completa):
			assert_int(puesto.get_child_count()).is_equal(nodos_por_etapa[completa])
		else:
			nodos_por_etapa[completa] = puesto.get_child_count()
		assert_int(local.get("_jugador").uso_pedido.get_connections().size()).is_equal(conexiones)
		(
			assert_int(
				puesto.find_children("ProductosDe*", "MultiMeshInstance3D", false, false).size()
			)
			. is_equal(Catalogo.todos().size())
		)
		(
			assert_int(
				puesto.find_children("SueltosDe*", "MultiMeshInstance3D", false, false).size()
			)
			. is_equal(Catalogo.todos().size())
		)
		for producto in productos:
			var zona: Node3D = puesto.call("casillero", producto.id, 0)
			assert_object(zona).is_not_null()
			assert_int(repositor.estante().cupo(producto)).is_equal(
				puesto.call("casilleros")[producto.id]
			)
			if zona == null:
				return
			var fila: Node = puesto.get_node("ZonaDe" + producto.nombre)
			assert_int(fila.get_child_count()).is_equal(repositor.estante().cupo(producto))

	for jornada: int in [1, 4]:
		local.call("_al_abrir_la_jornada", jornada)
		await get_tree().process_frame
		await _comprobar_un_solo_gesto(local)


func _comprobar_un_solo_gesto(local: Node3D) -> void:
	var puesto: Node3D = local.get("_reposicion_manual")
	var producto := Catalogo.de(Producto.Id.ARVECOR)
	var estante: Estante = local.get("_repositor").estante()
	var ocupados := estante.casilleros_ocupados(producto)
	assert_array(ocupados).is_not_empty()
	if ocupados.is_empty():
		return
	var indice: int = ocupados[0]
	for candidato: int in ocupados:
		var zona: Node3D = puesto.call("casillero", producto.id, candidato)
		var elegida: Node3D = puesto.call("casillero", producto.id, indice)
		if absf(zona.global_position.y - 1.0) < absf(elegida.global_position.y - 1.0):
			indice = candidato
	var objetivo: Node3D = puesto.call("casillero", producto.id, indice)
	var vacios := estante.casilleros_vacios(producto)
	var antes := estante.unidades_en_gondola(producto)
	await _usar_con_mira(local, objetivo)
	var esperados := vacios.duplicate()
	esperados.append(indice)
	esperados.sort()
	assert_array(estante.casilleros_vacios(producto)).contains_exactly(esperados)
	assert_int(estante.unidades_en_gondola(producto)).is_equal(antes - 1)
	await _usar_con_mira(local, objetivo)
	assert_int(estante.unidades_en_gondola(producto)).is_equal(antes)
	assert_array(estante.casilleros_vacios(producto)).contains_exactly(vacios)


func test_un_frontal_repetido_central_se_agarra_y_repone() -> void:  # AC-STK-096
	var local := _abrir(1)
	var puesto: Node3D = local.get("_reposicion_manual")
	var repositor: Repositor = local.get("_repositor")
	var producto := Catalogo.de(Producto.Id.ARVECOR)
	var zonas: Array = puesto.get("_casilleros")[producto.id]
	var niveles: Dictionary[float, int] = {}
	for zona: Node3D in zonas:
		niveles[snappedf(zona.global_position.y, 0.01)] = zona.casillero
	assert_int(niveles.size()).is_equal(4)
	if niveles.size() != 4:
		return
	var alturas := niveles.keys()
	alturas.sort()
	var indice: int = niveles[alturas[2]]
	var antes := repositor.estante().unidades_en_gondola(producto)
	assert_bool(repositor.estante().completada()).is_true()
	await _usar_con_mira(local, zonas[indice])
	assert_array(repositor.estante().casilleros_vacios(producto)).contains_exactly([indice])
	assert_int(repositor.estante().unidades_en_gondola(producto)).is_equal(antes - 1)
	assert_bool(repositor.estante().completada()).is_false()
	await _usar_con_mira(local, zonas[indice])
	assert_int(repositor.estante().unidades_en_gondola(producto)).is_equal(antes)
	assert_bool(repositor.estante().completada()).is_true()


func _usar_con_mira(local: Node3D, zona: Node3D) -> void:
	var puesto: Node3D = local.get("_reposicion_manual")
	var disposicion: DisposicionDeLaGondola = puesto.get("disposicion")
	var id: Producto.Id = zona.get("producto")
	var frente := DisposicionDeLaGondola.frente(
		disposicion.principales[id], disposicion.filas_de_adelante[id]
	)
	var jugador: CharacterBody3D = local.get("_jugador")
	var pies := _piso_libre(local, zona.global_position, frente)
	assert_bool(pies.is_finite()).is_true()
	if not pies.is_finite():
		return
	jugador.global_position = pies
	jugador.reset_physics_interpolation()
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	camara.position = Vector3.UP * ReglasDelJugador.ALTURA_DE_LA_CAMARA
	camara.look_at(zona.global_position)
	for cuadro in 4:
		await get_tree().physics_frame
	puesto.call("_ofrecer_a_la_mira")
	jugador.call("_leer_la_mira")
	assert_object(jugador.get("_enfocado")).is_same(zona)
	if jugador.get("_enfocado") != zona:
		return
	var clic := InputEventAction.new()
	clic.action = ReglasDeLosObjetos.ACCION_AGARRAR
	clic.pressed = true
	jugador.call("_unhandled_input", clic)
	clic.pressed = false
	jugador.call("_unhandled_input", clic)


func test_una_unidad_sostenida_no_sobrevive_al_cambio_de_etapa() -> void:  # AC-STK-098
	var local := _abrir(3)
	var puesto: Node3D = local.get("_reposicion_manual")
	var agarre: Agarre = local.get("_agarre")
	for siguiente: int in [3, 4, 5]:
		puesto.call("retirar", Producto.Id.ACTRONCITO)
		assert_object(agarre.manos().sostenido()).is_not_null()
		local.call("_al_abrir_la_jornada", siguiente)
		await get_tree().process_frame
		assert_object(agarre.manos().sostenido()).is_null()
		assert_array(puesto.call("unidades_sueltas")).is_empty()


func _piso_libre(local: Node3D, punto: Vector3, frente: Vector3) -> Vector3:
	var jugador: CharacterBody3D = local.get("_jugador")
	var cuerpo: CollisionShape3D = jugador.get_node("Cuerpo")
	var espacio := local.get_world_3d().direct_space_state
	for distancia: float in [0.75, 1.0, 1.25]:
		var candidato := punto + frente * distancia
		var rayo := PhysicsRayQueryParameters3D.create(
			Vector3(candidato.x, 3, candidato.z),
			Vector3(candidato.x, -1, candidato.z),
			jugador.collision_mask
		)
		rayo.exclude = [jugador.get_rid()]
		var golpe := espacio.intersect_ray(rayo)
		if golpe.get("collider") != local.get_node("Estructura/SueloSolido"):
			continue
		var pies: Vector3 = golpe.position + Vector3.UP * 0.02
		var consulta := PhysicsShapeQueryParameters3D.new()
		consulta.shape = cuerpo.shape
		consulta.transform = Transform3D(Basis.IDENTITY, pies) * cuerpo.transform
		consulta.collision_mask = jugador.collision_mask
		consulta.exclude = [jugador.get_rid()]
		consulta.margin = 0.0
		if espacio.intersect_shape(consulta, 1).is_empty():
			assert_object(golpe.collider).is_same(local.get_node("Estructura/SueloSolido"))
			assert_array(espacio.intersect_shape(consulta, 1)).is_empty()
			return pies
	return Vector3.INF


func test_las_cajas_ausentes_no_aparecen_en_fisica_y_se_restauran() -> void:  # AC-STK-097
	var local := _abrir(8)
	var cajas: Array = local.get("_cajas_de_productos")
	for cuadro in 3:
		await get_tree().physics_frame
	for caja: Caja in cajas:
		assert_bool(_volumen_encuentra(local, caja)).is_true()
	for jornada: int in [1, 2, 3, 4, 8]:
		local.call("_al_abrir_la_jornada", jornada)
		for cuadro in 3:
			await get_tree().physics_frame
		var productos := Catalogo.de_la_jornada(jornada)
		var visibles := 0
		for caja: Caja in cajas:
			var presente := productos.any(func(p: Producto) -> bool: return p.id == caja.producto)
			assert_bool(caja.visible).is_equal(presente)
			assert_bool(caja.is_in_group(ReglasDelJugador.GRUPO_INTERACTUABLE)).is_equal(presente)
			assert_bool(_volumen_encuentra(local, caja)).is_equal(presente)
			assert_bool(_rayo_encuentra(local, caja)).is_equal(presente)
			visibles += int(caja.visible)
		assert_int(visibles).is_equal(productos.size())


func _volumen_encuentra(local: Node3D, caja: Caja) -> bool:
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = caja.get_node("Cuerpo").shape
	consulta.transform = caja.get_node("Cuerpo").global_transform
	consulta.collision_mask = 1
	var golpes := local.get_world_3d().direct_space_state.intersect_shape(consulta, 32)
	return golpes.any(func(golpe: Dictionary) -> bool: return golpe.collider == caja)


func _rayo_encuentra(local: Node3D, caja: Caja) -> bool:
	var media: float = caja.get_node("Cuerpo").scale.y
	var consulta := PhysicsRayQueryParameters3D.create(
		caja.global_position + Vector3.UP * (media + 0.005), caja.global_position, 1
	)
	var excluidas: Array[RID] = []
	for otra: Caja in local.get("_cajas_de_productos"):
		if otra != caja:
			excluidas.append(otra.get_rid())
	consulta.exclude = excluidas
	return local.get_world_3d().direct_space_state.intersect_ray(consulta).get("collider") == caja
