## Los vencidos tirados al contenedor cumplen su obligatoria al llegar el quinto.
extends GdUnitTestSuite

const JORNADA := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 2

var _reloj: RelojDelTurno


func _recolector(jornada: int = JORNADA) -> RecolectorDeBasura:
	var obligatorias := Apertura.obligatorias(jornada)
	var turno := Turno.new(Reglas.DURACION_DEL_TURNO, obligatorias)
	_reloj = auto_free(RelojDelTurno.new())
	_reloj.arrancar(turno, obligatorias)
	var agarre: Agarre = auto_free(Agarre.new())
	agarre.punto_de_carga = auto_free(Node3D.new())
	var repositor: Repositor = auto_free(Repositor.new())
	repositor.agarre = agarre
	repositor.reloj = _reloj
	var producto := Catalogo.de(Producto.Id.CINDOLOR)
	var inventario := Inventario.new([producto], {producto.id: 8})
	inventario.ingresar(producto, Inventario.Ubicacion.DEPOSITO, 8)
	repositor.arrancar(Estante.new(inventario, [producto]))
	var recolector: RecolectorDeBasura = auto_free(RecolectorDeBasura.new())
	recolector.reloj = _reloj
	recolector.agarre = agarre
	recolector.repositor = repositor
	recolector.arrancar(
		TareaDeLaBasura.de_la_jornada(jornada), TareaDeLosVencidos.de_la_jornada(jornada)
	)
	return recolector


func _tirar(recolector: RecolectorDeBasura, vencida: bool) -> void:
	var unidad := UnidadDeProducto.new(Catalogo.de(Producto.Id.CINDOLOR), vencida)
	var cuerpo: Node3D = auto_free(Node3D.new())
	assert_bool(recolector.agarre.pedir_agarrar(unidad, cuerpo)).is_true()
	assert_int(recolector.pedir_tirar(true)).is_equal(ReglasDeLaBasura.Tiro.TIRADO)


func _cumplida() -> bool:
	return _reloj.obligatoria(Tarea.Tipo.DESECHAR_VENCIDOS).completada()


func test_con_cuatro_tirados_no_se_cumple_y_con_el_quinto_si() -> void:  # AC-SHF-059, AC-SHF-061
	var recolector := _recolector()
	for _vencido in ReglasDelEstante.CINDOLOR_VENCIDOS - 1:
		_tirar(recolector, true)
	assert_bool(_cumplida()).is_false()
	_tirar(recolector, true)
	assert_bool(_cumplida()).is_true()


func test_tirar_otro_objeto_despues_no_deshace_el_cumplimiento() -> void:  # AC-SHF-059
	var recolector := _recolector()
	for _vencido in ReglasDelEstante.CINDOLOR_VENCIDOS:
		_tirar(recolector, true)
	_tirar(recolector, false)
	assert_bool(_cumplida()).is_true()


func test_un_sano_de_mas_no_suple_al_quinto_y_con_el_quinto_cumple() -> void:  # AC-SHF-060
	var recolector := _recolector()
	for _vencido in ReglasDelEstante.CINDOLOR_VENCIDOS - 1:
		_tirar(recolector, true)
	_tirar(recolector, false)
	assert_bool(_cumplida()).is_false()
	_tirar(recolector, true)
	assert_bool(_cumplida()).is_true()


func test_una_jornada_sin_vencidos_no_cuenta_los_que_se_tiran() -> void:  # AC-SHF-059
	var recolector := _recolector(JORNADA + 1)
	for _vencido in ReglasDelEstante.CINDOLOR_VENCIDOS:
		_tirar(recolector, true)
	assert_object(_reloj.obligatoria(Tarea.Tipo.DESECHAR_VENCIDOS)).is_null()
