extends GdUnitTestSuite


func test_el_fin_se_publica_solo_en_la_pulsacion_que_termina() -> void:  # AC-CTR-047
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	var obligatorias := Apertura.obligatorias(4)
	reloj.arrancar(Turno.new(Reglas.DURACION_DEL_TURNO, obligatorias), obligatorias)
	var ventanilla: Ventanilla = auto_free(Ventanilla.new())
	ventanilla.reloj = reloj
	var compradores := Compradores.de_la_jornada(4)
	var dialogos := DialogosDeCompradores.new()
	dialogos.tin = PackedStringArray(["Una sola entrada"])
	compradores[0].dialogos = dialogos
	ventanilla.arrancar(TareaDeAtender.new(compradores, Inventario.new(Catalogo.todos())))
	reloj.avanzar(120.0)
	var finales: Array[bool] = []
	ventanilla.conversacion_terminada.connect(func() -> void: finales.append(true))
	ventanilla.pedir_interaccion(null)
	assert_array(finales).is_empty()
	assert_str(ventanilla.atencion().dialogo().entrada_actual()).is_equal("Una sola entrada")
	ventanilla.pedir_interaccion(null)
	assert_array(finales).has_size(1)
	assert_bool(ventanilla.atencion().dialogo().terminado()).is_true()
