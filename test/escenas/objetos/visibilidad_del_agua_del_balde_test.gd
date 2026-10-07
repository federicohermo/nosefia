extends GdUnitTestSuite

const Malla := preload("res://test/performance/medir_malla_liquida.gd")
const Fuera := preload("res://test/performance/medir_agua_fuera_de_camara.gd")
const Superficie := preload("res://src/escenas/objetos/superficie_liquida.gd")
const PASO := 1.0 / 60.0
const LEJOS := Vector3(100.0, 0.0, 0.0)


## Una superficie que actualiza su malla como con un renderizador real: sin pantalla la recrea
## en cada dibujo, y ese camino no mira la cámara.
func _superficie(posicion: Vector3, en_balde: bool = true, padre: Node = null) -> Superficie:
	var raiz: Node3D = auto_free(Node3D.new())
	(self if padre == null else padre).add_child(raiz)
	var superficie := Malla.crear(raiz, en_balde)
	(superficie.get_parent() as Node3D).position = posicion
	superficie.set("_recrea_la_superficie", false)
	return superficie


func _camara(desde: Vector3, hacia: Vector3, padre: Node = null) -> Camera3D:
	var camara: Camera3D = auto_free(Camera3D.new())
	# Interpolada, su encuadre es el del cuadro anterior: acá no corre ninguno.
	camara.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	(self if padre == null else padre).add_child(camara)
	camara.look_at_from_position(desde, hacia)
	camara.make_current()
	return camara


## Cambia la pose, pide un dibujo y dice si la malla se volvió a calcular.
func _se_redibuja(superficie: Superficie, nivel: float) -> bool:
	var vertices: PackedVector3Array = superficie.get("_vertices")
	var normales: PackedVector3Array = superficie.get("_normales")
	var antes := [vertices.duplicate(), normales.duplicate()]
	superficie.set("_nivel_visual", nivel)
	superficie.call("_process", PASO)
	return antes[0] != vertices or antes[1] != normales


## La malla calculada es la del estado de ahora: dibujarla de nuevo sin cámara no la cambia.
func _esta_al_dia(superficie: Superficie, camara: Camera3D) -> bool:
	var vertices: PackedVector3Array = superficie.get("_vertices")
	var antes := vertices.duplicate()
	camara.current = false
	superficie.set("_estaba_quieta", false)
	superficie.call("_dibujar")
	camara.make_current()
	return antes == vertices


func test_un_balde_activo_fuera_del_encuadre_no_recalcula_su_malla_y_sigue_simulando() -> void:
	var agua := _superficie(LEJOS)
	var camara := _camara(Vector3.ZERO, Vector3.FORWARD)
	assert_bool(Fuera.esta_fuera_de_cuadro(camara, agua)).is_true()
	var estado := Fuera.estado(agua)
	for paso: int in 30:
		Fuera.avanzar(agua, paso)
		assert_bool(_se_redibuja(agua, 0.2 + 0.02 * paso)).is_false()
	assert_float(agua.get("_onda")).is_greater(0.0001)
	assert_bool(Fuera.estado(agua) == estado).is_false()
	camara.look_at_from_position(LEJOS + Vector3(0.0, 2.0, 1.0), LEJOS)
	assert_int(Fuera.esquinas_en_cuadro(camara, agua)).is_equal(8)
	assert_bool(_se_redibuja(agua, 1.0)).is_true()
	assert_bool(_esta_al_dia(agua, camara)).is_true()


func test_la_caja_que_cruza_el_borde_se_dibuja_aunque_su_centro_quede_afuera() -> void:
	var camara := _camara(Vector3.ZERO, Vector3.FORWARD)
	camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	var borde := _borde_derecho(camara)
	for caso: Array in [
		[0.0, -0.001, true], [0.0, 0.001, false], [PI / 4.0, -0.001, true], [PI / 4.0, 0.001, false]
	]:
		var agua := _superficie(Vector3.ZERO)
		var recipiente := agua.get_parent() as Node3D
		recipiente.rotation.y = caso[0]
		var caja := (agua.mesh as ArrayMesh).custom_aabb
		# Cuánto sobresale la caja girada hacia el borde, medido desde el centro del balde.
		var alcance := 0.0
		for esquina: int in 8:
			alcance = maxf(alcance, (recipiente.basis * caja.get_endpoint(esquina)).x)
		recipiente.position = Vector3(borde + alcance + caso[1], 0.0, -5.0)
		assert_bool(camara.is_position_in_frustum(agua.global_position)).is_false()
		assert_bool(_se_redibuja(agua, 0.5)).is_equal(caso[2])


func _borde_derecho(camara: Camera3D) -> float:
	for plano: Plane in camara.get_frustum():
		if plano.normal.is_equal_approx(Vector3.RIGHT):
			return plano.d
	return NAN


func test_un_balde_detras_de_la_camara_no_recalcula_su_malla() -> void:
	var agua := _superficie(Vector3(0.0, 0.0, 5.0))
	var camara := _camara(Vector3.ZERO, Vector3.FORWARD)
	assert_bool(Fuera.esta_fuera_de_cuadro(camara, agua)).is_true()
	assert_bool(_se_redibuja(agua, 0.5)).is_false()
	camara.look_at_from_position(Vector3.ZERO, Vector3.BACK)
	assert_bool(_se_redibuja(agua, 0.7)).is_true()


func test_sin_camara_el_agua_fuera_de_todo_encuadre_se_dibuja() -> void:
	var agua := _superficie(LEJOS)
	assert_object(get_viewport().get_camera_3d()).is_null()
	assert_bool(_se_redibuja(agua, 0.5)).is_true()


