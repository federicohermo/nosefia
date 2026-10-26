## El lector conserva las unidades físicas agrupadas y el examen de la que está en mano.
extends GdUnitTestSuite

const TinYTia := preload("res://test/escenas/tin_y_tia.gd")
const ALMACEN := preload("res://src/escenas/almacen.tscn")
const AperturaConLugar := preload("res://test/escenas/apertura_con_lugar.gd")
const CIERRE := preload("res://src/dominio/almacen/reglas_del_cierre.gd")
const Habitaciones := preload("res://src/escenas/puestos/habitaciones_del_almacen.gd")
const RelojDePrueba := preload("res://test/reloj_de_prueba.gd")
var _almacen: Node3D


func after_test() -> void:
	get_tree().paused = false
	if is_instance_valid(_almacen):
		for tipo: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
			for audio: Node in _almacen.find_children("*", tipo, true, false):
				audio.call("stop")
				audio.set("stream", null)
		_almacen.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_almacen = null


func _abrir(con_lugar: bool = true) -> void:
	_almacen = ALMACEN.instantiate()
	_almacen.set("_partida", Partida.desde({"jornada": ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA}))
	_almacen.set("compradores_de_la_apertura", TinYTia.en_cualquier_jornada)
	add_child(_almacen)
	AperturaConLugar.abrir_con_semilla(_almacen)
	if con_lugar:
		AperturaConLugar.abrir_con_todo_el_lugar(_almacen)
	_almacen.get("_jugador").set_process(false)
	_almacen.get("_jugador").set_physics_process(false)


func _unidad() -> ObjetoAgarrable:
	_almacen.get("_reposicion_manual").call("retirar", Producto.Id.ACTRONCITO)
	return _almacen.get("_agarre").cuerpo_sostenido()


func _desorden() -> bool:
	return CIERRE.hay_desorden(
		_almacen.call("_estados_del_cierre"), _almacen.get("_partida").jornada()
	)


func test_suelta_en_cada_habitacion_cuenta_aunque_el_grupo_oculte_su_malla() -> void:  # AC-CLN-041
	_abrir()
	var lector: Habitaciones = _almacen.get("_habitaciones")
	var unidad := _unidad()
	_almacen.get("_agarre").soltar(true)
	assert_bool(unidad.get_node("Malla").visible).is_false()
	for partes: Array[AABB] in [lector.local, lector.deposito, lector.bano]:
		unidad.global_position = lector.to_global(partes[0].get_center())
		assert_bool(_desorden()).is_true()
	var copia: Array[Node3D] = _almacen.get("_reposicion_manual").call("unidades_sueltas")
	assert_array(copia).contains_exactly([unidad])
	copia.clear()
	assert_array(_almacen.get("_reposicion_manual").call("unidades_sueltas")).has_size(1)


func test_devolver_o_colocar_retira_suelta_y_no_cuenta_el_repuesto() -> void:  # AC-CLN-041
	_abrir()
	var agarre: Agarre = _almacen.get("_agarre")
	var puesto: Node3D = _almacen.get("_reposicion_manual")
	var unidad := _unidad()
	agarre.soltar(true)
	assert_bool(_desorden()).is_true()
	agarre.pedir_agarrar(unidad.datos, unidad)
	puesto.call("devolver", Producto.Id.ACTRONCITO)
	assert_bool(_desorden()).is_false()
	assert_array(puesto.call("unidades_sueltas")).is_empty()
	unidad = _unidad()
	puesto.call("pedir_colocar", Producto.Id.ACTRONCITO)
	assert_object(agarre.cuerpo_sostenido()).is_null()
	assert_bool(_desorden()).is_false()
	assert_array(puesto.call("unidades_sueltas")).is_empty()


func test_apoyada_sobre_una_caja_del_deposito_sigue_siendo_suelta() -> void:  # AC-CLN-041
	_abrir()
	var lector: Habitaciones = _almacen.get("_habitaciones")
	var caja: RigidBody3D = _almacen.get("_cajas_de_productos")[0]
	var forma_de_caja: CollisionShape3D = caja.get_node("Cuerpo")
	var caja_local := forma_de_caja.transform * forma_de_caja.shape.get_debug_mesh().get_aabb()
	caja.global_basis = Basis.IDENTITY
	caja.global_position = lector.to_global(lector.deposito[0].get_center())
	caja.global_position.y = lector.to_global(lector.deposito[0].position).y - caja_local.position.y
	assert_bool(caja.freeze).is_true()
	var unidad := _unidad()
	_almacen.get("_agarre").soltar(true)
	unidad.global_basis = Basis.IDENTITY
	var forma: CollisionShape3D = unidad.get_node("Forma")
	var unidad_local := forma.transform * forma.shape.get_debug_mesh().get_aabb()
	unidad.global_position = caja.global_position
	unidad.global_position.y += caja_local.end.y - unidad_local.position.y + 0.1
	for cuadro in 120:
		await get_tree().physics_frame
	assert_int(lector.de(unidad.global_position)).is_equal(CIERRE.Habitacion.DEPOSITO)
	assert_float(unidad.global_position.y + unidad_local.position.y).is_equal_approx(
		caja.global_position.y + caja_local.end.y, 0.03
	)
	assert_array(_almacen.get("_reposicion_manual").call("unidades_sueltas")).contains_exactly(
		[unidad]
	)
	assert_bool(_desorden()).is_true()


