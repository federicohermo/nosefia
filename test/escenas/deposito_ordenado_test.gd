extends GdUnitTestSuite

const AvanceDeDevolucion := preload("res://test/avance_de_devolucion.gd")

const ReglasDelCierre := preload("res://src/dominio/almacen/reglas_del_cierre.gd")
const ALMACEN := preload("res://src/escenas/almacen.tscn")
const Caja := preload("res://src/escenas/objetos/caja_de_productos.gd")
const RelojDePrueba := preload("res://test/reloj_de_prueba.gd")


class Sitio:
	extends RefCounted
	var pies: Vector3
	var punto: Vector3

	func _init(posicion: Vector3, objetivo: Vector3) -> void:
		pies = posicion
		punto = objetivo


func _abrir(jornada: int = ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA) -> Node3D:
	var local: Node3D = auto_free(ALMACEN.instantiate())
	local.set("_partida", Partida.desde({"jornada": jornada, "medios": 0}))
	add_child(local)
	local.get_node("Interfaz/PersianaDeLaNoche").terminar()
	local.get("_jugador").set_physics_process(false)
	local.get("_reloj").set_process(false)
	for _cuadro in 4:
		await get_tree().physics_frame
	return local


func _apoyo(local: Node3D, caja: Caja) -> Dictionary:
	var media: float = caja.get_node("Cuerpo").scale.y
	var rayo := PhysicsRayQueryParameters3D.create(
		caja.global_position, caja.global_position + Vector3.DOWN * (media + 0.02)
	)
	rayo.exclude = [caja.get_rid()]
	return local.get_world_3d().direct_space_state.intersect_ray(rayo)


func _estanteria(golpe: Dictionary) -> bool:
	if golpe.is_empty():
		return false
	var nombre: String = str(golpe.collider.get_parent().name)
	return nombre.begins_with("deposito_pallet_") and nombre != "deposito_pallet_piso"


func _puntos_de_foco(local: Node3D, caja: Caja) -> Array[Sitio]:
	var espacio := local.get_world_3d().direct_space_state
	var jugador: CharacterBody3D = local.get("_jugador")
	var cuerpo: CollisionShape3D = jugador.get_node("Cuerpo")
	var piso: CollisionShape3D = local.get_node("Estructura/SueloSolido/Fondo")
	var sitios: Array[Sitio] = []
	var volumen: CollisionShape3D = caja.get_node("Cuerpo")
	var limites := volumen.global_transform * volumen.shape.get_debug_mesh().get_aabb()
	var objetivos: Array[Vector3] = [limites.get_center()]
	for direccion: Vector3 in [
		Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK, Vector3.UP
	]:
		objetivos.append(limites.get_center() + direccion * limites.size / 2.0)
	for paso in 24:
		var rumbo := Vector3(cos(TAU * paso / 24.0), 0, sin(TAU * paso / 24.0))
		for distancia: float in [0.7, 0.9, 1.1, 1.3, 1.5, 1.7, 1.9, 2.1, 2.3]:
			var candidato := caja.global_position + rumbo * distancia
			var rayo := PhysicsRayQueryParameters3D.create(
				Vector3(candidato.x, 3.0, candidato.z),
				Vector3(candidato.x, -1.0, candidato.z),
				jugador.collision_mask
			)
			rayo.exclude = [jugador.get_rid()]
			var golpe := espacio.intersect_ray(rayo)
			if golpe.get("collider") != piso.get_parent():
				continue
			var pies: Vector3 = golpe.position + Vector3.UP * 0.01
			var consulta := PhysicsShapeQueryParameters3D.new()
			consulta.shape = cuerpo.shape
			consulta.transform = Transform3D(Basis.IDENTITY, pies) * cuerpo.transform
			consulta.collision_mask = jugador.collision_mask
			consulta.exclude = [jugador.get_rid()]
			consulta.margin = 0.0
			if not espacio.intersect_shape(consulta, 4).is_empty():
				continue
			var ojos := pies + Vector3.UP * ReglasDelJugador.ALTURA_DE_LA_CAMARA
			for objetivo in objetivos:
				var vista := PhysicsRayQueryParameters3D.create(ojos, objetivo, 3)
				vista.exclude = [jugador.get_rid()]
				var impacto := espacio.intersect_ray(vista)
				if (
					impacto.get("collider") == caja
					and (
						ReglasDelJugador.proximidad(ojos, impacto.position)
						<= ReglasDelJugador.ALCANCE_DE_LA_MIRA
					)
				):
					sitios.append(Sitio.new(pies, impacto.position))
	return sitios


