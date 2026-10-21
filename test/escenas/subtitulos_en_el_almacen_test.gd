## La E en el local: lo que se mira con las manos vacías se piensa, lo que se lleva queda fijo
## mientras se examina, y lo que no tiene texto calla.
##
## Las tablas y el tiempo de la línea tienen sus casos en `dominio/`. Acá se afirma el cableado:
## que cada cosa del local llegue a su texto, y que el gesto no cambie nada más.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const ZonaDeReposicion := preload("res://src/escenas/puestos/zona_de_reposicion.gd")

const INODORO := SubtitulosAlExaminar.INODORO
const LAVATORIO := SubtitulosAlExaminar.LAVATORIO
const TEXTO_DE_PRUEBA := "abcdefghijklmnopqrst"


func _almacen_con_jugador_quieto(jornada: int = ReglasDeLaPartida.PRIMERA_JORNADA) -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	almacen.set("_partida", Partida.desde({"jornada": jornada}))
	add_child(almacen)
	await get_tree().physics_frame
	almacen.get("_jugador").set_physics_process(false)
	return almacen


## Le pone el foco al objetivo y le manda la E, que es lo que hace la tecla de verdad.
func _examinar(jugador: Node3D, objetivo: Node3D) -> void:
	jugador.set("_enfocado", objetivo)
	var evento := InputEventAction.new()
	evento.action = ReglasDeLosObjetos.ACCION_EXAMINAR
	evento.pressed = true
	jugador.call("_unhandled_input", evento)


func _linea(almacen: Node3D) -> Label:
	return almacen.get("_hud").get("_subtitulo")


## Afirma que la E sobre `objetivo` muestra `texto` y que no pasó nada más.
func _piensa(almacen: Node3D, objetivo: Node3D, texto: String) -> void:
	var jugador: Node3D = almacen.get("_jugador")
	var agarre: Agarre = almacen.get("_agarre")
	assert_object(objetivo).is_not_null()
	if objetivo == null:
		return
	var lugar := objetivo.global_transform
	_examinar(jugador, objetivo)
	(
		assert_str(_linea(almacen).text)
		. override_failure_message("%s dice «%s»" % [objetivo.get_path(), _linea(almacen).text])
		. is_equal(texto)
	)
	assert_float(_linea(almacen).modulate.a).is_equal(1.0)
	assert_bool(jugador.get("examen").esta_examinando()).is_false()
	assert_bool(jugador.get("_control").esta_suspendido()).is_false()
	assert_object(agarre.manos().sostenido()).is_null()
	assert_bool(objetivo.global_transform.is_equal_approx(lugar)).is_true()


func test_lo_fijo_del_local_dice_su_texto_con_las_manos_vacias() -> void:  # AC-SUB-002, AC-SUB-013
	var almacen: Node3D = await _almacen_con_jugador_quieto()
	var hallazgos: Hallazgos = almacen.get("_jugador").get("examen").hallazgos()
	var casos := {
		"Estructura/inodoro/StaticBody3D": INODORO,
		"Estructura/bano_inodoro_2/StaticBody3D": INODORO,
		"Estructura/vanitory/StaticBody3D": LAVATORIO,
		"Estructura/bano_lavatorio_2/StaticBody3D": LAVATORIO,
		"Estructura/base compu/StaticBody3D": SubtitulosAlExaminar.COMPUTADORA,
		"Estructura/cajaregistradora/StaticBody3D": SubtitulosAlExaminar.CAJA_REGISTRADORA,
		"Estructura/Lector": SubtitulosAlExaminar.LECTOR,
		"Estructura/puertaentrada/CuerpoDeLaHoja": SubtitulosAlExaminar.ENTRADA_PRINCIPAL,
		"Estructura/puertajefe/CuerpoDeLaHoja": SubtitulosAlExaminar.PUERTA_DEL_JEFE,
		"Estructura/porton/CuerpoDeLaHoja": SubtitulosAlExaminar.PORTON,
	}
	for ruta: String in casos:
		_piensa(
			almacen, almacen.get_node_or_null(ruta), SubtitulosAlExaminar.de_lo_fijo(casos[ruta])
		)
	var contenedor := SubtitulosAlExaminar.de_lo_fijo(SubtitulosAlExaminar.CONTENEDOR)
	_piensa(almacen, almacen.get("_contenedor"), contenedor)
	_piensa(almacen, almacen.get("_tapa_del_contenedor"), contenedor)
	var notas: Array = almacen.get_node("Estructura/NotasDelAlmacen").get("notas")
	assert_int(notas.size()).is_greater_equal(5)
	for nota: Node3D in notas:
		_piensa(
			almacen,
			nota,
			SubtitulosAlExaminar.de_lo_fijo(SubtitulosAlExaminar.id_de_la_nota(nota.get("id")))
		)
	assert_int(hallazgos.cantidad()).is_zero()