func test_la_unidad_en_examen_vuelve_a_la_foto_sin_reingresar_al_grupo() -> void:  # AC-CLN-043
	_abrir()
	var unidad := _unidad()
	var examen: Examen = _almacen.get("_jugador").examen
	assert_array(_almacen.get("_reposicion_manual").call("unidades_sueltas")).is_empty()
	assert_bool(_desorden()).is_false()
	assert_bool(examen.iniciar()).is_true()
	assert_bool(_desorden()).is_true()
	assert_array(_almacen.get("_reposicion_manual").call("unidades_sueltas")).is_empty()
	assert_object(_almacen.get("_agarre").cuerpo_sostenido()).is_same(unidad)
	examen.terminar()
	assert_bool(_desorden()).is_false()


func test_recuperar_la_unidad_de_afuera_y_soltar_adentro_cambia_el_motivo() -> void:  # AC-CLN-044
	_abrir()
	var lector: Habitaciones = _almacen.get("_habitaciones")
	var agarre: Agarre = _almacen.get("_agarre")
	var unidad := _unidad()
	agarre.soltar(true)
	unidad.global_position = lector.to_global(
		lector.local[0].get_center() + Vector3.UP * lector.local[0].size.y
	)
	assert_bool(CIERRE.hay_objetos_afuera(_almacen.call("_estados_del_cierre"))).is_true()
	agarre.pedir_agarrar(unidad.datos, unidad)
	assert_bool(CIERRE.hay_objetos_afuera(_almacen.call("_estados_del_cierre"))).is_false()
	agarre.soltar(true)
	unidad.global_position = lector.to_global(lector.local[0].get_center())
	assert_bool(CIERRE.hay_objetos_afuera(_almacen.call("_estados_del_cierre"))).is_false()
	assert_bool(_desorden()).is_true()


func _pulsar_comprador() -> void:
	var evento := InputEventMouseButton.new()
	evento.pressed = true
	evento.button_index = MOUSE_BUTTON_LEFT
	var puesto: Node3D = _almacen.get_node("Estructura/Ventanilla")
	if puesto.get("_abierta"):
		puesto.call("_input", evento)
	else:
		puesto.get_node("Comprador/Objetivo").call("accionar")