func test_cada_caja_se_enfoca_y_se_agarra_en_la_apertura_sin_retirar_otras() -> void:  # AC-STK-077
	var local := await _abrir()
	var cajas: Array = local.get("_cajas_de_productos")
	assert_int(cajas.size()).is_equal(Catalogo.todos().size())
	var sitios_iniciales: Dictionary[Caja, Sitio] = {}
	# Primero se mide toda la descarga intacta: retirar una exterior no puede habilitar otra.
	for caja: Caja in cajas:
		var sitios := _puntos_de_foco(local, caja)
		(
			assert_array(sitios)
			. override_failure_message("Sin foco en la apertura intacta: %s" % caja.name)
			. is_not_empty()
		)
		if not sitios.is_empty():
			sitios_iniciales[caja] = sitios[0]
	var jugador: Node3D = local.get("_jugador")
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	var agarre: Agarre = local.get("_agarre")
	for caja: Caja in sitios_iniciales:
		var sitio := sitios_iniciales[caja]
		jugador.global_position = sitio.pies
		jugador.reset_physics_interpolation()
		camara.position = Vector3.UP * ReglasDelJugador.ALTURA_DE_LA_CAMARA
		camara.look_at(sitio.punto)
		for _cuadro in 3:
			await get_tree().physics_frame
		jugador.call("_leer_la_mira")
		assert_object(jugador.get("_enfocado")).is_same(caja)
		assert_bool(agarre.pedir_agarrar(caja.datos, caja)).is_true()
		assert_object(agarre.manos().sostenido()).is_same(caja.datos)
		agarre.soltar(false)
		# Restaurar antes del siguiente cuadro impide que el gesto despeje las cajas interiores.
		for original: Caja in cajas:
			original.volver_a_su_lugar()
	assert_int(sitios_iniciales.size()).is_equal(cajas.size())


func test_la_pila_completa_no_se_superpone_y_la_mira_alcanza_cada_caja() -> void:  # AC-STK-077
	var local := await _abrir()
	var cajas: Array = []
	var llegadas := Apertura.productos_con_cajas_apiladas(
		ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA
	)
	for caja: Caja in local.get("_cajas_de_productos"):
		if llegadas.has(caja.producto):
			cajas.append(caja)
		else:
			assert_bool(caja.global_transform.is_equal_approx(caja.pose_de_estanteria())).is_true()
			assert_bool(_estanteria(_apoyo(local, caja))).is_true()
	assert_int(cajas.size()).is_equal(llegadas.size())
	var jugador: Node3D = local.get("_jugador")
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	var espacio := local.get_world_3d().direct_space_state
	for caja: Caja in cajas:
		assert_int(local.get("_habitaciones").de(caja.global_position)).is_equal(
			ReglasDelCierre.Habitacion.DEPOSITO
		)
		var apoyo := _apoyo(local, caja)
		(
			assert_bool(apoyo.is_empty())
			. override_failure_message("Sin apoyo: %s" % caja.name)
			. is_false()
		)
		assert_bool(_estanteria(apoyo)).is_false()
		var base := apoyo
		while base.get("collider") is Caja:
			base = _apoyo(local, base.collider as Caja)
		(
			assert_bool(
				(
					not base.is_empty()
					and str(base.collider.get_parent().name).begins_with("PalletDeEntrega")
				)
			)
			. override_failure_message("La pila no descansa sobre madera: %s" % caja.name)
			. is_true()
		)
		var volumen := PhysicsShapeQueryParameters3D.new()
		var forma := BoxShape3D.new()
		forma.size = Vector3.ONE * (caja.get_node("Cuerpo").scale.x * 2.0 - 0.01)
		volumen.shape = forma
		volumen.transform = caja.global_transform
		volumen.exclude = [caja.get_rid(), jugador.get_rid()]
		volumen.margin = 0.0
		(
			assert_array(espacio.intersect_shape(volumen, 8))
			. override_failure_message("Superposición: %s" % caja.name)
			. is_empty()
		)
	# Una descarga compacta se desarma desde afuera: sacar la capa superior descubre la siguiente.
	var pendientes := cajas.duplicate()
	pendientes.sort_custom(
		func(a: Caja, b: Caja) -> bool: return a.global_position.y > b.global_position.y
	)
	var agarre: Agarre = local.get("_agarre")
	while not pendientes.is_empty():
		var caja: Caja = null
		var sitios: Array[Sitio] = []
		for candidata: Caja in pendientes:
			sitios = _puntos_de_foco(local, candidata)
			if not sitios.is_empty():
				caja = candidata
				break
		(
			assert_array(sitios)
			. override_failure_message("La descarga no se puede terminar de retirar con la mira")
			. is_not_empty()
		)
		if sitios.is_empty():
			break
		jugador.global_position = sitios[0].pies
		jugador.reset_physics_interpolation()
		camara.position = Vector3.UP * ReglasDelJugador.ALTURA_DE_LA_CAMARA
		camara.look_at(sitios[0].punto)
		for _cuadro in 3:
			await get_tree().physics_frame
		jugador.call("_leer_la_mira")
		assert_object(jugador.get("_enfocado")).is_same(caja)
		assert_bool(agarre.pedir_agarrar(caja.datos, caja)).is_true()
		agarre.soltar(false)
		caja.global_transform = caja.pose_de_estanteria()
		caja.quedarse_quieta()
		caja.sleeping_state_changed.emit()
		pendientes.erase(caja)
		for _cuadro: int in 4:
			await get_tree().physics_frame
	assert_array(pendientes).is_empty()


