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
	for jornada: int in [1, 2]:
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


func test_salida_gira_abre_ambas_y_cierra_una_vez() -> void:  # AC-SHF-043, AC-SHF-044, AC-SHF-046
	for jornada: int in [1, 2]:
		var almacen := await _abrir(jornada)
		var jugador: Node3D = almacen.get("_jugador")
		var control: ControlDelJugador = jugador.get("_control")
		var cuadro := 1.0 / 144.0
		var tiempo := 0.0
		var proximo := 0.0
		for _indice in 300:
			while proximo <= tiempo:
				control.girar(Vector2(0.1, 0.0))
				proximo += 1.0 / 125.0
			control.avanzar_el_dibujo(cuadro)
			tiempo += cuadro
		control.avanzar_el_dibujo(SuavizadoDelGiro.VENTANA)
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
		var hojas := _hojas_de_entrada(almacen)
		var otra: Node3D = hojas.back()
		var centro := (_canto_exterior(hojas.front(), false) + _canto_exterior(otra, true)) * 0.5
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
		var direccion := Vector3(centro.x - orientada.origin.x, 0.0, centro.z - orientada.origin.z)
		direccion = direccion.normalized()
		assert_float((-orientada.basis.z).dot(direccion)).is_equal_approx(1.0, 0.001)
		assert_array(sonidos).is_equal([entrada])
		assert_bool(puerta.abierta()).is_true()
		entrada.call("_physics_process", 0.1)
		assert_float(puerta.angulo()).is_between(0.0, Puerta.ANGULO_ABIERTA)
		assert_bool(persiana.visible).is_false()
		assert_bool(pantalla.visible).is_false()
		entrada.call("_physics_process", 10.0)
		entrada.call("_physics_process", 0.1)
		assert_float(puerta.angulo()).is_equal(Puerta.ANGULO_ABIERTA)
		assert_bool(persiana.visible).is_false()
		assert_int(guardado.escrituras).is_zero()
		otra.call("_physics_process", 10.0)
		otra.call("_physics_process", 0.1)
		assert_float(otra.call("puerta").angulo()).is_equal(Puerta.ANGULO_ABIERTA)
		assert_bool(persiana.visible).is_true()
		assert_bool(pantalla.visible).is_false()
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
		var hojas := _hojas_de_entrada(almacen)
		var angulos: Array[float] = []
		var transformadas: Array[Transform3D] = []
		for hoja: Node3D in hojas:
			if abriendo:
				hoja.call("_physics_process", 0.1)
			angulos.append(hoja.call("puerta").angulo())
			transformadas.append(hoja.get("hoja").global_transform)
		var vista: Transform3D = jugador.call("mira")
		var lugar := jugador.global_position
		pausa.pausar()
		salida.set_process(true)
		for hoja: Node3D in hojas:
			hoja.set_physics_process(true)
		for _cuadro in 3:
			await get_tree().process_frame
		assert_bool((jugador.call("mira") as Transform3D).is_equal_approx(vista)).is_true()
		for indice: int in hojas.size():
			assert_float(hojas[indice].call("puerta").angulo()).is_equal(angulos[indice])
			(
				assert_bool(
					(hojas[indice].get("hoja").global_transform as Transform3D).is_equal_approx(
						transformadas[indice]
					)
				)
				. is_true()
			)
		assert_bool(pantalla.visible).is_false()
		pausa.reanudar()
		salida.set_process(false)
		for hoja: Node3D in hojas:
			hoja.set_physics_process(false)
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
		for hoja: Node3D in _hojas_de_entrada(almacen):
			hoja.call("_physics_process", 10.0)
			hoja.call("_physics_process", 0.1)
		(
			assert_bool(
				(almacen.get_node("Interfaz/PersianaDeLaNoche") as PersianaDeLaNoche).visible
			)
			. is_true()
		)
		assert_bool(pantalla.visible).is_false()


func test_el_tiempo_cierra_sin_giro_ni_apertura_de_la_entrada() -> void:  # AC-SHF-046
	var almacen := await _abrir(2)
	var jugador: Node3D = almacen.get("_jugador")
	var antes: Transform3D = jugador.call("mira")
	var reloj: RelojDelTurno = almacen.get("_reloj")
	reloj.terminar()
	(
		assert_bool((almacen.get_node("Interfaz/PersianaDeLaNoche") as PersianaDeLaNoche).visible)
		. is_true()
	)
	assert_bool((almacen.get("_pantalla") as PantallaDeDevolucion).visible).is_false()
	assert_bool((jugador.call("mira") as Transform3D).is_equal_approx(antes)).is_true()
	assert_bool(almacen.get_node(ENTRADA).call("puerta").abierta()).is_false()


