extends GdUnitTestSuite

const RUTA_DEL_ALMACEN := "res://src/escenas/almacen.tscn"
const RelojDePrueba := preload("res://test/reloj_de_prueba.gd")
const AvanceDeDevolucion := preload("res://test/avance_de_devolucion.gd")
const ENTRADA := "Estructura/puertaentrada/CuerpoDeLaHoja"
const AVISO: String = PilaDeNotificaciones.TEXTOS[Notificaciones.Tipo.TAREAS_TERMINADAS]
const RETRABA: String = PilaDeNotificaciones.TEXTOS[Notificaciones.Tipo.SALIDA_RETRABADA]

var _ruta_guardado: String


func before_test() -> void:
	_ruta_guardado = Guardado.ruta_por_defecto
	Guardado.ruta_por_defecto = "user://salida_573.guardado"
	Guardado.new().borrar()


func after_test() -> void:
	get_tree().paused = false
	Guardado.new().borrar()
	Guardado.ruta_por_defecto = _ruta_guardado


func test_retirar_y_reponer_retraba_y_rehabilita_la_entrada() -> void:  # AC-SHF-041
	var segunda := ReglasDeLaPartida.PRIMERA_JORNADA + 1
	var almacen := await _abrir(segunda)
	var repositor: Repositor = almacen.get("_repositor")
	var puesto: Node3D = almacen.get("_reposicion_manual")
	for producto in Catalogo.de_la_jornada(segunda):
		for indice in repositor.estante().casilleros_vacios(producto):
			puesto.call("retirar", producto.id)
			puesto.call("pedir_colocar", producto.id, indice)
	assert_bool(repositor.estante().completada()).is_true()
	_cumplir(almacen)
	var producto := Catalogo.de(Producto.Id.ACTRONCITO)
	var antes := repositor.estante().unidades_en_gondola(producto)
	var ocupados := repositor.estante().casilleros_ocupados(producto)
	assert_array(ocupados).is_not_empty()
	puesto.call("agarrar_de_la_gondola", producto.id, ocupados[0])
	assert_int(repositor.estante().unidades_en_gondola(producto)).is_equal(antes - 1)
	assert_bool(repositor.estante().completada()).is_false()
	assert_object(repositor.agarre.manos().sostenido()).is_instanceof(UnidadDeProducto)
	assert_bool(repositor.reloj.obligatoria(Tarea.Tipo.REPONER).completada()).is_false()
	assert_bool(almacen.call("_puede_salir")).is_false()
	assert_array(_textos(almacen)).contains(RETRABA).not_contains(AVISO)
	puesto.call("pedir_colocar", producto.id, ocupados[0])
	assert_bool(repositor.reloj.obligatoria(Tarea.Tipo.REPONER).completada()).is_true()
	assert_bool(almacen.call("_puede_salir")).is_true()
	assert_array(_textos(almacen)).not_contains(RETRABA).not_contains(AVISO)
	await get_tree().process_frame


func test_no_salir_conserva_el_ritmo_y_cierra_por_el_recorrido_natural() -> void:  # AC-SHF-038
	for con_pendiente: bool in [false, true]:
		var almacen := await _abrir(3)
		_cumplir(almacen)
		var reloj: RelojDelTurno = almacen.get("_reloj")
		if con_pendiente:
			assert_bool(reloj.descumplir(reloj.obligatoria(Tarea.Tipo.REPONER))).is_true()
		_pila(almacen)._process(Notificaciones.DURACION)
		assert_array(_textos(almacen)).is_empty()
		var cierres: Array[int] = []
		reloj.turno_cerrado.connect(cierres.append)
		RelojDePrueba.avanzar_turno(reloj, _restante(almacen) - 1.0)
		assert_array(cierres).is_empty()
		assert_float(_restante(almacen)).is_equal(1.0)
		RelojDePrueba.avanzar_turno(reloj, 1.0)
		var esperadas := Apertura.cantidad_de_obligatorias(3) - int(con_pendiente)
		assert_array(cierres).is_equal([esperadas])
		assert_bool((almacen.get("_pantalla") as PantallaDeDevolucion).visible).is_true()
		assert_array(_textos(almacen)).is_empty()
		reloj.avanzar(10.0)
		almacen.call("_revisar_la_salida")
		assert_array(cierres).has_size(1)
		assert_array(_textos(almacen)).is_empty()


