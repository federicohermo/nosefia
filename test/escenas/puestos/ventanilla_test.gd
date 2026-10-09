## La ventanilla que se ve: su cableado, su contrato de interacción y lo que tiene prohibido.
##
## El cableado se instancia; los casos de cámara entran al árbol con física real.
extends GdUnitTestSuite

const ESCENA := "res://src/escenas/puestos/ventanilla.tscn"
const SCRIPT := "res://src/escenas/puestos/ventanilla.gd"
const ESCENA_DEL_ALMACEN := "res://src/escenas/almacen.tscn"
const ESCENA_DEL_JUGADOR := "res://src/escenas/jugador.tscn"
const ESCENA_DEL_PANEL := "res://src/ui/diegetica/panel_de_la_ventanilla.tscn"

## El script del puesto se preloadea para poder tiparlo: los scripts de `escenas/` son cáscara y
## no declaran `class_name`.
const VentanillaQueSeVe := preload("res://src/escenas/puestos/ventanilla.gd")

## Lo que escribiría la posición del jugador desde afuera. El 004 aplica su yaw por cuadro, así
## que escribirlo acá lo desincroniza del dominio y al reanudar la cámara salta al yaw viejo.
const ESCRITURAS_PROHIBIDAS := [
	"jugador.transform", "jugador.position", "jugador.rotation", "jugador.global_position"
]


func _ventanilla() -> VentanillaQueSeVe:
	return auto_free(load(ESCENA).instantiate())


func test_la_ventanilla_esta_en_el_grupo_que_la_mira_puede_enfocar() -> void:
	# Sin el grupo, el rayo la ve y el jugador no: la mira no la marca como algo con lo
	# que se puede interactuar, y el jugador no tiene cómo enterarse de que ahí se atiende.
	var ventanilla := _ventanilla()
	assert_bool(ventanilla.is_in_group(ReglasDelJugador.GRUPO_INTERACTUABLE)).is_true()
	assert_bool(ventanilla.has_method(ReglasDeLosObjetos.METODO_ACCIONAR)).is_true()


func test_la_ventanilla_recibe_al_jugador_y_al_reloj_por_export() -> void:
	# Los dos por `@export` y no por `get_node()` hacia arriba: una escena que se reacomoda
	# rompe la ruta sin que nada avise hasta que se corre.
	var texto := FileAccess.get_file_as_string(SCRIPT)
	assert_str(texto).is_not_empty()
	for propiedad: String in ["@export var jugador", "@export var reloj"]:
		(
			assert_bool(texto.contains(propiedad))
			. override_failure_message("`ventanilla.gd` no declara `%s`" % propiedad)
			. is_true()
		)


func test_la_ventanilla_sale_con_la_accion_compartida() -> void:
	var texto := FileAccess.get_file_as_string(SCRIPT)
	assert_bool(texto.contains("ReglasDelJugador.ACCION_USAR")).is_true()
	assert_bool(texto.contains("func _input(")).is_true()


func test_la_ventanilla_no_le_escribe_el_transform_al_jugador() -> void:
	# Suspender **es** clavar la cámara: la puerta del control alcanza, y escribir la pose por
	# encima la desincroniza del dominio sin que ningún gate lo diga.
	var texto := FileAccess.get_file_as_string(SCRIPT)
	for escritura: String in ESCRITURAS_PROHIBIDAS:
		(
			assert_bool(texto.contains(escritura))
			. override_failure_message("`ventanilla.gd` escribe `%s`" % escritura)
			. is_false()
		)


func test_el_almacen_instancia_la_ventanilla_exactamente_una_vez() -> void:
	# Se cuenta sobre el texto del `.tscn` y no sobre el árbol instanciado porque lo que hay que
	# afirmar es que se referencia **una sola vez**: dos ventanillas serían dos tareas de atender
	# corriendo sobre el mismo turno, y el jefe contaría una sola.
	var texto := FileAccess.get_file_as_string(
		"res://src/escenas/puestos/estructura_del_almacen.tscn"
	)
	assert_str(texto).is_not_empty()
	assert_int(texto.count(ESCENA)).is_equal(1)


