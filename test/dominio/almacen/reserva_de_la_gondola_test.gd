## Una unidad puede estar fuera del metal y ocupar el espacio reservado a la mercadería.
extends GdUnitTestSuite

const Reserva := preload("res://src/dominio/almacen/reserva_de_la_gondola.gd")
const MUEBLE := AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))
const UNIDAD := AABB(Vector3(-0.1, -0.1, -0.1), Vector3(0.2, 0.2, 0.2))


func test_el_hueco_reservado_no_admite_una_unidad_aunque_no_haya_metal() -> void:  # AC-PLY-018
	(
		assert_bool(
			Reserva.se_superponen(UNIDAD, Transform3D.IDENTITY, MUEBLE, Transform3D.IDENTITY)
		)
		. is_true()
	)


func test_una_esquina_adentro_cuenta_aunque_el_centro_este_afuera() -> void:  # AC-PLY-018
	var pose := Transform3D(Basis.IDENTITY, Vector3(1.05, 0, 0))
	assert_bool(MUEBLE.has_point(pose.origin)).is_false()
	assert_bool(Reserva.se_superponen(UNIDAD, pose, MUEBLE, Transform3D.IDENTITY)).is_true()


func test_la_unidad_oblicua_exterior_no_ocupa_la_esquina_de_su_aabb_global() -> void:  # AC-PLY-018
	var unidad := AABB(Vector3(-0.6, -0.2, -0.1), Vector3(1.2, 0.4, 0.2))
	var pose := Transform3D(Basis(Vector3.UP, PI / 4.0), Vector3(1.4, 0, 1.4))
	assert_bool((pose * unidad).intersects(MUEBLE)).is_true()
	assert_bool(Reserva.se_superponen(unidad, pose, MUEBLE, Transform3D.IDENTITY)).is_false()


func test_la_reserva_conserva_la_escala_y_la_vuelta_del_mueble() -> void:  # AC-PLY-018
	var marco := Transform3D(
		Basis(Vector3.UP, PI / 3.0).scaled(Vector3(2, 1, 0.5)), Vector3(8, 2, -5)
	)
	var pose := marco * Transform3D(Basis.IDENTITY, Vector3(0.95, 0, 0))
	assert_bool(Reserva.se_superponen(UNIDAD, pose, MUEBLE, marco)).is_true()
	pose.origin = marco * Vector3(1.2, 0, 0)
	assert_bool(Reserva.se_superponen(UNIDAD, pose, MUEBLE, marco)).is_false()


func test_el_contacto_exterior_sin_volumen_comun_no_invade_la_reserva() -> void:  # AC-PLY-018
	var pose := Transform3D(Basis.IDENTITY, Vector3(1.1, 0, 0))
	assert_bool(Reserva.se_superponen(UNIDAD, pose, MUEBLE, Transform3D.IDENTITY)).is_false()


func test_un_volumen_vacio_no_ocupa_una_reserva() -> void:
	(
		assert_bool(
			Reserva.se_superponen(AABB(), Transform3D.IDENTITY, MUEBLE, Transform3D.IDENTITY)
		)
		. is_false()
	)


func test_escalar_ambos_volumenes_no_cambia_si_hay_superposicion() -> void:  # AC-PLY-018
	for escala: float in [0.00001, 1.0, 100000.0]:
		var base := Basis.IDENTITY.scaled(Vector3.ONE * escala)
		var marco := Transform3D(base, Vector3.ZERO)
		var afuera := Transform3D(base, Vector3(1.2 * escala, 0, 0))
		var adentro := Transform3D(base, Vector3(0.95 * escala, 0, 0))
		assert_bool(Reserva.se_superponen(UNIDAD, afuera, MUEBLE, marco)).is_false()
		assert_bool(Reserva.se_superponen(UNIDAD, adentro, MUEBLE, marco)).is_true()
