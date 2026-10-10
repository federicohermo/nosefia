extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const AperturaConLugar := preload("res://test/escenas/apertura_con_lugar.gd")
const OBJETO_SUELTO := preload("res://src/escenas/objetos/objeto_agarrable.tscn")

## Dónde nace el objeto suelto que crea un caso: un punto libre del piso del local. Es su lugar de
## origen, adonde la red de seguridad lo puede devolver.
const LIBRE_EN_EL_LOCAL := Vector3(2.7, 0.2, 2.7)


func test_los_puestos_completan_la_jornada_y_permiten_abrir_la_siguiente() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	var reloj: RelojDelTurno = almacen.get("_reloj")
	var tiempos: Array[float] = []
	reloj.tiempo_consumido.connect(func(restante: float) -> void: tiempos.append(restante))
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(reloj.corriendo()).is_true()
	_comprobar_ninguna_cumplida_al_abrir(almacen)
	_comprobar_huecos(almacen, _completos_al_abrir(ReglasDeLaPartida.PRIMERA_JORNADA))
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
	reloj.avanzar(Reglas.DURACION_DEL_TURNO / Ritmo.SEGUNDOS_DE_TURNO_POR_SEGUNDO_REAL)
	await get_tree().process_frame
	assert_bool(pantalla.visible).is_true()
	var continuar: Button = pantalla.get_node("Fondo/Panel/Continuar")
	continuar.pressed.emit()
	var ciclo: CicloDeJornadas = almacen.get("_ciclo")
	assert_int(ciclo.partida().jornada()).is_equal(ReglasDeLaPartida.PRIMERA_JORNADA + 1)
	assert_bool(pantalla.visible).is_false()
	assert_bool(reloj.corriendo()).is_true()
	_comprobar_ninguna_cumplida_al_abrir(almacen)
	var recolector: RecolectorDeBasura = almacen.get("_recolector")
	assert_int(recolector.tarea().depositadas()).is_zero()
	_comprobar_huecos(almacen, _completos_al_abrir(ReglasDeLaPartida.PRIMERA_JORNADA + 1))
	_comprobar_planilla_en_cero(almacen)


## Cuántos productos abren esa jornada con la fila de adelante completa: todos menos los que
## ella hace faltar. La noche no abre vacía, y la siguiente tampoco hereda lo repuesto.
func _completos_al_abrir(jornada: int) -> int:
	return Catalogo.todos().size() - Apertura.faltantes_de_la_jornada(jornada).size()


# AC-STK-026
func _comprobar_planilla_en_cero(almacen: Node3D) -> void:
	var registro: RegistroDeVentas = almacen.get("_computadora").registro()
	for producto in Catalogo.todos():
		assert_int(registro.unidades_de(producto)).is_zero()
	var reloj: RelojDelTurno = almacen.get("_reloj")
	assert_bool(reloj.obligatoria(Tarea.Tipo.REGISTRAR).completada()).is_false()


# AC-STK-024
func _comprobar_ninguna_cumplida_al_abrir(almacen: Node3D) -> void:
	var reloj: RelojDelTurno = almacen.get("_reloj")
	for tipo: Tarea.Tipo in Tarea.Tipo.values():
		assert_bool(reloj.obligatoria(tipo).completada()).is_false()
	var contador: Label = almacen.get("_hud").get("_tareas")
	assert_str(contador.text).is_equal(
		Hud.TEXTO_DE_LAS_TAREAS % Marcador.tareas(0, Apertura.cantidad_de_obligatorias())
	)


