extends GdUnitTestSuite

const RelojDePrueba := preload("res://test/reloj_de_prueba.gd")

var _reloj: RelojDelTurno
var _ventanilla: Ventanilla


func after_test() -> void:
	get_tree().paused = false
	if is_instance_valid(_ventanilla):
		_ventanilla.queue_free()
	if is_instance_valid(_reloj):
		_reloj.queue_free()
	await get_tree().process_frame


func _abrir(compradores: Array[Comprador]) -> void:
	_reloj = RelojDelTurno.new()
	_ventanilla = Ventanilla.new()
	_ventanilla.reloj = _reloj
	add_child(_reloj)
	add_child(_ventanilla)
	_reloj.set_process(false)
	var obligatorias := Apertura.obligatorias(Compradores.JORNADA_DE_FEDE_Y_MIA)
	_reloj.arrancar(Apertura.turno_de_la_jornada(obligatorias), obligatorias)
	_ventanilla.arrancar(TareaDeAtender.new(compradores, Inventario.new(Catalogo.todos())))


func test_cada_frontera_exacta_emite_una_vez_la_instancia_original() -> void:  # AC-CTR-050
	var compradores := Compradores.segunda_jornada_definida()
	_abrir(compradores)
	var eventos: Array[Array] = []
	_ventanilla.comprador_llegado.connect(
		func(c: Comprador) -> void: eventos.append([AgendaDeCompradores.Tipo.LLEGO, c])
	)
	_ventanilla.comprador_vencido.connect(
		func(c: Comprador) -> void: eventos.append([AgendaDeCompradores.Tipo.VENCIO, c])
	)
	var antes := 0.0
	for indice in 2:
		for extremo in 2:
			var instante: float = compradores[indice].horario[extremo]
			var cantidad := indice * 2 + extremo
			RelojDePrueba.avanzar_turno(_reloj, instante - 1.0 - antes)
			assert_array(eventos).has_size(cantidad)
			RelojDePrueba.avanzar_turno(_reloj, 1.0)
			assert_array(eventos).has_size(cantidad + 1)
			assert_int(eventos[-1][0]).is_equal(extremo)
			assert_object(eventos[-1][1]).is_same(compradores[indice])
			_reloj.avanzar(0.0)
			assert_array(eventos).has_size(cantidad + 1)
			RelojDePrueba.avanzar_turno(_reloj, 1.0)
			assert_array(eventos).has_size(cantidad + 1)
			antes = instante + 1.0
	assert_bool(_ventanilla.tarea().completada()).is_false()


# AC-CTR-050, AC-CTR-054
func test_saltar_al_cierre_procesa_mia_antes_de_publicar_el_resultado() -> void:
	var compradores := Compradores.segunda_jornada_definida()
	_abrir(compradores)
	var eventos: Array[String] = []
	_ventanilla.comprador_llegado.connect(
		func(c: Comprador) -> void: eventos.append("llega " + c.nombre())
	)
	_ventanilla.comprador_vencido.connect(
		func(c: Comprador) -> void: eventos.append("vence " + c.nombre())
	)
	var al_cerrar := func(_cumplidas: int) -> void:
		eventos.append("cierra")
		assert_bool(_ventanilla.tarea().compras_cerradas()).is_true()
	_reloj.turno_cerrado.connect(al_cerrar)
	RelojDePrueba.avanzar_turno(_reloj, Reglas.DURACION_DEL_TURNO)
	assert_array(eventos).contains_exactly(
		["llega Fede", "vence Fede", "llega Mía", "vence Mía", "cierra"]
	)
	_reloj.avanzar(100.0)
	assert_array(eventos).has_size(5)


func test_la_pausa_real_no_adelanta_la_agenda_de_j2() -> void:  # AC-CTR-050
	_abrir(Compradores.segunda_jornada_definida())
	_reloj.set_process(true)
	await get_tree().process_frame
	get_tree().paused = true
	var turno: Turno = _reloj.get("_turno")
	var antes := turno.tiempo_restante()
	await get_tree().create_timer(0.05, true).timeout
	assert_float(turno.tiempo_restante()).is_equal(antes)
	assert_object(_ventanilla.atencion()).is_null()
	get_tree().paused = false
	await get_tree().process_frame
	_reloj.set_process(false)
	assert_bool(_reloj.corriendo()).is_true()
