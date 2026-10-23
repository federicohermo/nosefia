extends GdUnitTestSuite

const ANCHO_DEL_VANO := 3.0
const ALTO_DEL_VANO := 2.8
const ALTURA_DEL_CENTRO := 1.5
const ALTURA_DE_LOS_OJOS := 1.8
const FOV_VERTICAL := 75.0
const ASPECTO := 16.0 / 9.0


## Un vano girado `giro` radianes, con la bisagra A de un lado y la B del otro.
func _vano(giro: float, invertido: bool) -> Dictionary:
	var eje := Vector3.RIGHT.rotated(Vector3.UP, giro)
	var centro := Vector3(7.0, ALTURA_DEL_CENTRO, -4.0)
	var a := centro - eje * ANCHO_DEL_VANO * 0.5
	var b := centro + eje * ANCHO_DEL_VANO * 0.5
	if invertido:
		var cambio := a
		a = b
		b = cambio
	return {"a": a, "b": b, "centro": centro, "eje": eje, "normal": eje.cross(Vector3.UP)}


func _frontal(vano: Dictionary, desde: Vector3, fov: float = FOV_VERTICAL) -> PoseDeLaVista:
	return PoseDeLaVista.frontal_al_vano(vano.a, vano.b, desde, ALTO_DEL_VANO, fov, ASPECTO)


func _mirada(pose: PoseDeLaVista) -> Vector3:
	return Basis.from_euler(Vector3(pose.orientacion.y, pose.orientacion.x, 0.0)) * Vector3.FORWARD


func _ojos(vano: Dictionary, lateral: float, hondo: float) -> Vector3:
	var lugar: Vector3 = vano.centro + vano.eje * lateral + vano.normal * hondo
	lugar.y = ALTURA_DE_LOS_OJOS
	return lugar


func test_termina_centrada_y_perpendicular_desde_cualquier_lugar() -> void:  # AC-SHF-047
	for giro: float in [0.0, 0.7, -2.4, PI]:
		for invertido: bool in [false, true]:
			var vano := _vano(giro, invertido)
			for lateral: float in [-6.0, 0.0, 0.3, 5.0]:
				for hondo: float in [0.5, 2.0, 9.0]:
					var desde := _ojos(vano, lateral, hondo)
					var pose := _frontal(vano, desde)
					var relativa := pose.posicion - vano.centro as Vector3
					assert_float(relativa.dot(vano.eje)).is_equal_approx(0.0, 0.01)
					assert_float(relativa.dot(vano.normal)).is_greater(0.0)
					assert_float(_mirada(pose).dot(-vano.normal)).is_equal_approx(1.0, 0.0001)
					assert_float(pose.orientacion.y).is_equal_approx(0.0, 0.0001)
					assert_float(pose.posicion.y).is_equal_approx(ALTURA_DE_LOS_OJOS, 0.0001)


func test_el_lado_del_interior_es_el_del_jugador() -> void:  # AC-SHF-047
	var vano := _vano(0.4, false)
	for lado: float in [-1.0, 1.0]:
		var pose := _frontal(vano, _ojos(vano, 0.0, 3.0 * lado))
		var relativa := pose.posicion - vano.centro as Vector3
		assert_float(signf(relativa.dot(vano.normal))).is_equal(lado)


func test_la_pose_no_depende_de_donde_se_empieza_y_encuadra_el_vano_entero() -> void:  # AC-SHF-047
	var vano := _vano(1.1, false)
	var poses: Array[PoseDeLaVista] = []
	for lateral: float in [-4.0, 0.0, 3.0]:
		poses.append(_frontal(vano, _ojos(vano, lateral, 2.0 + absf(lateral))))
	var mitad_vertical := tan(deg_to_rad(FOV_VERTICAL) * 0.5)
	for pose: PoseDeLaVista in poses:
		assert_vector(pose.posicion).is_equal_approx(poses[0].posicion, Vector3.ONE * 0.0001)
		var distancia := (pose.posicion - vano.centro as Vector3).dot(vano.normal)
		assert_float(ANCHO_DEL_VANO * 0.5 / distancia).is_less(mitad_vertical * ASPECTO)
		var piso := pose.posicion.y - (ALTURA_DEL_CENTRO - ALTO_DEL_VANO * 0.5)
		var techo := ALTURA_DEL_CENTRO + ALTO_DEL_VANO * 0.5 - pose.posicion.y
		assert_float(maxf(piso, techo) / distancia).is_less(mitad_vertical)