func test_la_pila_estable_vuelve_a_estantes_en_la_segunda_noche() -> void:  # AC-STK-077
	var local := await _abrir()
	var cajas: Array = local.get("_cajas_de_productos")
	var originales: Array[Vector3] = []
	for caja: Caja in cajas:
		originales.append(caja.global_position)
	for _cuadro in 120:
		await get_tree().physics_frame
	for indice in cajas.size():
		assert_float(cajas[indice].global_position.distance_to(originales[indice])).is_less_equal(
			0.01
		)
	RelojDePrueba.avanzar_turno(local.get("_reloj"), Reglas.DURACION_DEL_TURNO)
	var pantalla: PantallaDeDevolucion = local.get("_pantalla")
	AvanceDeDevolucion.entregar(pantalla)
	pantalla.elegir()
	AvanceDeDevolucion.pasar_la_reflexion(pantalla)
	AvanceDeDevolucion.terminar_movimiento(pantalla)
	await get_tree().process_frame
	for _cuadro in 4:
		await get_tree().physics_frame
	for caja: Caja in cajas:
		assert_bool(caja.lugar_de_origen().is_equal_approx(caja.pose_de_estanteria())).is_true()
		(
			assert_bool(_estanteria(_apoyo(local, caja)))
			. override_failure_message("No volvió a estantería: %s" % caja.name)
			. is_true()
		)
	assert_array(local.find_children("PalletsDeEntrega", "Node3D", false, false)).is_empty()


func _ordenar_en_sus_estanterias(local: Node3D) -> void:
	# La escena ya declara cada lugar artístico; el fixture lo toma antes de la apertura.
	var plantilla: Node3D = ALMACEN.instantiate()
	for caja: Caja in local.get("_cajas_de_productos"):
		var origen: Node3D = plantilla.get_node("Objetos/" + str(caja.name))
		caja.transform = origen.transform
		caja.quedarse_quieta()
		caja.sleeping_state_changed.emit()
	plantilla.free()
	for _cuadro in 4:
		await get_tree().physics_frame


