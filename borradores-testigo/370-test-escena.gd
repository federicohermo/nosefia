extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const BolsaEnLaMano := preload("res://test/escenas/bolsa_en_la_mano.gd")
const CONTENEDOR := "Estructura/deposito_contenedor_soporte/deposito_contenedor_cuerpo/StaticBody3D"


func _abrir(jornada: int = 2) -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	almacen.set("_partida", Partida.desde({"jornada": jornada, "medios": 0}))
	add_child(almacen)
	almacen.get("_jugador").set_physics_process(false)
	for _cuadro in 3:
		await get_tree().physics_frame
	return almacen


func _accion(almacen: Node3D, objetivo: Node3D, accion: StringName) -> void:
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set("_enfocado", objetivo)
	var evento := InputEventAction.new()
	evento.action = accion
	evento.pressed = true
	jugador.call("_unhandled_input", evento)


func _cumplidas(almacen: Node3D) -> int:
	var partida: Partida = almacen.get("_partida")
	return (
		partida.obligatorias().filter(func(tarea: Tarea) -> bool: return tarea.completada()).size()
	)


func test_solo_la_segunda_noche_muestra_bolsas_en_los_tachos() -> void:  # AC-CLN-007
	for jornada in range(1, 6):
		var almacen := await _abrir(jornada)
		var bolsas: Array[Node3D] = almacen.get("_bolsas")
		for numero in bolsas.size():
			var bolsa := bolsas[numero] as ObjetoAgarrable
			assert_bool(bolsa.visible).is_equal(jornada == 2)
			assert_bool(bolsa.freeze).is_true()
			assert_bool(bolsa.get_node("Forma").disabled).is_true()
			var tacho := almacen.get_node(BolsaEnLaMano.RUTAS[numero]) as StaticBody3D
			assert_bool(tacho.is_in_group(ReglasDelJugador.GRUPO_INTERACTUABLE)).is_true()
			assert_int(tacho.get("tacho")).is_equal(numero)
			assert_str(bolsa.datos.id).is_equal(ReglasDeLaBasura.id_de_la_bolsa(numero + 1))
			if jornada != 2:
				_accion(almacen, tacho, ReglasDelJugador.ACCION_USAR)
				assert_object((almacen.get("_agarre") as Agarre).manos().sostenido()).is_null()
		almacen.queue_free()
		await get_tree().process_frame


func test_los_tres_tachos_enfocados_entregan_y_la_tercera_cuenta() -> void:  # AC-CLN-054 AC-CLN-012
	var almacen := await _abrir()
	var recolector: RecolectorDeBasura = almacen.get("_recolector")
	var agarre: Agarre = almacen.get("_agarre")
	var reloj: RelojDelTurno = almacen.get("_reloj")
	var hud: Label = almacen.get("_hud").get("_tareas")
	var avisos: Array[int] = []
	reloj.tarea_completada.connect(func(cantidad: int) -> void: avisos.append(cantidad))
	var previo := _cumplidas(almacen)
	for numero in 3:
		var tacho := almacen.get_node(BolsaEnLaMano.RUTAS[numero]) as StaticBody3D
		assert_bool(await BolsaEnLaMano.enfocar(almacen, tacho)).is_true()
		assert_object((tacho.get_parent() as MeshInstance3D).material_overlay).is_not_null()
		var candidato: CampoDeInteraccion.Candidato = almacen.get("_jugador").call(
			"_medir_candidato", tacho
		)
		assert_bool(candidato.visible).is_true()
		assert_float(candidato.distancia).is_less_equal(ReglasDelJugador.ALCANCE_DE_LA_MIRA)
		var bolsa: ObjetoAgarrable = almacen.get("_bolsas")[numero]
		var boca := bolsa.global_position
		_accion(almacen, tacho, ReglasDelJugador.ACCION_USAR)
		assert_object(agarre.cuerpo_sostenido()).is_same(bolsa)
		assert_bool(recolector.tarea().tiene_bolsa(numero)).is_false()
		assert_bool(bolsa.global_position.is_equal_approx(boca)).is_false()
		assert_bool(bolsa.get_node("Forma").disabled).is_false()
		assert_int(recolector.tarea().depositadas()).is_equal(numero)
		_accion(almacen, almacen.get_node(CONTENEDOR), ReglasDeLosObjetos.ACCION_AGARRAR)
		assert_object(agarre.manos().sostenido()).is_null()
		assert_bool(reloj.obligatoria(Tarea.Tipo.SACAR_LA_BASURA).completada()).is_equal(
			numero == 2
		)
	assert_int(_cumplidas(almacen)).is_equal(previo + 1)
	assert_array(avisos).contains([previo + 1])
	assert_str(hud.text).contains(str(previo + 1))