func _entregar_a_tin(
	todas: bool = true, desde_gondola: bool = false, solapados: bool = false
) -> Array[ObjetoAgarrable]:
	# La recepción y las unidades retiradas deben pertenecer al mismo inventario.
	_abrir(false)
	var reloj: RelojDelTurno = _almacen.get("_reloj")
	reloj.set_process(false)
	for _cuadro in 3:
		await get_tree().physics_frame
	var ventana: Node3D = _almacen.get_node("Estructura/Ventanilla")
	var jugador: CharacterBody3D = _almacen.get("_jugador")
	var forma_jugador: CollisionShape3D = jugador.get_node("Cuerpo")
	var capsula := forma_jugador.shape as CapsuleShape3D
	var antepecho: MeshInstance3D = ventana.get("antepecho")
	var lugar := (
		ventana.global_position
		- ventana.global_basis.z * (capsula.radius + antepecho.get_aabb().size.z / 2.0 + 0.1)
	)
	var suelo: StaticBody3D = _almacen.get("_reposicion_manual").get("suelo")
	var consulta := PhysicsRayQueryParameters3D.create(
		lugar + Vector3.UP, lugar + Vector3.DOWN * 2.0, 1 | ReglasDeLosObjetos.CAPA_DEL_CONTORNO
	)
	consulta.exclude = [jugador.get_rid()]
	var piso := jugador.get_world_3d().direct_space_state.intersect_ray(consulta)
	assert_object(piso.get("collider")).is_same(suelo)
	if piso.is_empty():
		return []
	lugar.y = (piso["position"] as Vector3).y
	jugador.global_position = lugar
	for _cuadro in 3:
		await get_tree().physics_frame
	var prueba := PhysicsShapeQueryParameters3D.new()
	prueba.shape = capsula
	prueba.transform = forma_jugador.global_transform
	var contactos := jugador.get_world_3d().direct_space_state.intersect_shape(prueba)
	var encuentra_jugador := false
	for contacto: Dictionary in contactos:
		encuentra_jugador = encuentra_jugador or contacto["collider"] == jugador
	assert_bool(encuentra_jugador).is_true()
	# El testigo sólido es una jamba real; el centro del hueco ya no contiene vidrio.
	var jamba := (
		ventana.global_transform * Vector3(antepecho.get_aabb().end.x + capsula.radius, 0.5, 0.0)
	)
	var pared := PhysicsRayQueryParameters3D.create(
		jamba - ventana.global_basis.z, jamba + ventana.global_basis.z, 1
	)
	(
		assert_object(
			jugador.get_world_3d().direct_space_state.intersect_ray(pared).get("collider")
		)
		. is_not_null()
	)
	assert_bool(_desorden()).is_false()
	var atenciones: Ventanilla = _almacen.get("_atenciones")
	if solapados:
		var compradores := Compradores.de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA)
		compradores[1].horario = Vector2(7200, 14400)
		var inventario: Inventario = (_almacen.get("_repositor") as Repositor).estante().get(
			"_inventario"
		)
		var tarea := TareaDeAtender.new(compradores, inventario)
		atenciones.arrancar(tarea)
		(_almacen.get("_computadora") as ComputadoraDeEscritorio).arrancar(
			RegistroDeVentas.new(Catalogo.todos(), tarea)
		)
	RelojDePrueba.avanzar_hasta(reloj, Vector2i(20, 30))
	ventana.call("abrir")
	_pulsar_comprador()
	while not atenciones.puede_abandonar():
		_pulsar_comprador()
	var manual: Node3D = _almacen.get("_reposicion_manual")
	var agarre: Agarre = _almacen.get("_agarre")
	var cuerpos: Array[ObjetoAgarrable] = []
	for producto in atenciones.atencion().comprador().pedido().productos():
		if desde_gondola:
			var estante: Estante = (_almacen.get("_repositor") as Repositor).estante()
			var ocupados := estante.casilleros_ocupados(producto)
			assert_array(ocupados).is_not_empty()
			manual.call("agarrar_de_la_gondola", producto.id, ocupados[0])
		else:
			manual.call("retirar", producto.id)
		var cuerpo := agarre.cuerpo_sostenido() as ObjetoAgarrable
		assert_object(cuerpo).is_not_null()
		cuerpos.append(cuerpo)
		_pulsar_comprador()
		assert_object(agarre.cuerpo_sostenido()).is_null()
		assert_bool(cuerpo.visible).is_false()
		if not todas:
			break
	return cuerpos


func _abandonar_tin(todas: bool = true, desde_gondola: bool = false) -> Array[ObjetoAgarrable]:
	var cuerpos := await _entregar_a_tin(todas, desde_gondola)
	RelojDePrueba.avanzar_hasta(_almacen.get("_reloj"), Vector2i(23, 0))
	for _cuadro in 60:
		await get_tree().physics_frame
	for cuerpo in cuerpos:
		assert_bool(is_instance_valid(cuerpo)).is_true()
	return cuerpos


func _afirmar_cierre_abandonadas(desorden: bool) -> void:
	assert_bool(_desorden()).is_equal(desorden)
	assert_bool(CIERRE.hay_objetos_afuera(_almacen.call("_estados_del_cierre"))).is_false()
	RelojDePrueba.avanzar_turno(_almacen.get("_reloj"), Reglas.DURACION_DEL_TURNO)
	var partida: Partida = _almacen.get("_partida")
	var esperados: Array[Partida.Llamado] = []
	if desorden:
		esperados.append(Partida.Llamado.LOCAL_DESORDENADO)
	assert_array(partida.llamados()).contains_exactly(esperados)


func _colocar_abandonada(cuerpo: ObjetoAgarrable) -> void:
	var manual: Node3D = _almacen.get("_reposicion_manual")
	var agarre: Agarre = _almacen.get("_agarre")
	var estante: Estante = (_almacen.get("_repositor") as Repositor).estante()
	var unidad := cuerpo.datos as UnidadDeProducto
	var producto := unidad.producto
	if estante.casilleros_vacios(producto).is_empty():
		manual.call("agarrar_de_la_gondola", producto.id, estante.casilleros_ocupados(producto)[0])
		manual.call("devolver", producto.id)
	assert_bool(agarre.pedir_agarrar(unidad, cuerpo)).is_true()
	assert_object(agarre.manos().sostenido()).is_same(unidad)
	manual.call("pedir_colocar", producto.id)
	assert_object(agarre.manos().sostenido()).is_null()


