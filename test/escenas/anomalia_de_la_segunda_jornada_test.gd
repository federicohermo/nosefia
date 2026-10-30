extends GdUnitTestSuite

const ReglasDelCierre := preload("res://src/dominio/almacen/reglas_del_cierre.gd")
const RelojDePrueba := preload("res://test/reloj_de_prueba.gd")
const CUERPO := (
	"Estructura/deposito_contenedor_grande_soporte/"
	+ "deposito_contenedor_grande_cuerpo/StaticBody3D"
)

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


func _abrir(
	jornada: int = AnomaliasDeLaJornada.JORNADA_SIN_AZUL, desde_checkpoint: bool = false
) -> Node3D:
	_almacen = load("res://src/escenas/almacen.tscn").instantiate()
	if not desde_checkpoint:
		_almacen.set("_partida", Partida.desde({"jornada": jornada, "medios": 0}))
	assert_int(_almacen.get("_partida").jornada()).is_equal(jornada)
	add_child(_almacen)
	for cuadro in 3:
		await get_tree().physics_frame
	_almacen.get("_jugador").set_physics_process(false)
	return _almacen


func _clic(objetivo: Node3D) -> void:
	var jugador: Node3D = _almacen.get("_jugador")
	jugador.set("_enfocado", objetivo)
	var evento := InputEventMouseButton.new()
	evento.button_index = MOUSE_BUTTON_LEFT
	evento.pressed = true
	jugador.call("_unhandled_input", evento)
	evento.pressed = false
	jugador.call("_unhandled_input", evento)


func _azul_ausente() -> void:
	var azul: ObjetoAgarrable = _almacen.get_node("Objetos/JabonAzul")
	assert_bool(azul.is_visible_in_tree()).is_false()
	assert_int(azul.collision_layer).is_zero()
	assert_int(azul.collision_mask).is_zero()
	assert_bool(azul.freeze).is_true()
	var jugador: Node3D = _almacen.get("_jugador")
	var candidato: CampoDeInteraccion.Candidato = jugador.call("_medir_candidato", azul)
	assert_bool(candidato.visible).is_false()
	var estados: Array[ReglasDelCierre.Estado] = _almacen.call("_estados_del_cierre")
	var utiles := 0
	for estado: ReglasDelCierre.Estado in estados:
		if estado.clase == ReglasDelCierre.Clase.UTIL_DE_LIMPIEZA:
			utiles += 1
	assert_int(utiles).is_equal(4)


func _unidad(de_gondola: bool = false) -> ObjetoAgarrable:
	var puesto: Node3D = _almacen.get("_reposicion_manual")
	var agarre: Agarre = _almacen.get("_agarre")
	if de_gondola:
		var estante: Estante = _almacen.get("_repositor").estante()
		var ocupados := estante.casilleros_ocupados(Catalogo.de(Producto.Id.POETICO))
		assert_array(ocupados).is_not_empty()
		puesto.call("agarrar_de_la_gondola", Producto.Id.POETICO, ocupados.back())
	else:
		puesto.call("retirar", Producto.Id.POETICO)
	assert_object(agarre.manos().sostenido()).is_instanceof(UnidadDeProducto)
	assert_int((agarre.manos().sostenido() as UnidadDeProducto).producto.id).is_equal(
		Producto.Id.POETICO
	)
	return agarre.cuerpo_sostenido() as ObjetoAgarrable


func _cantidades() -> Array[int]:
	var estante: Estante = _almacen.get("_repositor").estante()
	var producto := Catalogo.de(Producto.Id.POETICO)
	return [
		estante.unidades_en_deposito(producto),
		estante.unidades_en_gondola(producto),
		estante.reservadas(producto),
		_almacen.get("_repositor").caja(Producto.Id.POETICO).unidades(),
	]