func test_izquierdo_mano_ocupada_repeticion_y_suspension_no_extraen() -> void:  # AC-CLN-055
	var almacen := await _abrir()
	var jugador: Node3D = almacen.get("_jugador")
	var agarre: Agarre = almacen.get("_agarre")
	var recolector: RecolectorDeBasura = almacen.get("_recolector")
	var primero := almacen.get_node(BolsaEnLaMano.RUTAS[0])
	var segundo := almacen.get_node(BolsaEnLaMano.RUTAS[1])
	_accion(almacen, primero, ReglasDeLosObjetos.ACCION_AGARRAR)
	assert_object(agarre.manos().sostenido()).is_null()
	assert_bool(recolector.tarea().tiene_bolsa(0)).is_true()
	jugador.call("suspender")
	_accion(almacen, primero, ReglasDelJugador.ACCION_USAR)
	assert_bool(recolector.tarea().tiene_bolsa(0)).is_true()
	assert_object(agarre.manos().sostenido()).is_null()
	jugador.call("reanudar")
	_accion(almacen, primero, ReglasDelJugador.ACCION_USAR)
	var sostenido := agarre.cuerpo_sostenido()
	for objetivo: Node3D in [primero, segundo]:
		_accion(almacen, objetivo, ReglasDeLosObjetos.ACCION_AGARRAR)
		_accion(almacen, objetivo, ReglasDelJugador.ACCION_USAR)
		assert_object(agarre.cuerpo_sostenido()).is_same(sostenido)
	assert_bool(recolector.tarea().tiene_bolsa(1)).is_true()
	assert_int(recolector.tarea().depositadas()).is_zero()
	agarre.soltar(false)
	_accion(almacen, primero, ReglasDelJugador.ACCION_USAR)
	assert_object(agarre.manos().sostenido()).is_null()


func test_rescate_devuelve_cuerpo_libre_sin_reponer_el_tacho() -> void:  # AC-CLN-056
	var almacen := await _abrir()
	var bolsa := BolsaEnLaMano.sacar(almacen)
	assert_object(bolsa).is_not_null()
	var agarre: Agarre = almacen.get("_agarre")
	var id := bolsa.datos.id
	agarre.soltar(false)
	bolsa.global_position = Vector3(2.0, 5.9, -11.0)
	var red: RedDeSeguridad = almacen.get_node("Servicios/RedDeSeguridad")
	red.revisar(bolsa)
	assert_array(red.rescates).is_not_empty()
	assert_int(red.rescates[-1]["clase"]).is_equal(Rescate.Clase.ORIGEN)
	assert_bool(bolsa.freeze).is_false()
	assert_int(bolsa.collision_layer).is_not_equal(0)
	assert_bool(bolsa.visible).is_true()
	assert_bool(almacen.get("_recolector").tarea().tiene_bolsa(0)).is_false()
	assert_str(bolsa.datos.id).is_equal(id)
	_accion(almacen, bolsa, ReglasDeLosObjetos.ACCION_AGARRAR)
	assert_object(agarre.cuerpo_sostenido()).is_same(bolsa)
	_accion(almacen, almacen.get_node(CONTENEDOR), ReglasDeLosObjetos.ACCION_AGARRAR)
	assert_int(almacen.get("_recolector").tarea().depositadas()).is_equal(1)
	_accion(almacen, almacen.get_node(BolsaEnLaMano.RUTAS[0]), ReglasDelJugador.ACCION_USAR)
	assert_object(agarre.manos().sostenido()).is_null()


func test_la_pendiente_en_tacho_piso_o_mano_no_cruza_de_noche() -> void:  # AC-CLN-057 AC-CLN-038
	for estado in 3:
		var almacen := await _abrir()
		var agarre: Agarre = almacen.get("_agarre")
		for numero in 2:
			BolsaEnLaMano.sacar(almacen, numero)
			_accion(almacen, almacen.get_node(CONTENEDOR), ReglasDeLosObjetos.ACCION_AGARRAR)
		if estado > 0:
			BolsaEnLaMano.sacar(almacen, 2)
			if estado == 1:
				agarre.soltar(false)
		var reloj: RelojDelTurno = almacen.get("_reloj")
		assert_bool(reloj.obligatoria(Tarea.Tipo.SACAR_LA_BASURA).completada()).is_false()
		reloj.avanzar(Reglas.DURACION_DEL_TURNO)
		assert_bool(reloj.obligatoria(Tarea.Tipo.SACAR_LA_BASURA).completada()).is_false()
		almacen.call("_seguir")
		assert_int((almacen.get("_partida") as Partida).jornada()).is_equal(3)
		assert_object(agarre.manos().sostenido()).is_null()
		for bolsa: ObjetoAgarrable in almacen.get("_bolsas"):
			assert_bool(bolsa.visible).is_false()
			assert_bool(bolsa.get_node("Forma").disabled).is_true()
		almacen.queue_free()
		await get_tree().process_frame


func test_la_nota_de_la_segunda_jornada_nombra_tirar_quinta() -> void:  # AC-PLY-069
	var almacen := await _abrir()
	var hoja := almacen.get_node("Estructura/NotasDelAlmacen").get("notas")[0] as Node
	var dato: NotaPegada = hoja.call("dato")
	assert_array(dato.renglones()).has_size(5)
	assert_str(dato.renglones()[4]).is_equal("Tirar la basura")