func test_tres_abandonadas_quedan_adentro_sin_solidos_y_pausan_la_caida() -> void:  # AC-CTR-046
	var cuerpos := await _entregar_a_tin()
	assert_array(cuerpos).has_size(3)
	var identidades: Array[ObjetoDelAlmacen] = []
	for cuerpo in cuerpos:
		identidades.append(cuerpo.datos)
	RelojDePrueba.avanzar_hasta(_almacen.get("_reloj"), Vector2i(23, 0))
	var sueltas: Array[Node3D] = _almacen.get("_reposicion_manual").call("unidades_sueltas")
	assert_array(sueltas).contains_exactly_in_any_order(cuerpos)
	var posiciones: Array[Vector3] = []
	for cuerpo in cuerpos:
		assert_bool(is_instance_valid(cuerpo)).is_true()
		if not is_instance_valid(cuerpo):
			return
		posiciones.append(cuerpo.global_position)
	get_tree().paused = true
	await get_tree().create_timer(0.1, true).timeout
	for indice in cuerpos.size():
		assert_that(cuerpos[indice].global_position).is_equal(posiciones[indice])
	get_tree().paused = false
	for _cuadro in 90:
		await get_tree().physics_frame
	var lector: Habitaciones = _almacen.get("_habitaciones")
	var manual: Node3D = _almacen.get("_reposicion_manual")
	var suelo: StaticBody3D = manual.get("suelo")
	var espacio := manual.get_world_3d().direct_space_state
	for indice in cuerpos.size():
		var cuerpo := cuerpos[indice]
		assert_object(cuerpo.datos).is_same(identidades[indice])
		assert_bool(cuerpo.visible).is_true()
		assert_bool(cuerpo.freeze).is_false()
		assert_int(cuerpo.collision_layer).is_not_equal(0)
		assert_bool(cuerpo.has_meta(&"recibido_por_comprador")).is_false()
		assert_int(lector.de(cuerpo.global_position)).is_equal(CIERRE.Habitacion.LOCAL)
		var forma: CollisionShape3D = cuerpo.get_node("Forma")
		var consulta := PhysicsShapeQueryParameters3D.new()
		consulta.shape = forma.shape
		consulta.transform = forma.global_transform
		consulta.collision_mask = cuerpo.collision_mask
		consulta.margin = 0.0
		consulta.exclude = [cuerpo.get_rid(), suelo.get_rid()]
		assert_array(espacio.intersect_shape(consulta)).is_empty()
		var rayo := PhysicsRayQueryParameters3D.create(
			cuerpo.global_position,
			cuerpo.global_position + Vector3.DOWN * 2.0,
			cuerpo.collision_mask
		)
		var excluidos: Array[RID] = []
		for otro in cuerpos:
			excluidos.append(otro.get_rid())
		rayo.exclude = excluidos
		var apoyo := espacio.intersect_ray(rayo)
		assert_object(apoyo.get("collider")).is_same(suelo)
		var limite := forma.global_transform * forma.shape.get_debug_mesh().get_aabb()
		assert_float(limite.position.y).is_equal_approx((apoyo["position"] as Vector3).y, 0.03)
		assert_float(cuerpo.global_position.y).is_less(posiciones[indice].y)
		var grupo: MultiMeshInstance3D = (manual.get("_sueltos") as Array)[
			(cuerpo.datos as UnidadDeProducto).producto.id
		]
		assert_array(grupo.get("cuerpos")).contains(cuerpo)
		assert_int(grupo.multimesh.visible_instance_count).is_greater(0)
	var antes: Array[Vector3] = []
	for cuerpo in cuerpos:
		antes.append(cuerpo.global_position)
	RelojDePrueba.avanzar_turno(_almacen.get("_reloj"), 0.0)
	assert_array(manual.call("unidades_sueltas")).contains_exactly_in_any_order(cuerpos)
	for indice in cuerpos.size():
		assert_that(cuerpos[indice].global_position).is_equal(antes[indice])


func test_abandonadas_en_piso_dan_un_desorden_sin_objeto_afuera() -> void:  # AC-CTR-046
	var cuerpos := await _abandonar_tin()
	assert_array(cuerpos).has_size(3)
	_afirmar_cierre_abandonadas(true)


func test_colocar_las_tres_abandonadas_no_deja_desorden() -> void:  # AC-CTR-046
	var cuerpos := await _abandonar_tin()
	for cuerpo in cuerpos:
		_colocar_abandonada(cuerpo)
	assert_array(_almacen.get("_reposicion_manual").call("unidades_sueltas")).is_empty()
	_afirmar_cierre_abandonadas(false)


