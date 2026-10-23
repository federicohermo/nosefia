extends Node

## Conductor descartable de medición: no se commitea.
## Juega solo hasta J2 y ahí maneja al jugador real: su cámara, su foco y su gesto de agarrar.

const VENTANA_DESPUES_DEL_CONTROL := 4.0
const CAJAS_A_PROBAR := 3
const PASO_DE_LA_CAMINATA := 0.25
const RADIOS := [1.2, 0.9, 1.5, 1.8, 2.1, 2.5]

var _web := OS.has_feature("web")
var _estado := "menu"
var _desde := 0
var _grabando := false
var _caja_grabada: Node3D = null
var _con_repro := true
var _hasta := 2


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _web:
		_con_repro = (
			str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('repro') || '1'"))
			!= "0"
		)
		_hasta = int(
			str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('hasta') || '2'"))
		)


func marcar(nombre: String, dato: Variant = null) -> void:
	print("[med] %s %d %s" % [nombre, Time.get_ticks_usec(), str(dato)])
	if _web:
		JavaScriptBridge.eval(
			(
				"window.__marca && window.__marca(%s, %s)"
				% [JSON.stringify(nombre), JSON.stringify(str(dato))]
			)
		)


func _process(_delta: float) -> void:
	var ahora := Time.get_ticks_usec()
	if _grabando and _web and is_instance_valid(_caja_grabada):
		var caja := _caja_grabada
		var real := caja.global_position
		var dibujada := caja.get_global_transform_interpolated().origin
		(
			JavaScriptBridge
			. eval(
				(
					"window.__rep && window.__rep.push([performance.now(), %d, [%f,%f,%f], [%f,%f,%f], %d])"
					% [
						int(caja.is_visible_in_tree()),
						real.x,
						real.y,
						real.z,
						dibujada.x,
						dibujada.y,
						dibujada.z,
						int(caja.get("freeze"))
					]
				)
			)
		)
	var escena := get_tree().current_scene
	if escena == null:
		return
	match _estado:
		"menu":
			if (
				not escena.has_method("empezar_partida_nueva")
				or escena.has_method("anunciar_la_noche")
			):
				return
			if (
				_web
				and (
					escena.get("_copia") == null or escena.get("_calentamiento_en_el_menu") != null
				)
			):
				return
			if _desde == 0:
				_desde = ahora
			if ahora - _desde < 1000000:
				return
			marcar("nuevo_juego")
			escena.call("empezar_partida_nueva")
			_estado = "j1_instrucciones"
		"j1_instrucciones":
			if _saltear_instrucciones(escena):
				_estado = "j1_esperando_control"
		"j2_instrucciones":
			if _saltear_instrucciones(escena):
				_estado = "j2_esperando_control"
		"j3_instrucciones":
			if _saltear_instrucciones(escena):
				_estado = "j3_esperando_control"


func _saltear_instrucciones(escena: Node) -> bool:
	if not escena.has_method("anunciar_la_noche"):
		return false
	var instrucciones: Node = escena.get("_instrucciones")
	if int(instrucciones.get("_etapa")) != 2:
		return false
	marcar("instrucciones_legibles")
	while int(instrucciones.get("_etapa")) == 2:
		instrucciones.call("_al_avanzar")
	marcar("instrucciones_ok")
	return true


## Lo llama almacen.gd al devolver el control.
func control_devuelto(escena: Node, jornada: int) -> void:
	if jornada == 1:
		_terminar_j1.call_deferred(escena)
	elif jornada == 2 and _hasta >= 3:
		_terminar_j2.call_deferred(escena)
	elif jornada == 2:
		_repro_j2.call_deferred(escena)
	else:
		_limpiar_j3.call_deferred(escena)


func _terminar_j1(escena: Node) -> void:
	await get_tree().create_timer(2.0).timeout
	_estado = "j2_instrucciones"
	marcar("fin_j1_forzado")
	escena.get("_reloj").call("avanzar", 3600.0)


func _terminar_j2(escena: Node) -> void:
	await get_tree().create_timer(VENTANA_DESPUES_DEL_CONTROL).timeout
	_estado = "j3_instrucciones"
	marcar("fin_j2_forzado")
	escena.get("_reloj").call("avanzar", 3600.0)


func _cuadros(cantidad: int) -> void:
	for _i: int in cantidad:
		await get_tree().process_frame


