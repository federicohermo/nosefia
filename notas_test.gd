extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const UNIDAD := preload("res://src/escenas/objetos/objeto_agarrable.tscn")


func after_test() -> void:
	get_tree().paused = false


func _abrir() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	var jugador: Node3D = almacen.get_node("Jugador")
	jugador.set_physics_process(false)
	for _cuadro in 4:
		await get_tree().physics_frame
	return almacen


func _accion(jugador: Node3D, nota: Node3D, nombre: StringName) -> void:
	jugador.set("_enfocado", nota)
	var evento := InputEventAction.new()
	evento.action = nombre
	evento.pressed = true
	jugador.call("_unhandled_input", evento)


func _derecho() -> void:
	for presionado: bool in [true, false]:
		var evento := InputEventMouseButton.new()
		evento.button_index = MOUSE_BUTTON_RIGHT
		evento.pressed = presionado
		evento.position = get_viewport().get_visible_rect().get_center()
		get_viewport().push_input(evento)
		await get_tree().process_frame


func _vista(almacen: Node3D) -> NotaEncuadrada:
	return almacen.get_node("Interfaz/NotaEncuadrada")


func test_las_cinco_hojas_abren_su_propio_dato_y_cierran_con_el_derecho() -> void:  # AC-PLY-063
	var almacen := await _abrir()
	var jugador: Node3D = almacen.get_node("Jugador")
	var puesto: Node = almacen.get_node("Estructura/NotasDelAlmacen")
	var vista := _vista(almacen)
	var ids: Array[int] = []
	for hoja: StaticBody3D in puesto.get("notas"):
		ids.append(hoja.get("id"))
		_accion(jugador, hoja, ReglasDelJugador.ACCION_USAR)
		assert_bool(vista.visible).is_true()
		assert_bool((jugador.get("_control") as ControlDelJugador).esta_suspendido()).is_true()
		assert_str((vista.get("_titulo") as Label).text).is_equal(hoja.call("dato").titulo())
		if hoja.call("imagen") == null:
			assert_object((vista.get("_imagen") as TextureRect).texture).is_null()
		else:
			assert_object((vista.get("_imagen") as TextureRect).texture).is_same(
				hoja.call("imagen")
			)
		await _derecho()
		assert_bool(vista.visible).is_false()
		assert_bool((jugador.get("_control") as ControlDelJugador).esta_suspendido()).is_false()
	assert_array(ids).contains_exactly_in_any_order(NotaPegada.Id.values())


func test_cada_objeto_sigue_en_la_mano_al_leer_y_salir() -> void:  # AC-PLY-064
	var almacen := await _abrir()
	var jugador: Node3D = almacen.get_node("Jugador")
	var agarre: Agarre = almacen.get("_agarre")
	var unidad: Node3D = UNIDAD.instantiate()
	unidad.set("datos", UnidadDeProducto.new(Catalogo.de(Producto.Id.ACTRONCITO)))
	almacen.add_child(unidad)
	var objetos: Array[Node3D] = [
		unidad,
		almacen.get("_cajas_de_productos")[0],
		almacen.get_node("Objetos/Mopa"),
		almacen.get_node("Objetos/Balde"),
		almacen.get_node("Objetos/JabonAmarillo"),
		almacen.get_node("Objetos/BolsaDeBasura1")
	]
	var pedidos: Array[Node3D] = []
	jugador.connect("uso_pedido", func(objeto: Node3D) -> void: pedidos.append(objeto))
	var hoja: Node3D = (almacen.get_node("Estructura/NotasDelAlmacen").get("notas") as Array)[0]
	for objeto in objetos:
		var dato: ObjetoDelAlmacen = objeto.get("datos")
		assert_bool(agarre.pedir_agarrar(dato, objeto)).is_true()
		var padre := objeto.get_parent()
		var punto := objeto.transform
		_accion(jugador, hoja, ReglasDelJugador.ACCION_USAR)
		assert_bool(_vista(almacen).visible).is_true()
		_accion(jugador, hoja, ReglasDeLosObjetos.ACCION_AGARRAR)
		_accion(jugador, hoja, ReglasDeLosObjetos.ACCION_EXAMINAR)
		assert_bool((jugador.get("examen") as Examen).esta_examinando()).is_false()
		assert_object(agarre.manos().sostenido()).is_same(dato)
		assert_object(objeto.get_parent()).is_same(padre)
		assert_bool(objeto.transform.is_equal_approx(punto)).is_true()
		await _derecho()
		assert_object(agarre.manos().sostenido()).is_same(dato)
		assert_object(objeto.get_parent()).is_same(padre)
		assert_bool(objeto.transform.is_equal_approx(punto)).is_true()
		agarre.entregar()
	assert_array(pedidos).is_empty()


