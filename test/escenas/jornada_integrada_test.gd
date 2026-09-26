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
) -> void:
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
	await _atender(almacen)
	await _registrar(almacen)
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
	_comprobar_planilla_en_cero(almacen)


# AC-STK-026
func _comprobar_planilla_en_cero(almacen: Node3D) -> void:
	var registro: RegistroDeVentas = almacen.get("_computadora").registro()
	for producto in Catalogo.todos():
		assert_int(registro.unidades_de(producto)).is_zero()


func test_abrir_la_jornada_termina_el_examen_en_curso() -> void:  # AC-INV-025
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().process_frame
	var jugador: Node3D = almacen.get("_jugador")
	var control: ControlDelJugador = jugador.get("_control")
	var examen: Examen = jugador.get("examen")
	var agarre: Agarre = almacen.get("_agarre")
	var bolsa: RigidBody3D = almacen.get_node("Objetos/BolsaDeBasura1")
	var trapeador: RigidBody3D = almacen.get_node("Objetos/Trapeador")
	var terminados := [0]
	examen.examen_terminado.connect(func() -> void: terminados[0] += 1)
	almacen.call("_al_abrir_la_jornada", 2)
	assert_int(terminados[0]).is_zero()
	# Lo examinado del mundo vuelve a su lugar.
	var padre := bolsa.get_parent()
	assert_bool(examen.iniciar(bolsa.get("datos"), bolsa)).is_true()
	assert_bool(control.esta_suspendido()).is_true()
	almacen.call("_al_abrir_la_jornada", 2)
	assert_bool(examen.esta_examinando()).is_false()
	assert_bool(control.esta_suspendido()).is_false()
	assert_object(bolsa.get_parent()).is_same(padre)
	# Lo que se llevaba queda a los pies, y no en la cara.
	assert_bool(agarre.pedir_agarrar(trapeador.get("datos"), trapeador)).is_true()
	assert_bool(examen.iniciar()).is_true()
	almacen.call("_al_abrir_la_jornada", 2)
	assert_bool(examen.esta_examinando()).is_false()
	assert_bool(control.esta_suspendido()).is_false()
	assert_object(agarre.manos().sostenido()).is_null()
	assert_int(examen.punto_de_examen.get_child_count()).is_zero()
	# La E siguiente examina lo que la mira tiene adelante.
	assert_bool(examen.iniciar(bolsa.get("datos"), bolsa)).is_true()
	assert_object(bolsa.get_parent()).is_same(examen.punto_de_examen)
	examen.terminar()
	assert_int(terminados[0]).is_equal(3)


func _reponer(almacen: Node3D) -> void:
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	for caja: Node3D in almacen.get("_cajas_de_productos"):
		var producto := Catalogo.de(caja.get("producto"))
		var zona: AABB = almacen.get("_reposicion_manual").zona(producto.id)
		var direccion := Vector3(0, 0, 1.5)
		if producto.id == Producto.Id.BURBALOO:
			direccion = Vector3(1.5, 0, 0)
		elif producto.id == Producto.Id.ZUCARACHAS:
			direccion = Vector3(-1.5, 0, 0)
		elif producto.id == Producto.Id.LAYSNTT:
			direccion = Vector3(0, 0, -1.5)
		camara.global_position = zona.get_center() + direccion
		camara.look_at(zona.get_center())
		for unidad in producto.umbral:
			almacen.get("_reposicion_manual").call("retirar_de_la_caja", caja)
			almacen.get("_reposicion_manual").get_node("ZonaDe" + producto.nombre).call(
				"interactuar"
			)
	await get_tree().process_frame
	var reloj: RelojDelTurno = almacen.get("_reloj")
	assert_bool(reloj.obligatoria(Tarea.Tipo.REPONER).completada()).is_true()