func test_los_tres_tachos_dicen_su_texto_con_bolsa_o_sin_ella() -> void:  # AC-SUB-013
	var almacen: Node3D = await _almacen_con_jugador_quieto()
	var recolector: RecolectorDeBasura = almacen.get("_recolector")
	var tachos: Array = almacen.call("_tachos")
	assert_int(tachos.size()).is_equal(3)
	# Una noche con las tres bolsas, y a una ya se la sacaron: un tacho con bolsa y otro sin.
	recolector.arrancar(TareaDeLaBasura.new(ReglasDeLaBasura.ids_de_las_bolsas()))
	recolector.tarea().sacar(TareaDeLaBasura.Tacho.LOCAL, true)
	var antes := {}
	for tacho: Node3D in tachos:
		antes[tacho.get("tacho")] = recolector.tarea().tiene_bolsa(tacho.get("tacho"))
	assert_bool(antes.values().has(true)).is_true()
	assert_bool(antes.values().has(false)).is_true()
	for tacho: Node3D in tachos:
		var cual: TareaDeLaBasura.Tacho = tacho.get("tacho")
		_piensa(
			almacen, tacho, SubtitulosAlExaminar.de_lo_fijo(SubtitulosAlExaminar.id_del_tacho(cual))
		)
		assert_str(_linea(almacen).text).is_not_empty()
		assert_bool(recolector.tarea().tiene_bolsa(cual)).is_equal(antes[cual])


func test_la_puerta_del_bano_habla_solo_las_noches_que_esta_trabada() -> void:  # AC-SUB-021
	var abierta := ReglasDeLaPartida.PRIMERA_JORNADA
	while (
		abierta < ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA
		and not Apertura.pide(abierta, Tarea.Tipo.LIMPIAR)
	):
		abierta += 1
	assert_int(abierta).is_greater(ReglasDeLaPartida.PRIMERA_JORNADA)
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	almacen.set("_partida", Partida.desde({"jornada": abierta - 1}))
	add_child(almacen)
	await get_tree().physics_frame
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	var puerta: Node3D = almacen.get_node("Estructura/puerta2/CuerpoDeLaHoja")
	assert_str(String(puerta.get("identidad"))).is_equal(String(SubtitulosAlExaminar.BANO_CERRADO))
	_piensa(almacen, puerta, SubtitulosAlExaminar.de_lo_fijo(SubtitulosAlExaminar.BANO_CERRADO))
	almacen.call("_al_abrir_la_jornada", abierta)
	assert_str(String(puerta.get("identidad"))).is_empty()
	_examinar(jugador, puerta)
	assert_str(_linea(almacen).text).is_empty()
	_examinar(jugador, almacen.get_node("Estructura/inodoro/StaticBody3D"))
	_examinar(jugador, puerta)
	assert_str(_linea(almacen).text).is_equal(SubtitulosAlExaminar.de_lo_fijo(INODORO))