func test_abrir_la_jornada_termina_el_examen_en_curso() -> void:  # AC-INV-025
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().process_frame
	var jugador: Node3D = almacen.get("_jugador")
	var control: ControlDelJugador = jugador.get("_control")
	var examen: Examen = jugador.get("examen")
	var agarre: Agarre = almacen.get("_agarre")
	# Un objeto suelto propio del caso: los útiles y las bolsas vuelven a su lugar al abrir la
	# jornada, y ahí no se vería dónde quedó lo que se llevaba.
	var llevado: RigidBody3D = OBJETO_SUELTO.instantiate()
	llevado.position = LIBRE_EN_EL_LOCAL
	almacen.add_child(llevado)
	(
		assert_bool(_libre_en_el_local(llevado))
		. override_failure_message("%v ya no está libre en el local" % LIBRE_EN_EL_LOCAL)
		. is_true()
	)
	var terminados := [0]
	examen.examen_terminado.connect(func() -> void: terminados[0] += 1)
	almacen.call("_al_abrir_la_jornada", 2)
	assert_int(terminados[0]).is_zero()
	# Lo que se llevaba queda a los pies, y no en la cara ni donde se mira.
	assert_bool(agarre.pedir_agarrar(llevado.get("datos"), llevado)).is_true()
	assert_bool(examen.iniciar()).is_true()
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	camara.look_at(jugador.global_position + jugador.frente() * 1.2)
	var pies := agarre.punto_de_respaldo.global_position
	almacen.call("_al_abrir_la_jornada", 2)
	assert_bool(examen.esta_examinando()).is_false()
	assert_bool(control.esta_suspendido()).is_false()
	assert_object(agarre.manos().sostenido()).is_null()
	assert_int(examen.punto_de_examen.get_child_count()).is_zero()
	assert_vector(llevado.global_position).is_equal_approx(pies, Vector3.ONE * 0.01)
	assert_int(terminados[0]).is_equal(1)


func test_con_otra_pantalla_encima_la_e_no_abre_un_examen() -> void:
	# Así suspenden la placa del cierre y la computadora. La E abría un examen de lo enfocado o
	# de lo que se lleva, y la segunda reanudaba al jugador con la pantalla abierta.
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().process_frame
	var jugador: Node3D = almacen.get("_jugador")
	var control: ControlDelJugador = jugador.get("_control")
	var examen: Examen = jugador.get("examen")
	var agarre: Agarre = almacen.get("_agarre")
	var balde: RigidBody3D = almacen.get_node("Objetos/Balde")
	jugador.suspender()
	jugador.set("_enfocado", almacen.get_node("Objetos/BolsaDeBasura1"))
	var evento := InputEventAction.new()
	evento.action = ReglasDeLosObjetos.ACCION_EXAMINAR
	evento.pressed = true
	for llevado: RigidBody3D in [null, balde]:
		if llevado != null:
			assert_bool(agarre.pedir_agarrar(llevado.get("datos"), llevado)).is_true()
		for vez in 2:
			jugador.call("_unhandled_input", evento)
			assert_bool(examen.esta_examinando()).is_false()
		assert_bool(control.esta_suspendido()).is_true()


func _reponer(almacen: Node3D) -> void:
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	var estante: Estante = almacen.get("_repositor").estante()
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
		for unidad in estante.cupo(producto) - estante.unidades_en_gondola(producto):
			almacen.get("_reposicion_manual").call("usar_la_caja", caja)
			almacen.get("_reposicion_manual").casillero(producto.id).call("interactuar")
	await get_tree().process_frame
	var reloj: RelojDelTurno = almacen.get("_reloj")
	assert_bool(reloj.obligatoria(Tarea.Tipo.REPONER).completada()).is_true()


func _registrar(almacen: Node3D) -> void:
	var escritorio: Node3D = almacen.get_node("Estructura/base compu/StaticBody3D")
	escritorio.call(ReglasDeLosObjetos.METODO_ACCIONAR)
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
	var contador: Label = almacen.get("_hud").get("_tareas")
	var con_registrar := contador.text
	# Una unidad de más la descumple, y sacarla la vuelve a cumplir.
	_boton_de_la_fila(filas, 0, 5).pressed.emit()
	assert_bool(tarea.completada()).is_false()
	assert_str(contador.text).is_not_equal(con_registrar)
	_boton_de_la_fila(filas, 0, 3).pressed.emit()
	await get_tree().process_frame
	assert_bool(reloj.corriendo()).is_true()
	assert_bool(tarea.completada()).is_true()
	assert_str(contador.text).is_equal(con_registrar)
	escritorio.call("cerrar")


## Los botones de una fila de la planilla: «−» en la columna 3 y «+» en la 5.
func _boton_de_la_fila(filas: Node, indice: int, columna: int) -> Button:
	return filas.get_child(indice).get_child(columna)


