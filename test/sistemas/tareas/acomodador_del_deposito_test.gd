extends GdUnitTestSuite


func test_cumple_descumple_y_congela_el_cierre() -> void:  # AC-STK-079, AC-SHF-007, AC-SHF-019
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	var acomodador: AcomodadorDelDeposito = auto_free(AcomodadorDelDeposito.new())
	acomodador.reloj = reloj
	var tareas := Apertura.obligatorias(1)
	reloj.arrancar(Turno.new(1.0, tareas), tareas)
	var estado := OrdenDelDeposito.Estado.new(Producto.Id.ACTRONCITO)
	var cambios: Array[int] = []
	reloj.tarea_completada.connect(func(cantidad: int) -> void: cambios.append(cantidad))
	reloj.tarea_descumplida.connect(func(cantidad: int) -> void: cambios.append(cantidad))
	acomodador.revisar([estado])
	estado.apoyo = OrdenDelDeposito.Apoyo.ESTANTERIA
	acomodador.revisar([estado])
	assert_array(cambios).contains_exactly([1])
	assert_bool(reloj.obligatoria(Tarea.Tipo.ORDENAR_LAS_CAJAS).completada()).is_true()
	estado.apoyo = OrdenDelDeposito.Apoyo.OTRO
	acomodador.revisar([estado])
	assert_array(cambios).contains_exactly([1, 0])
	estado.en_mano = true
	acomodador.revisar([estado])
	reloj.avanzar(1.0)
	estado.en_mano = false
	acomodador.revisar([estado])
	assert_bool(reloj.obligatoria(Tarea.Tipo.ORDENAR_LAS_CAJAS).completada()).is_true()
	assert_array(cambios).contains_exactly([1, 0, 1])


func test_sin_particular_no_completa_otra_tarea() -> void:  # AC-STK-079
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	var tareas := Apertura.obligatorias(3)
	var turno := Turno.new(1.0, tareas)
	reloj.arrancar(turno, tareas)
	var acomodador: AcomodadorDelDeposito = auto_free(AcomodadorDelDeposito.new())
	acomodador.reloj = reloj
	acomodador.revisar([])
	assert_int(turno.tareas_cumplidas()).is_zero()
