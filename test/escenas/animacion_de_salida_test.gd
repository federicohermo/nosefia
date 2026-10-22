extends GdUnitTestSuite

const RUTA_DEL_ALMACEN := "res://src/escenas/almacen.tscn"
const ENTRADA := "Estructura/puertaentrada/CuerpoDeLaHoja"

var _ruta_guardado: String


class GuardadoQueCuenta:
	extends Guardado

	var escrituras := 0

	func escribir(datos: Dictionary) -> bool:
		escrituras += 1
		return super.escribir(datos)


func before_test() -> void:
	_ruta_guardado = Guardado.ruta_por_defecto
	Guardado.ruta_por_defecto = "user://animacion_de_salida.guardado"
	Guardado.new().borrar()


func after_test() -> void:
	get_tree().paused = false
	Guardado.new().borrar()
	Guardado.ruta_por_defecto = _ruta_guardado


func test_salir_toma_el_control_sin_bajar_la_persiana_ni_abrir_aun() -> void:  # AC-SHF-043
	for jornada: int in [1, 2, 3]:
		var almacen := await _abrir(jornada)
		var jugador: Node3D = almacen.get("_jugador")
		var entrada: Node3D = almacen.get_node(ENTRADA)
		var persiana: PersianaDeLaNoche = almacen.get_node("Interfaz/PersianaDeLaNoche")
		var pantalla: PantallaDeDevolucion = almacen.get("_pantalla")
		assert_bool(almacen.call("_puede_salir")).is_true()
		assert_bool(entrada.call("puerta").abierta()).is_false()
		assert_bool(persiana.visible).is_false()
		assert_bool(pantalla.visible).is_false()
		_primario_sobre_la_entrada(almacen)
		assert_bool(jugador.call("suspendido")).is_true()
		assert_bool(persiana.visible).is_false()
		assert_bool(pantalla.visible).is_false()
		assert_bool(entrada.call("puerta").abierta()).is_false()


# AC-SHF-043, AC-SHF-044, AC-SHF-046
func test_cada_noche_gira_abre_y_produce_una_devolucion_y_un_guardado() -> void:
	for jornada: int in [1, 2, 3]:
		var almacen := await _abrir(jornada)
		var jugador: Node3D = almacen.get("_jugador")
		var control: ControlDelJugador = jugador.get("_control")
		control.girar(Vector2(500.0, 100.0))
		jugador.call("_aplicar_la_rotacion")
		assert_bool(control.giro_atrasado()).is_true()
		var entrada: Node3D = almacen.get_node(ENTRADA)
		var salida: SalidaDelAlmacen = almacen.get("_salida")
		var puerta: Puerta = entrada.call("puerta")
		var reloj: RelojDelTurno = almacen.get("_reloj")
		var persiana: PersianaDeLaNoche = almacen.get_node("Interfaz/PersianaDeLaNoche")
		var pantalla: PantallaDeDevolucion = almacen.get("_pantalla")
		var ciclo: CicloDeJornadas = almacen.get("_ciclo")
		var guardado := GuardadoQueCuenta.new()
		almacen.get("_enlace_de_guardado").set("_guardado", guardado)
		var sonidos: Array[Node3D] = []
		var devoluciones: Array[int] = []
		entrada.connect("puerta_abierta", sonidos.append)
		ciclo.jornada_cerrada.connect(
			func(noche: int, _cumplidas: int) -> void: devoluciones.append(noche)
		)
		var vista: Transform3D = jugador.call("mira")
		var hoja: MeshInstance3D = entrada.get("hoja")
		var centro := hoja.global_transform * hoja.get_aabb().get_center()
		var direccion := (centro - vista.origin).normalized()
		_primario_sobre_la_entrada(almacen)
		assert_bool((jugador.call("mira") as Transform3D).is_equal_approx(vista)).is_true()
		jugador.call("_process", 1.0)
		assert_bool((jugador.call("mira") as Transform3D).is_equal_approx(vista)).is_true()
		salida._process(SalidaVoluntaria.DURACION_DEL_GIRO * 0.5)
		assert_array(sonidos).is_empty()
		assert_float(puerta.angulo()).is_zero()
		assert_bool(persiana.visible).is_false()
		reloj.terminar()
		reloj.avanzar(1000.0)
		entrada.call("accionar")
		assert_array(devoluciones).is_empty()
		assert_int(guardado.escrituras).is_zero()
		salida._process(SalidaVoluntaria.DURACION_DEL_GIRO * 0.5)
		var orientada: Transform3D = jugador.call("mira")
		assert_float((-orientada.basis.z).dot(direccion)).is_equal_approx(1.0, 0.0001)
		assert_array(sonidos).is_equal([entrada])
		assert_bool(puerta.abierta()).is_true()
		entrada.call("_physics_process", 0.1)
		assert_float(puerta.angulo()).is_between(0.0, Puerta.ANGULO_ABIERTA)
		assert_bool(persiana.visible).is_false()
		assert_bool(pantalla.visible).is_false()
		entrada.call("_physics_process", 10.0)
		entrada.call("_physics_process", 0.1)
		assert_float(puerta.angulo()).is_equal(Puerta.ANGULO_ABIERTA)
		assert_bool(persiana.visible).is_true()
		assert_bool(pantalla.visible).is_true()
		assert_array(devoluciones).is_equal([jornada])
		assert_int(guardado.escrituras).is_equal(1)
		assert_int(guardado.cargar().get("jornada", -1)).is_equal(jornada + 1)
		salida.confirmar_apertura()
		reloj.terminar()
		assert_array(sonidos).has_size(1)
		assert_array(devoluciones).has_size(1)
		assert_int(guardado.escrituras).is_equal(1)