func _pulsar(accion: StringName) -> void:
	var evento := InputEventAction.new()
	evento.action = accion
	evento.pressed = true
	Input.parse_input_event(evento)
	var suelta := InputEventAction.new()
	suelta.action = accion
	suelta.pressed = false
	Input.parse_input_event(suelta)


func _apuntar(jugador: Node, objetivo: Vector3) -> void:
	var camara: Camera3D = jugador.get("_camara")
	var d := objetivo - camara.global_position
	jugador.get("_control").call("orientar", atan2(-d.x, -d.z))
	jugador.get("_mirada").set("_pitch", atan2(d.y, Vector2(d.x, d.z).length()))
	jugador.call("_aplicar_la_rotacion")


func _piso(jugador: Node3D, p: Vector3, excluidos: Array[RID]) -> Variant:
	var consulta := PhysicsRayQueryParameters3D.create(
		p + Vector3.UP * 1.5, p + Vector3.DOWN * 3.0, 0xFFFFFFFF
	)
	consulta.exclude = excluidos
	var golpe := jugador.get_world_3d().direct_space_state.intersect_ray(consulta)
	if golpe.is_empty() or golpe["normal"].y < 0.7:
		return null
	return golpe["position"]


func _lugar_para_mirar(
	escena: Node3D, jugador: CharacterBody3D, caja: Node3D, subir: float = 0.2
) -> Variant:
	var puerta: Node3D = escena.get_node("Estructura/puerta")
	var base := puerta.global_position - caja.global_position
	base.y = 0.0
	base = base.normalized()
	var espacio := jugador.get_world_3d().direct_space_state
	var cuerpo: CollisionShape3D = jugador.get_node("Cuerpo")
	var centro := caja.global_position + Vector3.UP * subir
	var excluidos: Array[RID] = [jugador.get_rid(), (caja as CollisionObject3D).get_rid()]
	for radio: float in RADIOS:
		for k: int in 16:
			var dir := base.rotated(Vector3.UP, TAU * k / 16.0)
			var p := caja.global_position + dir * radio
			p.y = caja.global_position.y + 0.3
			var suelo: Variant = _piso(jugador, p, excluidos)
			if suelo == null:
				continue
			var forma := PhysicsShapeQueryParameters3D.new()
			forma.shape = cuerpo.shape
			forma.transform = Transform3D(Basis.IDENTITY, (suelo as Vector3) + Vector3.UP * 0.95)
			forma.exclude = [jugador.get_rid()]
			forma.collision_mask = 0xFFFFFFFF
			if not espacio.intersect_shape(forma, 1).is_empty():
				continue
			var ojo := (suelo as Vector3) + Vector3.UP * 1.7
			var consulta := PhysicsRayQueryParameters3D.create(
					ojo, ojo + (centro - ojo) * 1.3, 0xFFFFFFFF
				)
			consulta.exclude = [jugador.get_rid()]
			var golpe := espacio.intersect_ray(consulta)
			if not golpe.is_empty() and golpe["collider"] == caja:
				return suelo
	return null


func _caminar(jugador: CharacterBody3D, hasta: Vector3, sostenida: Node3D) -> void:
	var excluidos: Array[RID] = [jugador.get_rid()]
	if sostenida is CollisionObject3D:
		excluidos.append((sostenida as CollisionObject3D).get_rid())
	var desde := jugador.global_position
	var largo := Vector2(hasta.x - desde.x, hasta.z - desde.z).length()
	var pasos := maxi(int(largo / PASO_DE_LA_CAMINATA), 1)
	for i: int in range(1, pasos + 1):
		var p := desde.lerp(hasta, float(i) / pasos)
		var suelo: Variant = _piso(jugador, p, excluidos)
		p.y = (suelo as Vector3).y if suelo != null else jugador.global_position.y
		jugador.global_position = p
		jugador.velocity = Vector3.ZERO
		var rumbo := hasta - desde
		rumbo.y = 0.0
		_apuntar(jugador, p + rumbo.normalized() * 3.0 + Vector3.UP * 1.2)
		await _cuadros(2)


func _barrer(jugador: CharacterBody3D) -> void:
	var p := jugador.global_position
	for inclinacion: float in [0.0, -0.5, 0.5]:
		for k: int in 8:
			var a := TAU * k / 8.0
			_apuntar(
				jugador,
				p + Vector3(sin(a), 0.0, cos(a)) * 3.0 + Vector3.UP * (1.7 + inclinacion * 3.0)
			)
			await _cuadros(3)