func test_tocar_la_ventanilla_clava_al_jugador_y_no_entrega_nada_para_levantar() -> void:
	var almacen := await _almacen_en()
	var ventanilla: VentanillaQueSeVe = almacen.get_node("Estructura/Ventanilla")
	var jugador: Node3D = almacen.get_node("Jugador")
	var pose := jugador.transform
	assert_object(ventanilla.call(ReglasDeLosObjetos.METODO_ACCIONAR)).is_null()
	assert_object(ventanilla.atenciones.atencion()).is_not_null()
	assert_that(jugador.transform).is_equal(pose)


func test_el_cableado_de_atender_llega_entero_desde_el_almacen() -> void:
	# Un `@export` de tipo `Node` en una escena escrita a mano va declarado ADEMÁS en el
	# `node_paths` del tag del nodo, o queda en `null`: la escena carga sin un solo error, los
	# nodos dan verde, y el juego muere en el primer cuadro con un
	# `Nonexistent function … in base 'Nil'` que no nombra ni al `.tscn` ni al `@export`.
	#
	# Los tres niveles se afirman juntos porque la trampa es la misma en los tres: la raíz, el
	# puesto instanciado que apunta afuera de su sub-escena, y el nodo de `sistemas/` que cuelga
	# suelto de la raíz. Contar la instancia no alcanza: una ventanilla instanciada sin su
	# `node_paths` está en la escena y no atiende a nadie.
	var almacen: Node3D = auto_free(load(ESCENA_DEL_ALMACEN).instantiate())
	(
		assert_object(almacen.get("_atenciones"))
		. override_failure_message(
			"`_atenciones` quedó en null: falta en el `node_paths` de la raíz"
		)
		. is_not_null()
	)
	var puesto: VentanillaQueSeVe = almacen.get_node("Estructura/Ventanilla")
	for propiedad: String in [
		"jugador", "reloj", "atenciones", "panel", "borde_superior", "antepecho"
	]:
		(
			assert_object(puesto.get(propiedad))
			. override_failure_message(
				"`Ventanilla.%s` quedó en null: falta en su `node_paths`" % propiedad
			)
			. is_not_null()
		)
	var atenciones: Ventanilla = almacen.get_node("Servicios/Atenciones")
	assert_object(atenciones.reloj).is_not_null()


func test_el_panel_de_la_ventanilla_llega_con_sus_seis_nodos() -> void:
	# Una sub-escena instanciada necesita su `script` declarado en su propio `.tscn`: sin él, el
	# `@export` que la apunta desde afuera queda en `null` **con el `node_paths` de la raíz bien
	# escrito**, y se diagnostica mal porque se revisa el `node_paths`, que está bien.
	var panel: PanelDeLaVentanilla = auto_free(load(ESCENA_DEL_PANEL).instantiate())
	for propiedad: String in ["_fondo", "_nombre", "_renglones", "_aviso", "_cobrar", "_despachar"]:
		(
			assert_object(panel.get(propiedad))
			. override_failure_message("`PanelDeLaVentanilla.%s` quedó en null" % propiedad)
			. is_not_null()
		)


func test_cancelar_con_el_vidrio_cerrado_no_le_devuelve_la_caminata_al_jugador() -> void:
	# El clic derecho llega desde cualquier rincón del local y examinar un objeto también suspende
	# (006): sin el corte, la salida de la ventanilla le devuelve la caminata al jugador en medio
	# de un examen, con el objeto pegado a la cara y sin un solo error.
	var ventanilla := _ventanilla()
	var jugador: Node3D = auto_free(load(ESCENA_DEL_JUGADOR).instantiate())
	ventanilla.jugador = jugador
	jugador.suspender()

	ventanilla.cerrar()

	assert_bool(jugador._control.esta_suspendido()).is_true()


