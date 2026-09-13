extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")

var _escala_anterior: float


func before_test() -> void:
	_escala_anterior = Engine.time_scale


func after_test() -> void:
	Engine.time_scale = _escala_anterior


# El límite usa tiempo del motor, que este caso acelera hasta el cierre.
@warning_ignore("unused_parameter")
func test_los_puestos_completan_la_jornada_y_permiten_abrir_la_siguiente(
	timeout: int = 6000000  # gdlint:ignore=unused-argument
) -> void:  # 041-AC9, 041-AC10
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	var reloj: RelojDelTurno = almacen.get("_reloj")
	var tiempos: Array[float] = []
	reloj.tiempo_consumido.connect(func(restante: float) -> void: tiempos.append(restante))
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(reloj.corriendo()).is_true()
	_comprobar_huecos(almacen, 0)
	await _reponer(almacen)
	_comprobar_huecos(almacen, Catalogo.todos().size())
	await _registrar(almacen)
	await _atender(almacen)
	await _limpiar(almacen)
	await _sacar_la_basura(almacen)
	for tipo: Tarea.Tipo in Tarea.Tipo.values():
		assert_bool(reloj.obligatoria(tipo).completada()).is_true()
	assert_bool(reloj.corriendo()).is_true()
	assert_float(tiempos.back()).is_less(tiempos.front())
	var pantalla: PantallaDeCierre = almacen.get("_pantalla")
	# Acelera el motor para ejercer el cierre sin llamar al reloj por dentro.
	Engine.time_scale = 2000.0
	for cuadro in 120:
		await get_tree().process_frame
		if pantalla.visible:
			break
	Engine.time_scale = _escala_anterior
	assert_bool(pantalla.visible).is_true()
	var continuar: Button = pantalla.get_node("Fondo/Panel/Continuar")
	continuar.pressed.emit()
	var ciclo: CicloDeJornadas = almacen.get("_ciclo")
	assert_int(ciclo.partida().jornada()).is_equal(ReglasDeLaPartida.PRIMERA_JORNADA + 1)
	assert_bool(pantalla.visible).is_false()
	assert_bool(reloj.corriendo()).is_true()
	for tipo: Tarea.Tipo in Tarea.Tipo.values():
		assert_bool(reloj.obligatoria(tipo).completada()).is_false()
	var recolector: RecolectorDeBasura = almacen.get("_recolector")
	assert_int(recolector.tarea().depositadas()).is_zero()
	_comprobar_huecos(almacen, 0)


func _reponer(almacen: Node3D) -> void:
	var estante: Node3D = almacen.get("_estante")
	for caja: Node3D in almacen.get("_cajas_de_productos"):
		var producto := Catalogo.de(caja.get("producto"))
		for unidad in producto.umbral:
			caja.call("interactuar")
			estante.call("interactuar")
	await get_tree().process_frame
	var reloj: RelojDelTurno = almacen.get("_reloj")
	assert_bool(reloj.obligatoria(Tarea.Tipo.REPONER).completada()).is_true()


func _registrar(almacen: Node3D) -> void:
	var escritorio: Node3D = almacen.get_node("Estructura/compu/StaticBody3D")
	escritorio.call("interactuar")
	var pantalla: PantallaDeComputadora = escritorio.get("pantalla")
	assert_bool(pantalla.visible).is_true()
	await _comprobar_reloj(almacen)
	var computadora: ComputadoraDeEscritorio = almacen.get("_computadora")
	var botones: Node = pantalla.caja().get_node("Botones")
	for indice in computadora.caja().del_dia().size():
		var boton: Button = botones.get_child(indice)
		boton.pressed.emit()
	await get_tree().process_frame
	var reloj: RelojDelTurno = almacen.get("_reloj")
	assert_bool(reloj.corriendo()).is_true()
	assert_bool(reloj.obligatoria(Tarea.Tipo.REGISTRAR).completada()).is_true()
	escritorio.call("cerrar")


