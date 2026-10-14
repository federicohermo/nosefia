extends GdUnitTestSuite

const PilaDelDeposito := preload("res://src/escenas/puestos/pila_del_deposito.gd")
const CAJA := preload("res://src/escenas/objetos/caja_de_productos.tscn")


func test_con_un_frente_las_etiquetas_miran_al_lado_del_pallet_mas_cercano() -> void:
	var cajas: Array[Node3D] = []
	for indice in 6:
		var caja: Node3D = auto_free(CAJA.instantiate())
		cajas.append(caja)
	var pallets: Array[MeshInstance3D] = []
	for giro: float in [0.0, PI / 2.0]:
		var pallet: MeshInstance3D = auto_free(MeshInstance3D.new())
		pallet.mesh = BoxMesh.new()
		pallet.rotation.y = giro
		add_child(pallet)
		pallets.append(pallet)
	# Casi +X: con pallets derechos o girados un cuarto, la etiqueta queda en +X justo.
	var frente := Vector3(1, 0, 0.2).normalized()
	var poses := PilaDelDeposito.poses(cajas, pallets, frente)
	for caja in cajas:
		var etiqueta := poses[caja].basis.x
		assert_vector(etiqueta).is_equal_approx(Vector3.RIGHT, Vector3.ONE * 1e-5)


func test_sin_frente_cada_caja_toma_el_giro_de_su_pallet() -> void:
	var cajas: Array[Node3D] = [auto_free(CAJA.instantiate())]
	var pallet: MeshInstance3D = auto_free(MeshInstance3D.new())
	pallet.mesh = BoxMesh.new()
	pallet.rotation.y = 0.7
	add_child(pallet)
	var poses := PilaDelDeposito.poses(cajas, [pallet])
	assert_vector(poses[cajas[0]].basis.x).is_equal_approx(
		Basis(Vector3.UP, 0.7).x, Vector3.ONE * 1e-5
	)
