extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")


func test_al_abrir_cada_heladera_su_canto_sigue_unido_al_mueble() -> void:
	var local: Node3D = auto_free(ALMACEN.instantiate())
	add_child(local)
	await get_tree().physics_frame
	var hojas: Array[MeshInstance3D] = []
	var cantos: Array[Vector3] = []
	var antes: Array[Vector3] = []
	for puerta: Node3D in local.get("_puertas"):
		var hoja: MeshInstance3D = puerta.get("hoja")
		if not str(hoja.name).begins_with("puerta_heladera_"):
			continue
		var caja := hoja.get_aabb()
		# El herraje está en el borde opuesto a la manija, sobre el dorso del marco.
		var canto := Vector3(caja.end.x, caja.get_center().y, caja.position.z)
		hojas.append(hoja)
		cantos.append(canto)
		antes.append(hoja.to_global(canto))
		# La tercera heladera está trabada en juego; acá se prueba su montaje móvil.
		puerta.set("traba", 0)
		puerta.call("usar")
	assert_int(hojas.size()).is_equal(3)
	for cuadro: int in 120:
		await get_tree().physics_frame
	for i: int in hojas.size():
		assert_float(hojas[i].to_global(cantos[i]).distance_to(antes[i])).is_less(0.001)
		var puerta: Puerta = hojas[i].get_node("CuerpoDeLaHoja").call("puerta")
		assert_float(puerta.angulo()).is_equal(Puerta.ANGULO_ABIERTA)