func test_abrir_y_cerrar_la_ventanilla_suspende_y_devuelve_el_control() -> void:
	var almacen := await _almacen_en()
	var ventanilla: VentanillaQueSeVe = almacen.get_node("Estructura/Ventanilla")
	var jugador: Node3D = almacen.get_node("Jugador")
	ventanilla.abrir()
	assert_bool(jugador.get("_control").esta_suspendido()).is_true()
	ventanilla.cerrar()
	assert_bool(jugador.get("_control").esta_suspendido()).is_false()
	assert_bool(ventanilla.panel.visible).is_false()


func after_test() -> void:
	get_tree().paused = false


func _almacen_en(tamano: Vector2i = Vector2i(1280, 720)) -> Node3D:
	var viewport: SubViewport = auto_free(SubViewport.new())
	viewport.size = tamano
	viewport.world_3d = World3D.new()
	add_child(viewport)
	var almacen: Node3D = auto_free(load(ESCENA_DEL_ALMACEN).instantiate())
	viewport.add_child(almacen)
	almacen.get_node("Jugador").set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	return almacen


func _esquinas_del_marco(ventanilla: VentanillaQueSeVe) -> Array[Vector3]:
	var puntos: Array[Vector3] = []
	var referencia := ventanilla.borde_superior.global_transform
	var soporte: AABB = (
		referencia.affine_inverse()
		* ventanilla.antepecho.global_transform
		* ventanilla.antepecho.get_aabb()
	)
	for x: float in [soporte.position.x, soporte.end.x]:
		puntos.append(referencia * Vector3(x, 0.0, 0.0))
		puntos.append(referencia * Vector3(x, soporte.end.y, soporte.position.z))
	return puntos


func _la_malla_tapa(camara: Camera3D, esquina: Vector3, malla: MeshInstance3D) -> bool:
	var inversa := malla.global_transform.affine_inverse()
	var desde := inversa * camara.global_position
	# El borde pertenece a la propia malla; se pregunta por el recorrido anterior a tocarlo.
	var hasta := inversa * esquina.move_toward(camara.global_position, 0.002)
	if malla.get_aabb().intersects_segment(desde, hasta) == null:
		return false
	var caras := malla.mesh.get_faces()
	for indice in range(0, caras.size(), 3):
		if (
			Geometry3D.segment_intersects_triangle(
				desde, hasta, caras[indice], caras[indice + 1], caras[indice + 2]
			)
			!= null
		):
			return true
	return false


func _afirmar_encuadre(ventanilla: VentanillaQueSeVe, camara: Camera3D) -> void:
	var pantalla := camara.get_viewport().get_visible_rect().size
	var minimo := pantalla
	var maximo := Vector2.ZERO
	for esquina in _esquinas_del_marco(ventanilla):
		assert_bool(camara.is_position_behind(esquina)).is_false()
		var punto := camara.unproject_position(esquina)
		assert_float(punto.x).is_between(-0.5, pantalla.x + 0.5)
		assert_float(punto.y).is_between(-0.5, pantalla.y + 0.5)
		minimo = minimo.min(punto)
		maximo = maximo.max(punto)
		var consulta := PhysicsRayQueryParameters3D.create(camara.global_position, esquina)
		# El vidrio es el cuerpo de interacción transparente, no un obstáculo de la vista.
		consulta.exclude = [ventanilla.get_rid()]
		var golpe := camara.get_world_3d().direct_space_state.intersect_ray(consulta)
		# Un contacto en el propio borde no tapa el recorrido anterior de la vista.
		if not golpe.is_empty():
			assert_float(camara.global_position.distance_to(golpe.position)).is_greater_equal(
				camara.global_position.distance_to(esquina) - 0.002
			)
		# La malla del antepecho no trae colisión. Sus triángulos sí ejercen la oclusión visual.
		assert_bool(_la_malla_tapa(camara, esquina, ventanilla.antepecho)).is_false()
		var pared: MeshInstance3D = ventanilla.get_parent().get_node("almacen")
		assert_bool(_la_malla_tapa(camara, esquina, pared)).is_false()
	var alto_ocupa := absf(minimo.y) < 0.5 and absf(maximo.y - pantalla.y) < 0.5
	var ancho_ocupa := absf(minimo.x) < 0.5 and absf(maximo.x - pantalla.x) < 0.5
	assert_bool(alto_ocupa or ancho_ocupa).is_true()


