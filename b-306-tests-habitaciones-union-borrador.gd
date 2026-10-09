## BORRADOR EXTERNO UNION: no aplicado ni ejecutado. IDs AC pendientes de reserva de B.
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


func test_la_union_compuesta_conserva_techo_y_ancho_del_paso_bajo_un_padre() -> void:
	var padre := auto_free(Node3D.new()) as Node3D
	padre.position = Vector3(19, 7, -13)
	padre.rotation.y = deg_to_rad(45)
	get_tree().root.add_child(padre)
	var lector := _lector(padre)
	lector.position = Vector3(3, 2, -4)
	lector.local.assign([AABB(Vector3(5, 0, 0), Vector3(1, 2, 1))])
	lector.deposito.assign([AABB(Vector3(7, 0, 0), Vector3(1, 2, 1))])
	(
		lector
		. bano
		. assign(
			[
				AABB(Vector3.ZERO, Vector3(2, 2, 2)),
				AABB(Vector3(0, 0, 2), Vector3(2, 4, 2)),
				AABB(Vector3(2, 0, 2.75), Vector3(1, 2, 0.5)),
				AABB(Vector3(-3, 0, 0), Vector3(1, 2, 1)),
			]
		)
	)
	var envolvente := lector.bano[0]
	for parte: AABB in lector.bano:
		envolvente = envolvente.merge(parte)
		assert_bool(parte.has_point(parte.get_center())).is_true()
		assert_int(lector.de(lector.to_global(parte.get_center()))).is_equal(
			ReglasDelCierre.Habitacion.BANO
		)
	# Sobre techo bajo, al costado del paso y en hueco entre partes disjuntas.
	for afuera: Vector3 in [Vector3(1, 3, 1), Vector3(2.5, 1, 2.5), Vector3(-1, 1, 0.5)]:
		for parte: AABB in lector.bano:
			assert_bool(parte.has_point(afuera)).is_false()
		assert_bool(lector.local[0].has_point(afuera)).is_false()
		assert_bool(lector.deposito[0].has_point(afuera)).is_false()
		assert_bool(envolvente.has_point(afuera)).is_true()
		var punto_mundial := lector.to_global(afuera)
		var envolvente_mundial: AABB = lector.global_transform * envolvente
		assert_bool(envolvente_mundial.has_point(punto_mundial)).is_true()
		assert_vector(lector.to_local(punto_mundial)).is_equal_approx(afuera, Vector3.ONE * 0.00001)
		assert_int(lector.de(punto_mundial)).is_equal(ReglasDelCierre.Habitacion.AFUERA)


func _lector(padre: Node3D) -> Habitaciones:
	var lector := Habitaciones.new()
	lector.local.assign([AABB(Vector3.ZERO, Vector3(1, 2, 1))])
	lector.deposito.assign([AABB(Vector3(3, 0, 0), Vector3(1, 2, 1))])
	lector.bano.assign([AABB(Vector3(0, 0, 3), Vector3(1, 2, 1))])
	padre.add_child(lector)
	return lector


func _afirmar_centros(lector: Habitaciones) -> void:
	assert_bool(lector.is_inside_tree()).is_true()
	assert_int(lector.de(lector.to_global(lector.local[0].get_center()))).is_equal(
		ReglasDelCierre.Habitacion.LOCAL
	)
	assert_int(lector.de(lector.to_global(lector.deposito[0].get_center()))).is_equal(
		ReglasDelCierre.Habitacion.DEPOSITO
	)
	assert_int(lector.de(lector.to_global(lector.bano[0].get_center()))).is_equal(
		ReglasDelCierre.Habitacion.BANO
	)


func _afirmar_afuera_de_caja_rotada(lector: Habitaciones) -> void:
	var punto_local := Vector3(-0.25, 1, 0.5)
	var punto_mundial := lector.to_global(punto_local)
	var envolvente_mundial: AABB = lector.global_transform * lector.local[0]
	# Primero prueban la premisa que distingue to_local de una envolvente agrandada.
	assert_bool(lector.local[0].has_point(punto_local)).is_false()
	assert_bool(lector.deposito[0].has_point(punto_local)).is_false()
	assert_bool(lector.bano[0].has_point(punto_local)).is_false()
	assert_bool(envolvente_mundial.has_point(punto_mundial)).is_true()
	assert_vector(lector.to_local(punto_mundial)).is_equal_approx(
		punto_local, Vector3.ONE * 0.00001
	)
	assert_int(lector.de(punto_mundial)).is_equal(ReglasDelCierre.Habitacion.AFUERA)