func test_la_puerta_del_cuartito_habla_solo_las_noches_que_esta_trabada() -> void:  # AC-SUB-022
	var abierta := ReglasDeLaPartida.PRIMERA_JORNADA
	while (
		abierta < ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA
		and not Apertura.pide(abierta, Tarea.Tipo.LIMPIAR)
	):
		abierta += 1
	assert_int(abierta).is_greater(ReglasDeLaPartida.PRIMERA_JORNADA)
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	almacen.set("_partida", Partida.desde({"jornada": abierta - 1}))
	add_child(almacen)
	await get_tree().physics_frame
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	var puerta: Node3D = almacen.get_node("Estructura/puerta_limpieza/CuerpoDeLaHoja")
	var cerrado := SubtitulosAlExaminar.de_lo_fijo(SubtitulosAlExaminar.CUARTITO_CERRADO)
	assert_str(cerrado).is_not_equal(
		SubtitulosAlExaminar.de_lo_fijo(SubtitulosAlExaminar.BANO_CERRADO)
	)
	_piensa(almacen, puerta, cerrado)
	almacen.call("_al_abrir_la_jornada", abierta)
	_examinar(jugador, puerta)
	assert_str(_linea(almacen).text).is_empty()
	_examinar(jugador, almacen.get_node("Estructura/inodoro/StaticBody3D"))
	_examinar(jugador, puerta)
	assert_str(_linea(almacen).text).is_equal(SubtitulosAlExaminar.de_lo_fijo(INODORO))
	almacen.call("_al_abrir_la_jornada", abierta - 1)
	assert_str(String(puerta.get("identidad"))).is_equal(
		String(SubtitulosAlExaminar.CUARTITO_CERRADO)
	)


func test_cada_unidad_puesta_en_la_gondola_dice_su_texto() -> void:  # AC-SUB-002, AC-SUB-011
	var almacen: Node3D = await _almacen_con_jugador_quieto(
		ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA
	)
	var puesto: Node = almacen.get("_reposicion_manual")
	puesto.call("_actualizar_zonas")
	var probados := {}
	for zonas: Array in puesto.get("_casilleros"):
		for zona: ZonaDeReposicion in zonas:
			if zona.papel == ZonaDeReposicion.Papel.AGARRAR and not probados.has(zona.producto):
				probados[zona.producto] = true
				_piensa(almacen, zona, SubtitulosAlExaminar.de_producto(zona.producto))
	assert_int(probados.size()).is_equal(Producto.Id.size())


func test_lo_que_no_tiene_texto_no_cambia_la_linea() -> void:  # AC-SUB-003, AC-SUB-013
	var almacen: Node3D = await _almacen_con_jugador_quieto()
	var jugador: Node3D = almacen.get("_jugador")
	var callados: Array[Node3D] = [
		null,
		almacen.get_node("Estructura/heladeranueva/puerta_heladera_0/CuerpoDeLaHoja"),
		almacen.get_node("Estructura/puerta/CuerpoDeLaHoja"),
		almacen.get_node("Estructura/Ventanilla"),
		almacen.get_node("Estructura/gondolanueva/StaticBody3D"),
	]
	for objetivo in callados:
		_examinar(jugador, objetivo)
		assert_str(_linea(almacen).text).is_empty()
	# Con un pensamiento visible, el gesto sin texto lo deja seguir.
	_examinar(jugador, almacen.get_node("Estructura/inodoro/StaticBody3D"))
	for objetivo in callados:
		_examinar(jugador, objetivo)
		assert_str(_linea(almacen).text).is_equal(SubtitulosAlExaminar.de_lo_fijo(INODORO))