func test_devolver_abandonadas_conserva_su_identidad() -> void:  # AC-CTR-046
	var cuerpos := await _abandonar_tin()
	var agarre: Agarre = _almacen.get("_agarre")
	for cuerpo in cuerpos:
		var unidad := cuerpo.datos as UnidadDeProducto
		var caja: ContenidoDeLaCaja = (_almacen.get("_repositor") as Repositor).caja(
			unidad.producto.id
		)
		var antes := caja.unidades()
		assert_bool(agarre.pedir_agarrar(unidad, cuerpo)).is_true()
		assert_object(agarre.manos().sostenido()).is_same(unidad)
		_almacen.get("_reposicion_manual").call("devolver", unidad.producto.id)
		assert_object(agarre.manos().sostenido()).is_null()
		assert_int(caja.unidades()).is_equal(antes + 1)
	assert_array(_almacen.get("_reposicion_manual").call("unidades_sueltas")).is_empty()
	_afirmar_cierre_abandonadas(false)


func test_colocar_dos_y_sostener_una_no_deja_desorden() -> void:  # AC-CTR-046
	var cuerpos := await _abandonar_tin()
	_colocar_abandonada(cuerpos[0])
	_colocar_abandonada(cuerpos[1])
	var agarre: Agarre = _almacen.get("_agarre")
	var unidad := cuerpos[2].datos
	assert_bool(agarre.pedir_agarrar(unidad, cuerpos[2])).is_true()
	assert_object(agarre.manos().sostenido()).is_same(unidad)
	assert_bool(_almacen.get("_jugador").examen.esta_examinando()).is_false()
	_afirmar_cierre_abandonadas(false)


func test_abandonada_de_gondola_rechaza_caja_llena_y_se_coloca() -> void:  # AC-CTR-046, AC-STK-055
	var cuerpos := await _abandonar_tin(false, true)
	var cuerpo := cuerpos[0]
	var unidad := cuerpo.datos as UnidadDeProducto
	var agarre: Agarre = _almacen.get("_agarre")
	var repositor: Repositor = _almacen.get("_repositor")
	var caja := repositor.caja(unidad.producto.id)
	var antes := caja.unidades()
	assert_int(antes).is_equal(ReglasDelEstante.UNIDADES_POR_CAJA)
	assert_bool(agarre.pedir_agarrar(unidad, cuerpo)).is_true()
	_almacen.get("_reposicion_manual").call("devolver", unidad.producto.id)
	assert_object(agarre.manos().sostenido()).is_same(unidad)
	assert_object(agarre.cuerpo_sostenido()).is_same(cuerpo)
	assert_int(caja.unidades()).is_equal(antes)
	_almacen.get("_reposicion_manual").call("pedir_colocar", unidad.producto.id)
	assert_object(agarre.manos().sostenido()).is_null()
	assert_array(_almacen.get("_reposicion_manual").call("unidades_sueltas")).is_empty()
	_afirmar_cierre_abandonadas(false)


func test_tirar_la_abandonada_descuenta_y_conserva_el_motivo_importante() -> void:  # AC-CTR-046
	var cuerpos := await _abandonar_tin(false)
	var cuerpo := cuerpos[0]
	var unidad := cuerpo.datos as UnidadDeProducto
	var agarre: Agarre = _almacen.get("_agarre")
	var repositor: Repositor = _almacen.get("_repositor")
	var deposito := repositor.estante().unidades_en_deposito(unidad.producto)
	var caja := repositor.caja(unidad.producto.id).unidades()
	assert_bool(agarre.pedir_agarrar(unidad, cuerpo)).is_true()
	var recolector: RecolectorDeBasura = _almacen.get("_recolector")
	assert_int(recolector.pedir_tirar(true)).is_equal(ReglasDeLaBasura.Tiro.TIRADO)
	assert_object(agarre.manos().sostenido()).is_null()
	assert_int(repositor.estante().unidades_en_deposito(unidad.producto)).is_equal(deposito - 1)
	assert_int(repositor.caja(unidad.producto.id).unidades()).is_equal(caja)
	assert_array(_almacen.get("_contenedor").tirados()).contains(cuerpo)
	var partida: Partida = _almacen.get("_partida")
	assert_array(partida.llamados()).contains_exactly([Partida.Llamado.OBJETO_TIRADO])