func _abrir(jornada: int, con_compradores: bool = false) -> Node3D:
	var almacen: Node3D = auto_free(load(RUTA_DEL_ALMACEN).instantiate())
	almacen.set("_partida", Partida.desde({"jornada": jornada}))
	if not con_compradores:
		almacen.set("compradores_de_la_apertura", func(_n: int) -> Array[Comprador]: return [])
	add_child(almacen)
	var reloj: RelojDelTurno = almacen.get("_reloj")
	reloj.set_process(false)
	almacen.get("_jugador").set_physics_process(false)
	_pila(almacen).set_process(false)
	await get_tree().process_frame
	almacen.get("_jugador").call("reanudar")
	return almacen


func _pila(almacen: Node3D) -> PilaDeNotificaciones:
	return almacen.get_node("Interfaz/PilaDeNotificaciones")


func _textos(almacen: Node3D) -> Array[String]:
	var textos: Array[String] = []
	for label: Label in _pila(almacen).find_children("*", "Label", true, false):
		textos.append(label.text)
	return textos


func _cumplir(almacen: Node3D) -> void:
	var reloj: RelojDelTurno = almacen.get("_reloj")
	var partida: Partida = almacen.get("_partida")
	for tarea in partida.obligatorias():
		reloj.completar(tarea)


func _restante(almacen: Node3D) -> float:
	return (almacen.get("_reloj").get("_turno") as Turno).tiempo_restante()


func _gesto(almacen: Node3D, primario: bool) -> void:
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set("_enfocado", almacen.get_node(ENTRADA))
	for pulsado: bool in [true, false]:
		var evento := InputEventMouseButton.new()
		evento.button_index = MOUSE_BUTTON_LEFT if primario else MOUSE_BUTTON_RIGHT
		evento.pressed = pulsado
		jugador.call("_unhandled_input", evento)


func _referencia(almacen: Node3D) -> String:
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set("_enfocado", almacen.get_node(ENTRADA))
	jugador.call("_publicar_la_referencia")
	return (almacen.get("_hud").get_node("Controles") as Label).text


# AC-SHF-041, AC-NTF-028, AC-NTF-032
func test_la_prueba_avisa_sin_acelerar_y_permanece_reversible() -> void:
	for jornada: int in range(
		ReglasDeLaPartida.PRIMERA_JORNADA, ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1
	):
		var almacen := await _abrir(jornada)
		var antes := _restante(almacen)
		var computadora: ComputadoraDeEscritorio = almacen.get("_computadora")
		computadora.pedir_abrir()
		assert_array(_textos(almacen)).not_contains(AVISO)
		_cumplir(almacen)
		assert_bool(almacen.call("_puede_salir")).is_equal(
			jornada < ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA
		)
		assert_array(_textos(almacen)).is_empty()
		var pantalla: PantallaDeComputadora = almacen.get_node("Interfaz/PantallaDeComputadora")
		var fila: Node = pantalla.caja().get("_filas").get_child(0).get_child(0)
		assert_bool((fila.get_child(3) as Button).disabled).is_false()
		assert_bool((fila.get_child(5) as Button).disabled).is_false()
		computadora.pedir_cerrar()
		assert_array(_textos(almacen)).is_equal(
			[AVISO] if jornada < ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA else []
		)
		assert_float(_restante(almacen)).is_equal(antes)
		var reloj: RelojDelTurno = almacen.get("_reloj")
		var tarea := reloj.obligatoria(Tarea.Tipo.REGISTRAR)
		assert_bool(reloj.descumplir(tarea)).is_true()
		assert_bool(almacen.call("_puede_salir")).is_false()
		assert_array(_textos(almacen)).is_equal(
			[RETRABA] if jornada < ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA else []
		)
		assert_bool(reloj.completar(tarea)).is_true()
		assert_bool(almacen.call("_puede_salir")).is_equal(
			jornada < ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA
		)
		assert_array(_textos(almacen)).is_empty()
		reloj.avanzar(1.0)
		assert_float(antes - _restante(almacen)).is_equal(Ritmo.de_la_jornada(jornada))
		almacen.call("_revisar_la_salida")
		assert_array(_textos(almacen)).is_empty()


