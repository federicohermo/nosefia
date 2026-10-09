## BORRADOR EXTERNO: no aplicado ni ejecutado. IDs AC pendientes de reserva de B.
## Destino propuesto: test/escenas/puestos/habitaciones_del_almacen_test.gd.
## Estas cajas sinteticas prueban conversion de coordenadas; no fijan el arte del almacen.
extends GdUnitTestSuite

const Habitaciones := preload("res://src/escenas/puestos/habitaciones_del_almacen.gd")
const ReglasDelCierre := preload("res://src/dominio/almacen/reglas_del_cierre.gd")


func test_clasifica_las_tres_habitaciones_con_lector_trasladado() -> void:
	var padre := auto_free(Node3D.new()) as Node3D
	get_tree().root.add_child(padre)
	var lector := _lector(padre)
	lector.position = Vector3(12, 4, -8)
	_afirmar_centros(lector)


func test_la_envolvente_mundial_no_agranda_una_habitacion_rotada() -> void:
	var padre := auto_free(Node3D.new()) as Node3D
	get_tree().root.add_child(padre)
	var lector := _lector(padre)
	lector.position = Vector3(12, 4, -8)
	lector.rotation.y = deg_to_rad(45)
	_afirmar_centros(lector)
	_afirmar_afuera_de_caja_rotada(lector)


func test_compone_traslacion_y_rotacion_de_un_padre_real() -> void:
	var padre := auto_free(Node3D.new()) as Node3D
	padre.position = Vector3(19, 7, -13)
	padre.rotation.y = deg_to_rad(45)
	get_tree().root.add_child(padre)
	var lector := _lector(padre)
	lector.position = Vector3(3, 2, -4)
	# La vuelta local y la heredada son distintas: el resultado mundial gira -45 grados.
	lector.rotation.y = deg_to_rad(-90)
	_afirmar_centros(lector)
	_afirmar_afuera_de_caja_rotada(lector)


func _lector(padre: Node3D) -> Habitaciones:
	var lector := Habitaciones.new()
	lector.local = AABB(Vector3.ZERO, Vector3(1, 2, 1))
	lector.deposito = AABB(Vector3(3, 0, 0), Vector3(1, 2, 1))
	lector.bano = AABB(Vector3(0, 0, 3), Vector3(1, 2, 1))
	padre.add_child(lector)
	return lector


func _afirmar_centros(lector: Habitaciones) -> void:
	assert_bool(lector.is_inside_tree()).is_true()
	assert_int(lector.de(lector.to_global(lector.local.get_center()))).is_equal(
		ReglasDelCierre.Habitacion.LOCAL
	)
	assert_int(lector.de(lector.to_global(lector.deposito.get_center()))).is_equal(
		ReglasDelCierre.Habitacion.DEPOSITO
	)
	assert_int(lector.de(lector.to_global(lector.bano.get_center()))).is_equal(
		ReglasDelCierre.Habitacion.BANO
	)


func _afirmar_afuera_de_caja_rotada(lector: Habitaciones) -> void:
	var punto_local := Vector3(-0.25, 1, 0.5)
	var punto_mundial := lector.to_global(punto_local)
	var envolvente_mundial: AABB = lector.global_transform * lector.local
	# Primero prueban la premisa que distingue to_local de una envolvente agrandada.
	assert_bool(lector.local.has_point(punto_local)).is_false()
	assert_bool(lector.deposito.has_point(punto_local)).is_false()
	assert_bool(lector.bano.has_point(punto_local)).is_false()
	assert_bool(envolvente_mundial.has_point(punto_mundial)).is_true()
	assert_vector(lector.to_local(punto_mundial)).is_equal_approx(
		punto_local, Vector3.ONE * 0.00001
	)
	assert_int(lector.de(punto_mundial)).is_equal(ReglasDelCierre.Habitacion.AFUERA)