func test_otras_pantallas_impiden_abrir_otra_hoja() -> void:  # AC-PLY-066
	var almacen := await _abrir()
	var jugador: Node3D = almacen.get_node("Jugador")
	var hoja: Node3D = (almacen.get_node("Estructura/NotasDelAlmacen").get("notas") as Array)[0]
	for ruta: String in ["Estructura/base compu/StaticBody3D", "Estructura/Ventanilla"]:
		var pantalla: Node3D = almacen.get_node(ruta)
		pantalla.call("abrir")
		_accion(jugador, hoja, ReglasDelJugador.ACCION_USAR)
		assert_bool(_vista(almacen).visible).is_false()
		assert_bool((jugador.get("_control") as ControlDelJugador).esta_suspendido()).is_true()
		pantalla.call("cerrar")
	var unidad: Node3D = UNIDAD.instantiate()
	var datos := UnidadDeProducto.new(Catalogo.de(Producto.Id.ACTRONCITO))
	unidad.set("datos", datos)
	almacen.add_child(unidad)
	var agarre: Agarre = jugador.get("agarre")
	assert_bool(agarre.pedir_agarrar(datos, unidad)).is_true()
	_accion(jugador, hoja, ReglasDeLosObjetos.ACCION_EXAMINAR)
	assert_bool((jugador.get("examen") as Examen).esta_examinando()).is_true()
	_accion(jugador, hoja, ReglasDelJugador.ACCION_USAR)
	assert_bool(_vista(almacen).visible).is_false()
	(jugador.get("examen") as Examen).terminar()


func test_cerrar_el_turno_quita_la_nota_y_deja_la_placa() -> void:  # AC-PLY-067
	var almacen := await _abrir()
	var jugador: Node3D = almacen.get_node("Jugador")
	var hoja: Node3D = (almacen.get_node("Estructura/NotasDelAlmacen").get("notas") as Array)[0]
	_accion(jugador, hoja, ReglasDelJugador.ACCION_USAR)
	assert_bool(_vista(almacen).visible).is_true()
	(almacen.get("_reloj") as RelojDelTurno).turno_cerrado.emit(0)
	assert_bool(_vista(almacen).visible).is_false()
	assert_bool((almacen.get_node("Interfaz/PantallaDeCierre") as CanvasLayer).visible).is_true()
	assert_bool((jugador.get("_control") as ControlDelJugador).esta_suspendido()).is_true()


