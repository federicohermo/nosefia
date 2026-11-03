extends GdUnitTestSuite

const AvanceDeDevolucion := preload("res://test/avance_de_devolucion.gd")

const ESCENA_DEL_ALMACEN := "res://src/escenas/almacen.tscn"
const NOTAS := Conversacion.Interlocutor.NOTAS
const RelojDePrueba := preload("res://test/reloj_de_prueba.gd")
## Cuántos cuadros se espera, como mucho, a que termine un calentamiento.
const CUADROS_DEL_CALENTAMIENTO := 3000

var _ruta_guardado: String


func before_test() -> void:
	_ruta_guardado = Guardado.ruta_por_defecto
	Guardado.ruta_por_defecto = "user://cierre_436.guardado"
	Guardado.new().borrar()


func after_test() -> void:
	get_tree().paused = false
	Guardado.new().borrar()
	Guardado.ruta_por_defecto = _ruta_guardado


func _almacen(partida: Partida = null) -> Node3D:
	var almacen: Node3D = auto_free(load(ESCENA_DEL_ALMACEN).instantiate())
	if partida != null:
		almacen.set("_partida", partida)
	add_child(almacen)
	await get_tree().process_frame
	return almacen


func _hasta_la_reflexion(almacen: Node3D) -> PantallaDeDevolucion:
	RelojDePrueba.avanzar_turno(
		almacen.get_node("Servicios/RelojDelTurno"), Reglas.DURACION_DEL_TURNO
	)
	await get_tree().process_frame
	var pantalla: PantallaDeDevolucion = almacen.get("_pantalla")
	AvanceDeDevolucion.entregar(pantalla)
	pantalla.elegir()
	AvanceDeDevolucion.terminar_movimiento(pantalla)
	return pantalla


func _aperturas(almacen: Node3D) -> Array[int]:
	var aperturas: Array[int] = []
	(almacen.get("_ciclo") as CicloDeJornadas).jornada_abierta.connect(aperturas.append)
	return aperturas


func _celular(almacen: Node3D) -> CelularDelEmpleado:
	return almacen.get_node("Interfaz/CelularDelEmpleado")


func _recuadro(almacen: Node3D) -> PantallaDeHipotesis:
	return almacen.get_node("Interfaz/PantallaDeHipotesis")


func _q() -> InputEventAction:
	var q := InputEventAction.new()
	q.action = Celular.ACCION
	q.pressed = true
	return q


func _segunda_con(pistas: Array[String]) -> Partida:
	var partida := Partida.desde({"jornada": ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1})
	partida.abrir_la_jornada()
	for pista: String in pistas:
		partida.expediente.registrar(pista)
	return partida


func test_la_reflexion_retiene_la_entrada_y_fija_las_notas() -> void:  # AC-SHF-028, AC-INV-057
	var almacen: Node3D = await _almacen(
		Partida.desde({"jornada": ReflexionDeCierre.JORNADA_DE_LOS_TEXTOS})
	)
	var aperturas := _aperturas(almacen)
	var pantalla := await _hasta_la_reflexion(almacen)
	assert_bool(pantalla.visible).is_true()
	assert_bool(_recuadro(almacen).visible).is_true()
	assert_int(_celular(almacen).celular().chat()).is_equal(NOTAS)
	almacen.call("_process", 30.0)
	almacen.call("_unhandled_input", _q())
	_celular(almacen).pedir_volver()
	assert_array(aperturas).is_empty()
	assert_bool(_celular(almacen).celular().fijo()).is_true()
	assert_int(_celular(almacen).celular().chat()).is_equal(NOTAS)
	assert_bool((almacen.get("_jugador") as Node).call("suspendido")).is_true()
	assert_bool((almacen.get("_reloj") as RelojDelTurno).corriendo()).is_false()
	var recuadro := _recuadro(almacen)
	for _texto: int in ReflexionDeCierre.TEXTOS_DE_LA_PRIMERA.size():
		recuadro.botones().back().pressed.emit()
	assert_bool(recuadro.visible).is_false()
	assert_int(_celular(almacen).bandeja().mensajes_de(NOTAS).size()).is_equal(
		ReflexionDeCierre.TEXTOS_DE_LA_PRIMERA.size()
	)
	AvanceDeDevolucion.terminar_movimiento(pantalla)
	assert_array(aperturas).is_equal([4])
	assert_bool(pantalla.visible).is_false()
	assert_bool(_celular(almacen).celular().fijo()).is_false()


func test_elegir_guarda_y_la_espera_retiene_la_tercera() -> void:  # AC-INV-062, AC-SAV-029
	var almacen: Node3D = await _almacen(_segunda_con(["2A", "2B"]))
	var aperturas := _aperturas(almacen)
	var pantalla := await _hasta_la_reflexion(almacen)
	var recuadro := _recuadro(almacen)
	assert_int(recuadro.botones().size()).is_equal(3)
	recuadro.botones()[1].pressed.emit()
	recuadro.botones().back().pressed.emit()
	var guardado := Guardado.new().cargar()
	assert_dict(guardado["elecciones"]).is_equal({4: "2B"})
	assert_int(guardado["cierre_pendiente"]).is_zero()
	var cuadro := 1.0 / 60.0
	almacen.call("_process", ReflexionDeCierre.ESPERA_ANTES_DE_LA_NOCHE - cuadro)
	assert_bool(recuadro.visible).is_true()
	assert_array(aperturas).is_empty()
	almacen.call("_process", cuadro)
	almacen.call("_process", 10.0)
	assert_bool(recuadro.visible).is_false()
	AvanceDeDevolucion.terminar_movimiento(pantalla)
	assert_array(aperturas).is_equal([5])