func _atender(almacen: Node3D) -> void:
	var ventanilla: Node3D = almacen.get_node("Estructura/Ventanilla")
	var panel: PanelDeLaVentanilla = ventanilla.get("panel")
	var reloj: RelojDelTurno = almacen.get("_reloj")
	var atenciones: Ventanilla = almacen.get("_atenciones")
	var agarre: Agarre = almacen.get("_agarre")
	var caja: CajaRegistradora = almacen.get("_caja")
	var destino: Node3D = almacen.get("_puesto_de_la_caja").get("destino_de_los_tickets")
	for intervalo: float in [120.0, 360.0]:
		reloj.avanzar(intervalo)
		ventanilla.call(ReglasDeLosObjetos.METODO_ACCIONAR)
		assert_bool(panel.visible).is_true()
		await _comprobar_reloj(almacen)
		var atendida := atenciones.atencion()
		assert_object(atendida).is_not_null()
		for _entrada in 4:
			panel.comprador_pulsado.emit()
			if atenciones.puede_abandonar():
				break
		caja.pedir_borrar()
		for producto in atendida.comprador().pedido().productos():
			for _unidad in atendida.comprador().pedido().unidades_de(producto):
				almacen.get("_reposicion_manual").retirar(producto.id)
				caja.pedir_anotar(agarre.manos().sostenido())
				panel.comprador_pulsado.emit()
		caja.pedir_imprimir()
		for nodo in destino.get_children():
			var papel := nodo as ObjetoAgarrable
			if papel != null and papel.datos is Ticket and papel.visible:
				agarre.pedir_agarrar(papel.datos, papel)
				panel.comprador_pulsado.emit()
		assert_bool(atendida.vendida()).is_true()
		for _entrada in 4:
			panel.comprador_pulsado.emit()
			if atenciones.puede_abandonar():
				break
		ventanilla.call("cerrar")
	await get_tree().process_frame
	assert_bool(reloj.corriendo()).is_true()
	assert_bool(reloj.obligatoria(Tarea.Tipo.CAJA).completada()).is_true()
	ventanilla.call("cerrar")


func _cumplidas(reloj: RelojDelTurno) -> int:
	var cumplidas := 0
	for tipo: Tarea.Tipo in Tarea.Tipo.values():
		cumplidas += int(reloj.obligatoria(tipo).completada())
	return cumplidas


## Borra las cuatro manchas como en el juego: por cada jabón, el balde se vacía en el inodoro, se
## llena en el lavatorio y se tiñe; la mopa se moja en él y pasa por las manchas que ese jabón
## borra.
func _limpiar(almacen: Node3D) -> void:
	# Se accede al inodoro y a su mancha abriendo la cabina, como en la partida.
	for numero: int in [1, 2]:
		almacen.get_node("Estructura/bano_puerta_%d/CuerpoDeLaHoja" % numero).call("usar")
	for cuadro in 60:
		await get_tree().physics_frame
	var jugador: Node3D = almacen.get("_jugador")
	var agarre: Agarre = almacen.get("_agarre")
	var lavatorio: Node3D = almacen.get_node("Estructura/vanitory/StaticBody3D")
	var inodoro: Node3D = almacen.get_node("Estructura/inodoro/StaticBody3D")
	var balde: Node3D = almacen.get_node("Objetos/Balde")
	var mopa: Node3D = almacen.get_node("Objetos/Mopa")
	var limpieza: Node3D = almacen.get("_limpieza")
	# Se buscan antes de soltar nada: lo soltado cuelga del almacén, y ya no de `Objetos`.
	var jabones: Array[Node3D] = []
	for nombre: String in ["JabonAmarillo", "JabonAzul", "JabonRosa"]:
		jabones.append(almacen.get_node("Objetos/" + nombre))
	for jabon in jabones:
		var pedida := ReglasDeLaLimpieza.agua_del_jabon(jabon.get("datos").id)
		_agarrar(agarre, balde)
		_usar_sobre(jugador, inodoro)
		_usar_sobre(jugador, lavatorio)
		_soltar_lejos(agarre)
		_agarrar(agarre, jabon)
		_usar_sobre(jugador, balde)
		_soltar_lejos(agarre)
		_agarrar(agarre, mopa)
		_usar_sobre(jugador, balde)
		for mancha: Node3D in limpieza.call("manchas"):
			var tipo := _piso(almacen).mancha_de(mancha.call("lugar_de_la_mancha")).tipo()
			if ReglasDeLaLimpieza.AGUA_QUE_BORRA[tipo] != pedida:
				continue
			await _enfocar_mancha(jugador, mancha)
			# La mopa requiere recarga junto a cada mancha: se transporta el balde antes.
			_soltar_lejos(agarre)
			_agarrar(agarre, balde)
			agarre.soltar(true)
			balde.global_position = jugador.global_position + Vector3.RIGHT * 0.8
			_agarrar(agarre, mopa)
			_usar_sobre(jugador, balde)
			await _enfocar_mancha(jugador, mancha)
			var clic := InputEventMouseButton.new()
			clic.button_index = MOUSE_BUTTON_RIGHT
			clic.pressed = true
			get_viewport().push_input(clic)
			(
				assert_bool(
					_piso(almacen).mancha_de(mancha.call("lugar_de_la_mancha")).esta_limpia()
				)
				. is_true()
			)
			await get_tree().create_timer(0.5).timeout
			assert_bool(mancha.visible).override_failure_message(mancha.name).is_false()
		_soltar_lejos(agarre)
	await get_tree().process_frame
	var reloj: RelojDelTurno = almacen.get("_reloj")
	assert_bool(reloj.obligatoria(Tarea.Tipo.LIMPIAR).completada()).is_true()