func _posiciones_transitables(almacen: Node3D, hoja: StaticBody3D) -> Array[Vector3]:
	var malla: MeshInstance3D = hoja.get("mallas")[0]
	var centro := malla.to_global(malla.mesh.get_aabb().get_center())
	var frente := malla.global_basis.y.normalized()
	if malla.mesh.get_surface_count() > 1:
		var normales: PackedVector3Array = malla.mesh.surface_get_arrays(1)[Mesh.ARRAY_NORMAL]
		var suma := Vector3.ZERO
		for normal in normales:
			suma += normal
		frente = (malla.global_basis.inverse().transposed() * suma).normalized()
	var lateral := frente.cross(Vector3.UP).normalized()
	var jugador: CharacterBody3D = almacen.get_node("Jugador")
	var espacio := almacen.get_world_3d().direct_space_state
	var forma: CollisionShape3D = jugador.get_node("Cuerpo")
	var sitios: Array[Vector3] = []
	for distancia: float in [0.6, 0.8, 1.0, 1.2, 1.5, 2.0]:
		for costado: float in [0.0, -0.2, 0.2, -0.4, 0.4]:
			var punto := centro + frente * distancia + lateral * costado
			var piso := PhysicsRayQueryParameters3D.create(
				punto + Vector3.UP, punto + Vector3.DOWN * 4.0, jugador.collision_mask
			)
			piso.exclude = [jugador.get_rid()]
			var golpe := espacio.intersect_ray(piso)
			print("B306NOTA ", hoja.get_path(), " candidato=", punto, " piso=", JSON.stringify(_b306_golpe(golpe)))
			if golpe.is_empty():
				continue
			var apoyo := golpe.collider as CollisionObject3D
			var dueno := apoyo.shape_owner_get_owner(apoyo.shape_find_owner(golpe.shape)) as Node
			if apoyo.name != "SueloSolido" and dueno.name != "VolumenDelPisoDelBano":
				print("B306NOTA rechazo_nombre")
				continue
			var posicion: Vector3 = golpe.position + Vector3.UP * 0.02
			var volumen := PhysicsShapeQueryParameters3D.new()
			volumen.shape = forma.shape
			volumen.transform = Transform3D(Basis.IDENTITY, posicion) * forma.transform
			volumen.collision_mask = jugador.collision_mask
			volumen.exclude = [jugador.get_rid()]
			var obstaculos := espacio.intersect_shape(volumen)
			if not obstaculos.is_empty():
				for obstaculo: Dictionary in obstaculos:
					print("B306NOTA rechazo_capsula ", obstaculo.collider.get_path())
				continue
			var ojo := posicion + Vector3.UP * ReglasDelJugador.ALTURA_DE_LA_CAMARA
			var consulta := PhysicsRayQueryParameters3D.create(ojo, centro, 3)
			consulta.exclude = [jugador.get_rid()]
			var impacto := espacio.intersect_ray(consulta)
			print("B306NOTA ojo=", ojo, " hoja=", centro, " impacto=", JSON.stringify(_b306_golpe(impacto)))
			if (
				impacto.get("collider") == hoja
				and ojo.distance_to(impacto.position) <= ReglasDelJugador.ALCANCE_DE_LA_MIRA
			):
				sitios.append(posicion)
	return sitios


# AC-PLY-071, AC-PLY-063
func test_cada_hoja_se_enfoca_desde_un_lugar_transitable_y_se_lee() -> void:
	var almacen := await _abrir()
	var jugador: CharacterBody3D = almacen.get_node("Jugador")
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	var puesto: Node = almacen.get_node("Estructura/NotasDelAlmacen")
	var leidas: Array[int] = []
	for hoja: StaticBody3D in puesto.get("notas"):
		var sitios := _posiciones_transitables(almacen, hoja)
		(
			assert_array(sitios)
			. override_failure_message("Sin lugar transitable para %s" % hoja.get_path())
			. is_not_empty()
		)
		# La aserción registra el fallo; este retorno sólo evita un error de índice posterior.
		if sitios.is_empty():
			return
		var malla: MeshInstance3D = hoja.get("mallas")[0]
		var anterior := malla.material_overlay
		jugador.global_position = sitios[0]
		jugador.reset_physics_interpolation()
		camara.position = Vector3.UP * ReglasDelJugador.ALTURA_DE_LA_CAMARA
		camara.look_at(malla.to_global(malla.mesh.get_aabb().get_center()))
		for _cuadro in 3:
			await get_tree().physics_frame
		jugador.call("_leer_la_mira")
		assert_object(jugador.get("_enfocado")).is_same(hoja)
		assert_object(malla.material_overlay).is_not_null()
		assert_bool(malla.material_overlay is ShaderMaterial).is_true()
		var evento := InputEventAction.new()
		evento.action = ReglasDelJugador.ACCION_USAR
		evento.pressed = true
		jugador.call("_unhandled_input", evento)
		assert_bool(_vista(almacen).visible).is_true()
		assert_str((_vista(almacen).get("_titulo") as Label).text).is_equal(
			hoja.call("dato").titulo()
		)
		assert_object(malla.material_overlay).is_same(anterior)
		leidas.append(hoja.get("id"))
		await _derecho()
	assert_array(leidas).contains_exactly_in_any_order(NotaPegada.Id.values())