func test_otra_jornada_retira_todas_las_abandonadas() -> void:  # AC-CTR-046
	var cuerpos := await _abandonar_tin()
	_almacen.call("_al_abrir_la_jornada", ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1)
	for _cuadro in 4:
		await get_tree().process_frame
	assert_array(_almacen.get("_reposicion_manual").call("unidades_sueltas")).is_empty()
	for cuerpo in cuerpos:
		assert_bool(is_instance_valid(cuerpo)).is_false()


func test_cero_y_solo_ticket_no_dejan_unidades() -> void:  # AC-CTR-040, AC-STK-056
	_abrir()
	var reloj: RelojDelTurno = _almacen.get("_reloj")
	reloj.set_process(false)
	var ventana: Node3D = _almacen.get_node("Estructura/Ventanilla")
	var atenciones: Ventanilla = _almacen.get("_atenciones")
	var agarre: Agarre = _almacen.get("_agarre")
	RelojDePrueba.avanzar_hasta(reloj, Vector2i(23, 0))
	assert_array(_almacen.get("_reposicion_manual").call("unidades_sueltas")).is_empty()
	RelojDePrueba.avanzar_hasta(reloj, Vector2i(23, 30))
	ventana.call("abrir")
	_pulsar_comprador()
	_pulsar_comprador()
	var caja: CajaRegistradora = _almacen.get("_caja")
	caja.pedir_borrar()
	for producto in atenciones.atencion().comprador().pedido().productos():
		caja.pedir_anotar(UnidadDeProducto.new(producto))
	caja.pedir_imprimir()
	var destino: Node3D = _almacen.get("_puesto_de_la_caja").get("destino_de_los_tickets")
	var papel: ObjetoAgarrable
	for hijo in destino.get_children():
		if hijo is ObjetoAgarrable and hijo.datos is Ticket and hijo.visible:
			papel = hijo as ObjetoAgarrable
	assert_object(papel).is_not_null()
	assert_bool(agarre.pedir_agarrar(papel.datos, papel)).is_true()
	_pulsar_comprador()
	assert_object(agarre.manos().sostenido()).is_null()
	RelojDePrueba.avanzar_hasta(reloj, Vector2i(2, 0))
	RelojDePrueba.avanzar_turno(reloj, 0.0)
	for _cuadro in 3:
		await get_tree().physics_frame
	assert_bool(is_instance_valid(papel)).is_false()
	assert_array(_almacen.get("_reposicion_manual").call("unidades_sueltas")).is_empty()
	assert_bool(atenciones.tarea().compras_cerradas()).is_true()
	assert_bool(reloj.obligatoria(Tarea.Tipo.REGISTRAR).completada()).is_false()
	RelojDePrueba.avanzar_turno(reloj, Reglas.DURACION_DEL_TURNO)
	assert_bool(reloj.obligatoria(Tarea.Tipo.REGISTRAR).completada()).is_true()
	assert_bool(reloj.obligatoria(Tarea.Tipo.CAJA).completada()).is_false()


func test_un_salto_desde_apertura_registra_cero_al_cerrar() -> void:  # AC-STK-056
	_abrir()
	var reloj: RelojDelTurno = _almacen.get("_reloj")
	reloj.set_process(false)
	var atenciones: Ventanilla = _almacen.get("_atenciones")
	var eventos: Array[String] = []
	atenciones.comprador_llegado.connect(
		func(comprador: Comprador) -> void: eventos.append("llego " + comprador.nombre())
	)
	atenciones.comprador_vencido.connect(
		func(comprador: Comprador) -> void: eventos.append("vencio " + comprador.nombre())
	)
	assert_bool(reloj.obligatoria(Tarea.Tipo.REGISTRAR).completada()).is_false()
	RelojDePrueba.avanzar_turno(reloj, Reglas.DURACION_DEL_TURNO)
	assert_array(eventos).contains_exactly(["llego Tin", "vencio Tin", "llego Tia", "vencio Tia"])
	assert_bool(atenciones.tarea().compras_cerradas()).is_true()
	assert_bool(reloj.obligatoria(Tarea.Tipo.REGISTRAR).completada()).is_true()
	assert_bool(reloj.obligatoria(Tarea.Tipo.CAJA).completada()).is_false()