func test_compradores_pendientes_o_vencidos_no_reemplazan_cobrar() -> void:  # AC-SHF-036
	for jornada: int in range(
		ReglasDeLaPartida.PRIMERA_JORNADA, ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA
	):
		var almacen := await _abrir(jornada, true)
		var reloj: RelojDelTurno = almacen.get("_reloj")
		var partida: Partida = almacen.get("_partida")
		for tarea in partida.obligatorias():
			if tarea.tipo() != Tarea.Tipo.CAJA:
				reloj.completar(tarea)
		var compradores := Compradores.de_la_jornada(jornada)
		for transcurrido: float in [0.0, compradores[0].horario.x, compradores[-1].horario.y]:
			var actual := Reglas.DURACION_DEL_TURNO - _restante(almacen)
			RelojDePrueba.avanzar_turno(reloj, transcurrido - actual)
			assert_bool(almacen.call("_puede_salir")).is_false()
			assert_array(_textos(almacen)).not_contains(AVISO)
		assert_bool(reloj.obligatoria(Tarea.Tipo.CAJA).completada()).is_false()


func test_venta_y_registro_habilitan_la_salida() -> void:  # AC-SHF-036, AC-SHF-038
	for jornada: int in range(
		ReglasDeLaPartida.PRIMERA_JORNADA, ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA
	):
		var almacen := await _abrir(jornada, true)
		var reloj: RelojDelTurno = almacen.get("_reloj")
		var partida: Partida = almacen.get("_partida")
		for tarea in partida.obligatorias():
			if tarea.tipo() not in [Tarea.Tipo.CAJA, Tarea.Tipo.REGISTRAR]:
				reloj.completar(tarea)
		await _vender(almacen, jornada)
		assert_bool(reloj.obligatoria(Tarea.Tipo.CAJA).completada()).is_true()
		assert_bool(reloj.obligatoria(Tarea.Tipo.REGISTRAR).completada()).is_true()
		assert_array(_textos(almacen)).contains(AVISO)
		var cierres: Array[int] = []
		reloj.turno_cerrado.connect(cierres.append)
		_gesto(almacen, true)
		await _completar_la_salida(almacen)
		assert_array(cierres).is_equal([partida.obligatorias().size()])
		assert_float(_restante(almacen)).is_zero()
		assert_bool((almacen.get("_pantalla") as PantallaDeDevolucion).visible).is_true()
		var persiana: PersianaDeLaNoche = almacen.get_node("Interfaz/PersianaDeLaNoche")
		assert_bool(persiana.visible).is_true()
		AvanceDeDevolucion.entregar(almacen.get("_pantalla"))
		var celular: CelularDelEmpleado = almacen.get("_celular")
		assert_array(celular.bandeja().mensajes_de(Conversacion.Interlocutor.JEFE)).is_not_empty()
		assert_int(Guardado.new().cargar().get("jornada", -1)).is_equal(jornada + 1)
		_gesto(almacen, true)
		almacen.get_node(ENTRADA).call("accionar")
		assert_array(cierres).has_size(1)
		assert_array(_textos(almacen)).is_empty()


