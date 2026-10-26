extends GdUnitTestSuite

const CHICA := 0.2
const GRANDE := 0.3
const ESTANTE := 1.0
const TECHO := 2.45

const A := Producto.Id.ACTRONCITO
const D := Producto.Id.DUREXTRA
const B := Producto.Id.BURBALOO
const Z := Producto.Id.ZUCARACHAS
const L := Producto.Id.LAYSNNT
const M := Producto.Id.MALBARDO


func _repisas() -> Array[AABB]:
	return [
		AABB(Vector3(-0.5, ESTANTE - 0.1, -0.5), Vector3(5.0, 0.1, 1.0)),
		AABB(Vector3(-0.5, TECHO, -0.5), Vector3(5.0, 0.1, 1.0)),
	]


func _en_estante(media: float, x: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(x, ESTANTE + media, 0.0))


func _en_el_piso(media: float, x: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(x, media, 3.0))


func _caja(id: Producto.Id, media: float, x: float) -> OrganizacionDelDeposito.Caja:
	return OrganizacionDelDeposito.Caja.new(id, media, _en_estante(media, x), true)


func _cajas() -> Array[OrganizacionDelDeposito.Caja]:
	return [
		_caja(A, CHICA, 0.25),
		_caja(D, CHICA, 0.75),
		_caja(B, CHICA, 1.25),
		_caja(Z, CHICA, 1.75),
		_caja(L, GRANDE, 2.5),
		_caja(M, GRANDE, 3.2),
	]


func _de_fabrica(
	cajas: Array[OrganizacionDelDeposito.Caja]
) -> Dictionary[Producto.Id, Transform3D]:
	var poses: Dictionary[Producto.Id, Transform3D] = {}
	for caja in cajas:
		poses[caja.producto] = caja.fabrica
	return poses


func _afirmar_pose(
	poses: Dictionary[Producto.Id, Transform3D], id: Producto.Id, esperada: Transform3D
) -> void:
	(
		assert_bool(poses[id].is_equal_approx(esperada))
		. override_failure_message(
			"%s: abrió en %s y se esperaba %s" % [Producto.Id.keys()[id], poses[id], esperada]
		)
		. is_true()
	)


func _limites(pose: Transform3D, media: float) -> AABB:
	return AABB(pose.origin - Vector3.ONE * media, Vector3.ONE * media * 2.0)


func _sin_superposicion(
	poses: Dictionary[Producto.Id, Transform3D], cajas: Array[OrganizacionDelDeposito.Caja]
) -> void:
	for una in cajas:
		for otra in cajas:
			if una.producto < otra.producto:
				var nucleo := _limites(poses[una.producto], una.media).grow(-0.001)
				(
					assert_bool(nucleo.intersects(_limites(poses[otra.producto], otra.media)))
					. override_failure_message(
						(
							"%s se superpone con %s"
							% [Producto.Id.keys()[una.producto], Producto.Id.keys()[otra.producto]]
						)
					)
					. is_false()
				)


func _esta_encima_de_otra(
	id: Producto.Id,
	poses: Dictionary[Producto.Id, Transform3D],
	cajas: Array[OrganizacionDelDeposito.Caja]
) -> bool:
	var propia: Vector3 = poses[id].origin
	for otra in cajas:
		if otra.producto == id:
			continue
		var debajo := _limites(poses[otra.producto], otra.media)
		var centro := debajo.get_center()
		var en_planta := (
			absf(propia.x - centro.x) <= otra.media and absf(propia.z - centro.z) <= otra.media
		)
		var base: float = _limites(poses[id], _media_de(id, cajas)).position.y
		if en_planta and absf(base - debajo.end.y) < 0.001:
			return true
	return false


func _media_de(id: Producto.Id, cajas: Array[OrganizacionDelDeposito.Caja]) -> float:
	for caja in cajas:
		if caja.producto == id:
			return caja.media
	return 0.0