func _registrar(almacen: Node3D) -> void:
	var escritorio: Node3D = almacen.get_node("Estructura/base compu/StaticBody3D")
	escritorio.call("interactuar")
	var pantalla: PantallaDeComputadora = escritorio.get("pantalla")
	assert_bool(pantalla.visible).is_true()
	await _comprobar_reloj(almacen)
	var computadora: ComputadoraDeEscritorio = almacen.get("_computadora")
	var atender: TareaDeAtender = almacen.get("_atenciones").tarea()
	var filas: Node = pantalla.caja().get_node("Desplazamiento/Filas")
	var productos := computadora.registro().productos()
	var reloj: RelojDelTurno = almacen.get("_reloj")
	var tarea := reloj.obligatoria(Tarea.Tipo.REGISTRAR)
	assert_int(filas.get_child_count()).is_equal(Catalogo.todos().size())
	for indice in productos.size():
		for unidad in atender.vendidas_de(productos[indice]):
			_boton_de_la_fila(filas, indice, 5).pressed.emit()
	assert_bool(tarea.completada()).is_true()
	# Una unidad de más la descumple, y sacarla la vuelve a cumplir.
	_boton_de_la_fila(filas, 0, 5).pressed.emit()
	assert_bool(tarea.completada()).is_false()
	_boton_de_la_fila(filas, 0, 3).pressed.emit()
	await get_tree().process_frame
	assert_bool(reloj.corriendo()).is_true()
	assert_bool(tarea.completada()).is_true()
	escritorio.call("cerrar")


## Los botones de una fila de la planilla: «−» en la columna 3 y «+» en la 5.
func _boton_de_la_fila(filas: Node, indice: int, columna: int) -> Button:
	return filas.get_child(indice).get_child(columna)


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
		await _enfocar_mancha(jugador, mancha)
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
	var jugador: Node3D = almacen.get("_jugador")
	jugador.global_position = zona.global_position + Vector3.BACK
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
	var presentacion: Node3D = almacen.get("_reposicion_manual")
	var repositor: Repositor = almacen.get("_repositor")
	for producto in Catalogo.todos():
		var grupo: MultiMeshInstance3D = presentacion.get_node("ProductosDe" + producto.nombre)
		# Las copias visibles son la guía entera más lo repuesto: la guía no cambia nunca y
		# arranca a la vista, así que el cero del inventario no es un cero de copias.
		var guia := grupo.multimesh.instance_count - producto.umbral
		assert_int(grupo.multimesh.visible_instance_count).is_equal(
			guia + repositor.estante().unidades_en_gondola(producto)
		)
	assert_int(repositor.estante().productos_completos()).is_equal(esperados)


func _enfocar_mancha(jugador: Node3D, mancha: Node3D) -> void:
	jugador.set_physics_process(false)
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	camara.position = Vector3.UP * ReglasDelJugador.ALTURA_DE_LA_CAMARA
	for direccion in [Vector3.BACK, Vector3.FORWARD, Vector3.LEFT, Vector3.RIGHT]:
		jugador.global_position = mancha.global_position + direccion
		camara.look_at(mancha.global_position + Vector3.UP * 0.03)
		for cuadro in 4:
			await get_tree().physics_frame
		jugador.call("_leer_la_mira")
		if jugador.get("_enfocado") == mancha:
			break
	assert_object(jugador.get("_enfocado")).is_same(mancha)


## Deja las dos puertas giradas `cuadros` pasos de física y abre la jornada siguiente. Afirma
## que, en el mismo paso, las dos quedaron cerradas y con la hoja en su lugar.
func _abrir_con_las_puertas_giradas(cuadros: int) -> Array:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	var puertas: Array = almacen.get("_puertas")
	assert_int(puertas.size()).is_equal(2)
	var cerradas: Array[Transform3D] = []
	for puerta: Node3D in puertas:
		cerradas.append(puerta.get_parent().transform)
		puerta.call("interactuar")
	for cuadro in cuadros:
		await get_tree().physics_frame
	almacen.call("_al_abrir_la_jornada", ReglasDeLaPartida.PRIMERA_JORNADA + 1)
	for indice in puertas.size():
		var puerta: Node3D = puertas[indice]
		var estado: Puerta = puerta.call("puerta")
		assert_bool(estado.abierta()).is_false()
		assert_float(estado.angulo()).is_equal(0.0)
		assert_bool(puerta.get_parent().transform.is_equal_approx(cerradas[indice])).is_true()
	return puertas


func test_la_puerta_abierta_anoche_arranca_cerrada() -> void:  # AC-PLY-036
	var puertas: Array = await _abrir_con_las_puertas_giradas(120)
	assert_array(puertas).has_size(2)


func test_la_puerta_a_medio_giro_arranca_cerrada() -> void:  # AC-PLY-037
	var puertas: Array = await _abrir_con_las_puertas_giradas(5)
	assert_array(puertas).has_size(2)
