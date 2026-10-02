extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const AperturaConLugar := preload("res://test/escenas/apertura_con_lugar.gd")


func test_sacar_y_colocar_no_interpola_las_otras_copias_entre_casilleros() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	almacen.get("_jugador").set_physics_process(false)
	var faltantes: Dictionary[Producto.Id, int] = {}
	AperturaConLugar.abrir_con_faltantes(almacen, faltantes)
	var puesto: Node3D = almacen.get("_reposicion_manual")
	for producto in Catalogo.todos():
		var grupo: MultiMeshInstance3D = puesto.get_node("ProductosDe" + producto.nombre)
		var antes := grupo.multimesh.buffer
		var visibles := grupo.multimesh.visible_instance_count
		assert_int(visibles).is_greater(2)
		puesto.call("agarrar_de_la_gondola", producto.id, 1)
		assert_int(grupo.multimesh.visible_instance_count).is_equal(visibles - 1)
		# El buffer compacta las copias, pero esos índices no identifican al mismo casillero.
		# Interpolarlos hace viajar los envases restantes durante un cuadro, aunque los datos
		# finales sean correctos. El renderer es quien interpola, fuera del estado del script.
		assert_bool(grupo.is_physics_interpolated()).is_false()
		puesto.call("pedir_colocar", producto.id, 1)
		assert_bool(grupo.multimesh.buffer == antes).is_true()
		assert_int(grupo.multimesh.visible_instance_count).is_equal(visibles)
		assert_bool(grupo.is_physics_interpolated()).is_false()


func test_pasarse_por_los_productos_no_reemplaza_ni_reordena_sus_superficies() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	almacen.get("_jugador").set_physics_process(false)
	var faltantes: Dictionary[Producto.Id, int] = {}
	AperturaConLugar.abrir_con_faltantes(almacen, faltantes)
	var puesto: Node3D = almacen.get("_reposicion_manual")
	for producto in Catalogo.todos():
		var grupo: MultiMeshInstance3D = puesto.get_node("ProductosDe" + producto.nombre)
		var copias := grupo.multimesh
		var antes := copias.buffer
		var visibles := copias.visible_instance_count
		var zonas: Array[Node] = puesto.get_node("ZonaDe" + producto.nombre).get_children()
		assert_int(zonas.size()).is_greater(0)
		for zona in zonas:
			assert_int(zona.get("papel")).is_equal(2)
			puesto.call("_al_enfocar", zona, 0.5)
			var vista: MeshInstance3D = zona.get("vista")
			assert_bool(vista.visible).is_true()
			assert_object(vista.material_override).is_same(zona.get("sin_superficie"))
			assert_bool(copias.buffer == antes).is_true()
			assert_int(copias.visible_instance_count).is_equal(visibles)
			puesto.call("_al_perder_el_foco")
			assert_bool(vista.visible).is_false()
			assert_bool(copias.buffer == antes).is_true()


func test_la_mira_no_atrae_un_producto_fuera_de_su_tolerancia() -> void:  # AC-PLY-004
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	jugador.set_process(false)
	var faltantes: Dictionary[Producto.Id, int] = {}
	AperturaConLugar.abrir_con_faltantes(almacen, faltantes)
	var puesto: Node3D = almacen.get("_reposicion_manual")
	puesto.set_physics_process(false)
	var producto := Catalogo.de(Producto.Id.ARVEJAS)
	var zona: Node3D = puesto.get_node("ZonaDe" + producto.nombre).get_child(0)
	var disposicion: DisposicionDeLaGondola = puesto.get("disposicion")
	var frente := DisposicionDeLaGondola.frente(
		disposicion.principales[producto.id], disposicion.filas_de_adelante[producto.id]
	)
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	camara.global_position = zona.global_position + frente * 0.9 + Vector3.UP * 0.15
	camara.look_at(zona.global_position)
	puesto.call("_ofrecer_a_la_mira")
	for cuadro in 4:
		await get_tree().physics_frame
	var centrado: CampoDeInteraccion.Candidato = jugador.call("_medir_candidato", zona)
	assert_bool(centrado.visible).is_true()
	assert_bool(centrado.es_producto).is_true()
	assert_int(CampoDeInteraccion.elegir([centrado])).is_equal(zona.get_instance_id())
	camara.rotate_object_local(Vector3.UP, deg_to_rad(12.0))
	var apartado: CampoDeInteraccion.Candidato = jugador.call("_medir_candidato", zona)
	assert_bool(apartado.visible).is_true()
	assert_float(apartado.desvio).is_greater(ReglasDelJugador.DESVIO_MAXIMO_DE_PRODUCTOS)
	assert_float(apartado.desvio).is_less(ReglasDelJugador.DESVIO_MAXIMO_DE_LA_MIRA)
	assert_int(CampoDeInteraccion.elegir([apartado])).is_equal(Foco.SIN_OBJETIVO)


func test_el_producto_suelto_se_enfoca_con_las_aristas_de_los_casilleros() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	almacen.get("_jugador").set_physics_process(false)
	var faltantes: Dictionary[Producto.Id, int] = {}
	AperturaConLugar.abrir_con_faltantes(almacen, faltantes)
	var puesto: Node3D = almacen.get("_reposicion_manual")
	var producto := Catalogo.de(Producto.Id.ARVEJAS)
	puesto.call("agarrar_de_la_gondola", producto.id, 1)
	var unidades: Array[Node3D] = puesto.get("_unidades")
	assert_int(unidades.size()).is_equal(1)
	var zona: MeshInstance3D = puesto.get_node("ZonaDe" + producto.nombre).get_child(0).get("vista")
	var aristas := unidades[0].get("material_de_foco") as ShaderMaterial
	assert_object(aristas).is_same(zona.material_overlay)
	assert_float(aristas.get_shader_parameter("grosor")).is_equal(
		IndicacionDelFoco.GROSOR_DE_PRODUCTOS
	)
