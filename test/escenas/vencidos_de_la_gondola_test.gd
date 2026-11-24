extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const AperturaConLugar := preload("res://test/escenas/apertura_con_lugar.gd")


func test_el_cindolor_vencido_de_la_gondola_lee_su_celda_del_atlas() -> void:
	# El vencido viaja con su propia textura, que es una celda del atlas: su material lleva la
	# escala y el desplazamiento que la recorren. Un dibujo que los pierde muestra otra zona de la
	# textura, estirada, en vez del frente de la caja.
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	AperturaConLugar.abrir_con_semilla(almacen)
	var puesto: Node3D = almacen.get("_reposicion_manual")
	var dibujo: MultiMeshInstance3D = puesto.get_node("VencidosDeCindolor")
	var modelo := load("res://assets/models/producto_cindolor_vencido.res") as ArrayMesh
	assert_int(dibujo.multimesh.mesh.get_surface_count()).is_equal(modelo.get_surface_count())
	for superficie in modelo.get_surface_count():
		var original := modelo.surface_get_material(superficie) as BaseMaterial3D
		var dibujado := dibujo.multimesh.mesh.surface_get_material(superficie) as ShaderMaterial
		assert_vector(original.uv1_scale).is_not_equal(Vector3.ONE)
		assert_vector(dibujado.get_shader_parameter("escala_uv")).is_equal(original.uv1_scale)
		assert_vector(dibujado.get_shader_parameter("desplazamiento_uv")).is_equal(
			original.uv1_offset
		)
