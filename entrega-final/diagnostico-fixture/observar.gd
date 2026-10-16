extends SceneTree

const BolsaEnLaMano := preload("res://test/escenas/bolsa_en_la_mano.gd")
const DESTINO := (
	"C:/Users/fede_/AppData/Local/Temp/nosefia-batch-425-435/"
	+ "434-observer-superficie01/medicion.json"
)
var _mediciones: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_probar")


func _golpe(jugador: Node3D, bolsa: RigidBody3D, sin_contorno := false) -> Dictionary:
	var mascara := bolsa.collision_mask
	if sin_contorno:
		mascara &= ~ReglasDeLosObjetos.CAPA_DEL_CONTORNO
	var ojo: Transform3D = jugador.mira()
	var consulta := PhysicsRayQueryParameters3D.create(
		ojo.origin, ojo.origin - ojo.basis.z * ReglasDelJugador.ALCANCE_DE_LA_MIRA, mascara
	)
	consulta.exclude = [jugador.get_rid(), bolsa.get_rid()]
	return jugador.get_world_3d().direct_space_state.intersect_ray(consulta)


func _hit(golpe: Dictionary) -> Dictionary:
	if golpe.is_empty():
		return {}
	return {
		"collider": str(golpe["collider"].get_path()),
		"position": str(golpe["position"]),
		"normal": str(golpe["normal"]),
		"normal_y": golpe["normal"].y,
		"shape": golpe.get("shape"),
		"face_index": golpe.get("face_index")
	}


func _reserva(jugador: Node3D, forma: CollisionShape3D, pose: Transform3D) -> Array[String]:
	var choques: Array[String] = []
	for cuerpo: PhysicsBody3D in jugador.get("muebles_con_reserva"):
		var malla := cuerpo.get_parent() as MeshInstance3D
		if (
			malla != null
			and malla.mesh != null
			and ReservaDeLaGondola.se_superponen(
				LimitesDeForma.de(forma.shape), pose, malla.get_aabb(), malla.global_transform
			)
		):
			choques.append(str(malla.get_path()))
	return choques


func _volumen(jugador: Node3D, bolsa: RigidBody3D, pose: Transform3D, mascara: int) -> Dictionary:
	var formas: Array[Dictionary] = []
	var libre := true
	for forma: CollisionShape3D in bolsa.find_children("*", "CollisionShape3D", true, false):
		if forma.disabled or forma.shape == null:
			continue
		var global := pose * forma.transform
		var consulta := PhysicsShapeQueryParameters3D.new()
		consulta.shape = forma.shape
		consulta.transform = global
		consulta.collision_mask = mascara | ReglasDeLosObjetos.CAPA_DEL_CONTORNO
		consulta.exclude = [bolsa.get_rid()]
		consulta.margin = 0.0
		var fisicos: Array[String] = []
		for toque: Dictionary in jugador.get_world_3d().direct_space_state.intersect_shape(
			consulta, 32
		):
			fisicos.append(str(toque["collider"].get_path()))
		var reservas := _reserva(jugador, forma, global)
		libre = libre and fisicos.is_empty() and reservas.is_empty()
		formas.append(
			{
				"ruta": str(forma.get_path()),
				"tipo": forma.shape.get_class(),
				"aabb_local": str(LimitesDeForma.de(forma.shape)),
				"pose": str(global),
				"fisicos": fisicos,
				"reservas_sat": reservas
			}
		)
	return {"libre_fisica_y_sat": libre, "formas": formas}


func _soltar(almacen: Node3D, bolsa: RigidBody3D) -> void:
	var agarre: Agarre = almacen.get("_agarre")
	assert(agarre.pedir_agarrar(bolsa.get("datos"), bolsa))
	agarre.soltar(true)


func _registrar(almacen: Node3D, bolsa: RigidBody3D, etiqueta: String, extra: Dictionary) -> void:
	var jugador: Node3D = almacen.get("_jugador")
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	var agarre: Agarre = almacen.get("_agarre")
	var golpe := _golpe(jugador, bolsa, true)
	var mascara := bolsa.collision_mask
	assert(agarre.pedir_agarrar(bolsa.get("datos"), bolsa))
	var mano := agarre.punto_de_soltado.global_position
	var derecha: Basis = jugador.call("_derecho", bolsa.global_basis)
	var pose := Transform3D(derecha, mano)
	var datos := {
		"etiqueta": etiqueta,
		"jugador": str(jugador.global_transform),
		"giro": str(jugador.get_node("Giro").global_transform),
		"camara": str(camara.global_transform),
		"mano_ruta": str(agarre.punto_de_soltado.get_path()),
		"mano": str(agarre.punto_de_soltado.global_transform),
		"rayo": _hit(golpe),
		"hand_completo": _volumen(jugador, bolsa, pose, mascara),
		"extra": extra
	}
	if not golpe.is_empty():
		var minimo := INF
		for forma: CollisionShape3D in bolsa.find_children("*", "CollisionShape3D", true, false):
			var limites: AABB = (
				Transform3D(derecha) * forma.transform * LimitesDeForma.de(forma.shape)
			)
			minimo = minf(minimo, limites.position.y)
		var apoyada := Transform3D(
			derecha, golpe["position"] + Vector3.UP * (ReglasDeLosObjetos.ROCE - minimo)
		)
		datos["volumen_sobre_objetivo"] = _volumen(jugador, bolsa, apoyada, mascara)
	agarre.soltar(true)
	datos["resultado_posicion"] = str(bolsa.global_position)
	datos["resultado_distancia_hand"] = bolsa.global_position.distance_to(mano)
	_mediciones.append(datos)