func test_un_campo_de_vision_mas_angosto_aleja_la_camara() -> void:  # AC-SHF-047
	var vano := _vano(0.0, false)
	var desde := _ojos(vano, 0.0, 2.0)
	var ancho := _frontal(vano, desde, 100.0)
	var angosto := _frontal(vano, desde, 50.0)
	assert_float(angosto.posicion.distance_to(vano.centro)).is_greater(
		ancho.posicion.distance_to(vano.centro)
	)


func test_una_pantalla_mas_angosta_aleja_la_camara_para_no_cortar_las_hojas() -> void:  # AC-SHF-047
	var vano := _vano(0.0, false)
	var desde := _ojos(vano, 0.0, 2.0)
	var ancha := PoseDeLaVista.frontal_al_vano(vano.a, vano.b, desde, 0.2, FOV_VERTICAL, ASPECTO)
	var vertical := PoseDeLaVista.frontal_al_vano(vano.a, vano.b, desde, 0.2, FOV_VERTICAL, 0.5)
	assert_float(vertical.posicion.distance_to(vano.centro)).is_greater(
		ancha.posicion.distance_to(vano.centro)
	)


func test_entre_dos_poses_la_posicion_y_la_orientacion_se_mezclan() -> void:  # AC-SHF-047
	var desde := PoseDeLaVista.new(Vector3.ZERO, Vector2(1.0, 0.4))
	var hacia := PoseDeLaVista.new(Vector3(4.0, 0.0, -2.0), Vector2(-1.0, 0.0))
	assert_vector(desde.mezclada_con(hacia, 0.0).posicion).is_equal(desde.posicion)
	assert_vector(desde.mezclada_con(hacia, 1.0).posicion).is_equal(hacia.posicion)
	var mitad := desde.mezclada_con(hacia, 0.5)
	assert_vector(mitad.posicion).is_equal_approx(Vector3(2.0, 0.0, -1.0), Vector3.ONE * 0.0001)
	assert_vector(mitad.orientacion).is_equal_approx(Vector2(0.0, 0.2), Vector2.ONE * 0.0001)


func test_la_mezcla_toma_el_camino_corto_del_yaw() -> void:  # AC-SHF-044
	for sentido: float in [-1.0, 1.0]:
		var desde := PoseDeLaVista.new(Vector3.ZERO, Vector2(deg_to_rad(179.0) * sentido, 0.0))
		var hacia := PoseDeLaVista.new(Vector3.ZERO, Vector2(-deg_to_rad(179.0) * sentido, 0.0))
		var medio := desde.mezclada_con(hacia, 0.5)
		var recorrido := wrapf(medio.orientacion.x - desde.orientacion.x, -PI, PI)
		assert_float(rad_to_deg(recorrido)).is_equal_approx(sentido, 0.0001)


func test_un_jugador_ya_de_frente_no_se_mueve() -> void:  # AC-SHF-047
	var vano := _vano(0.9, false)
	var pose := _frontal(vano, _ojos(vano, 0.0, 4.0))
	var otra := _frontal(vano, pose.posicion)
	assert_vector(otra.posicion).is_equal_approx(pose.posicion, Vector3.ONE * 0.0001)
	assert_vector(otra.orientacion).is_equal_approx(pose.orientacion, Vector2.ONE * 0.0001)