func _probar_caja(escena: Node3D, jugador: CharacterBody3D, caja: Node3D) -> bool:
	var hallado: Variant = _lugar_para_mirar(escena, jugador, caja)
	if hallado == null:
		marcar("sin_lugar", caja.name)
		return false
	var spot: Vector3 = hallado
	var pose: Transform3D = caja.call("pose_de_estanteria")
	var puerta: Node3D = escena.get_node("Estructura/puerta")
	var arranque: Transform3D = escena.get("_arranque")
	jugador.call("ubicar", Transform3D(Basis.IDENTITY, spot))
	marcar("caja", "%s %s" % [caja.name, str(caja.get("producto"))])
	_caja_grabada = caja
	_grabando = true
	await _cuadros(2)
	for _i: int in 12:
		_apuntar(jugador, caja.global_position + Vector3.UP * 0.2)
		await _cuadros(1)
	var enfocado: Variant = jugador.call("enfocado")
	marcar("enfocado", enfocado.name if enfocado is Node else "nada")
	if enfocado != caja:
		_grabando = false
		return false
	_pulsar(&"agarrar")
	await _cuadros(20)
	var agarre: Object = escena.get("_agarre")
	var sostenida: Variant = agarre.call("cuerpo_sostenido")
	marcar("agarrada", sostenida.name if sostenida is Node else "no")
	if sostenida != caja:
		_grabando = false
		return false
	var altura := jugador.global_position.y
	var puerta_en_piso := Vector3(puerta.global_position.x, altura, puerta.global_position.z)
	var adentro := Vector3(arranque.origin.x, altura, arranque.origin.z)
	marcar("camino_al_almacen")
	await _caminar(jugador, puerta_en_piso, caja)
	await _caminar(jugador, adentro, caja)
	marcar("en_el_almacen")
	await _barrer(jugador)
	marcar("camino_al_deposito")
	await _caminar(jugador, puerta_en_piso, caja)
	await _caminar(jugador, spot, caja)
	for _i: int in 10:
		_apuntar(jugador, pose.origin + Vector3.UP * 0.1)
		await _cuadros(1)
	marcar("soltando")
	_pulsar(&"agarrar")
	await _cuadros(90)
	marcar("apoyada")
	var cerca := caja.global_position + (spot - caja.global_position).normalized() * 0.9
	cerca.y = spot.y
	jugador.global_position = cerca
	for _i: int in 90:
		_apuntar(jugador, caja.global_position + Vector3.UP * 0.2)
		await _cuadros(1)
	marcar("mirada_de_cerca")
	_grabando = false
	return true


func _repro_j2(escena: Node3D) -> void:
	await get_tree().create_timer(VENTANA_DESPUES_DEL_CONTROL).timeout
	if not _con_repro:
		marcar("sonda_sin_repro")
		_volcar()
		return
	marcar("repro_inicio")
	var jugador: CharacterBody3D = escena.get("_jugador")
	var visibles: Array[Node3D] = []
	for caja: Node3D in escena.get("_cajas_de_productos"):
		if caja.is_visible_in_tree():
			visibles.append(caja)
	marcar("cajas_visibles", visibles.size())
	var hechas := 0
	for caja: Node3D in visibles:
		if hechas >= CAJAS_A_PROBAR:
			break
		if await _probar_caja(escena, jugador, caja):
			hechas += 1
	marcar("repro_fin", hechas)
	await get_tree().create_timer(1.0).timeout
	_volcar()


func _mirar(escena: Node3D, jugador: CharacterBody3D, objetivo: Node3D, subir: float) -> bool:
	var hallado: Variant = null
	for alto: float in [subir, 0.3, 0.6, 0.9, 1.2, 0.05, 1.5]:
		hallado = _lugar_para_mirar(escena, jugador, objetivo, alto)
		if hallado != null:
			subir = alto
			break
	if hallado == null:
		marcar("sin_lugar", "%s %s" % [objetivo.name, str(objetivo.global_position)])
		return false
	var spot: Vector3 = hallado
	jugador.call("ubicar", Transform3D(Basis.IDENTITY, spot))
	var centro := objetivo.global_position + Vector3.UP * subir
	for _i: int in 12:
		_apuntar(jugador, centro)
		await _cuadros(1)
	var enfocado: Variant = jugador.call("enfocado")
	marcar("enfocado", enfocado.name if enfocado is Node else "nada")
	return enfocado == objetivo


func _util(escena: Node3D, identidad: StringName) -> Node3D:
	for util: Node3D in escena.get("_utiles_de_limpieza"):
		if util.get("datos").id == identidad:
			return util
	return null