func test_pausar_cada_etapa_conserva_la_secuencia_y_la_mano() -> void:  # AC-SHF-045, AC-PLY-104
	for abriendo: bool in [false, true]:
		var almacen := await _abrir(1)
		var jugador: CharacterBody3D = almacen.get("_jugador")
		var agarre: Agarre = almacen.get("_agarre")
		var caja: Node3D = almacen.get("_cajas_de_productos")[0]
		assert_bool(agarre.pedir_agarrar(caja.get("datos"), caja)).is_true()
		var sostenido := agarre.manos().sostenido()
		var padre := caja.get_parent()
		var entrada: Node3D = almacen.get_node(ENTRADA)
		var salida: SalidaDelAlmacen = almacen.get("_salida")
		var pausa: ControlDePausa = almacen.get_node("Interfaz/ControlDePausa")
		var pantalla: PantallaDeDevolucion = almacen.get("_pantalla")
		jugador.velocity = Vector3(3.0, -1.0, 2.0)
		_primario_sobre_la_entrada(almacen)
		assert_vector(jugador.velocity).is_equal(Vector3.ZERO)
		salida._process(SalidaVoluntaria.DURACION_DEL_GIRO * (1.0 if abriendo else 0.5))
		if abriendo:
			entrada.call("_physics_process", 0.1)
		var vista: Transform3D = jugador.call("mira")
		var lugar := jugador.global_position
		var angulo: float = entrada.call("puerta").angulo()
		pausa.pausar()
		salida.set_process(true)
		entrada.set_physics_process(true)
		for _cuadro in 3:
			await get_tree().process_frame
		assert_bool((jugador.call("mira") as Transform3D).is_equal_approx(vista)).is_true()
		assert_float(entrada.call("puerta").angulo()).is_equal(angulo)
		assert_bool(pantalla.visible).is_false()
		pausa.reanudar()
		salida.set_process(false)
		entrada.set_physics_process(false)
		jugador.call("reanudar")
		jugador.set_physics_process(true)
		for accion: StringName in [
			ReglasDeLosObjetos.ACCION_AGARRAR,
			ReglasDelJugador.ACCION_USAR,
			ReglasDeLosObjetos.ACCION_EXAMINAR,
		]:
			var evento := InputEventAction.new()
			evento.action = accion
			evento.pressed = true
			jugador.call("_unhandled_input", evento)
		almacen.call("_alternar_el_celular")
		var mouse := InputEventMouseMotion.new()
		mouse.relative = Vector2(600.0, 300.0)
		jugador.call("_unhandled_input", mouse)
		Input.action_press(ReglasDelJugador.ACCION_ADELANTE)
		jugador.call("_physics_process", 0.1)
		Input.action_release(ReglasDelJugador.ACCION_ADELANTE)
		assert_bool(jugador.call("suspendido")).is_true()
		assert_vector(jugador.global_position).is_equal(lugar)
		assert_object(agarre.manos().sostenido()).is_same(sostenido)
		assert_object(caja.get_parent()).is_same(padre)
		assert_bool(jugador.get("examen").esta_examinando()).is_false()
		assert_bool((almacen.get("_celular") as CelularDelEmpleado).celular().abierto()).is_false()
		assert_str((almacen.get("_hud").get_node("Controles") as Label).text).is_empty()
		assert_bool((jugador.call("mira") as Transform3D).is_equal_approx(vista)).is_true()
		if not abriendo:
			salida._process(SalidaVoluntaria.DURACION_DEL_GIRO * 0.5)
		entrada.call("_physics_process", 10.0)
		entrada.call("_physics_process", 0.1)
		assert_bool(pantalla.visible).is_true()


func test_el_tiempo_cierra_sin_giro_ni_apertura_de_la_entrada() -> void:  # AC-SHF-046
	var almacen := await _abrir(3)
	var jugador: Node3D = almacen.get("_jugador")
	var antes: Transform3D = jugador.call("mira")
	var reloj: RelojDelTurno = almacen.get("_reloj")
	reloj.terminar()
	assert_bool((almacen.get("_pantalla") as PantallaDeDevolucion).visible).is_true()
	assert_bool((jugador.call("mira") as Transform3D).is_equal_approx(antes)).is_true()
	assert_bool(almacen.get_node(ENTRADA).call("puerta").abierta()).is_false()


func _abrir(jornada: int) -> Node3D:
	var almacen: Node3D = auto_free(load(RUTA_DEL_ALMACEN).instantiate())
	almacen.set("_partida", Partida.desde({"jornada": jornada}))
	almacen.set("compradores_de_la_apertura", func(_n: int) -> Array[Comprador]: return [])
	add_child(almacen)
	var reloj: RelojDelTurno = almacen.get("_reloj")
	reloj.set_process(false)
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	almacen.get("_salida").set_process(false)
	almacen.get_node(ENTRADA).set_physics_process(false)
	await get_tree().process_frame
	jugador.call("reanudar")
	for tarea in (almacen.get("_partida") as Partida).obligatorias():
		reloj.completar(tarea)
	return almacen


func _primario_sobre_la_entrada(almacen: Node3D) -> void:
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set("_enfocado", almacen.get_node(ENTRADA))
	for presionado: bool in [true, false]:
		var evento := InputEventMouseButton.new()
		evento.button_index = MOUSE_BUTTON_LEFT
		evento.pressed = presionado
		jugador.call("_unhandled_input", evento)
