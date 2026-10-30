## Las consecuencias del descarte se acumulan al cierre, según qué se tiró.
extends GdUnitTestSuite

const AvanceDeDevolucion := preload("res://test/avance_de_devolucion.gd")

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const BolsaEnLaMano := preload("res://test/escenas/bolsa_en_la_mano.gd")
const Habitaciones := preload("res://src/escenas/puestos/habitaciones_del_almacen.gd")
const CUERPO := (
	"Estructura/deposito_contenedor_grande_soporte/"
	+ "deposito_contenedor_grande_cuerpo/StaticBody3D"
)
const ReglasDelCierre := preload("res://src/dominio/almacen/reglas_del_cierre.gd")
const RelojDePrueba := preload("res://test/reloj_de_prueba.gd")

var _almacen: Node3D


func after_test() -> void:
	if is_instance_valid(_almacen):
		for tipo: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
			for audio: Node in _almacen.find_children("*", tipo, true, false):
				audio.call("stop")
				audio.set("stream", null)
		_almacen.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_almacen = null


func _abrir() -> void:
	_almacen = ALMACEN.instantiate()
	_almacen.set(
		"_partida",
		Partida.desde({"jornada": ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1, "medios": 0})
	)
	_almacen.set("compradores_de_la_apertura", func(_n: int) -> Array[Comprador]: return [])
	add_child(_almacen)
	var jugador: Node3D = _almacen.get("_jugador")
	jugador.set_process(false)
	jugador.set_physics_process(false)


func _tirar(objeto: ObjetoAgarrable) -> void:
	var agarre: Agarre = _almacen.get("_agarre")
	if ReglasDeLaBasura.ids_de_las_bolsas().has(objeto.datos.id):
		var numero := ReglasDeLaBasura.ids_de_las_bolsas().find(objeto.datos.id)
		assert_object(BolsaEnLaMano.sacar(_almacen, numero)).is_same(objeto)
	if agarre.cuerpo_sostenido() != objeto:
		assert_bool(agarre.pedir_agarrar(objeto.datos, objeto)).is_true()
	var jugador: Node3D = _almacen.get("_jugador")
	jugador.set("_enfocado", _almacen.get_node(CUERPO))
	var evento := InputEventMouseButton.new()
	evento.button_index = MOUSE_BUTTON_LEFT
	evento.pressed = true
	jugador.call("_unhandled_input", evento)
	assert_object(agarre.cuerpo_sostenido()).is_null()


func _unidad() -> ObjetoAgarrable:
	_almacen.get("_reposicion_manual").call("retirar", Producto.Id.ACTRONCITO)
	var agarre: Agarre = _almacen.get("_agarre")
	return agarre.cuerpo_sostenido() as ObjetoAgarrable


func _ticket() -> ObjetoAgarrable:
	var puesto: Node3D = _almacen.get("_puesto_de_la_caja")
	var anteriores: Array[Node3D] = puesto.call("tickets_en_el_mundo")
	var productos: Array[Producto] = [Catalogo.de(Producto.Id.MAROLINI)]
	(_almacen.get("_caja") as CajaRegistradora).ticket_impreso.emit(Ticket.new(productos))
	for papel: Node3D in puesto.call("tickets_en_el_mundo"):
		if not anteriores.has(papel):
			return papel as ObjetoAgarrable
	return null


func _cerrar(impecable: bool) -> void:
	var partida: Partida = _almacen.get("_partida")
	var reloj: RelojDelTurno = _almacen.get("_reloj")
	if impecable:
		for tarea: Tarea in partida.obligatorias():
			reloj.completar(tarea)
	RelojDePrueba.avanzar_turno(reloj, Reglas.DURACION_DEL_TURNO)


func _seguir() -> void:
	var pantalla: PantallaDeDevolucion = _almacen.get("_pantalla")
	AvanceDeDevolucion.entregar(pantalla)
	pantalla.elegir()
	AvanceDeDevolucion.pasar_la_reflexion(pantalla)
	AvanceDeDevolucion.terminar_movimiento(pantalla)
	await get_tree().process_frame
	_almacen.get_node("Interfaz/PersianaDeLaNoche").terminar()


func _otros_motivos() -> void:
	var lector: Habitaciones = _almacen.get("_habitaciones")
	var caja: Node3D = _almacen.get("_cajas_de_productos")[0]
	caja.global_position = lector.to_global(lector.bano[0].get_center())
	var unidad := _unidad()
	assert_object(unidad).is_not_null()
	unidad = _almacen.get("_agarre").soltar(true)
	unidad.global_position = lector.to_global(lector.local[0].end + Vector3.ONE)