func _afirmar_apoyos_libres(cuerpos: Array[ObjetoAgarrable]) -> void:
	var manual: Node3D = _almacen.get("_reposicion_manual")
	var suelo: StaticBody3D = manual.get("suelo")
	var espacio := manual.get_world_3d().direct_space_state
	var lector: Habitaciones = _almacen.get("_habitaciones")
	var excluidos: Array[RID] = []
	for cuerpo in cuerpos:
		excluidos.append(cuerpo.get_rid())
	for cuerpo in cuerpos:
		assert_int(lector.de(cuerpo.global_position)).is_equal(CIERRE.Habitacion.LOCAL)
		var forma: CollisionShape3D = cuerpo.get_node("Forma")
		var consulta := PhysicsShapeQueryParameters3D.new()
		consulta.shape = forma.shape
		consulta.transform = forma.global_transform
		consulta.collision_mask = cuerpo.collision_mask
		consulta.exclude = [cuerpo.get_rid(), suelo.get_rid()]
		consulta.margin = 0.0
		assert_array(espacio.intersect_shape(consulta)).is_empty()
		var rayo := PhysicsRayQueryParameters3D.create(
			cuerpo.global_position,
			cuerpo.global_position + Vector3.DOWN * 2.0,
			cuerpo.collision_mask
		)
		rayo.exclude = excluidos
		var piso := espacio.intersect_ray(rayo)
		assert_object(piso.get("collider")).is_same(suelo)
		if not piso.is_empty():
			var limites := forma.global_transform * forma.shape.get_debug_mesh().get_aabb()
			assert_float(limites.position.y).is_equal_approx((piso["position"] as Vector3).y, 0.03)


func test_dos_vencimientos_en_un_avance_separan_cinco_cuerpos() -> void:  # AC-CTR-040, AC-CTR-046
	var cuerpos := await _entregar_a_tin(true, false, true)
	var reloj: RelojDelTurno = _almacen.get("_reloj")
	var atenciones: Ventanilla = _almacen.get("_atenciones")
	var agarre: Agarre = _almacen.get("_agarre")
	var ventana: Node3D = _almacen.get_node("Estructura/Ventanilla")
	var emisiones: Array[Array] = []
	ventana.connect(
		"entregas_abandonadas",
		func(entregas: Array[Node3D]) -> void: emisiones.append(entregas.duplicate())
	)
	RelojDePrueba.avanzar_hasta(reloj, Vector2i(22, 0))
	_pulsar_comprador()
	_pulsar_comprador()
	for producto in atenciones.atencion().comprador().pedido().productos():
		_almacen.get("_reposicion_manual").call("retirar", producto.id)
		var cuerpo := agarre.cuerpo_sostenido() as ObjetoAgarrable
		assert_object(cuerpo).is_not_null()
		cuerpos.append(cuerpo)
		_pulsar_comprador()
		assert_object(agarre.cuerpo_sostenido()).is_null()
	RelojDePrueba.avanzar_hasta(reloj, Vector2i(0, 0))
	assert_array(emisiones).has_size(2)
	assert_array(emisiones[0]).has_size(3)
	assert_array(emisiones[1]).has_size(2)
	(
		assert_array(_almacen.get("_reposicion_manual").call("unidades_sueltas"))
		. contains_exactly_in_any_order(cuerpos)
	)
	var huellas: Array[AABB] = []
	for cuerpo in cuerpos:
		var forma: CollisionShape3D = cuerpo.get_node("Forma")
		var huella := forma.global_transform * forma.shape.get_debug_mesh().get_aabb()
		for anterior in huellas:
			assert_bool(huella.intersects(anterior)).is_false()
		huellas.append(huella)
	for _cuadro in 90:
		await get_tree().physics_frame
	_afirmar_apoyos_libres(cuerpos)
	RelojDePrueba.avanzar_turno(reloj, 0.0)
	assert_array(emisiones).has_size(2)
	(
		assert_array(_almacen.get("_reposicion_manual").call("unidades_sueltas"))
		. contains_exactly_in_any_order(cuerpos)
	)


func test_el_sector_proximo_ocupado_busca_otro_apoyo_interior() -> void:  # AC-CTR-046
	var cuerpos := await _entregar_a_tin()
	var ventana: Node3D = _almacen.get_node("Estructura/Ventanilla")
	ventana.call("cerrar")
	var punto: Marker3D = ventana.get("piso_de_entregas")
	var jugador: CharacterBody3D = _almacen.get("_jugador")
	jugador.global_position += ventana.global_basis.x * 1.1
	var bloque := StaticBody3D.new()
	_almacen.add_child(bloque)
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(1.2, 0.6, 1.2)
	forma.shape = caja
	bloque.add_child(forma)
	bloque.global_position = (
		punto.global_position + Vector3.UP * caja.size.y / 2.0 - ventana.global_basis.z * 0.35
	)
	for _cuadro in 3:
		await get_tree().physics_frame
	var prueba := PhysicsShapeQueryParameters3D.new()
	prueba.shape = caja
	prueba.transform = forma.global_transform
	prueba.collision_mask = jugador.collision_mask
	var suelo: StaticBody3D = _almacen.get("_reposicion_manual").get("suelo")
	prueba.exclude = [bloque.get_rid(), suelo.get_rid()]
	prueba.margin = 0.0
	assert_array(jugador.get_world_3d().direct_space_state.intersect_shape(prueba)).is_empty()
	RelojDePrueba.avanzar_hasta(_almacen.get("_reloj"), Vector2i(23, 0))
	for _cuadro in 90:
		await get_tree().physics_frame
	(
		assert_array(_almacen.get("_reposicion_manual").call("unidades_sueltas"))
		. contains_exactly_in_any_order(cuerpos)
	)
	_afirmar_apoyos_libres(cuerpos)
	var ocupado := forma.global_transform * caja.get_debug_mesh().get_aabb()
	var apoyo_lateral := false
	for cuerpo in cuerpos:
		var lateral := ventana.global_basis.x.dot(cuerpo.global_position - punto.global_position)
		apoyo_lateral = apoyo_lateral or absf(lateral) > caja.size.x / 2.0
		var volumen: CollisionShape3D = cuerpo.get_node("Forma")
		(
			assert_bool(
				(volumen.global_transform * volumen.shape.get_debug_mesh().get_aabb()).intersects(
					ocupado
				)
			)
			. is_false()
		)

	assert_bool(apoyo_lateral).is_true()