func test_sin_escrituras_de_buffers_el_agua_se_dibuja_aunque_la_camara_no_la_vea() -> void:
	var agua := _superficie(LEJOS)
	var camara := _camara(Vector3.ZERO, Vector3.FORWARD)
	assert_bool(Fuera.esta_fuera_de_cuadro(camara, agua)).is_true()
	agua.set("_recrea_la_superficie", true)
	assert_bool(_se_redibuja(agua, 0.5)).is_true()
	var malla: PackedVector3Array = agua.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_bool(malla == agua.get("_vertices")).is_true()


func test_el_agua_decide_con_la_camara_de_su_propio_viewport() -> void:
	var principal := _camara(Vector3.ZERO, Vector3.FORWARD)
	var vista: SubViewport = auto_free(SubViewport.new())
	add_child(vista)
	var propia := _camara(LEJOS + Vector3(0.0, 2.0, 1.0), LEJOS, vista)
	var agua := _superficie(LEJOS, true, vista)
	assert_object(agua.get_viewport().get_camera_3d()).is_same(propia)
	assert_bool(Fuera.esta_fuera_de_cuadro(principal, agua)).is_true()
	assert_bool(_se_redibuja(agua, 0.5)).is_true()
	var raiz := agua.get_parent().get_parent()
	raiz.reparent(self)
	assert_object(agua.get_viewport().get_camera_3d()).is_same(principal)
	assert_bool(_se_redibuja(agua, 0.7)).is_false()


func test_el_nivel_que_termina_fuera_del_encuadre_se_ve_al_volver() -> void:
	var agua := _superficie(LEJOS)
	var camara := _camara(LEJOS + Vector3(0.0, 2.0, 1.0), LEJOS)
	agua.visible = false
	agua.llenar()
	agua.set_process(false)
	agua.set_physics_process(false)
	agua.call("_process", PASO)
	var vertices: PackedVector3Array = agua.get("_vertices")
	var vacia := vertices.duplicate()
	camara.look_at_from_position(Vector3.ZERO, Vector3.FORWARD)
	for paso: int in 4:
		agua.call("_physics_process", Superficie.DURACION_DEL_NIVEL / 4.0)
		agua.call("_process", PASO)
	assert_bool(agua.get("_cambiando_nivel")).is_false()
	assert_float(agua.get("_nivel_visual")).is_equal(1.0)
	assert_bool(vacia == vertices).is_true()
	camara.look_at_from_position(LEJOS + Vector3(0.0, 2.0, 1.0), LEJOS)
	agua.call("_process", PASO)
	assert_bool(vacia == vertices).is_false()
	assert_bool(_esta_al_dia(agua, camara)).is_true()


func test_las_ondas_que_se_amortiguan_fuera_dejan_la_malla_quieta_al_volver() -> void:
	var agua := _superficie(LEJOS)
	var camara := _camara(LEJOS + Vector3(0.0, 2.0, 1.0), LEJOS)
	for paso: int in 12:
		Fuera.avanzar(agua, paso)
	agua.call("_process", PASO)
	var vertices: PackedVector3Array = agua.get("_vertices")
	var agitada := vertices.duplicate()
	assert_float(_desnivel(agitada)).is_greater(0.001)
	camara.look_at_from_position(Vector3.ZERO, Vector3.FORWARD)
	for paso: int in 600:
		agua.call("_physics_process", PASO)
		agua.call("_process", PASO)
	assert_bool(agitada == vertices).is_true()
	camara.look_at_from_position(LEJOS + Vector3(0.0, 2.0, 1.0), LEJOS)
	agua.call("_process", PASO)
	assert_float(_desnivel(vertices)).is_less(0.001)


func _desnivel(vertices: PackedVector3Array) -> float:
	var menor := INF
	var mayor := -INF
	for vertice: Vector3 in vertices:
		menor = minf(menor, vertice.y)
		mayor = maxf(mayor, vertice.y)
	return mayor - menor


func test_la_mancha_fuera_del_encuadre_se_sigue_dibujando() -> void:
	var mancha := _superficie(LEJOS, false)
	var camara := _camara(Vector3.ZERO, Vector3.FORWARD)
	assert_bool(Fuera.esta_fuera_de_cuadro(camara, mancha)).is_true()
	var vertices: PackedVector3Array = mancha.get("_vertices")
	var antes := vertices.duplicate()
	mancha.set("_tiempo", 7.0)
	mancha.call("_process", PASO)
	assert_bool(antes == vertices).is_false()


func test_el_agua_quieta_se_descarta_sin_consultar_la_camara() -> void:
	var agua := _superficie(LEJOS)
	var camara := _camara(Vector3.ZERO, Vector3.FORWARD)
	assert_bool(Fuera.esta_fuera_de_cuadro(camara, agua)).is_true()
	# Pedir el encuadre de la cámara reserva memoria: es la huella de que se la consultó.
	assert_int(Malla.pedido_transitorio(camara.get_frustum)).is_greater(0)
	assert_int(Malla.pedido_transitorio(Callable(agua, "_dibujar"))).is_greater(0)
	camara.current = false
	agua.set("_onda", 0.0)
	agua.set("_pendiente", Vector2.ZERO)
	agua.call("_dibujar")
	assert_bool(agua.get("_estaba_quieta")).is_true()
	camara.make_current()
	assert_int(Malla.pedido_transitorio(Callable(agua, "_dibujar"))).is_equal(0)
