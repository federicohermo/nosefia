extends GdUnitTestSuite

const Medicion := preload("res://test/performance/medir_agua_fuera_de_camara.gd")
const Malla := preload("res://test/performance/medir_malla_liquida.gd")
const Superficie := preload("res://src/escenas/objetos/superficie_liquida.gd")


func _balde(posicion: Vector3) -> Superficie:
	var raiz: Node3D = auto_free(Node3D.new())
	add_child(raiz)
	var agua := Malla.crear(raiz, true)
	(agua.get_parent() as Node3D).position = posicion
	return agua


func _camara(al_balde: bool) -> Camera3D:
	var camara: Camera3D = auto_free(Camera3D.new())
	camara.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(camara)
	camara.make_current()
	Medicion.apuntar(camara, al_balde)
	return camara


func test_el_balde_se_mueve_en_cada_paso_sin_salir_de_su_lugar() -> void:
	var menor := INF
	var mayor := -INF
	for paso: int in Medicion.PASOS_FUERA:
		var posicion := Medicion.posicion_en(paso)
		assert_float(posicion.distance_to(Medicion.LEJOS)).is_less(0.031)
		menor = minf(menor, posicion.x)
		mayor = maxf(mayor, posicion.x)
	assert_float(mayor - menor).is_greater(0.05)


func test_la_caja_queda_fuera_de_un_encuadre_y_entera_adentro_del_otro() -> void:
	var agua := _balde(Medicion.LEJOS)
	var camara := _camara(false)
	for paso: int in Medicion.PASOS_FUERA:
		(agua.get_parent() as Node3D).position = Medicion.posicion_en(paso)
		assert_bool(Medicion.esta_fuera_de_cuadro(camara, agua)).is_true()
		assert_int(Medicion.esquinas_en_cuadro(camara, agua)).is_equal(0)
	Medicion.apuntar(camara, true)
	assert_bool(Medicion.esta_fuera_de_cuadro(camara, agua)).is_false()
	assert_int(Medicion.esquinas_en_cuadro(camara, agua)).is_equal(8)


func test_una_caja_que_cruza_el_borde_no_esta_fuera_ni_entera_adentro() -> void:
	var camara := _camara(false)
	camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	var agua := _balde(Vector3(10.0 * camara.size, 0.0, -5.0))
	assert_bool(Medicion.esta_fuera_de_cuadro(camara, agua)).is_true()
	var borde := 0.0
	for plano: Plane in camara.get_frustum():
		if plano.normal.is_equal_approx(Vector3.RIGHT):
			borde = plano.d
	assert_float(borde).is_greater(0.0)
	(agua.get_parent() as Node3D).position.x = borde
	assert_bool(Medicion.esta_fuera_de_cuadro(camara, agua)).is_false()
	assert_int(Medicion.esquinas_en_cuadro(camara, agua)).is_between(1, 7)


func test_avanzar_cambia_el_estado_de_la_simulacion_en_cada_paso() -> void:
	var agua := _balde(Medicion.LEJOS)
	var vistos := {}
	for paso: int in 20:
		Medicion.avanzar(agua, paso)
		vistos[Medicion.sha256(Medicion.estado(agua))] = true
	assert_float(agua.get("_onda")).is_greater(0.0001)
	assert_int(vistos.size()).is_equal(20)