func test_retomar_vuelve_a_la_eleccion_sin_la_devolucion() -> void:  # AC-SAV-029
	var previa := _segunda_con(["2A"])
	previa.cerrar_la_jornada(0)
	Guardado.new().escribir(PoliticaDeGuardado.datos(previa))
	var almacen: Node3D = await _almacen()
	var aperturas := _aperturas(almacen)
	assert_bool((almacen.get("_reloj") as RelojDelTurno).corriendo()).is_false()
	var reposicion: Node3D = almacen.get("_reposicion_manual")
	(
		assert_array(reposicion.find_children("SueltosDe*", "MultiMeshInstance3D", false, false))
		. is_empty()
	)
	almacen.call("retomar_la_partida")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var pantalla: PantallaDeDevolucion = almacen.get("_pantalla")
	assert_int(pantalla.a_la_vista()).is_zero()
	AvanceDeDevolucion.terminar_movimiento(pantalla)
	AvanceDeDevolucion.terminar_movimiento(pantalla)
	var recuadro := _recuadro(almacen)
	assert_bool(recuadro.visible).is_true()
	assert_int(recuadro.botones().size()).is_equal(1)
	assert_array(aperturas).is_empty()
	recuadro.botones().back().pressed.emit()
	assert_dict(Guardado.new().cargar()["elecciones"]).is_equal({4: "2A"})
	almacen.call("_process", ReflexionDeCierre.ESPERA_ANTES_DE_LA_NOCHE)
	AvanceDeDevolucion.terminar_movimiento(pantalla)
	assert_array(aperturas).is_equal([5])
	assert_int(pantalla.a_la_vista()).is_zero()
	var grupos := reposicion.find_children("SueltosDe*", "MultiMeshInstance3D", false, false)
	assert_int(grupos.size()).is_equal(Catalogo.todos().size())
	var casilleros: Dictionary = reposicion.call("casilleros")
	for producto: Producto in Catalogo.todos():
		var grupo := reposicion.get_node("SueltosDe" + producto.nombre) as MultiMeshInstance3D
		assert_int(grupo.multimesh.instance_count).is_equal(casilleros[producto.id])
	almacen.get_node("Interfaz/PersianaDeLaNoche").terminar()
	var reloj: RelojDelTurno = almacen.get("_reloj")
	for tarea: Tarea in (almacen.get("_partida") as Partida).obligatorias():
		tarea.completar()
	RelojDePrueba.avanzar_turno(reloj, Reglas.DURACION_DEL_TURNO)
	await get_tree().process_frame
	AvanceDeDevolucion.entregar(pantalla)
	pantalla.elegir()
	AvanceDeDevolucion.terminar_movimiento(pantalla)
	# La noche del corte espera a que su oscuridad quede preparada.
	for _cuadro in CUADROS_DEL_CALENTAMIENTO:
		if aperturas.size() == 2:
			break
		await get_tree().process_frame
	assert_array(aperturas).is_equal([5, 6])
	(
		assert_array(reposicion.find_children("SueltosDe*", "MultiMeshInstance3D", false, false))
		. is_equal(grupos)
	)


func test_las_notas_de_la_tercera_noche() -> void:  # AC-INV-064
	var almacen: Node3D = await _almacen(_segunda_con(["2B"]))
	var pantalla := await _hasta_la_reflexion(almacen)
	_recuadro(almacen).botones().back().pressed.emit()
	almacen.call("_process", ReflexionDeCierre.ESPERA_ANTES_DE_LA_NOCHE)
	AvanceDeDevolucion.terminar_movimiento(pantalla)
	almacen.get_node("Interfaz/PersianaDeLaNoche").terminar()
	var bandeja := _celular(almacen).bandeja()
	assert_bool(bandeja.conversaciones().has(bandeja.conversacion_de(NOTAS))).is_true()
	var notas := bandeja.mensajes_de(NOTAS)
	var esperadas := (almacen.get("_partida") as Partida).expediente.mensajes_de_notas()
	assert_int(notas.size()).is_equal(3)
	for indice: int in esperadas.size():
		assert_str(notas[indice].identidad).is_equal(esperadas[indice].identidad)
	assert_object(notas[0].foto).is_not_null()
	assert_str(notas[2].identidad).is_equal("NOTA_2B_HIPOTESIS")


func test_la_pausa_congela_la_eleccion_y_la_espera() -> void:  # AC-INV-063
	var almacen: Node3D = await _almacen(_segunda_con(["2A", "2B"]))
	await _hasta_la_reflexion(almacen)
	var recuadro := _recuadro(almacen)
	var reflexion := (almacen.get("_partida") as Partida).reflexion
	var pausa: ControlDePausa = almacen.get_node("Interfaz/ControlDePausa")
	recuadro.botones()[1].pressed.emit()
	var mostrado := recuadro.texto()
	pausa.pausar()
	assert_bool(recuadro.can_process()).is_false()
	for _cuadro: int in 10:
		await get_tree().process_frame
	pausa.reanudar()
	assert_str(recuadro.texto()).is_equal(mostrado)
	assert_str(reflexion.mostrada().identidad).is_equal("2B")
	recuadro.botones().back().pressed.emit()
	var restante := reflexion.restante()
	pausa.pausar()
	for _cuadro: int in 10:
		await get_tree().process_frame
	assert_float(reflexion.restante()).is_equal(restante)
	assert_bool(recuadro.visible).is_true()
	pausa.reanudar()
	assert_float(reflexion.restante()).is_equal(restante)