func test_leer_continua_el_reloj_y_la_pausa_se_dibuja_encima() -> void:  # AC-PLY-067, AC-PLY-066
	var almacen := await _abrir()
	var jugador: Node3D = almacen.get_node("Jugador")
	var hoja: Node3D = almacen.get_node("Estructura/NotasDelAlmacen").get("notas")[0]
	var reloj: RelojDelTurno = almacen.get("_reloj")
	var tiempos: Array[float] = []
	reloj.tiempo_consumido.connect(func(tiempo: float) -> void: tiempos.append(tiempo))
	_accion(jugador, hoja, ReglasDelJugador.ACCION_USAR)
	for _cuadro in 6:
		await get_tree().process_frame
	assert_bool(reloj.corriendo()).is_true()
	assert_int(tiempos.size()).is_greater(1)
	assert_float(tiempos.back()).is_less(tiempos.front())
	var pausa: ControlDePausa = almacen.get_node("Interfaz/ControlDePausa")
	var evento := InputEventAction.new()
	evento.action = &"ui_cancel"
	evento.pressed = true
	pausa.call("_input", evento)
	var menu: CanvasLayer = almacen.get_node("Interfaz/MenuDePausa")
	assert_bool(get_tree().paused).is_true()
	assert_bool(menu.visible).is_true()
	assert_bool(_vista(almacen).visible).is_true()
	assert_int(menu.layer).is_greater(_vista(almacen).layer)
	pausa.call("_input", evento)
	assert_bool(get_tree().paused).is_false()
	assert_bool(menu.visible).is_false()
	assert_bool(_vista(almacen).visible).is_true()
	assert_bool((jugador.get("_control") as ControlDelJugador).esta_suspendido()).is_true()


func test_izquierdo_y_examen_no_abren_la_hoja_y_la_mano_cargada_suelta() -> void:  # AC-PLY-065
	var almacen := await _abrir()
	var jugador: Node3D = almacen.get_node("Jugador")
	var hoja: Node3D = almacen.get_node("Estructura/NotasDelAlmacen").get("notas")[0]
	for accion: StringName in [
		ReglasDeLosObjetos.ACCION_AGARRAR, ReglasDeLosObjetos.ACCION_EXAMINAR
	]:
		_accion(jugador, hoja, accion)
		assert_bool(_vista(almacen).visible).is_false()
		assert_bool((jugador.get("examen") as Examen).esta_examinando()).is_false()
	var unidad: Node3D = UNIDAD.instantiate()
	var datos := UnidadDeProducto.new(Catalogo.de(Producto.Id.ACTRONCITO))
	unidad.set("datos", datos)
	almacen.add_child(unidad)
	var agarre: Agarre = jugador.get("agarre")
	assert_bool(agarre.pedir_agarrar(datos, unidad)).is_true()
	_accion(jugador, hoja, ReglasDeLosObjetos.ACCION_AGARRAR)
	assert_object(agarre.manos().sostenido()).is_null()
	assert_bool(_vista(almacen).visible).is_false()


func test_la_hoja_abierta_no_se_reemplaza_por_otro_foco() -> void:  # AC-PLY-066
	var almacen := await _abrir()
	var jugador: Node3D = almacen.get_node("Jugador")
	var hojas: Array = almacen.get_node("Estructura/NotasDelAlmacen").get("notas")
	_accion(jugador, hojas[0], ReglasDelJugador.ACCION_USAR)
	assert_bool(_vista(almacen).visible).is_true()
	var titulo: String = (_vista(almacen).get("_titulo") as Label).text
	_accion(jugador, hojas[1], ReglasDelJugador.ACCION_USAR)
	assert_str((_vista(almacen).get("_titulo") as Label).text).is_equal(titulo)
	assert_bool(_vista(almacen).visible).is_true()


