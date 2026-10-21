## El cableado de la primera noche que termina sola: el almacén pregunta al dominio cada vez que
## una obligatoria se cumple, y el reloj acelera. La noche abre sin compradores para que el ciclo
## de la ventanilla ya esté cerrado y la condición dependa sólo de las obligatorias.
extends GdUnitTestSuite

const RUTA_DEL_ALMACEN := "res://src/escenas/almacen.tscn"
const RelojDePrueba := preload("res://test/reloj_de_prueba.gd")

var _cierres := 0
var _almacen: Node3D


func before_test() -> void:
	_cierres = 0


func _abrir(jornada: int, con_compradores: bool = false) -> RelojDelTurno:
	var escena := load(RUTA_DEL_ALMACEN) as PackedScene
	var almacen: Node3D = auto_free(escena.instantiate())
	almacen.set("_partida", Partida.desde({"jornada": jornada}))
	if not con_compradores:
		almacen.set(
			"compradores_de_la_apertura",
			func(_jornada: int) -> Array[Comprador]:
				var nadie: Array[Comprador] = []
				return nadie
		)
	add_child(almacen)
	_almacen = almacen
	var reloj: RelojDelTurno = almacen.get("_reloj")
	reloj.set_process(false)
	almacen.get("_jugador").set_physics_process(false)
	await get_tree().process_frame
	assert_bool((almacen.get("_atenciones") as Ventanilla).tarea().compras_cerradas()).is_equal(
		not con_compradores
	)
	reloj.turno_cerrado.connect(func(_cumplidas: int) -> void: _cierres += 1)
	return reloj


func _cumplir_lo_que_no_es_cobrar(reloj: RelojDelTurno, jornada: int) -> void:
	for tarea in Apertura.obligatorias(jornada):
		if tarea.tipo() != Tarea.Tipo.CAJA:
			reloj.completar(reloj.obligatoria(tarea.tipo()))


func _restante(reloj: RelojDelTurno) -> float:
	return (reloj.get("_turno") as Turno).tiempo_restante()


func _baja_en(reloj: RelojDelTurno, segundos_reales: float) -> float:
	reloj.avanzar(0.0)
	var antes := _restante(reloj)
	reloj.avanzar(segundos_reales)
	return antes - _restante(reloj)


func test_cumplir_lo_ultimo_acelera_hasta_el_cierre() -> void:  # AC-SHF-031, AC-SHF-032
	var jornada := ReglasDeLaPartida.PRIMERA_JORNADA
	var reloj := await _abrir(jornada)
	assert_float(_baja_en(reloj, 1.0)).is_equal(Ritmo.de_la_jornada(jornada))
	RelojDePrueba.avanzar_hasta(reloj, Vector2i(5, 59))
	var cobrar := reloj.obligatoria(Tarea.Tipo.CAJA)
	assert_bool(cobrar.completada()).is_false()
	_cumplir_lo_que_no_es_cobrar(reloj, jornada)
	reloj.avanzar(0.0)
	var duracion := CierreAnticipado.DURACION_DE_LA_ACELERACION
	var restante := _restante(reloj)
	assert_float(_baja_en(reloj, 1.0)).is_equal_approx(restante / duracion, 0.001)
	reloj.avanzar(duracion * 0.5)
	assert_int(_cierres).is_zero()
	reloj.avanzar(duracion)
	assert_float(_restante(reloj)).is_equal(0.0)
	assert_int(_cierres).is_equal(1)
	assert_bool(cobrar.completada()).is_false()


func test_si_nadie_compra_acelera_al_vencer_el_ultimo() -> void:  # AC-SHF-032
	var jornada := ReglasDeLaPartida.PRIMERA_JORNADA
	var reloj := await _abrir(jornada, true)
	assert_object(reloj.obligatoria(Tarea.Tipo.REPONER)).is_null()
	var compradores := Compradores.de_la_jornada(jornada)
	var vencido := [false]
	var atenciones: Ventanilla = _almacen.get("_atenciones")
	atenciones.comprador_vencido.connect(
		func(comprador: Comprador) -> void:
			if comprador.nombre() == compradores[-1].nombre():
				vencido[0] = true
	)
	assert_float(_baja_en(reloj, 1.0)).is_equal(Ritmo.de_la_jornada(jornada))
	var transcurrido := Reglas.DURACION_DEL_TURNO - _restante(reloj)
	RelojDePrueba.avanzar_turno(reloj, compradores[-1].horario.y - transcurrido - 1.0)
	assert_bool(vencido[0]).is_false()
	RelojDePrueba.avanzar_turno(reloj, 2.0)
	assert_bool(vencido[0]).is_true()
	assert_bool(reloj.obligatoria(Tarea.Tipo.REGISTRAR).completada()).is_false()
	reloj.avanzar(0.0)
	var restante := _restante(reloj)
	var duracion := CierreAnticipado.DURACION_DE_LA_ACELERACION
	assert_float(_baja_en(reloj, 1.0)).is_equal_approx(restante / duracion, 0.001)
	reloj.avanzar(duracion)
	assert_int(_cierres).is_equal(1)
	assert_bool(reloj.obligatoria(Tarea.Tipo.REGISTRAR).completada()).is_true()
	assert_bool(reloj.obligatoria(Tarea.Tipo.CAJA).completada()).is_false()
	var partida: Partida = _almacen.get("_partida")
	assert_int(partida.antecedentes().fallas(Tarea.Tipo.REPONER)).is_zero()