func _mirar_desde_piso_libre(objetivo: Node3D) -> void:
	var jugador: CharacterBody3D = _almacen.get("_jugador")
	var forma: CollisionShape3D = jugador.get_node("Cuerpo")
	var espacio := jugador.get_world_3d().direct_space_state
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma.shape
	consulta.collision_mask = jugador.collision_mask
	consulta.exclude = [jugador.get_rid()]
	var encontrada := Vector3.INF
	for distancia: float in [0.6, 0.9, 1.2, 1.5]:
		# Las diagonales también: contra un rincón con otros útiles, las cuatro rectas se tapan.
		for direccion: Vector3 in [
			Vector3.BACK,
			Vector3.LEFT,
			Vector3.FORWARD,
			Vector3.RIGHT,
			(Vector3.FORWARD + Vector3.LEFT).normalized(),
			(Vector3.FORWARD + Vector3.RIGHT).normalized(),
			(Vector3.BACK + Vector3.LEFT).normalized(),
			(Vector3.BACK + Vector3.RIGHT).normalized(),
		]:
			var punto := objetivo.global_position + direccion * distancia
			var rayo := PhysicsRayQueryParameters3D.create(
				Vector3(punto.x, 3.0, punto.z), Vector3(punto.x, -1.0, punto.z), 1
			)
			rayo.exclude = [jugador.get_rid()]
			var golpe := espacio.intersect_ray(rayo)
			if golpe.get("collider") != _almacen.get_node("Estructura/SueloSolido"):
				continue
			var pie: Vector3 = golpe.position + Vector3.UP * 0.005
			consulta.transform = Transform3D(Basis.IDENTITY, pie + forma.position)
			if espacio.intersect_shape(consulta, 1).is_empty():
				encontrada = pie
				break
		if encontrada.is_finite():
			break
	assert_bool(encontrada.is_finite()).override_failure_message(objetivo.name).is_true()
	if not encontrada.is_finite():
		return
	jugador.ubicar(Transform3D(Basis.IDENTITY, encontrada))
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	camara.look_at(objetivo.global_position + Vector3.UP * 0.1)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_array(espacio.intersect_shape(consulta, 1)).is_empty()
	jugador.call("_leer_la_mira")
	assert_object(jugador.enfocado()).is_same(objetivo)


# AC-ANO-001 AC-CLN-018
func test_la_disponibilidad_de_lavandina_cubre_las_cinco_jornadas() -> void:
	await _abrir(ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA)
	for jornada in range(
		ReglasDeLaPartida.PRIMERA_JORNADA,
		ReglasDeLaPartida.PRIMERA_JORNADA + ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA
	):
		_almacen.call("_al_abrir_la_jornada", jornada)
		var presentes := 0
		for util: ObjetoAgarrable in _almacen.get("_utiles_de_limpieza"):
			if util.is_visible_in_tree():
				presentes += 1
		assert_int(presentes).is_equal(4 if jornada == AnomaliasDeLaJornada.JORNADA_SIN_AZUL else 5)
		var piso: PisoDelLocal = _almacen.get("_limpiador").piso()
		assert_bool(piso.balde().tiene_agua()).is_false()
		assert_bool(piso.mopa().esta_mojada()).is_false()
		if jornada == AnomaliasDeLaJornada.JORNADA_SIN_AZUL:
			_azul_ausente()


func test_los_objetos_disponibles_arrancan_dentro_de_su_habitacion() -> void:  # AC-CLN-040
	await _abrir(ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA)
	for jornada in range(
		ReglasDeLaPartida.PRIMERA_JORNADA,
		ReglasDeLaPartida.PRIMERA_JORNADA + ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA
	):
		_almacen.call("_al_abrir_la_jornada", jornada)
		var estados: Array[ReglasDelCierre.Estado] = _almacen.call("_estados_del_cierre")
		assert_bool(ReglasDelCierre.hay_desorden(estados, jornada)).is_false()
		assert_bool(ReglasDelCierre.hay_objetos_afuera(estados)).is_false()
		for estado: ReglasDelCierre.Estado in estados:
			if estado.clase == ReglasDelCierre.Clase.UTIL_DE_LIMPIEZA:
				assert_int(estado.habitacion).is_equal(ReglasDelCierre.Habitacion.CUARTITO)
			elif estado.clase == ReglasDelCierre.Clase.CAJA:
				assert_int(estado.habitacion).is_equal(ReglasDelCierre.Habitacion.DEPOSITO)