func _afirmar_pose(actual: Transform3D, esperada: Transform3D) -> void:
	for indice in 4:
		var valor := actual.origin if indice == 3 else actual.basis[indice]
		var otro := esperada.origin if indice == 3 else esperada.basis[indice]
		assert_vector(valor).is_equal_approx(otro, Vector3.ONE * 0.00001)


func _izquierdo_del_jugador(jugador: Node3D, enfocado: Node3D) -> void:
	jugador.set("_enfocado", enfocado)
	var evento := InputEventAction.new()
	evento.action = ReglasDeLosObjetos.ACCION_AGARRAR
	evento.pressed = true
	jugador.call("_unhandled_input", evento)


func test_encuadra_y_vuelve_en_dos_aspectos() -> void:  # AC-PLY-058, AC-PLY-059, AC-PLY-060
	for tamano: Vector2i in [Vector2i(1280, 720), Vector2i(960, 720)]:
		var almacen := await _almacen_en(tamano)
		var jugador: Node3D = almacen.get_node("Jugador")
		var camara: Camera3D = jugador.get_node("Giro/Camara")
		var giro: Node3D = jugador.get_node("Giro")
		var control: ControlDelJugador = jugador.get("_control")
		control.girar(Vector2(130.0, -60.0))
		jugador.call("_aplicar_la_rotacion")
		var pose := camara.global_transform
		var cuerpo := jugador.global_transform
		var giro_antes := giro.transform
		var angulos := Vector2(control.yaw(), control.pitch())
		var ventanilla: VentanillaQueSeVe = almacen.get_node("Estructura/Ventanilla")
		ventanilla.abrir()
		for _cuadro in 8:
			await get_tree().process_frame
		_afirmar_encuadre(ventanilla, camara)
		_afirmar_pose(jugador.global_transform, cuerpo)
		_afirmar_pose(giro.transform, giro_antes)
		ventanilla.cerrar()
		_afirmar_pose(camara.global_transform, pose)
		assert_vector(Vector2(control.yaw(), control.pitch())).is_equal(angulos)


func test_el_izquierdo_suspendido_no_suelta_ni_agarra() -> void:  # AC-PLY-061, AC-PLY-062
	var almacen := await _almacen_en()
	var jugador: Node3D = almacen.get_node("Jugador")
	var agarre: Agarre = jugador.get("agarre")
	var unidad: Node3D = auto_free(
		load("res://src/escenas/objetos/objeto_agarrable.tscn").instantiate()
	)
	var datos := UnidadDeProducto.new(Catalogo.de(Producto.Id.ACTRONCITO))
	unidad.set("datos", datos)
	almacen.add_child(unidad)
	for ruta: String in ["Estructura/Ventanilla", "Estructura/base compu/StaticBody3D"]:
		var puesto: Node3D = almacen.get_node(ruta)
		puesto.call("abrir")
		_izquierdo_del_jugador(jugador, unidad)
		assert_object(agarre.manos().sostenido()).is_null()
		puesto.call("cerrar")
		assert_bool(agarre.pedir_agarrar(datos, unidad)).is_true()
		var padre := unidad.get_parent()
		puesto.call("abrir")
		_izquierdo_del_jugador(jugador, puesto)
		assert_object(agarre.manos().sostenido()).is_same(datos)
		assert_object(unidad.get_parent()).is_same(padre)
		puesto.call("cerrar")
		assert_object(agarre.manos().sostenido()).is_same(datos)
		agarre.soltar(true)