# AC-SHF-042, AC-NTF-029, AC-NTF-032
func test_los_botones_retraban_y_recuperan_cada_ciclo() -> void:
	var almacen := await _abrir(1, true)
	var reloj: RelojDelTurno = almacen.get("_reloj")
	for tarea in (almacen.get("_partida") as Partida).obligatorias():
		if tarea.tipo() not in [Tarea.Tipo.CAJA, Tarea.Tipo.REGISTRAR]:
			reloj.completar(tarea)
	await _vender(almacen, 1)
	var computadora: ComputadoraDeEscritorio = almacen.get("_computadora")
	computadora.pedir_abrir()
	computadora.pedir_cerrar()
	var producto := computadora.registro().productos()[0]
	var correctas := computadora.registro().unidades_de(producto)
	var antes := _restante(almacen)
	assert_bool(reloj.obligatoria(Tarea.Tipo.REGISTRAR).completada()).is_true()
	assert_bool(almacen.call("_puede_salir")).is_true()
	assert_array(_textos(almacen)).contains(AVISO)
	for _ciclo in 2:
		computadora.pedir_abrir()
		var sumar := _boton(almacen, 5)
		var restar := _boton(almacen, 3)
		assert_bool(sumar.disabled).is_false()
		assert_bool(restar.disabled).is_false()
		sumar.pressed.emit()
		assert_int(computadora.registro().unidades_de(producto)).is_equal(correctas + 1)
		assert_bool(reloj.obligatoria(Tarea.Tipo.REGISTRAR).completada()).is_false()
		assert_bool(almacen.call("_puede_salir")).is_false()
		almacen.get_node(ENTRADA).call("accionar")
		assert_bool(reloj.corriendo()).is_true()
		assert_str(_referencia(almacen)).not_contains("[Click Izq]")
		assert_array(_textos(almacen)).not_contains(RETRABA).not_contains(AVISO)
		computadora.pedir_cerrar()
		assert_array(_textos(almacen)).contains(RETRABA).not_contains(AVISO)
		_pila(almacen)._process(Notificaciones.DURACION - 0.1)
		almacen.call("_revisar_la_salida")
		_pila(almacen)._process(0.1)
		assert_array(_textos(almacen)).not_contains(RETRABA)
		computadora.pedir_abrir()
		_boton(almacen, 3).pressed.emit()
		assert_int(computadora.registro().unidades_de(producto)).is_equal(correctas)
		assert_bool(reloj.obligatoria(Tarea.Tipo.REGISTRAR).completada()).is_true()
		assert_bool(almacen.call("_puede_salir")).is_true()
		assert_str(_referencia(almacen)).contains("[Click Izq] Interactuar")
		computadora.pedir_cerrar()
		assert_array(_textos(almacen)).not_contains(RETRABA).not_contains(AVISO)
	computadora.pedir_abrir()
	_boton(almacen, 5).pressed.emit()
	assert_bool(almacen.call("_puede_salir")).is_false()
	_boton(almacen, 3).pressed.emit()
	assert_bool(almacen.call("_puede_salir")).is_true()
	computadora.pedir_cerrar()
	assert_array(_textos(almacen)).not_contains(RETRABA).not_contains(AVISO)
	assert_float(_restante(almacen)).is_equal(antes)


func _boton(almacen: Node3D, indice: int) -> Button:
	var pantalla: PantallaDeComputadora = almacen.get_node("Interfaz/PantallaDeComputadora")
	return pantalla.caja().get("_filas").get_child(0).get_child(0).get_child(indice)


func test_el_cierre_real_descarta_la_espera_y_la_noche_siguiente_avisa() -> void:  # AC-NTF-032
	for retrabada: bool in [false, true]:
		var almacen := await _abrir(1)
		var computadora: ComputadoraDeEscritorio = almacen.get("_computadora")
		var reloj: RelojDelTurno = almacen.get("_reloj")
		if retrabada:
			_cumplir(almacen)
		computadora.pedir_abrir()
		if retrabada:
			reloj.descumplir(reloj.obligatoria(Tarea.Tipo.REGISTRAR))
		else:
			_cumplir(almacen)
		assert_array(_textos(almacen)).not_contains(AVISO).not_contains(RETRABA)
		RelojDePrueba.avanzar_turno(reloj, _restante(almacen))
		assert_bool(reloj.corriendo()).is_false()
		assert_bool(computadora.computadora().abierta()).is_false()
		assert_array(_textos(almacen)).is_empty()
		(almacen.get("_ciclo") as CicloDeJornadas).abrir_la_jornada()
		computadora.pedir_abrir()
		_cumplir(almacen)
		assert_bool(almacen.call("_puede_salir")).is_true()
		assert_array(_textos(almacen)).is_empty()
		computadora.pedir_cerrar()
		assert_array(_textos(almacen)).is_equal([AVISO])
		await get_tree().process_frame


