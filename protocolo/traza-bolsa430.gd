## Diagnóstico externo: replica las tres fases de AC-PLY-035 sin sustituir el jugador.
extends SceneTree

const BolsaEnLaMano = preload("res://test/escenas/bolsa_en_la_mano.gd")
var local: Node3D
var fases: Array[Dictionary] = []
var destino := "C:/Users/fede_/AppData/Local/Temp/nosefia-batch-425-435/428/traza-bolsa430.json"


func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--salida="):
			destino = arg.trim_prefix("--salida=")
	call_deferred("_ejecutar")


func _ejecutar() -> void:
	print("TRAZA428_BOLSA_INICIO AC-PLY-035 MISMO_FIXTURE_SIN_SOURCE_PATCH")
	local = load("res://src/escenas/almacen.tscn").instantiate()
	root.add_child(local)
	await physics_frame
	var jugador: Node3D = local.get("_jugador")
	jugador.set_physics_process(false)
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	var bolsa := BolsaEnLaMano.preparar(local)
	var numero := 0
	for punto: Vector3 in [
		camara.global_position + jugador.frente() * 10.0,
		camara.global_position + Vector3.UP * 10.0 + jugador.frente() * 0.1
	]:
		camara.look_at(punto)
		_soltar_y_registrar("sin-superficie-%d" % numero, bolsa)
		numero += 1
	var otra := BolsaEnLaMano.preparar(local, 1)
	var piso: Vector3 = jugador.global_position + jugador.frente() * 1.2
	camara.look_at(piso)
	var toca: Vector3 = _golpe(jugador, bolsa)["position"]
	var media: Vector3 = (otra.get_node("Forma").shape as BoxShape3D).size / 2.0
	# Mismo montaje explícito del test, no es foco falso ni un resultado de producción.
	otra.global_position = toca + Vector3(media.x * 1.5, media.y, 0.0)
	await physics_frame
	camara.look_at(piso)
	_soltar_y_registrar("piso-encimado-con-otra", bolsa)
	var apoyo: Vector3 = local.get("_reposicion_manual").call("_apoyo", Producto.Id.UAKAS)
	var estante := apoyo + Vector3.LEFT * 0.12
	camara.global_position = estante + Vector3(2.0, 1.4, 0.0)
	camara.look_at(estante)
	var testigo := _golpe(jugador, bolsa, true)
	print("TRAZA428_BOLSA_PREMISA ", testigo, " estante_esperado=", local.get("_estante"))
	_soltar_y_registrar("estante-interior-tercer-bloque", bolsa)
	# Relectura posterior rotulada: el return de la señal original no es observable.
	# No se inyecta un script ni se presenta esta llamada como el return del primer gesto.
	var antes_relectura := bolsa.global_transform
	var admite: bool = jugador.call("_apoyar_sobre_lo_mirado", bolsa)
	var despues_relectura := bolsa.global_transform
	var extra := {
		"tipo": "relectura posterior, separada del gesto original",
		"apoyar_sobre_lo_mirado_bool": admite,
		"pose_antes": antes_relectura,
		"pose_despues": despues_relectura,
		"idempotente": antes_relectura.is_equal_approx(despues_relectura)
	}
	print("TRAZA428_BOLSA_RELECTURA ", extra)
	var archivo := FileAccess.open(destino, FileAccess.WRITE)
	archivo.store_string(
		JSON.stringify(
			_json({"fases": fases, "testigo_estante": testigo, "relectura": extra}), "\t"
		)
	)
	archivo = null
	for audio: Node in local.find_children("*", "Node", true, false):
		if audio is AudioStreamPlayer or audio is AudioStreamPlayer3D:
			audio.call("stop")
			audio.set("stream", null)
	local.queue_free()
	local = null
	for cuadro in 4:
		await process_frame
	print(
		"TRAZA428_BOLSA_FINAL diagnostico_completo=true fases=",
		fases.size(),
		" AC035_ultima_coincide=",
		fases[-1].coincide_001,
		" relectura_idempotente=",
		extra.idempotente
	)
	quit(0 if extra.idempotente else 3)