func test_cualquier_destino_previo_equivale_a_la_apertura_directa() -> void:  # AC-ANO-002
	await _abrir(ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA)
	var agarre: Agarre = _almacen.get("_agarre")
	var jugador: Node3D = _almacen.get("_jugador")
	var azul: ObjetoAgarrable = _almacen.get_node("Objetos/JabonAzul")
	for destino: String in ["mano", "examen", "piso", "contenedor"]:
		_almacen.call("_al_abrir_la_jornada", ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA)
		assert_bool(agarre.pedir_agarrar(azul.datos, azul)).is_true()
		match destino:
			"examen":
				assert_bool(jugador.examen.iniciar()).is_true()
			"piso":
				agarre.soltar(false)
			"contenedor":
				_clic(_almacen.get_node(CUERPO))
				assert_array(_almacen.get("_contenedor").tirados()).is_empty()
		_almacen.call("_al_abrir_la_jornada", AnomaliasDeLaJornada.JORNADA_SIN_AZUL)
		assert_bool(jugador.examen.esta_examinando()).is_false()
		assert_object(agarre.cuerpo_sostenido()).is_null()
		_azul_ausente()
		_almacen.call("_al_abrir_la_jornada", AnomaliasDeLaJornada.JORNADA_SIN_AZUL)
		_azul_ausente()
	await after_test()
	assert_str(Guardado.ruta_por_defecto).is_not_equal(Guardado.RUTA_DEL_USUARIO)
	(
		assert_bool(
			Guardado.new().escribir(
				PoliticaDeGuardado.datos(
					Partida.desde({"jornada": AnomaliasDeLaJornada.JORNADA_SIN_AZUL})
				)
			)
		)
		. is_true()
	)
	await _abrir(5, true)
	_azul_ausente()


# AC-ANO-003 AC-CLN-065
func test_la_tercera_jornada_recupera_el_mismo_bidon_y_su_estado_fisico() -> void:
	await _abrir(ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA)
	var azul: ObjetoAgarrable = _almacen.get_node("Objetos/JabonAzul")
	var padre := azul.get_parent()
	var pose := azul.lugar_de_origen()
	var capa := azul.collision_layer
	var mascara := azul.collision_mask
	var congelado := azul.freeze
	_almacen.call("_al_abrir_la_jornada", AnomaliasDeLaJornada.JORNADA_SIN_AZUL)
	_almacen.call("_al_abrir_la_jornada", AnomaliasDeLaJornada.JORNADA_SIN_AZUL)
	_azul_ausente()
	_almacen.call("_al_abrir_la_jornada", AnomaliasDeLaJornada.JORNADA_SIN_AZUL + 1)
	assert_object(_almacen.get_node("Objetos/JabonAzul")).is_same(azul)
	assert_object(azul.get_parent()).is_same(padre)
	assert_bool(azul.global_transform.is_equal_approx(pose)).is_true()
	assert_int(azul.collision_layer).is_equal(capa)
	assert_int(azul.collision_mask).is_equal(mascara)
	assert_bool(azul.freeze).is_equal(congelado)
	assert_bool(azul.is_visible_in_tree()).is_true()
	assert_bool(_almacen.get("_agarre").pedir_agarrar(azul.datos, azul)).is_true()
	assert_bool(_almacen.get("_jugador").examen.iniciar()).is_true()
	assert_str(azul.datos.nombre).is_not_equal("Poético (jabón azul)")
	assert_str(String(azul.datos.id)).is_equal("jabon_azul")
	assert_str(azul.datos.texto_al_examinar()).contains("2")


# AC-CLN-061 AC-CLN-064 AC-EMP-067
func test_poetico_de_caja_y_gondola_tine_sin_descontar_y_se_devuelve() -> void:
	await _abrir(AnomaliasDeLaJornada.JORNADA_SIN_AZUL)
	var agarre: Agarre = _almacen.get("_agarre")
	var balde: ObjetoAgarrable = _almacen.get_node("Objetos/Balde")
	var piso: PisoDelLocal = _almacen.get("_limpiador").piso()
	var partida: Partida = _almacen.get("_partida")
	for de_gondola: bool in [false, true]:
		var unidad := _unidad(de_gondola)
		assert_object(unidad).is_not_null()
		if unidad == null:
			return
		var cantidades := _cantidades()
		var identidad := unidad.datos
		await _mirar_desde_piso_libre(balde)
		for mezcla in range(2):
			piso.balde().vaciar()
			piso.balde().llenar()
			_clic(balde)
			assert_int(piso.balde().agua()).is_equal(ReglasDeLaLimpieza.Agua.AZUL)
			assert_object(agarre.cuerpo_sostenido()).is_same(unidad)
			assert_object(agarre.manos().sostenido()).is_same(identidad)
			assert_array(_cantidades()).is_equal(cantidades)
		assert_bool(partida.uso_de_poetico_en(5)).is_true()
		if de_gondola:
			_almacen.get("_reposicion_manual").call("pedir_colocar", Producto.Id.POETICO)
		else:
			_almacen.get("_reposicion_manual").call("devolver", Producto.Id.POETICO)
		assert_object(agarre.cuerpo_sostenido()).is_null()
		assert_int(_cantidades()[2]).is_zero()