func test_la_entrada_se_cierra_al_pasar_de_la_segunda_a_la_tercera() -> void:  # AC-SHF-046
	var almacen := await _abrir(2)
	var entrada: Node3D = almacen.get_node(ENTRADA)
	var cerradas: Dictionary[Node3D, Transform3D] = {}
	for hoja: Node3D in _hojas_de_entrada(almacen):
		cerradas[hoja] = hoja.get("hoja").global_transform
	_primario_sobre_la_entrada(almacen)
	almacen.get("_salida").call("_process", SalidaVoluntaria.DURACION_DEL_GIRO)
	for hoja: Node3D in _hojas_de_entrada(almacen):
		hoja.call("_physics_process", Puerta.ANGULO_ABIERTA / Puerta.VELOCIDAD_DEL_GIRO)
		hoja.call("_physics_process", 0.0)
	assert_bool(entrada.call("puerta").abierta()).is_true()
	assert_int((almacen.get("_partida") as Partida).jornada()).is_equal(2)
	await almacen.call("_preparar_lo_postergado")
	almacen.get("_ciclo").call("abrir_la_jornada")
	for hoja: Node3D in cerradas:
		assert_bool(hoja.call("puerta").abierta()).is_false()
		assert_float(hoja.call("puerta").angulo()).is_zero()
		(
			assert_bool(
				(hoja.get("hoja").global_transform as Transform3D).is_equal_approx(cerradas[hoja])
			)
			. is_true()
		)
	assert_bool(almacen.call("_puede_salir")).is_false()


func test_las_hojas_giran_sobre_sus_cantos_exteriores_hacia_el_mismo_lado() -> void:  # AC-SHF-043
	var almacen := await _abrir(1)
	var hojas := _hojas_de_entrada(almacen)
	for derecha: bool in [false, true]:
		var cuerpo: Node3D = hojas.back() if derecha else hojas.front()
		var hoja: MeshInstance3D = cuerpo.get("hoja")
		var bisagra := _canto_exterior(cuerpo, derecha)
		var canto_local := hoja.to_local(bisagra)
		var centro_local := hoja.get_aabb().get_center()
		var centro_cerrado := hoja.to_global(centro_local)
		cuerpo.call("abrir_para_salida")
		for _paso in 8:
			cuerpo.call("_physics_process", Puerta.ANGULO_ABIERTA / Puerta.VELOCIDAD_DEL_GIRO / 8.0)
			assert_vector(hoja.to_global(canto_local)).is_equal_approx(
				bisagra, Vector3.ONE * 0.0001
			)
			assert_float(hoja.to_global(centro_local).z).is_greater(centro_cerrado.z)
			assert_float(hoja.to_global(centro_local).y).is_equal_approx(centro_cerrado.y, 0.0001)
		assert_float(cuerpo.call("puerta").angulo()).is_equal(Puerta.ANGULO_ABIERTA)
		cuerpo.call("cerrar_de_golpe")


func test_retoma_y_reintenta_la_tercera_con_hojas_cerradas() -> void:  # AC-SHF-046, AC-PLY-103
	assert_bool(Guardado.new().escribir(PartidaSerializada.sanear({"jornada": 3}))).is_true()
	for _intento in 2:
		var almacen := await _abrir(3, true)
		assert_int((almacen.get("_partida") as Partida).jornada()).is_equal(3)
		for entrada: Node3D in _hojas_de_entrada(almacen):
			assert_bool(entrada.call("puerta").abierta()).is_false()
			assert_float(entrada.call("puerta").angulo()).is_zero()
			entrada.call("accionar")
			entrada.call("_physics_process", Puerta.ANGULO_ABIERTA / Puerta.VELOCIDAD_DEL_GIRO)
			assert_float(entrada.call("puerta").angulo()).is_zero()
		assert_bool(almacen.call("_puede_salir")).is_false()
		assert_bool((almacen.get("_pantalla") as PantallaDeDevolucion).visible).is_false()


func test_cualquiera_de_las_hojas_inicia_la_salida_de_ambas() -> void:  # AC-PLY-104
	for derecha: bool in [false, true]:
		var almacen := await _abrir(1)
		var hojas := _hojas_de_entrada(almacen)
		_primario_sobre_la_entrada(almacen, hojas.back() if derecha else hojas.front())
		assert_bool(almacen.get("_jugador").call("suspendido")).is_true()
		almacen.get("_salida").call("_process", SalidaVoluntaria.DURACION_DEL_GIRO)
		for hoja: Node3D in hojas:
			assert_bool(hoja.call("puerta").abierta()).is_true()
			assert_float(hoja.call("puerta").angulo()).is_zero()