func test_la_caja_que_cerro_en_estanteria_abre_donde_quedo() -> void:  # AC-STK-111
	var cajas := _cajas()
	var guardadas: Dictionary[Producto.Id, Transform3D] = _de_fabrica(cajas)
	guardadas[A] = _en_estante(CHICA, 0.75)
	guardadas[D] = _en_estante(CHICA, 0.25)
	var poses := OrganizacionDelDeposito.abrir(cajas, guardadas, _repisas())
	for id in guardadas:
		_afirmar_pose(poses, id, guardadas[id])


func test_la_caja_sobre_otra_que_esta_en_estanteria_abre_igual() -> void:  # AC-STK-111
	var cajas := _cajas()
	var guardadas: Dictionary[Producto.Id, Transform3D] = _de_fabrica(cajas)
	guardadas[B] = Transform3D(Basis.IDENTITY, Vector3(1.75, ESTANTE + CHICA * 3.0, 0.0))
	var poses := OrganizacionDelDeposito.abrir(cajas, guardadas, _repisas())
	_afirmar_pose(poses, B, guardadas[B])
	_afirmar_pose(poses, Z, guardadas[Z])


func test_sin_poses_guardadas_cada_caja_abre_en_su_lugar() -> void:  # AC-STK-111 AC-STK-113
	var cajas := _cajas()
	var vacias: Dictionary[Producto.Id, Transform3D] = {}
	var poses := OrganizacionDelDeposito.abrir(cajas, vacias, _repisas())
	for caja in cajas:
		_afirmar_pose(poses, caja.producto, caja.fabrica)


func test_la_caja_ausente_abre_en_su_lugar_de_fabrica() -> void:  # AC-STK-113
	var cajas := _cajas()
	var ausente := OrganizacionDelDeposito.Caja.new(M, GRANDE, _en_estante(GRANDE, 3.2), false)
	cajas[5] = ausente
	var guardadas: Dictionary[Producto.Id, Transform3D] = {M: _en_el_piso(GRANDE, 0.0)}
	var poses := OrganizacionDelDeposito.abrir(cajas, guardadas, _repisas())
	_afirmar_pose(poses, M, ausente.fabrica)


func test_las_cajas_que_cerraron_afuera_abren_cada_una_en_un_hueco_libre() -> void:  # AC-STK-112
	var cajas := _cajas()
	var guardadas: Dictionary[Producto.Id, Transform3D] = _de_fabrica(cajas)
	guardadas[A] = _en_el_piso(CHICA, 0.0)
	guardadas[D] = Transform3D(Basis.IDENTITY, Vector3(1.0, 0.7, 3.0))
	guardadas[B] = Transform3D(Basis.IDENTITY, Vector3(2.0, 0.15 + CHICA, 3.0))
	guardadas[Z] = Transform3D(Basis.IDENTITY, Vector3(0.0, CHICA * 3.0, 3.0))
	var poses := OrganizacionDelDeposito.abrir(cajas, guardadas, _repisas())
	var lugares: Array[Vector3] = []
	for id: Producto.Id in [A, D, B, Z]:
		var lugar: Vector3 = poses[id].origin
		assert_float(lugar.y).is_equal_approx(ESTANTE + CHICA, 0.001)
		assert_float(lugar.z).is_equal_approx(0.0, 0.001)
		assert_array(lugares).not_contains([lugar])
		lugares.append(lugar)
	_sin_superposicion(poses, cajas)


func test_una_sola_caja_afuera_abre_en_un_hueco_y_las_demas_no_se_mueven() -> void:  # AC-STK-112
	var cajas := _cajas()
	var guardadas: Dictionary[Producto.Id, Transform3D] = _de_fabrica(cajas)
	guardadas[A] = _en_el_piso(CHICA, 0.0)
	var poses := OrganizacionDelDeposito.abrir(cajas, guardadas, _repisas())
	_afirmar_pose(poses, A, _en_estante(CHICA, 0.25))
	for id: Producto.Id in [D, B, Z, L, M]:
		_afirmar_pose(poses, id, _de_fabrica(cajas)[id])