func test_poetico_tirado_es_un_producto_y_suma_el_motivo_una_vez() -> void:  # AC-CLN-076
	await _abrir(AnomaliasDeLaJornada.JORNADA_SIN_AZUL)
	_almacen.set("compradores_de_la_apertura", func(_n: int) -> Array[Comprador]: return [])
	_almacen.call("_al_abrir_la_jornada", AnomaliasDeLaJornada.JORNADA_SIN_AZUL)
	var agarre: Agarre = _almacen.get("_agarre")
	var unidad := _unidad()
	_clic(_almacen.get_node(CUERPO))
	assert_object(agarre.cuerpo_sostenido()).is_null()
	assert_array(_almacen.get("_contenedor").tirados()).contains_exactly([unidad])
	var partida: Partida = _almacen.get("_partida")
	var reloj: RelojDelTurno = _almacen.get("_reloj")
	for tarea: Tarea in partida.obligatorias():
		reloj.completar(tarea)
	RelojDePrueba.avanzar_turno(reloj, Reglas.DURACION_DEL_TURNO)
	assert_int(partida.medios()).is_equal(1)


func test_los_rechazos_no_sueltan_ni_publican_y_la_consulta_no_actua() -> void:  # AC-CLN-062
	await _abrir(AnomaliasDeLaJornada.JORNADA_SIN_AZUL)
	var unidad := _unidad()
	var balde: Node3D = _almacen.get_node("Objetos/Balde")
	var jugador: Node3D = _almacen.get("_jugador")
	var limpiador: Limpiador = _almacen.get("_limpiador")
	var partida: Partida = _almacen.get("_partida")
	var rechazados: Array[ReglasDeLaLimpieza.Resultado] = []
	var aceptados: Array[StringName] = []
	limpiador.uso_rechazado.connect(
		func(resultado: ReglasDeLaLimpieza.Resultado) -> void: rechazados.append(resultado)
	)
	limpiador.balde_tenido_con.connect(
		func(id: StringName, _agua: ReglasDeLaLimpieza.Agua) -> void: aceptados.append(id)
	)
	var cantidades := _cantidades()
	for agua: ReglasDeLaLimpieza.Agua in [
		ReglasDeLaLimpieza.Agua.NINGUNA,
		ReglasDeLaLimpieza.Agua.AZUL,
		ReglasDeLaLimpieza.Agua.ROSA,
		ReglasDeLaLimpieza.Agua.AMARILLO
	]:
		limpiador.piso().balde().vaciar()
		if agua != ReglasDeLaLimpieza.Agua.NINGUNA:
			limpiador.piso().balde().llenar()
			limpiador.piso().balde().tenir(agua)
		var contexto: ReferenciaDeControles.Contexto = jugador.call(
			"_contexto_sobre", balde, unidad.datos
		)
		assert_int(ReferenciaDeControles.ruta(true, contexto, false)).is_equal(
			ReferenciaDeControles.Ruta.PEDIR_USO
		)
		assert_array(aceptados).is_empty()
		assert_int(limpiador.piso().balde().agua()).is_equal(agua)
		_clic(balde)
		assert_int(rechazados.back()).is_equal(
			(
				ReglasDeLaLimpieza.Resultado.BALDE_VACIO
				if agua == ReglasDeLaLimpieza.Agua.NINGUNA
				else ReglasDeLaLimpieza.Resultado.BALDE_YA_TENIDO
			)
		)
		assert_int(limpiador.piso().balde().agua()).is_equal(agua)
		assert_object(_almacen.get("_agarre").cuerpo_sostenido()).is_same(unidad)
		assert_array(_cantidades()).is_equal(cantidades)
		assert_bool(limpiador.piso().mopa().esta_mojada()).is_false()
		assert_bool(partida.uso_de_poetico_en(5)).is_false()
	assert_array(rechazados).has_size(4)
	assert_array(aceptados).is_empty()