func _probar() -> void:
	for caso in 2:
		var almacen: Node3D = load("res://src/escenas/almacen.tscn").instantiate()
		root.add_child(almacen)
		await physics_frame
		var jugador: CharacterBody3D = almacen.get("_jugador")
		jugador.set_physics_process(false)
		var camara: Camera3D = jugador.get_node("Giro/Camara")
		var bolsa := BolsaEnLaMano.preparar(almacen)
		assert(bolsa != null)
		var puesto: Node3D = almacen.get("_reposicion_manual")
		var apoyo: Vector3 = puesto.call("_apoyo", Producto.Id.UAKAS)
		if caso == 0:
			# Reproduce los dos bordes previos antes de la pose heredada, sin cambiar producción.
			for punto: Vector3 in [
				camara.global_position + jugador.frente() * 10.0,
				camara.global_position + Vector3.UP * 10.0 + jugador.frente() * 0.1
			]:
				camara.look_at(punto)
				_soltar(almacen, bolsa)
			var otra := BolsaEnLaMano.preparar(almacen, 1)
			var piso: Vector3 = jugador.global_position + jugador.frente() * 1.2
			camara.look_at(piso)
			var toca: Vector3 = _golpe(jugador, bolsa)["position"]
			var media: Vector3 = (otra.get_node("Forma").shape as BoxShape3D).size / 2.0
			otra.global_position = toca + Vector3(media.x * 1.5, media.y, 0.0)
			await physics_frame
			camara.look_at(piso)
			_soltar(almacen, bolsa)
			var estante := apoyo + Vector3.LEFT * 0.12
			camara.global_position = estante + Vector3(2.0, 1.4, 0.0)
			camara.look_at(estante)
			_registrar(
				almacen, bolsa, "legado-exacto", {"apoyo": str(apoyo), "estante": str(estante)}
			)
		else:
			var disposicion: DisposicionDeLaGondola = puesto.get("disposicion")
			var frente := DisposicionDeLaGondola.frente(
				disposicion.principales[Producto.Id.UAKAS],
				disposicion.filas_de_adelante[Producto.Id.UAKAS]
			)
			var objetivo := apoyo - frente * 0.12
			var distancia := 1.3
			var lateral := 1.0
			var candidato := objetivo + frente * distancia + frente.cross(Vector3.UP) * lateral
			var suelo := PhysicsRayQueryParameters3D.create(
				Vector3(candidato.x, 3.0, candidato.z), Vector3(candidato.x, -1.0, candidato.z), 1
			)
			suelo.exclude = [jugador.get_rid(), bolsa.get_rid()]
			var piso := jugador.get_world_3d().direct_space_state.intersect_ray(suelo)
			var extra := {
				"apoyo": str(apoyo),
				"objetivo": str(objetivo),
				"frente": str(frente),
				"distancia": distancia,
				"lateral": lateral,
				"piso": _hit(piso)
			}
			if not piso.is_empty():
				# La holgura de 5 mm es la del fixture existente BolsaEnLaMano.sitios.
				var pie: Vector3 = piso["position"] + Vector3.UP * 0.005
				jugador.ubicar(Transform3D(Basis.IDENTITY, pie))
				camara.position = Vector3.UP * ReglasDelJugador.ALTURA_DE_LA_CAMARA
				var vista := Transform3D(Basis.IDENTITY, camara.global_position).looking_at(
					objetivo
				)
				var angulos := vista.basis.get_euler()
				var control: ControlDelJugador = jugador.get("_control")
				control.orientar(angulos.y)
				control.girar(Vector2(0, -angulos.x / ReglasDelJugador.SENSIBILIDAD_DEL_MOUSE))
				control.avanzar_el_dibujo(1.0)
				jugador.call("_aplicar_la_rotacion")
				await physics_frame
				var cuerpo: CollisionShape3D = jugador.get_node("Cuerpo")
				var consulta := PhysicsShapeQueryParameters3D.new()
				consulta.shape = cuerpo.shape
				consulta.transform = cuerpo.global_transform
				consulta.collision_mask = jugador.collision_mask
				consulta.exclude = [jugador.get_rid(), bolsa.get_rid()]
				consulta.margin = 0.0
				extra["jugador_entra"] = (
					jugador.get_world_3d().direct_space_state.intersect_shape(consulta).is_empty()
				)
				_registrar(almacen, bolsa, "candidato-%02d" % caso, extra)
		for tipo: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
			for audio: Node in almacen.find_children("*", tipo, true, false):
				audio.call("stop")
				audio.set("stream", null)
		almacen.queue_free()
		for cuadro in 3:
			await physics_frame
	var archivo := FileAccess.open(DESTINO, FileAccess.WRITE)
	archivo.store_string(JSON.stringify(_mediciones, "\t"))
	archivo.close()
	print("434_OBSERVER_SUPERFICIE_COMPLETO")
	quit(0)