func test_la_unidad_en_la_mano_queda_fija_mientras_se_examina() -> void:  # AC-SUB-007, AC-SUB-011
	var almacen: Node3D = await _almacen_con_jugador_quieto()
	var jugador: Node3D = almacen.get("_jugador")
	var hud: Hud = almacen.get("_hud")
	var caja: Node3D = almacen.get("_cajas_de_productos")[Producto.Id.ACTRONCITO]
	_examinar(jugador, almacen.get_node("Estructura/inodoro/StaticBody3D"))
	assert_str(_linea(almacen).text).is_equal(SubtitulosAlExaminar.de_lo_fijo(INODORO))
	jugador.set("_enfocado", caja)
	var usar := InputEventAction.new()
	usar.action = ReglasDelJugador.ACCION_USAR
	usar.pressed = true
	jugador.call("_unhandled_input", usar)
	assert_object(almacen.get("_agarre").manos().sostenido() as UnidadDeProducto).is_not_null()
	_examinar(jugador, caja)
	assert_bool(jugador.get("examen").esta_examinando()).is_true()
	assert_str(_linea(almacen).text).is_equal(
		SubtitulosAlExaminar.de_producto(Producto.Id.ACTRONCITO)
	)
	hud.call("_process", 60.0)
	assert_str(_linea(almacen).text).is_equal(
		SubtitulosAlExaminar.de_producto(Producto.Id.ACTRONCITO)
	)
	assert_float(_linea(almacen).modulate.a).is_equal(1.0)
	_examinar(jugador, caja)
	assert_bool(jugador.get("examen").esta_examinando()).is_false()
	assert_str(_linea(almacen).text).is_empty()


func test_con_otra_interfaz_o_la_pausa_la_e_no_piensa() -> void:  # AC-SUB-008
	var almacen: Node3D = await _almacen_con_jugador_quieto()
	var jugador: Node3D = almacen.get("_jugador")
	var hud: Hud = almacen.get("_hud")
	var inodoro: Node3D = almacen.get_node("Estructura/inodoro/StaticBody3D")
	jugador.call("suspender")
	_examinar(jugador, inodoro)
	assert_str(_linea(almacen).text).is_empty()
	jugador.call("reanudar")
	# La pausa congela el árbol: el jugador no recibe la E y el HUD no consume el pensamiento.
	# En el juego el almacén cuelga de la raíz, que se pausa; acá cuelga de la suite.
	var cadena: Array[Node] = [hud, hud.get_parent()]
	for nodo in cadena:
		assert_int(nodo.process_mode).is_equal(Node.PROCESS_MODE_INHERIT)
	assert_int(almacen.process_mode).is_equal(Node.PROCESS_MODE_INHERIT)
	almacen.process_mode = Node.PROCESS_MODE_PAUSABLE
	hud.pensar(TEXTO_DE_PRUEBA)
	hud.call("_process", 1.0)
	get_tree().paused = true
	var pausados := not hud.can_process() and not jugador.can_process()
	get_tree().paused = false
	assert_bool(pausados).is_true()
	assert_str(_linea(almacen).text).is_equal(TEXTO_DE_PRUEBA)
	assert_float(_linea(almacen).modulate.a).is_equal(1.0)
	hud.call("_process", 1.79)
	assert_str(_linea(almacen).text).is_equal(TEXTO_DE_PRUEBA)
	hud.call("_process", 1.8 - 1.79)
	assert_str(_linea(almacen).text).is_empty()


func test_la_jornada_nueva_abre_con_la_linea_vacia() -> void:  # AC-SUB-009
	var almacen: Node3D = await _almacen_con_jugador_quieto()
	var hud: Hud = almacen.get("_hud")
	hud.pensar(TEXTO_DE_PRUEBA)
	hud.call("_process", 2.55)
	assert_float(_linea(almacen).modulate.a).is_less(1.0)
	assert_str(_linea(almacen).text).is_equal(TEXTO_DE_PRUEBA)
	almacen.call("_al_abrir_la_jornada", ReglasDeLaPartida.PRIMERA_JORNADA + 1)
	assert_str(_linea(almacen).text).is_empty()