func test_pausa_y_examen_bloquean_el_tenido_hasta_reanudar() -> void:  # AC-CLN-066 AC-EMP-068
	await _abrir(AnomaliasDeLaJornada.JORNADA_SIN_AZUL)
	var unidad := _unidad()
	var balde: Node3D = _almacen.get_node("Objetos/Balde")
	var jugador: Node3D = _almacen.get("_jugador")
	var pausa: ControlDePausa = _almacen.get_node("Interfaz/ControlDePausa")
	var limpiador: Limpiador = _almacen.get("_limpiador")
	var aceptados: Array[StringName] = []
	limpiador.balde_tenido_con.connect(
		func(id: StringName, _agua: ReglasDeLaLimpieza.Agua) -> void: aceptados.append(id)
	)
	limpiador.piso().balde().llenar()
	pausa.pausar()
	assert_bool(get_tree().paused).is_true()
	_clic(balde)
	assert_array(aceptados).is_empty()
	assert_bool(_almacen.get("_partida").uso_de_poetico_en(5)).is_false()
	pausa.reanudar()
	assert_bool(jugador.examen.iniciar()).is_true()
	_clic(balde)
	assert_bool(jugador.examen.esta_examinando()).is_true()
	assert_array(aceptados).is_empty()
	assert_int(limpiador.piso().balde().agua()).is_equal(ReglasDeLaLimpieza.Agua.LIMPIA)
	assert_object(_almacen.get("_agarre").cuerpo_sostenido()).is_same(unidad)
	jugador.examen.terminar()
	_clic(balde)
	assert_array(aceptados).contains_exactly([unidad.datos.id])
	assert_bool(_almacen.get("_partida").uso_de_poetico_en(5)).is_true()


func test_el_cierre_bloquea_el_tenido_sin_anotar_un_hecho_futuro() -> void:  # AC-CLN-066 AC-EMP-068
	await _abrir(AnomaliasDeLaJornada.JORNADA_SIN_AZUL)
	var unidad := _unidad()
	var limpiador: Limpiador = _almacen.get("_limpiador")
	var aceptados: Array[StringName] = []
	limpiador.balde_tenido_con.connect(
		func(id: StringName, _agua: ReglasDeLaLimpieza.Agua) -> void: aceptados.append(id)
	)
	limpiador.piso().balde().llenar()
	_almacen.get("_reloj").avanzar(Reglas.DURACION_DEL_TURNO)
	assert_bool(_almacen.get("_reloj").corriendo()).is_false()
	_clic(_almacen.get_node("Objetos/Balde"))
	assert_array(aceptados).is_empty()
	assert_int(limpiador.piso().balde().agua()).is_equal(ReglasDeLaLimpieza.Agua.LIMPIA)
	assert_object(_almacen.get("_agarre").cuerpo_sostenido()).is_same(unidad)
	assert_bool(_almacen.get("_partida").uso_de_poetico_en(5)).is_false()


func test_la_mopa_azul_de_poetico_muestra_carga_y_borra_solo_moho() -> void:  # AC-CLN-063
	await _abrir(AnomaliasDeLaJornada.JORNADA_SIN_AZUL)
	_unidad()
	var limpiador: Limpiador = _almacen.get("_limpiador")
	var balde: Node3D = _almacen.get_node("Objetos/Balde")
	limpiador.piso().balde().llenar()
	_clic(balde)
	var mopa: ObjetoAgarrable = _almacen.get_node("Objetos/Mopa")
	_almacen.get("_agarre").soltar(false)
	assert_bool(_almacen.get("_agarre").pedir_agarrar(mopa.datos, mopa)).is_true()
	_clic(balde)
	assert_int(limpiador.piso().mopa().agua()).is_equal(ReglasDeLaLimpieza.Agua.AZUL)
	assert_float(limpiador.piso().mopa().carga_restante()).is_equal(1.0)
	assert_that(mopa.call("color_de_la_carga")).is_equal(
		ReglasDeLaLimpieza.COLOR_DEL_AGUA[ReglasDeLaLimpieza.Agua.AZUL]
	)
	for mancha: Node3D in _almacen.get("_limpieza").manchas():
		_clic(mancha)
		var estado := limpiador.piso().mancha_de(mancha.call("lugar_de_la_mancha"))
		assert_bool(estado.esta_limpia()).is_equal(
			estado.tipo() == ReglasDeLaLimpieza.TipoDeMancha.MOHO
		)
	assert_int(limpiador.piso().lugares().size()).is_equal(8)