func test_la_salida_termina_de_frente_al_vano_desde_cualquier_lugar() -> void:  # AC-SHF-047
	var finales: Array[Vector3] = []
	var partidas := [[-2.0, 1.2, 0.0], [0.0, 2.5, PI], [1.5, 1.0, 2.0], [0.4, 3.0, -1.3]]
	for partida: Array in partidas:
		var almacen := await _abrir(1)
		var jugador: Node3D = almacen.get("_jugador")
		var camara: Camera3D = jugador.get_node("Giro/Camara")
		var hojas := _hojas_de_entrada(almacen)
		var bisagra_a: Vector3 = hojas.front().get("eje_de_la_bisagra").global_position
		var bisagra_b: Vector3 = hojas.back().get("eje_de_la_bisagra").global_position
		var centro := (bisagra_a + bisagra_b) * 0.5
		var alto: float = hojas.front().get("hoja").get_aabb().size.y
		var eje := Vector3(bisagra_b.x - bisagra_a.x, 0.0, bisagra_b.z - bisagra_a.z).normalized()
		var normal := eje.cross(Vector3.UP)
		if (jugador.global_position - centro).dot(normal) < 0.0:
			normal = -normal
		var lateral: float = partida[0]
		var hondo: float = partida[1]
		var yaw: float = partida[2]
		var lugar := centro + eje * lateral + normal * hondo
		lugar.y = jugador.global_position.y
		jugador.call("ubicar", Transform3D(Basis(Vector3.UP, yaw), lugar))
		_primario_sobre_la_entrada(almacen)
		(almacen.get("_salida") as SalidaDelAlmacen)._process(SalidaVoluntaria.DURACION_DEL_GIRO)
		var vista: Transform3D = jugador.call("mira")
		var adelante := -vista.basis.z
		assert_float((vista.origin - centro).dot(eje)).is_equal_approx(0.0, 0.01)
		assert_float((vista.origin - centro).dot(normal)).is_greater(0.0)
		assert_float(adelante.angle_to(-normal)).is_less(deg_to_rad(0.1))
		assert_float(adelante.y).is_equal_approx(0.0, 0.0001)
		for punta: Vector3 in [bisagra_a, bisagra_b]:
			for lado: float in [-0.5, 0.5]:
				var esquina: Vector3 = punta + Vector3.UP * alto * lado
				assert_bool(camara.is_position_in_frustum(esquina)).is_true()
		finales.append(vista.origin)
	for final: Vector3 in finales:
		assert_vector(final).is_equal_approx(finales[0], Vector3.ONE * 0.001)


func _hojas_de_entrada(almacen: Node3D) -> Array[Node3D]:
	var hojas: Array[Node3D] = []
	for cuerpo: Node in almacen.find_children("*", "AnimatableBody3D", true, false):
		if (
			cuerpo.get("consultar_salida") is Callable
			and (cuerpo.get("consultar_salida") as Callable).is_valid()
		):
			hojas.append(cuerpo)
	return hojas


func _canto_exterior(cuerpo: Node3D, derecha: bool) -> Vector3:
	var hoja: MeshInstance3D = cuerpo.get("hoja")
	var caja := hoja.get_aabb()
	var extremo := caja.end.x if derecha else caja.position.x
	var frente := -INF
	for superficie: int in hoja.mesh.get_surface_count():
		var vertices: PackedVector3Array = hoja.mesh.surface_get_arrays(superficie)[
			Mesh.ARRAY_VERTEX
		]
		for vertice: Vector3 in vertices:
			if is_equal_approx(vertice.x, extremo):
				frente = maxf(frente, vertice.z)
	return hoja.to_global(Vector3(extremo, caja.get_center().y, frente))


func _abrir(jornada: int, desde_guardado: bool = false) -> Node3D:
	var almacen: Node3D = auto_free(load(RUTA_DEL_ALMACEN).instantiate())
	if not desde_guardado:
		almacen.set("_partida", Partida.desde({"jornada": jornada}))
	almacen.set("compradores_de_la_apertura", func(_n: int) -> Array[Comprador]: return [])
	add_child(almacen)
	var reloj: RelojDelTurno = almacen.get("_reloj")
	reloj.set_process(false)
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	almacen.get("_salida").set_process(false)
	for entrada: Node3D in _hojas_de_entrada(almacen):
		entrada.set_physics_process(false)
	await get_tree().process_frame
	jugador.call("reanudar")
	for tarea in (almacen.get("_partida") as Partida).obligatorias():
		reloj.completar(tarea)
	return almacen


func _primario_sobre_la_entrada(almacen: Node3D, entrada: Node3D = null) -> void:
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set("_enfocado", almacen.get_node(ENTRADA) if entrada == null else entrada)
	for presionado: bool in [true, false]:
		var evento := InputEventMouseButton.new()
		evento.button_index = MOUSE_BUTTON_LEFT
		evento.pressed = presionado
		jugador.call("_unhandled_input", evento)