func _agarrar_util(escena: Node3D, jugador: CharacterBody3D, identidad: StringName) -> bool:
	var util := _util(escena, identidad)
	if util == null:
		marcar("sin_util", identidad)
		return false
	var malla := util.get("malla") as MeshInstance3D
	var centro := (malla.global_transform * malla.get_aabb()).get_center()
	if not await _mirar(escena, jugador, util, centro.y - util.global_position.y):
		return false
	_pulsar(&"agarrar")
	await _cuadros(30)
	var sostenida: Variant = escena.get("_agarre").call("cuerpo_sostenido")
	marcar("util_en_la_mano", "%s %s" % [identidad, sostenida == util])
	return sostenida == util


func _usar_sobre(escena: Node3D, jugador: CharacterBody3D, objetivo: Node3D, subir: float) -> void:
	if not await _mirar(escena, jugador, objetivo, subir):
		return
	_pulsar(&"agarrar")
	await _cuadros(60)
	marcar("uso_dado", objetivo.name)


## Lo suelta en el centro del local, en un lugar para cada uno: dos cuerpos soltados encima se
## expulsan entre sí.
func _soltar(escena: Node3D, jugador: CharacterBody3D, lugar: int) -> void:
	var arranque: Transform3D = escena.get("_arranque")
	var p := arranque.origin + Vector3(-2.0 + 1.0 * lugar, 0.0, 1.5)
	var suelo: Variant = _piso(jugador, p, [jugador.get_rid()])
	if suelo != null:
		p = suelo
	jugador.call("ubicar", Transform3D(Basis.IDENTITY, p))
	_apuntar(jugador, p + Vector3(0.0, 1.0, 3.0))
	await _cuadros(5)
	escena.get("_agarre").call("soltar", true)
	await _cuadros(90)


func _limpiar_j3(escena: Node3D) -> void:
	await get_tree().create_timer(VENTANA_DESPUES_DEL_CONTROL).timeout
	if not _con_repro:
		marcar("sonda_sin_repro")
		_volcar()
		return
	marcar("limpieza_inicio")
	var jugador: CharacterBody3D = escena.get("_jugador")
	var limpiador: Object = escena.get("_limpiador")
	var piso: Object = limpiador.call("piso")
	var mancha: Node3D = null
	for candidata: Node3D in escena.get("_limpieza").call("manchas"):
		if (
			PisoDelLocal.superficie_de(candidata.call("lugar_de_la_mancha"))
			== PisoDelLocal.Superficie.PISO
		):
			mancha = candidata
			break
	marcar("mancha", mancha.name if mancha != null else "ninguna")
	var jabon: StringName = &"jabon_azul"
	if mancha != null:
		var estado: Object = piso.call("mancha_de", mancha.call("lugar_de_la_mancha"))
		var agua: int = ReglasDeLaLimpieza.AGUA_QUE_BORRA[estado.call("tipo")]
		for id: StringName in ReglasDeLaLimpieza.JABONES:
			if ReglasDeLaLimpieza.JABONES[id] == agua:
				jabon = id
	var lugar := 3
	for id: StringName in ReglasDeLaLimpieza.JABONES:
		if id != jabon and await _agarrar_util(escena, jugador, id):
			await _soltar(escena, jugador, lugar)
			lugar += 1
	var lavatorio: Node3D = escena.get_node("Estructura/vanitory/StaticBody3D")
	var balde := _util(escena, &"balde")
	if await _agarrar_util(escena, jugador, &"balde"):
		await _usar_sobre(escena, jugador, lavatorio, 0.0)
		await _soltar(escena, jugador, 0)
	if await _agarrar_util(escena, jugador, jabon):
		await _usar_sobre(escena, jugador, balde, 0.1)
		await _soltar(escena, jugador, 1)
	if await _agarrar_util(escena, jugador, &"mopa"):
		await _usar_sobre(escena, jugador, balde, 0.1)
		if mancha != null:
			await _usar_sobre(escena, jugador, mancha, 0.0)
			await _usar_sobre(escena, jugador, mancha, 0.0)
		await _soltar(escena, jugador, 2)
	marcar("limpieza_fin")
	await get_tree().create_timer(1.0).timeout
	_volcar()


func _volcar() -> void:
	print("[med] LISTO")
	if _web:
		JavaScriptBridge.eval("window.__med_listo = true")
	else:
		get_tree().quit()