func test_abrir_dos_veces_y_cerrar_el_turno_devuelve_la_primera_pose() -> void:  # AC-PLY-060
	var almacen := await _almacen_en()
	var jugador: Node3D = almacen.get_node("Jugador")
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	var pose := camara.global_transform
	var ventanilla: VentanillaQueSeVe = almacen.get_node("Estructura/Ventanilla")
	ventanilla.abrir()
	ventanilla.abrir()
	(almacen.get("_reloj") as RelojDelTurno).turno_cerrado.emit(0)
	_afirmar_pose(camara.global_transform, pose)
	assert_bool(ventanilla.panel.visible).is_false()


func test_giro_atrasado_preserva_el_encuadre() -> void:  # AC-PLY-058, AC-PLY-060
	var almacen := await _almacen_en()
	var jugador: Node3D = almacen.get_node("Jugador")
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	var posicion := camara.position
	var control: ControlDelJugador = jugador.get("_control")
	_preparar_mouse_lento(control)
	control.girar(Vector2(300.0, -130.0))
	assert_bool(control.giro_atrasado()).is_true()
	var angulos := Vector2(control.yaw(), control.pitch())
	var ventanilla: VentanillaQueSeVe = almacen.get_node("Estructura/Ventanilla")
	ventanilla.abrir()
	var encuadre := camara.global_transform
	for _cuadro in 10:
		jugador.call("_process", 0.01)
		_afirmar_pose(camara.global_transform, encuadre)
	_afirmar_encuadre(ventanilla, camara)
	ventanilla.cerrar()
	assert_vector(camara.position).is_equal(posicion)
	assert_vector(-camara.global_basis.z).is_equal_approx(
		-Basis.from_euler(Vector3(control.pitch(), control.yaw(), 0.0)).z, Vector3.ONE * 0.00001
	)
	assert_vector(Vector2(control.yaw(), control.pitch())).is_equal(angulos)
	for _cuadro in 8:
		jugador.call("_process", 0.01)
		assert_vector(-camara.global_basis.z).is_equal_approx(
			-Basis.from_euler(Vector3(control.pitch(), control.yaw(), 0.0)).z, Vector3.ONE * 0.00001
		)


func test_el_aspecto_nuevo_se_usa_al_abrir_otra_vez() -> void:  # AC-PLY-058
	var almacen := await _almacen_en()
	var jugador: Node3D = almacen.get_node("Jugador")
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	var ventanilla: VentanillaQueSeVe = almacen.get_node("Estructura/Ventanilla")
	ventanilla.abrir()
	var pose := camara.global_transform
	var viewport := camara.get_viewport() as SubViewport
	viewport.size = Vector2i(540, 720)
	jugador.call("_process", 0.1)
	_afirmar_pose(camara.global_transform, pose)
	ventanilla.cerrar()
	ventanilla.abrir()
	_afirmar_encuadre(ventanilla, camara)
	assert_bool(camara.global_transform.is_equal_approx(pose)).is_false()
	ventanilla.cerrar()


func test_datos_invalidos_no_mueven_la_camara() -> void:  # AC-PLY-058, AC-PLY-060
	var almacen := await _almacen_en()
	var jugador: Node3D = almacen.get_node("Jugador")
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	var pose := camara.global_transform
	jugador.call("dejar_de_asomarse")
	_afirmar_pose(camara.global_transform, pose)
	jugador.call("asomarse", Transform3D.IDENTITY, Vector2.ZERO, 0.0)
	_afirmar_pose(camara.global_transform, pose)


## Reportes de 125 Hz sobre cuadros de 144 Hz: ejercen el atraso real del control.
func _preparar_mouse_lento(control: ControlDelJugador) -> void:
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