func test_la_caja_grande_sin_hueco_abre_encima_de_otra() -> void:  # AC-STK-112
	var cajas := _cajas()
	cajas.pop_back()
	var guardadas: Dictionary[Producto.Id, Transform3D] = _de_fabrica(cajas)
	guardadas[L] = _en_el_piso(GRANDE, 0.0)
	guardadas[B] = _en_estante(CHICA, 2.5)
	var poses := OrganizacionDelDeposito.abrir(cajas, guardadas, _repisas())
	assert_float(poses[L].origin.y).is_equal_approx(ESTANTE + CHICA * 2.0 + GRANDE, 0.001)
	assert_bool(_esta_encima_de_otra(L, poses, cajas)).is_true()
	_sin_superposicion(poses, cajas)


func test_con_un_solo_hueco_una_abre_en_el_y_la_otra_encima() -> void:  # AC-STK-112
	var cajas := _cajas()
	var guardadas: Dictionary[Producto.Id, Transform3D] = _de_fabrica(cajas)
	guardadas[A] = _en_el_piso(CHICA, 0.0)
	guardadas[D] = _en_el_piso(CHICA, 1.0)
	guardadas[B] = _en_estante(CHICA, 0.5)
	var poses := OrganizacionDelDeposito.abrir(cajas, guardadas, _repisas())
	_afirmar_pose(poses, B, guardadas[B])
	_afirmar_pose(poses, A, _en_estante(CHICA, 1.25))
	assert_float(poses[D].origin.y).is_greater(ESTANTE + CHICA * 2.0 - 0.001)
	assert_bool(_esta_encima_de_otra(D, poses, cajas)).is_true()
	_sin_superposicion(poses, cajas)


func test_dos_cajas_en_el_mismo_lugar_no_se_superponen() -> void:  # AC-STK-112
	var cajas := _cajas()
	var guardadas: Dictionary[Producto.Id, Transform3D] = _de_fabrica(cajas)
	guardadas[D] = guardadas[A]
	var poses := OrganizacionDelDeposito.abrir(cajas, guardadas, _repisas())
	_afirmar_pose(poses, A, guardadas[A])
	_afirmar_pose(poses, D, _en_estante(CHICA, 0.75))
	_sin_superposicion(poses, cajas)


func test_la_pila_de_llegada_sin_ordenar_abre_en_las_estanterias() -> void:  # AC-STK-113
	var cajas := _cajas()
	var guardadas: Dictionary[Producto.Id, Transform3D] = _de_fabrica(cajas)
	guardadas[L] = _en_el_piso(GRANDE, 4.0)
	guardadas[M] = Transform3D(Basis.IDENTITY, Vector3(4.0, GRANDE * 3.0, 3.0))
	var poses := OrganizacionDelDeposito.abrir(cajas, guardadas, _repisas())
	for id: Producto.Id in [L, M]:
		assert_float(poses[id].origin.y).is_equal_approx(ESTANTE + GRANDE, 0.001)
		assert_float(poses[id].origin.z).is_equal_approx(0.0, 0.001)
	_sin_superposicion(poses, cajas)


func test_las_cajas_fijas_conservan_su_pose_y_nadie_las_pisa() -> void:  # AC-STK-077
	var cajas := _cajas()
	var guardadas: Dictionary[Producto.Id, Transform3D] = _de_fabrica(cajas)
	guardadas[D] = _en_el_piso(CHICA, 0.0)
	var fijas: Dictionary[Producto.Id, Transform3D] = {A: _en_estante(CHICA, 0.75)}
	var poses := OrganizacionDelDeposito.abrir(cajas, guardadas, _repisas(), fijas)
	_afirmar_pose(poses, A, fijas[A])
	_afirmar_pose(poses, D, _en_estante(CHICA, 0.25))
	_sin_superposicion(poses, cajas)
