extends GdUnitTestSuite

const ALMACEN := "res://src/escenas/almacen.tscn"
const AperturaConLugar := preload("res://test/escenas/apertura_con_lugar.gd")


func test_los_huecos_dibujados_son_exactamente_los_casilleros_vacios() -> void:
	var almacen: Node3D = auto_free((load(ALMACEN) as PackedScene).instantiate())
	add_child(almacen)
	almacen.get("_jugador").set_physics_process(false)
	var puesto: Node3D = almacen.get("_reposicion_manual")
	for producto in Catalogo.todos():
		assert_bool(puesto.has_node("HuecosDe" + producto.nombre)).is_true()
		if not puesto.has_node("HuecosDe" + producto.nombre):
			return
		_afirma_huecos(almacen, producto)


func test_agarrar_y_reponer_cambia_el_hueco_sin_cambiar_el_foco() -> void:
	var almacen: Node3D = auto_free((load(ALMACEN) as PackedScene).instantiate())
	add_child(almacen)
	almacen.get("_jugador").set_physics_process(false)
	var completos: Dictionary[Producto.Id, int] = {}
	AperturaConLugar.abrir_con_faltantes(almacen, completos)
	var puesto: Node3D = almacen.get("_reposicion_manual")
	var producto := Catalogo.de(Producto.Id.MAROLINI)
	assert_bool(puesto.has_node("HuecosDe" + producto.nombre)).is_true()
	if not puesto.has_node("HuecosDe" + producto.nombre):
		return
	var zona: Node3D = puesto.call("casillero", producto.id, 1)
	puesto.call("_al_enfocar", zona, 0.5)
	var vista: MeshInstance3D = zona.get("vista")
	assert_bool(vista.visible).is_true()
	var contorno := vista.material_overlay
	_afirma_huecos(almacen, producto)
	puesto.call("agarrar_de_la_gondola", producto.id, 1)
	_afirma_huecos(almacen, producto)
	assert_bool(vista.visible).is_true()
	assert_object(vista.material_overlay).is_same(contorno)
	puesto.call("pedir_colocar", producto.id, 1)
	_afirma_huecos(almacen, producto)
	assert_bool(vista.visible).is_true()
	assert_object(vista.material_overlay).is_same(contorno)
	puesto.call("_al_perder_el_foco")
	assert_bool(vista.visible).is_false()
	_afirma_huecos(almacen, producto)


func test_abrir_otra_jornada_reconstruye_los_huecos() -> void:
	var almacen: Node3D = auto_free((load(ALMACEN) as PackedScene).instantiate())
	add_child(almacen)
	almacen.get("_jugador").set_physics_process(false)
	var producto := Catalogo.de(Producto.Id.ACTRONCITO)
	var puesto: Node3D = almacen.get("_reposicion_manual")
	assert_bool(puesto.has_node("HuecosDe" + producto.nombre)).is_true()
	if not puesto.has_node("HuecosDe" + producto.nombre):
		return
	for cantidad: int in [0, 3, 1]:
		var faltantes: Dictionary[Producto.Id, int] = {producto.id: cantidad}
		AperturaConLugar.abrir_con_faltantes(almacen, faltantes)
		_afirma_huecos(almacen, producto)


func _afirma_huecos(almacen: Node3D, producto: Producto) -> void:
	var puesto: Node3D = almacen.get("_reposicion_manual")
	var estante := (almacen.get("_repositor") as Repositor).estante()
	var vacios := estante.casilleros_vacios(producto)
	var grupo: MultiMeshInstance3D = puesto.get_node("HuecosDe" + producto.nombre)
	assert_bool(grupo.is_physics_interpolated()).is_false()
	assert_int(grupo.multimesh.visible_instance_count).is_equal(vacios.size())
	assert_int(grupo.multimesh.instance_count).is_equal(estante.cupo(producto))
	var buffer := grupo.multimesh.buffer
	assert_int(buffer.size()).is_equal(
		estante.cupo(producto) * DisposicionDeLaGondola.FLOTANTES_POR_COPIA
	)
	for indice in vacios.size():
		var zona: Node3D = puesto.call("casillero", producto.id, vacios[indice])
		var esperado: Transform3D = puesto.call("_copia_del_casillero", producto.id, vacios[indice])
		var dibujado := DisposicionDeLaGondola.copia(buffer, indice)
		assert_bool(dibujado.is_equal_approx(esperado)).is_true()
		assert_int(zona.get("papel")).is_not_equal(2)