func _enfocar_abandonada(cuerpo: ObjetoAgarrable) -> bool:
	var jugador: CharacterBody3D = _almacen.get("_jugador")
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	var forma: CollisionShape3D = jugador.get_node("Cuerpo")
	var manual: Node3D = _almacen.get("_reposicion_manual")
	var suelo: StaticBody3D = manual.get("suelo")
	var espacio := jugador.get_world_3d().direct_space_state
	var excluidos: Array[RID] = [jugador.get_rid()]
	for suelta: RigidBody3D in manual.call("unidades_sueltas"):
		excluidos.append(suelta.get_rid())
	for direccion: Vector3 in [Vector3.FORWARD, Vector3.LEFT, Vector3.RIGHT, Vector3.BACK]:
		var lugar := cuerpo.global_position + direccion
		var rayo := PhysicsRayQueryParameters3D.create(
			lugar + Vector3.UP, lugar + Vector3.DOWN * 2.0, jugador.collision_mask
		)
		rayo.exclude = excluidos
		var piso := espacio.intersect_ray(rayo)
		if piso.get("collider") != suelo:
			continue
		lugar.y = (piso["position"] as Vector3).y + 0.01
		var consulta := PhysicsShapeQueryParameters3D.new()
		consulta.shape = forma.shape
		consulta.transform = Transform3D(Basis.IDENTITY, lugar) * forma.transform
		consulta.collision_mask = jugador.collision_mask
		consulta.exclude = [jugador.get_rid()]
		consulta.margin = 0.0
		if not espacio.intersect_shape(consulta).is_empty():
			continue
		jugador.global_position = lugar
		camara.look_at(cuerpo.global_position)
		jugador.reset_physics_interpolation()
		camara.reset_physics_interpolation()
		for _cuadro in 3:
			await get_tree().physics_frame
		jugador.call("_leer_la_mira")
		if jugador.get("_enfocado") == cuerpo:
			assert_float(camara.global_position.distance_to(cuerpo.global_position)).is_less(
				ReglasDelJugador.ALCANCE_DE_LA_MIRA
			)
			return true
	return false


func test_cada_abandonada_se_recoge_con_el_foco_y_clic_reales() -> void:  # AC-CTR-046
	var cuerpos := await _abandonar_tin()
	_almacen.get_node("Estructura/Ventanilla").call("cerrar")
	var agarre: Agarre = _almacen.get("_agarre")
	for cuerpo in cuerpos:
		var identidad := cuerpo.datos as UnidadDeProducto
		var enfocable := await _enfocar_abandonada(cuerpo)
		assert_bool(enfocable).is_true()
		if not enfocable:
			return
		var evento := InputEventAction.new()
		evento.action = ReglasDeLosObjetos.ACCION_AGARRAR
		evento.pressed = true
		_almacen.get("_jugador").call("_unhandled_input", evento)
		assert_object(agarre.cuerpo_sostenido()).is_same(cuerpo)
		assert_object(agarre.manos().sostenido()).is_same(identidad)
		# La prueba detuvo el proceso del jugador: ejercemos su lectura normal antes
		# de que devolver recicle o libere el cuerpo que acaba de salir del foco.
		for _cuadro in 3:
			await get_tree().physics_frame
		_almacen.get("_jugador").call("_leer_la_mira")
		_almacen.get("_reposicion_manual").call("devolver", identidad.producto.id)
		assert_object(agarre.manos().sostenido()).is_null()
	_afirmar_cierre_abandonadas(false)