func _piso(almacen: Node3D) -> PisoDelLocal:
	return (almacen.get("_limpiador") as Limpiador).piso()


func _agarrar(agarre: Agarre, util: Node3D) -> void:
	assert_bool(agarre.pedir_agarrar(util.call("interactuar"), util)).is_true()


## El clic derecho sobre el objetivo, con la mira apagada: lo que se tiene adelante lo pone el caso.
func _usar_sobre(jugador: Node3D, objetivo: Node3D) -> void:
	jugador.set_physics_process(false)
	jugador.set("_enfocado", objetivo)
	var evento := InputEventAction.new()
	evento.action = ReglasDelJugador.ACCION_USAR
	evento.pressed = true
	jugador.call("_unhandled_input", evento)


## Suelta lo que se lleva y lo devuelve a su lugar del baño: tirado adelante, taparía la mancha
## que se enfoca después.
func _soltar_lejos(agarre: Agarre) -> void:
	var soltado := agarre.soltar(true)
	soltado.global_transform = soltado.call(ReglasDeLosObjetos.METODO_LUGAR_DE_ORIGEN)


func _sacar_la_basura(almacen: Node3D) -> void:
	var agarre: Agarre = almacen.get("_agarre")
	var contenedor: Node3D = almacen.get_node(
		"Estructura/deposito_contenedor_soporte/deposito_contenedor_cuerpo/StaticBody3D"
	)
	var jugador: Node3D = almacen.get("_jugador")
	var recolector: RecolectorDeBasura = almacen.get("_recolector")
	for bolsa: ObjetoAgarrable in almacen.get("_bolsas"):
		assert_bool(agarre.pedir_agarrar(bolsa.datos, bolsa)).is_true()
		jugador.set("_enfocado", contenedor)
		var clic := InputEventMouseButton.new()
		clic.button_index = MOUSE_BUTTON_LEFT
		clic.pressed = true
		jugador.call("_unhandled_input", clic)
		assert_bool(recolector.tarea().esta_depositada(bolsa.datos.id)).is_true()
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
		# Las copias visibles son la guía entera más lo que la góndola tiene puesto: la guía no
		# cambia nunca y arranca a la vista, y los casilleros son las últimas copias, tantos
		# como el cupo del producto.
		var guia := grupo.multimesh.instance_count - repositor.estante().cupo(producto)
		assert_int(grupo.multimesh.visible_instance_count).is_equal(
			guia + repositor.estante().unidades_en_gondola(producto)
		)
	assert_int(repositor.estante().productos_completos()).is_equal(esperados)


func _enfocar_mancha(jugador: Node3D, mancha: Node3D) -> void:
	jugador.set_physics_process(false)
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	camara.position = Vector3.UP * ReglasDelJugador.ALTURA_DE_LA_CAMARA
	for direccion: Vector3 in [Vector3.BACK, Vector3.FORWARD, Vector3.LEFT, Vector3.RIGHT]:
		jugador.global_position = mancha.global_position + direccion
		camara.look_at(mancha.global_position + Vector3.UP * 0.03)
		for cuadro in 4:
			await get_tree().physics_frame
		jugador.call("_leer_la_mira")
		if jugador.get("_enfocado") == mancha:
			break
	assert_object(jugador.get("_enfocado")).is_same(mancha)