func test_completar_solo_al_cerrar_no_avisa_que_se_puede_salir() -> void:  # AC-NTF-028, AC-NTF-031
	var almacen := await _abrir(1)
	var reloj: RelojDelTurno = almacen.get("_reloj")
	for tarea in (almacen.get("_partida") as Partida).obligatorias():
		if tarea.tipo() != Tarea.Tipo.REGISTRAR:
			reloj.completar(tarea)
	assert_bool(reloj.obligatoria(Tarea.Tipo.REGISTRAR).completada()).is_false()
	var al_completar: Array[bool] = []
	reloj.tarea_completada.connect(
		func(_cuantas: int) -> void:
			al_completar.append(true)
			assert_array(_textos(almacen)).not_contains(AVISO).not_contains(RETRABA)
	)
	RelojDePrueba.avanzar_turno(reloj, _restante(almacen))
	assert_array(al_completar).is_equal([true])
	assert_bool(reloj.obligatoria(Tarea.Tipo.REGISTRAR).completada()).is_true()
	assert_array(_textos(almacen)).is_empty()
	assert_bool(almacen.call("_puede_salir")).is_false()


func _vender(almacen: Node3D, jornada: int) -> void:
	var reloj: RelojDelTurno = almacen.get("_reloj")
	var atenciones: Ventanilla = almacen.get("_atenciones")
	var computadora: ComputadoraDeEscritorio = almacen.get("_computadora")
	for comprador in Compradores.de_la_jornada(jornada):
		var actual := Reglas.DURACION_DEL_TURNO - _restante(almacen)
		RelojDePrueba.avanzar_turno(reloj, comprador.horario.x - actual)
		var atencion := atenciones.atencion()
		assert_object(atencion).is_not_null()
		assert_str(atencion.comprador().nombre()).is_equal(comprador.nombre())
		while not atenciones.puede_abandonar() or not atencion.conversacion_iniciada():
			atenciones.pedir_interaccion(null)
		var estante := Estante.new(atencion.get("_inventario") as Inventario, Catalogo.todos())
		var renglones: Array[Producto] = []
		for producto in comprador.pedido().productos():
			for _unidad in comprador.pedido().unidades_de(producto):
				var unidad := estante.retirar(producto)
				assert_object(unidad).is_not_null()
				assert_int(atenciones.pedir_interaccion(unidad)).is_equal(
					RecepcionDeCompra.Resultado.ACEPTADA
				)
				renglones.append(producto)
		assert_int(atenciones.pedir_interaccion(Ticket.new(renglones))).is_equal(
			RecepcionDeCompra.Resultado.COMPLETA
		)
		assert_bool(atencion.vendida()).is_true()
		assert_array(_textos(almacen)).not_contains(AVISO)
		for producto in renglones:
			computadora.pedir_sumar(producto)
		for _entrada in 12:
			if atencion.despachada():
				break
			atenciones.pedir_interaccion(null)
		assert_bool(atencion.despachada()).is_true()
		await get_tree().process_frame


func test_entrada_sin_permiso_suena_trabada() -> void:  # AC-PLY-103, AC-PLY-040
	for jornada: int in [
		ReglasDeLaPartida.PRIMERA_JORNADA, ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA
	]:
		var almacen := await _abrir(jornada)
		var entrada: Node3D = almacen.get_node(ENTRADA)
		var trabadas: Array[Node3D] = []
		entrada.connect("puerta_trabada", trabadas.append)
		if jornada == ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA:
			_cumplir(almacen)
		assert_str(_referencia(almacen)).not_contains("[Click Izq]")
		_gesto(almacen, true)
		assert_array(trabadas).is_equal([entrada])
		_gesto(almacen, false)
		assert_array(trabadas).has_size(1)
		assert_bool(entrada.call("puerta").abierta()).is_false()
		assert_float(entrada.call("puerta").angulo()).is_zero()
		assert_bool((almacen.get("_reloj") as RelojDelTurno).corriendo()).is_true()


