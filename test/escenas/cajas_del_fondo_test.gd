## Las siete cajas que sólo existen como caja (BR-STK-054) están en una pila contra el fondo del
## depósito, y no cuentan para ordenar las cajas (BR-STK-056).
extends GdUnitTestSuite

const AvanceDeDevolucion := preload("res://test/avance_de_devolucion.gd")
const ReglasDelCierre := preload("res://src/dominio/almacen/reglas_del_cierre.gd")
const RelojDePrueba := preload("res://test/reloj_de_prueba.gd")
const ALMACEN := preload("res://src/escenas/almacen.tscn")
const Caja := preload("res://src/escenas/objetos/caja_de_productos.gd")
const COMPLETA := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA

## Cuánto se mira alrededor del portón y de la puerta del cuartito: lo que la pila no puede tapar.
const PASO := 0.4
const TOLERANCIA := 0.02


func _abrir(jornada: int = COMPLETA) -> Node3D:
	var local: Node3D = auto_free(ALMACEN.instantiate())
	local.set("_partida", Partida.desde({"jornada": jornada, "medios": 0}))
	add_child(local)
	local.get_node("Interfaz/PersianaDeLaNoche").terminar()
	local.get("_jugador").set_physics_process(false)
	local.get("_reloj").set_process(false)
	for _cuadro in 4:
		await get_tree().physics_frame
	return local


func _limites(caja: Caja) -> AABB:
	var cuerpo: CollisionShape3D = caja.get_node("Cuerpo")
	return cuerpo.global_transform * LimitesDeForma.de(cuerpo.shape)


func _limites_de(nodo: Node3D) -> AABB:
	var total := AABB()
	var primera := true
	var mallas: Array[Node] = nodo.find_children("*", "MeshInstance3D", true, false)
	if nodo is MeshInstance3D:
		mallas.append(nodo)
	for malla: MeshInstance3D in mallas:
		var caja := malla.global_transform * malla.get_aabb()
		total = caja if primera else total.merge(caja)
		primera = false
	return total


func _apoyo(local: Node3D, caja: Caja) -> Dictionary:
	var media := _limites(caja).size.y / 2.0
	var rayo := PhysicsRayQueryParameters3D.create(
		caja.global_position, caja.global_position + Vector3.DOWN * (media + 0.02)
	)
	rayo.exclude = [caja.get_rid()]
	return local.get_world_3d().direct_space_state.intersect_ray(rayo)


func _fondo(local: Node3D) -> Array[Caja]:
	var cajas: Array[Caja] = []
	for caja: Caja in local.get("_cajas_del_fondo"):
		cajas.append(caja)
	return cajas


func test_las_siete_estan_en_una_pila_de_cuatro_abajo_y_tres_arriba() -> void:  # AC-STK-130
	var local := await _abrir()
	var cajas := _fondo(local)
	assert_int(cajas.size()).is_equal(Catalogo.SOLO_CAJAS.size())
	var abajo := 0
	var arriba := 0
	for caja in cajas:
		assert_bool(caja.visible).is_true()
		assert_int(local.get("_habitaciones").de(caja.global_position)).is_equal(
			ReglasDelCierre.Habitacion.DEPOSITO
		)
		var apoyo: Node3D = _apoyo(local, caja).get("collider")
		assert_object(apoyo).is_not_null()
		if apoyo is Caja:
			arriba += 1
		else:
			assert_str(str(apoyo.get_parent().name)).starts_with("PalletDeEntrega")
			abajo += 1
	assert_int(abajo).is_equal(4)
	assert_int(arriba).is_equal(3)


func test_la_pila_no_toca_estanterias_ni_otras_cajas_ni_tapa_el_paso() -> void:  # AC-STK-130
	var local := await _abrir()
	var estructura: Node3D = local.get_node("Estructura")
	var libres: Array[AABB] = []
	for nombre: StringName in [&"porton", &"cuartito_cuerpo"]:
		libres.append(_limites_de(estructura.get_node(NodePath(nombre))).grow(PASO))
	var estanterias: Array[AABB] = []
	for hijo in estructura.get_children():
		if str(hijo.name).begins_with("gondola_deposito"):
			estanterias.append(_limites_de(hijo as Node3D))
	for caja in _fondo(local):
		var propia := _limites(caja).grow(-TOLERANCIA)
		for estanteria in estanterias:
			assert_bool(propia.intersects(estanteria)).is_false()
		for otra: Caja in local.get("_cajas_de_productos"):
			assert_bool(propia.intersects(_limites(otra))).is_false()
		for zona in libres:
			assert_bool(propia.intersects(zona)).is_false()


func test_las_siete_amanecen_cada_noche_en_la_pila() -> void:  # AC-STK-130
	var local := await _abrir()
	var cajas := _fondo(local)
	var pila: Array[Vector3] = []
	for caja in cajas:
		pila.append(caja.global_position)
	cajas[0].global_position += Vector3(0.0, 0.0, 2.0)
	RelojDePrueba.avanzar_turno(local.get("_reloj"), Reglas.DURACION_DEL_TURNO)
	var pantalla: PantallaDeDevolucion = local.get("_pantalla")
	AvanceDeDevolucion.entregar(pantalla)
	pantalla.elegir()
	AvanceDeDevolucion.pasar_la_reflexion(pantalla)
	AvanceDeDevolucion.terminar_movimiento(pantalla)
	await get_tree().process_frame
	for _cuadro in 4:
		await get_tree().physics_frame
	for indice in cajas.size():
		assert_float(cajas[indice].global_position.distance_to(pila[indice])).is_less(0.05)


func test_ordenar_las_cajas_no_cuenta_la_pila_del_fondo() -> void:  # AC-STK-131
	var local := await _abrir()
	var reloj: RelojDelTurno = local.get("_reloj")
	var tarea := reloj.obligatoria(Tarea.Tipo.ORDENAR_LAS_CAJAS)
	assert_object(tarea).is_not_null()
	var plantilla: Node3D = ALMACEN.instantiate()
	for caja: Caja in local.get("_cajas_de_productos"):
		var origen: Node3D = plantilla.get_node("Objetos/" + str(caja.name))
		caja.transform = origen.transform
		caja.quedarse_quieta()
		caja.sleeping_state_changed.emit()
	plantilla.free()
	for _cuadro in 4:
		await get_tree().physics_frame
	assert_bool(tarea.completada()).is_true()
	for caja in _fondo(local):
		assert_int(local.get("_habitaciones").de(caja.global_position)).is_equal(
			ReglasDelCierre.Habitacion.DEPOSITO
		)
	(
		assert_array(
			ReglasDelCierre.clases_de_desorden(local.call("_estados_del_cierre"), COMPLETA)
		)
		. not_contains(ReglasDelCierre.Clase.CAJA)
	)