func test_apoyar_descumplir_sostener_y_examinar_actualizan_ordenar_y_hud() -> void:  # AC-STK-079
	var local := await _abrir()
	var reloj: RelojDelTurno = local.get("_reloj")
	var tarea := reloj.obligatoria(Tarea.Tipo.ORDENAR_LAS_CAJAS)
	assert_object(tarea).is_not_null()
	if tarea == null:
		return
	assert_bool(tarea.completada()).is_false()
	await _ordenar_en_sus_estanterias(local)
	assert_bool(tarea.completada()).is_true()
	var contador: Label = local.get("_hud").get("_tareas")
	assert_str(contador.text).is_equal("Tareas 1/5")
	var caja: Caja = local.get("_cajas_de_productos")[0]
	var arriba: Caja = caja
	for candidata: Caja in local.get("_cajas_de_productos"):
		if candidata.global_position.y > arriba.global_position.y:
			arriba = candidata
	caja.global_position = (
		arriba.global_position
		+ Vector3.UP * (arriba.get_node("Cuerpo").scale.y + caja.get_node("Cuerpo").scale.y)
	)
	caja.quedarse_quieta()
	caja.sleeping_state_changed.emit()
	for _cuadro in 4:
		await get_tree().physics_frame
	assert_object(_apoyo(local, caja).get("collider")).is_same(arriba)
	assert_bool(tarea.completada()).is_true()
	var piso: CollisionShape3D = local.get_node("Estructura/SueloSolido/Fondo")
	var forma: BoxShape3D = piso.shape
	var limites := piso.global_transform * AABB(-forma.size / 2.0, forma.size)
	caja.global_position = Vector3(
		limites.end.x - 1.0,
		limites.end.y + caja.get_node("Cuerpo").scale.y,
		limites.position.z + 1.0
	)
	caja.quedarse_quieta()
	caja.sleeping_state_changed.emit()
	for _cuadro in 4:
		await get_tree().physics_frame
	assert_bool(_estanteria(_apoyo(local, caja))).is_false()
	assert_bool(tarea.completada()).is_false()
	assert_str(contador.text).is_equal("Tareas 0/5")
	var agarre: Agarre = local.get("_agarre")
	assert_bool(agarre.pedir_agarrar(caja.datos, caja)).is_true()
	await get_tree().process_frame
	assert_bool(tarea.completada()).is_false()
	assert_str(contador.text).is_equal("Tareas 0/5")
	assert_bool(local.get("_jugador").examen.iniciar()).is_true()
	await get_tree().process_frame
	assert_bool(tarea.completada()).is_false()
	assert_str(contador.text).is_equal("Tareas 0/5")
	local.get("_jugador").examen.terminar()
	agarre.soltar(false)
	await _ordenar_en_sus_estanterias(local)
	assert_bool(tarea.completada()).is_true()
	assert_str(contador.text).is_equal("Tareas 1/5")
	assert_bool(agarre.pedir_agarrar(caja.datos, caja)).is_true()
	await get_tree().process_frame
	assert_bool(tarea.completada()).is_false()
	assert_str(contador.text).is_equal("Tareas 0/5")
	RelojDePrueba.avanzar_turno(reloj, Reglas.DURACION_DEL_TURNO)
	agarre.soltar(false)
	await _ordenar_en_sus_estanterias(local)
	assert_bool(tarea.completada()).is_false()


func test_el_rescate_usa_el_origen_de_la_noche() -> void:  # AC-STK-080
	for en_estanteria: bool in [false, true]:
		var local := await _abrir()
		var id := Producto.Id.ACTRONCITO
		if not en_estanteria:
			var altura := -INF
			for caja: Caja in local.get("_cajas_de_productos"):
				if (
					caja.producto not in Catalogo.PRODUCTOS_DE_PRUEBA
					and caja.global_position.y > altura
				):
					id = caja.producto
					altura = caja.global_position.y
		var caja: Caja = local.get("_cajas_de_productos")[id]
		assert_bool(caja.global_transform.is_equal_approx(caja.pose_de_estanteria())).is_equal(
			en_estanteria
		)
		await _comprobar_rescate(local, id, en_estanteria)
		local.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame


func _comprobar_rescate(local: Node3D, id: Producto.Id, en_estanteria: bool) -> void:
	var caja: Caja = local.get("_cajas_de_productos")[id]
	var origen := caja.global_transform
	caja.global_position += Vector3.UP * 10.0
	caja.volver_a_su_lugar()
	(
		assert_bool(caja.global_transform.is_equal_approx(origen))
		. override_failure_message(
			(
				"%s: pose %s, origen %s, delta %s"
				% [
					caja.name,
					caja.global_position,
					origen.origin,
					caja.global_position - origen.origin
				]
			)
		)
		. is_true()
	)
	var solido := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var bloque := BoxShape3D.new()
	bloque.size = Vector3.ONE * 8.0
	forma.shape = bloque
	solido.add_child(forma)
	local.add_child(solido)
	solido.global_position = Vector3(50.0, 10.0, 50.0)
	await get_tree().physics_frame
	caja.global_position = solido.global_position

	var red: RedDeSeguridad = local.get_node("Servicios/RedDeSeguridad")
	assert_float(red.call("_hundido", caja, caja.global_transform)).is_greater(
		ReglasDeLosObjetos.ROCE
	)
	var retorno: Array = red.call("_origen", caja)
	assert_int(retorno.size()).is_equal(1)
	assert_bool((retorno[0] as Transform3D).is_equal_approx(origen)).is_true()
	assert_array(red.call("_alrededor", caja)).is_empty()
	red.revisar(caja)
	assert_int(red.rescates.size()).is_equal(1)
	assert_int(red.rescates[0]["clase"]).is_equal(
		Rescate.Clase.ORIGEN if en_estanteria else Rescate.Clase.ENCIMA_DEL_ORIGEN
	)
	assert_bool(caja.global_basis.is_equal_approx(origen.basis)).is_true()
	var delta := caja.global_position - origen.origin
	assert_float(absf(delta.x)).is_less(0.00001)
	assert_float(absf(delta.z)).is_less(0.00001)
	assert_float(delta.y).is_greater_equal(0.0)
	assert_float(delta.y).is_less_equal(ReglasDeLosObjetos.ROCE + 0.00001)
	assert_float(red.call("_hundido", caja, caja.global_transform)).is_less_equal(
		ReglasDeLosObjetos.ROCE
	)
	for _cuadro in 4:
		await get_tree().physics_frame
	assert_bool(_estanteria(_apoyo(local, caja))).is_equal(en_estanteria)
	(
		assert_bool(local.get("_reloj").obligatoria(Tarea.Tipo.ORDENAR_LAS_CAJAS).completada())
		. is_false()
	)


func test_hud_y_nota_siguen_la_jornada_sin_recargar_el_local() -> void:  # AC-SHF-027, AC-PLY-080
	var local := await _abrir()
	var contador: Label = local.get("_hud").get("_tareas")
	assert_str(contador.text).is_equal("Tareas 0/5")
	var notas: Array = local.get_node("Estructura/NotasDelAlmacen").get("notas")
	var hoja: Node
	for nota: Node in notas:
		if nota.get("id") == NotaPegada.Id.TAREAS_A_REALIZAR:
			hoja = nota
	assert_array(hoja.call("dato").renglones()).contains_exactly(
		[
			"Atención al cliente",
			"Registro de productos vendidos",
			"Limpieza",
			"Reposición",
			"Ordenar cajas en el depósito"
		]
	)
	var partida: Partida = local.get("_partida")
	for jornada in range(
		ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1,
		ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 3
	):
		for tarea in partida.obligatorias():
			local.get("_reloj").completar(tarea)
		RelojDePrueba.avanzar_turno(local.get("_reloj"), Reglas.DURACION_DEL_TURNO)
		var pantalla: PantallaDeDevolucion = local.get("_pantalla")
		AvanceDeDevolucion.entregar(pantalla)
		pantalla.elegir()
		AvanceDeDevolucion.pasar_la_reflexion(pantalla)
		AvanceDeDevolucion.terminar_movimiento(pantalla)
		await get_tree().process_frame
		local.get_node("Interfaz/PersianaDeLaNoche").terminar()
		assert_bool(local.get_node("Interfaz/PersianaDeLaNoche").en_pantalla()).is_false()
		for _cuadro in 4:
			await get_tree().physics_frame
		var esperada := NotaPegada.tareas_a_realizar(Apertura.obligatorias(jornada))
		if jornada == ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1:
			assert_str(hoja.call("dato").renglones()[4]).is_equal("Tirar la basura")
		assert_array(hoja.call("dato").renglones()).contains_exactly(esperada.renglones())
		assert_str(hoja.get("renglones_del_papel").text).is_equal(
			NotaEncuadrada.texto_de_renglones(hoja.call("dato"))
		)
		assert_str(contador.text).is_equal(
			"Tareas 0/%d" % Apertura.cantidad_de_obligatorias(jornada)
		)
	var declaradas := Apertura.cantidad_de_obligatorias(
		ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 2
	)
	assert_str(contador.text).is_equal("Tareas 0/%d" % declaradas)
	for tarea in partida.obligatorias():
		local.get("_reloj").completar(tarea)
	local.get("_reloj").completar(Tarea.new(Tarea.Tipo.ORDENAR_LAS_CAJAS))
	assert_str(contador.text).is_equal("Tareas %d/%d" % [declaradas, declaradas])