func _atender(almacen: Node3D) -> void:
	var ventanilla: Node3D = almacen.get_node("Estructura/Ventanilla")
	var panel: PanelDeLaVentanilla = ventanilla.get("panel")
	var cobrar: Button = panel.get_node("Fondo/Panel/Cobrar")
	for comprador in Compradores.de_la_jornada():
		ventanilla.call("interactuar")
		assert_bool(panel.visible).is_true()
		await _comprobar_reloj(almacen)
		cobrar.pressed.emit()
	await get_tree().process_frame
	var reloj: RelojDelTurno = almacen.get("_reloj")
	assert_bool(reloj.corriendo()).is_true()
	assert_bool(reloj.obligatoria(Tarea.Tipo.CAJA).completada()).is_true()
	ventanilla.call("cerrar")


func _limpiar(almacen: Node3D) -> void:
	var jugador: Node3D = almacen.get("_jugador")
	var agarre: Agarre = almacen.get("_agarre")
	var trapeador: Node3D = almacen.get_node("Objetos/Trapeador")
	assert_bool(agarre.pedir_agarrar(trapeador.call("interactuar"), trapeador)).is_true()
	var limpieza: Node3D = almacen.get("_limpieza")
	for mancha: Node3D in limpieza.call("manchas"):
		jugador.emit_signal("objetivo_enfocado", mancha, 1.0)
		for pasada in ReglasDeLaLimpieza.PASADAS_POR_MANCHA:
			var clic := InputEventMouseButton.new()
			clic.button_index = MOUSE_BUTTON_RIGHT
			clic.pressed = true
			get_viewport().push_input(clic)
		assert_bool(mancha.visible).is_false()
	agarre.soltar(true)
	await get_tree().process_frame
	var reloj: RelojDelTurno = almacen.get("_reloj")
	assert_bool(reloj.obligatoria(Tarea.Tipo.LIMPIAR).completada()).is_true()


func _sacar_la_basura(almacen: Node3D) -> void:
	var agarre: Agarre = almacen.get("_agarre")
	var zona: Area3D = almacen.get_node("Objetos/ZonaDeDescarte")
	var recolector: RecolectorDeBasura = almacen.get("_recolector")
	for bolsa: Node3D in almacen.get("_bolsas"):
		var datos: ObjetoDelAlmacen = bolsa.call("interactuar")
		assert_bool(agarre.pedir_agarrar(datos, bolsa)).is_true()
		agarre.punto_de_soltado.global_position = zona.global_position + Vector3.UP * 0.3
		assert_object(agarre.soltar(true)).is_same(bolsa)
		for cuadro in 5:
			await get_tree().physics_frame
		assert_bool(recolector.tarea().esta_depositada(datos.id)).is_true()
	var reloj: RelojDelTurno = almacen.get("_reloj")
	assert_bool(reloj.obligatoria(Tarea.Tipo.SACAR_LA_BASURA).completada()).is_true()


func _comprobar_reloj(almacen: Node3D) -> void:
	var reloj: RelojDelTurno = almacen.get("_reloj")
	var tiempos: Array[float] = []
	var registrar := func(restante: float) -> void: tiempos.append(restante)
	reloj.tiempo_consumido.connect(registrar)
	for cuadro in 3:
		await get_tree().process_frame
	reloj.tiempo_consumido.disconnect(registrar)
	assert_int(tiempos.size()).is_greater_equal(2)
	if tiempos.size() >= 2:
		assert_float(tiempos.back()).is_less(tiempos.front())


func _comprobar_huecos(almacen: Node3D, esperados: int) -> void:
	var estante: Node3D = almacen.get("_estante")
	var huecos: Node3D = estante.get("_huecos")
	assert_int(huecos.get_child_count()).is_equal(Catalogo.todos().size())
	var visibles := 0
	for hueco: Node3D in huecos.get_children():
		if hueco.visible:
			visibles += 1
	var repositor: Repositor = almacen.get("_repositor")
	assert_int(visibles).is_equal(esperados)
	assert_int(visibles).is_equal(repositor.estante().productos_completos())