func test_descumplir_despues_de_acelerar_no_frena() -> void:  # AC-SHF-034
	var jornada := ReglasDeLaPartida.PRIMERA_JORNADA
	var reloj := await _abrir(jornada)
	_cumplir_lo_que_no_es_cobrar(reloj, jornada)
	var registrar := reloj.obligatoria(Tarea.Tipo.REGISTRAR)
	var computadora: ComputadoraDeEscritorio = _almacen.get("_computadora")
	computadora.pedir_sumar(Catalogo.de(Producto.Id.MAROLINI))
	assert_bool(computadora.registro().coincide()).is_false()
	assert_bool(registrar.completada()).is_false()
	reloj.avanzar(0.0)
	var duracion := CierreAnticipado.DURACION_DE_LA_ACELERACION
	var restante := _restante(reloj)
	assert_float(_baja_en(reloj, 1.0)).is_equal_approx(restante / duracion, 0.001)
	reloj.avanzar(duracion)
	assert_int(_cierres).is_equal(1)
	assert_bool(computadora.registro().coincide()).is_false()
	assert_bool(registrar.completada()).is_false()


func test_las_otras_noches_no_aceleran() -> void:  # AC-SHF-035
	for jornada: int in [
		ReglasDeLaPartida.PRIMERA_JORNADA + 1,
		ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA,
		ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA,
	]:
		var reloj := await _abrir(jornada)
		_cumplir_lo_que_no_es_cobrar(reloj, jornada)
		(
			assert_float(_baja_en(reloj, 1.0))
			. override_failure_message("jornada %d" % jornada)
			. is_equal(Ritmo.de_la_jornada(jornada))
		)


func test_retomar_la_primera_noche_vuelve_al_ritmo_de_la_jornada() -> void:  # AC-SHF-035
	var jornada := ReglasDeLaPartida.PRIMERA_JORNADA
	var reloj := await _abrir(jornada)
	_cumplir_lo_que_no_es_cobrar(reloj, jornada)
	assert_float(_baja_en(reloj, 1.0)).is_greater(Ritmo.de_la_jornada(jornada))
	var retomado := await _abrir(jornada)
	assert_float(_baja_en(retomado, 1.0)).is_equal(Ritmo.de_la_jornada(jornada))


func test_la_ultima_compra_fisica_acelera_antes_de_la_despedida() -> void:  # AC-SHF-031
	var jornada := ReglasDeLaPartida.PRIMERA_JORNADA
	var reloj := await _abrir(jornada, true)
	var atenciones: Ventanilla = _almacen.get("_atenciones")
	var computadora: ComputadoraDeEscritorio = _almacen.get("_computadora")
	var compradores := Compradores.de_la_jornada(jornada)
	var compras: Array[bool] = []
	atenciones.compra_realizada.connect(func() -> void: compras.append(true))
	assert_object(reloj.obligatoria(Tarea.Tipo.REPONER)).is_null()
	for comprador in compradores:
		var hora := Vector2i(5, 59) if comprador == compradores[-1] else Vector2i(22, 0)
		RelojDePrueba.avanzar_hasta(reloj, hora)
		var atendida := atenciones.atencion()
		assert_str(atendida.comprador().nombre()).is_equal(comprador.nombre())
		assert_bool(atendida.fisica()).is_true()
		var inventario: Inventario = atendida.get("_inventario")
		var estante := Estante.new(inventario, Catalogo.todos())
		atenciones.pedir_interaccion(null)
		for _entrada in 8:
			if atenciones.puede_abandonar():
				break
			atenciones.pedir_interaccion(null)
		assert_bool(atenciones.puede_abandonar()).is_true()
		var renglones: Array[Producto] = []
		for producto in comprador.pedido().productos():
			for _unidad in comprador.pedido().unidades_de(producto):
				computadora.pedir_sumar(producto)
				var ocupados := estante.casilleros_ocupados(producto)
				assert_array(ocupados).is_not_empty()
				var unidad := estante.agarrar(producto, ocupados[0])
				assert_object(unidad).is_not_null()
				assert_int(atenciones.pedir_interaccion(unidad)).is_equal(
					RecepcionDeCompra.Resultado.ACEPTADA
				)
				renglones.append(producto)
		assert_bool(atendida.vendida()).is_false()
		assert_float(_baja_en(reloj, 0.01)).is_equal_approx(
			Ritmo.de_la_jornada(jornada) * 0.01, 0.001
		)
		assert_int(atenciones.pedir_interaccion(Ticket.new(renglones))).is_equal(
			RecepcionDeCompra.Resultado.COMPLETA
		)
		assert_bool(atendida.vendida()).is_true()
	assert_array(compras).has_size(compradores.size())
	var repositor: Repositor = _almacen.get("_repositor")
	assert_bool(repositor.estante().completada()).is_false()
	assert_bool(atenciones.atencion().despachada()).is_false()
	assert_bool(reloj.obligatoria(Tarea.Tipo.CAJA).completada()).is_true()
	assert_bool(reloj.obligatoria(Tarea.Tipo.REGISTRAR).completada()).is_true()
	reloj.avanzar(0.0)
	var restante := _restante(reloj)
	var duracion := CierreAnticipado.DURACION_DE_LA_ACELERACION
	assert_float(_baja_en(reloj, 1.0)).is_equal_approx(restante / duracion, 0.001)
	reloj.avanzar(duracion - 1.001)
	assert_int(_cierres).is_zero()
	reloj.avanzar(0.002)
	assert_float(_restante(reloj)).is_zero()
	assert_int(_cierres).is_equal(1)


func test_hud_y_nota_de_la_primera() -> void:  # AC-SHF-005, AC-SHF-027, AC-STK-094
	var reloj := await _abrir(1, true)
	assert_object(reloj.obligatoria(Tarea.Tipo.REPONER)).is_null()
	var hud: Hud = _almacen.get("_hud")
	assert_str((hud.get("_tareas") as Label).text).is_equal("Tareas 0/2")
	var notas: Array = _almacen.get_node("Estructura/NotasDelAlmacen").get("notas")
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