func test_tirar_una_unidad_suma_un_medio_y_la_deuda_se_conserva() -> void:  # AC-CLN-051
	_abrir()
	var partida: Partida = _almacen.get("_partida")
	var unidad := _unidad()
	assert_object(unidad).is_not_null()
	_tirar(unidad)
	_cerrar(true)
	assert_int(partida.medios()).is_equal(1)
	await _seguir()
	_cerrar(true)
	assert_int(partida.medios()).is_equal(1)


func test_utiles_rechazados_sin_motivo_y_vuelven_al_cuartito() -> void:  # AC-CLN-076
	_abrir()
	var agarre: Agarre = _almacen.get("_agarre")
	var jugador: Node3D = _almacen.get("_jugador")
	jugador.set("_enfocado", _almacen.get_node(CUERPO))
	var evento := InputEventMouseButton.new()
	evento.button_index = MOUSE_BUTTON_LEFT
	evento.pressed = true
	var piso: PisoDelLocal = _almacen.get("_limpiador").piso()
	piso.balde().llenar()
	piso.balde().tenir(ReglasDeLaLimpieza.Agua.AZUL)
	piso.mopa().mojar_en(piso.balde())
	for nombre: String in ["Mopa", "Balde", "JabonRosa", "JabonAmarillo"]:
		var util: ObjetoAgarrable = _almacen.get_node("Objetos/" + nombre)
		assert_bool(agarre.pedir_agarrar(util.datos, util)).is_true()
		jugador.call("_unhandled_input", evento)
		assert_object(agarre.manos().sostenido()).is_same(util.datos)
		assert_bool(util.visible).is_true()
		agarre.soltar(false)
		util.volver_a_su_lugar()
	assert_array(_almacen.get("_contenedor").tirados()).is_empty()
	_cerrar(true)
	assert_int((_almacen.get("_partida") as Partida).medios()).is_zero()
	await _seguir()
	var utiles := 0
	for estado: ReglasDelCierre.Estado in _almacen.call("_estados_del_cierre"):
		if estado.clase == ReglasDelCierre.Clase.UTIL_DE_LIMPIEZA:
			utiles += 1
			assert_int(estado.habitacion).is_equal(ReglasDelCierre.Habitacion.CUARTITO)
	assert_int(utiles).is_equal(5)
	assert_array(_almacen.get("_contenedor").tirados()).is_empty()


func test_bolsas_y_ticket_se_descartan_sin_este_llamado() -> void:  # AC-CLN-050
	_abrir()
	for numero: int in range(1, ReglasDeLaBasura.BOLSAS_DE_LA_JORNADA + 1):
		_tirar(_almacen.get_node("Objetos/BolsaDeBasura" + str(numero)))
	var papel := _ticket()
	assert_object(papel).is_not_null()
	_tirar(papel)
	_cerrar(true)
	assert_int((_almacen.get("_partida") as Partida).medios()).is_zero()
	assert_bool((_almacen.get("_recolector") as RecolectorDeBasura).tarea().completada()).is_true()


func test_varios_importantes_cuentan_una_vez_y_otra_noche_pueden_repetir() -> void:  # AC-CLN-051
	_abrir()
	var partida: Partida = _almacen.get("_partida")
	_tirar(_unidad())
	_tirar(_unidad())
	_cerrar(true)
	assert_int(partida.medios()).is_equal(1)
	await _seguir()
	_tirar(_unidad())
	_cerrar(true)
	assert_int(partida.medios()).is_equal(2)


func test_tres_motivos_con_grave_guardan_siete_y_permiten_continuar() -> void:  # AC-CLN-052
	_abrir()
	var partida: Partida = _almacen.get("_partida")
	_tirar(_unidad())
	_otros_motivos()
	_cerrar(false)
	assert_int(partida.medios()).is_equal(7)
	assert_bool(partida.terminada()).is_false()
	assert_int(Partida.desde(Guardado.new().cargar()).medios()).is_equal(7)
	await _seguir()
	_cerrar(true)
	assert_int(partida.medios()).is_equal(7)


func test_cuatro_motivos_con_grave_despiden_y_borran_el_guardado() -> void:  # AC-CLN-052
	_abrir()
	var partida: Partida = _almacen.get("_partida")
	var papel := _ticket()
	assert_object(papel).is_not_null()
	assert_bool((_almacen.get("_agarre") as Agarre).pedir_agarrar(papel.datos, papel)).is_true()
	_almacen.get("_jugador").uso_pedido.emit(_almacen.get_node("Estructura/inodoro/StaticBody3D"))
	await get_tree().process_frame
	_tirar(_unidad())
	_otros_motivos()
	_cerrar(false)
	assert_int(partida.medios()).is_equal(8)
	assert_int(partida.final()).is_equal(Partida.Final.DESPEDIDO)
	assert_bool(Guardado.new().hay_guardado()).is_false()