func test_el_corcho_conserva_cinco_hojas_y_solo_dos_ofrecen_lectura() -> void:  # AC-PLY-071
	var almacen := await _abrir()
	var corcho: Node3D = almacen.get_node("Estructura/board tareas")
	var funcionales := 0
	for indice in range(1, 6):
		var hoja: MeshInstance3D = corcho.get_node("board de tareas_%03d" % indice)
		assert_bool(hoja.is_visible_in_tree()).is_true()
		var cuerpo: StaticBody3D = hoja.get_node("StaticBody3D")
		if cuerpo.is_in_group(ReglasDelJugador.GRUPO_INTERACTUABLE):
			funcionales += 1
	assert_int(funcionales).is_equal(2)


func _b306_golpe(golpe: Dictionary) -> Dictionary:
	if golpe.is_empty():
		return {}
	var cuerpo := golpe.collider as CollisionObject3D
	var dueno := cuerpo.shape_owner_get_owner(cuerpo.shape_find_owner(golpe.shape)) as Node
	return {"cuerpo": str(cuerpo.get_path()), "dueno": str(dueno.get_path()), "pos": str(golpe.position), "normal": str(golpe.normal), "rid": str(golpe.rid)}

func _b306_traza(almacen: Node3D, jugador: CharacterBody3D, objeto: Node3D, etapa: String) -> void:
	var espacio := almacen.get_world_3d().direct_space_state
	var exclusiones: Array[RID] = [jugador.get_rid(), (objeto as CollisionObject3D).get_rid()]
	var ray := PhysicsRayQueryParameters3D.create(jugador.global_position + Vector3.UP * 0.5, Vector3(objeto.global_position.x, jugador.global_position.y + 0.5, objeto.global_position.z))
	ray.exclude = exclusiones
	var piso := PhysicsRayQueryParameters3D.create(jugador.global_position + Vector3.UP * 0.1, jugador.global_position + Vector3.DOWN * 5.0)
	piso.exclude = exclusiones
	var ojo: Transform3D = jugador.call("mira")
	var mira := PhysicsRayQueryParameters3D.create(ojo.origin, ojo.origin - ojo.basis.z * ReglasDelJugador.ALCANCE_DE_LA_MIRA)
	mira.exclude = exclusiones
	var datos := {"etapa": etapa, "objeto": str(objeto.name), "pos": str(objeto.global_position), "jugador": str(jugador.global_position), "velocidad": str(jugador.velocity), "en_piso": jugador.is_on_floor(), "padre": str(objeto.get_parent().get_path()), "segmento": _b306_golpe(espacio.intersect_ray(ray)), "piso_jugador": _b306_golpe(espacio.intersect_ray(piso)), "mira": _b306_golpe(espacio.intersect_ray(mira))}
	if objeto is RigidBody3D:
		var cuerpo := objeto as RigidBody3D
		var formas: Array[CollisionShape3D] = jugador.call("_formas_de", cuerpo)
		var limites: AABB = jugador.call("_limites_de", cuerpo, formas)
		var capsula := (jugador.get_node("Cuerpo") as CollisionShape3D).shape as CapsuleShape3D
		var ancho := Vector2(limites.size.x, limites.size.z).length() / 2.0
		var lugares := LugaresDelPiso.alrededor(espacio, jugador.global_position, jugador.call("frente"), capsula.radius + ancho + ReglasDeLosObjetos.ROCE, limites.size.y, ReglasDeLosObjetos.CAIDA_HASTA_EL_PISO, ReglasDeLosObjetos.LADOS_ALREDEDOR, cuerpo.collision_mask, exclusiones)
		datos["lugares"] = str(lugares)
	print("B306TRAZA ", JSON.stringify(datos))