func _soltar_y_registrar(nombre: String, bolsa: RigidBody3D) -> void:
	var jugador: Node3D = local.get("_jugador")
	var agarre: Agarre = local.get("_agarre")
	var sin_mira := agarre.punto_de_soltado.global_position
	var mascara_original := bolsa.collision_mask
	# Agarre apaga la mascara mientras sostiene: medir el rayo con la mascara original.
	var golpe: Dictionary = jugador.call("_golpe_de_la_mira", bolsa)
	var entrada := {
		"fase": nombre,
		"mira_real": jugador.mira(),
		"expected_sin_mira": sin_mira,
		"ray_shape_mask": bolsa.collision_mask,
		"rayo_crudo": _golpe(jugador, bolsa),
		"rayo_sin_contorno": _golpe(jugador, bolsa, true)
	}
	if not agarre.pedir_agarrar(bolsa.get("datos"), bolsa):
		print("TRAZA428_BOLSA_ERROR no se pudo agarrar ", nombre)
		quit(2)
		return
	entrada["golpe_admitido_por_normal"] = golpe
	if not golpe.is_empty():
		var formas := _formas(bolsa)
		var limites: AABB = jugador.call("_limites_de", bolsa, formas)
		var candidato: Vector3 = (
			golpe.position + Vector3.UP * (ReglasDeLosObjetos.ROCE - limites.position.y)
		)
		var pose_candidata := bolsa.global_transform
		pose_candidata.origin = candidato
		entrada["base_relativa"] = limites.position.y
		entrada["candidato_apuntar"] = pose_candidata
		entrada["predicados_candidato_sin_mover_bolsa"] = _predicados(
			bolsa, pose_candidata, mascara_original
		)
	# Único gesto real; sin pasos de física entre éste y la lectura de resultado.
	agarre.soltar(true)
	entrada["actual_inmediato"] = bolsa.global_transform
	var diferencia := (bolsa.global_position - sin_mira).abs()
	entrada["diferencia"] = diferencia
	entrada["coincide_001"] = diferencia.x <= 0.01 and diferencia.y <= 0.01 and diferencia.z <= 0.01
	entrada["entra_entero_bool_en_actual"] = jugador.call("_entra_entero", bolsa, _formas(bolsa))
	entrada["predicados_actual"] = _predicados(bolsa, bolsa.global_transform)
	fases.append(entrada)
	print("TRAZA428_BOLSA_FASE ", entrada)


func _formas(cuerpo: RigidBody3D) -> Array[CollisionShape3D]:
	var formas: Array[CollisionShape3D] = []
	formas.assign(cuerpo.find_children("*", "CollisionShape3D", false, false))
	return formas


func _predicados(
	cuerpo: RigidBody3D, pose: Transform3D, mascara_original := -1
) -> Array[Dictionary]:
	var salida: Array[Dictionary] = []
	for forma: CollisionShape3D in _formas(cuerpo):
		var t := pose * cuerpo.global_transform.affine_inverse() * forma.global_transform
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = forma.shape
		q.transform = t
		q.collision_mask = (
			(cuerpo.collision_mask if mascara_original < 0 else mascara_original)
			| ReglasDeLosObjetos.CAPA_DEL_CONTORNO
		)
		q.exclude = [cuerpo.get_rid()]
		var solidos := local.get_world_3d().direct_space_state.intersect_shape(q, 32)
		var reservas: Array[Dictionary] = []
		for cuerpo_mueble: PhysicsBody3D in local.get("_muebles_con_contorno"):
			var malla := cuerpo_mueble.get_parent() as MeshInstance3D
			reservas.append(
				{
					"mueble": str(malla.get_path()),
					"volumen": malla.get_aabb(),
					"transform": malla.global_transform,
					"SAT":
					ReservaDeLaGondola.se_superponen(
						LimitesDeForma.de(forma.shape), t, malla.get_aabb(), malla.global_transform
					)
				}
			)
		salida.append(
			{
				"forma": str(forma.get_path()),
				"volumen_local": LimitesDeForma.de(forma.shape),
				"transform": t,
				"mascara": q.collision_mask,
				"consulta_fisica_libre": solidos.is_empty(),
				"colliders": solidos,
				"reservas": reservas
			}
		)
	return salida


func _golpe(jugador: Node3D, cuerpo: RigidBody3D, sin_contorno := false) -> Dictionary:
	var mascara := cuerpo.collision_mask
	if sin_contorno:
		mascara &= ~ReglasDeLosObjetos.CAPA_DEL_CONTORNO
	var ojo: Transform3D = jugador.mira()
	var q := PhysicsRayQueryParameters3D.create(
		ojo.origin, ojo.origin - ojo.basis.z * ReglasDelJugador.ALCANCE_DE_LA_MIRA, mascara
	)
	q.exclude = [jugador.get_rid(), cuerpo.get_rid()]
	return jugador.get_world_3d().direct_space_state.intersect_ray(q)


func _json(v: Variant) -> Variant:
	var resultado: Variant = v
	if v is Vector3:
		resultado = [v.x, v.y, v.z]
	elif v is Transform3D:
		resultado = {
			"origen": _json(v.origin),
			"x": _json(v.basis.x),
			"y": _json(v.basis.y),
			"z": _json(v.basis.z)
		}
	elif v is AABB:
		resultado = {"posicion": _json(v.position), "tamano": _json(v.size)}
	elif v is Array:
		var a := []
		for x: Variant in v:
			a.append(_json(x))
		resultado = a
	elif v is Dictionary:
		var d := {}
		for k: Variant in v:
			d[str(k)] = _json(v[k])
		resultado = d
	elif v is Node:
		resultado = str(v.get_path())
	elif v is Object or v is RID:
		resultado = str(v)
	return resultado