func _abrir_con_las_puertas_giradas(cuadros: int) -> Array[float]:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	var puertas: Array = almacen.get("_puertas")
	assert_array(puertas).is_not_empty()
	var cerradas: Array[Transform3D] = []
	for puerta: Node3D in puertas:
		cerradas.append(puerta.get_parent().transform)
		puerta.call("usar" if puerta.has_method("usar") else "interactuar")
	for cuadro in cuadros:
		await get_tree().physics_frame
	var antes: Array[float] = []
	for puerta: Node3D in puertas:
		if puerta.get("traba") == 0:
			antes.append(puerta.call("puerta").angulo())
		else:
			assert_float(puerta.call("puerta").angulo()).is_equal(0.0)
	almacen.call("_al_abrir_la_jornada", ReglasDeLaPartida.PRIMERA_JORNADA + 1)
	for indice in puertas.size():
		var puerta: Node3D = puertas[indice]
		var estado: Puerta = puerta.call("puerta")
		assert_bool(estado.abierta()).is_false()
		assert_float(estado.angulo()).is_equal(0.0)
		assert_bool(puerta.get_parent().transform.is_equal_approx(cerradas[indice])).is_true()
	return antes


func test_la_puerta_abierta_anoche_arranca_cerrada() -> void:  # AC-PLY-036
	var antes: Array[float] = await _abrir_con_las_puertas_giradas(120)
	for angulo in antes:
		assert_float(angulo).is_equal(Puerta.ANGULO_ABIERTA)


func test_la_puerta_a_medio_giro_arranca_cerrada() -> void:  # AC-PLY-037
	var antes: Array[float] = await _abrir_con_las_puertas_giradas(5)
	for angulo in antes:
		assert_float(angulo).is_greater(0.0)
		assert_float(angulo).is_less(Puerta.ANGULO_ABIERTA)


func test_la_noche_siguiente_abre_con_cada_caja_llena_y_nada_afuera() -> void:  # AC-STK-037
	# Tres cajas que terminan la noche distinto: una vacía, otra con una unidad suya en la mano y
	# otra con una unidad devuelta. La noche siguiente no hereda ninguna de las tres.
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().process_frame
	AperturaConLugar.abrir_con_todo_el_lugar(almacen)
	almacen.get("_jugador").set_physics_process(false)
	var puesto: Node3D = almacen.get("_reposicion_manual")
	var agarre: Agarre = almacen.get("_agarre")
	var cajas: Array = almacen.get("_cajas_de_productos")
	# Actroncito tiene lugar para una caja entera: se vacía colocando de a una.
	var vacia := Producto.Id.ACTRONCITO
	for unidad in ReglasDelEstante.UNIDADES_POR_CAJA:
		puesto.call("usar_la_caja", cajas[vacia])
		puesto.call("pedir_colocar", vacia)
	var repositor: Repositor = almacen.get("_repositor")
	assert_int(repositor.caja(vacia).unidades()).is_zero()
	puesto.call("usar_la_caja", cajas[Producto.Id.JORGILLO])
	puesto.call("usar_la_caja", cajas[Producto.Id.JORGILLO])
	assert_object(agarre.manos().sostenido()).is_null()
	puesto.call("usar_la_caja", cajas[Producto.Id.MALBARDO])
	assert_object(agarre.manos().sostenido() as UnidadDeProducto).is_not_null()
	almacen.call("_al_abrir_la_jornada", ReglasDeLaPartida.PRIMERA_JORNADA + 1)
	assert_object(agarre.manos().sostenido()).is_null()
	var estante := repositor.estante()
	for producto in Catalogo.todos():
		(
			assert_int(repositor.caja(producto.id).unidades())
			. override_failure_message("la caja de %s no abre llena" % producto.nombre)
			. is_equal(ReglasDelEstante.UNIDADES_POR_CAJA)
		)
		assert_int(estante.reservadas(producto)).is_zero()


## La premisa del objeto suelto de los casos: su lugar de origen está libre en el local, con el
## piso justo abajo. La red lo devuelve ahí, y si el local cambia ese lugar puede dejar de serlo.
static func _libre_en_el_local(cuerpo: RigidBody3D) -> bool:
	var espacio := cuerpo.get_world_3d().direct_space_state
	for forma: CollisionShape3D in cuerpo.find_children("*", "CollisionShape3D", false, false):
		var consulta := PhysicsShapeQueryParameters3D.new()
		consulta.shape = forma.shape
		consulta.transform = forma.global_transform
		consulta.collision_mask = cuerpo.collision_mask
		consulta.exclude = [cuerpo.get_rid()]
		if not espacio.intersect_shape(consulta, 1).is_empty():
			return false
	var abajo := PhysicsRayQueryParameters3D.create(
		cuerpo.global_position, cuerpo.global_position + Vector3.DOWN * 0.2, cuerpo.collision_mask
	)
	abajo.exclude = [cuerpo.get_rid()]
	return not espacio.intersect_ray(abajo).is_empty()