func test_la_salida_respeta_mano_y_suspension() -> void:  # AC-PLY-104, AC-PLY-103
	for con_objeto: bool in [false, true]:
		var almacen := await _abrir(1)
		_cumplir(almacen)
		var jugador: Node3D = almacen.get("_jugador")
		var agarre: Agarre = almacen.get("_agarre")
		var objeto: Node3D = almacen.get("_cajas_de_productos")[0]
		if con_objeto:
			assert_bool(agarre.pedir_agarrar(objeto.get("datos"), objeto)).is_true()
		var sostenido := agarre.manos().sostenido()
		var padre := objeto.get_parent()
		_pila(almacen)._process(Notificaciones.DURACION)
		assert_str(_referencia(almacen)).contains("[Click Izq] Interactuar")
		_gesto(almacen, false)
		jugador.call("suspender")
		_gesto(almacen, true)
		assert_bool(almacen.get("_reloj").corriendo()).is_true()
		jugador.call("reanudar")
		jugador.set("_en_pausa", true)
		get_tree().paused = true
		_gesto(almacen, true)
		assert_bool(almacen.get("_reloj").corriendo()).is_true()
		get_tree().paused = false
		jugador.set("_en_pausa", false)
		_gesto(almacen, true)
		assert_bool(jugador.call("suspendido")).is_true()
		assert_object(agarre.manos().sostenido()).is_same(sostenido)
		assert_bool((almacen.get("_pantalla") as PantallaDeDevolucion).visible).is_false()
		await _completar_la_salida(almacen)
		assert_bool(almacen.get("_reloj").corriendo()).is_false()
		assert_object(agarre.manos().sostenido()).is_same(sostenido)
		assert_object(objeto.get_parent()).is_same(padre)
		assert_bool(almacen.get_node(ENTRADA).call("puerta").abierta()).is_true()


func test_otra_apertura_reinicia_la_salida() -> void:  # AC-SHF-039
	var almacen := await _abrir(1)
	_cumplir(almacen)
	assert_bool(almacen.call("_puede_salir")).is_true()
	_gesto(almacen, true)
	var ciclo: CicloDeJornadas = almacen.get("_ciclo")
	ciclo.abrir_la_jornada()
	assert_bool(almacen.call("_puede_salir")).is_false()
	assert_array(_textos(almacen)).is_empty()
	var computadora: ComputadoraDeEscritorio = almacen.get("_computadora")
	for producto in computadora.registro().productos():
		assert_int(computadora.registro().unidades_de(producto)).is_zero()
	assert_bool(computadora.registro().sumar(Catalogo.todos()[0])).is_true()
	var registrar := (almacen.get("_reloj") as RelojDelTurno).obligatoria(Tarea.Tipo.REGISTRAR)
	assert_bool(registrar.completar()).is_true()
	assert_bool(registrar.descompletar()).is_true()
	var retomado := await _abrir(1)
	assert_bool(retomado.call("_puede_salir")).is_false()


func test_hud_y_nota_de_la_primera() -> void:  # AC-SHF-005, AC-SHF-027, AC-STK-094
	var almacen := await _abrir(1, true)
	var reloj: RelojDelTurno = almacen.get("_reloj")
	assert_object(reloj.obligatoria(Tarea.Tipo.REPONER)).is_null()
	var hud: Hud = almacen.get("_hud")
	assert_str((hud.get("_tareas") as Label).text).is_equal("Tareas 0/2")
	var notas: Array = almacen.get_node("Estructura/NotasDelAlmacen").get("notas")
	var tareas: Array[NotaPegada] = []
	for nodo: Node in notas:
		if nodo.get("id") == NotaPegada.Id.TAREAS_A_REALIZAR:
			tareas.append(nodo.call("dato") as NotaPegada)
	assert_array(tareas).has_size(1)
	(
		assert_array(tareas[0].renglones())
		. contains_exactly(
			[
				NotaPegada.NOMBRES_DE_LAS_TAREAS[Tarea.Tipo.CAJA],
				NotaPegada.NOMBRES_DE_LAS_TAREAS[Tarea.Tipo.REGISTRAR],
			]
		)
	)


func _completar_la_salida(almacen: Node3D) -> void:
	var entrada: Node3D = almacen.get_node(ENTRADA)
	await assert_signal(entrada).wait_until(5000).is_emitted("hoja_quieta", entrada)
	assert_bool((almacen.get("_pantalla") as PantallaDeDevolucion).visible).is_true()
