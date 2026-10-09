extends GdUnitTestSuite

const NotaDelLocal := preload("res://src/escenas/objetos/nota_pegada.gd")
const MODELO := preload("res://assets/models/SEPT_JUEGOS_PROTOTIPO.glb")


func test_el_texto_fisico_y_la_vista_presentan_el_mismo_dato() -> void:  # AC-PLY-068, AC-PLY-069
	var cuerpo: NotaDelLocal = auto_free(NotaDelLocal.new())
	cuerpo.id = NotaPegada.Id.TAREAS_A_REALIZAR
	cuerpo.titulo_del_papel = auto_free(Label3D.new())
	cuerpo.renglones_del_papel = auto_free(Label3D.new())
	var dato := NotaPegada.tareas_a_realizar(
		[Tarea.new(Tarea.Tipo.SACAR_LA_BASURA), Tarea.new(Tarea.Tipo.LIMPIAR)]
	)
	cuerpo.declarar(dato)
	assert_object(cuerpo.dato()).is_same(dato)
	assert_str(cuerpo.titulo_del_papel.text).is_equal(dato.titulo())
	assert_str(cuerpo.renglones_del_papel.text).is_equal("1. Limpieza\n2. Sacar la basura")
	assert_str(cuerpo.renglones_del_papel.text).is_equal(NotaEncuadrada.texto_de_renglones(dato))
	assert_object(cuerpo.imagen()).is_null()


func test_las_tres_imagenes_vienen_del_frente_original() -> void:  # AC-PLY-070
	var modelo: Node3D = auto_free(MODELO.instantiate())
	var rutas: Array[String] = ["nota productos", "nota instrucciones", "nota baño inodoro"]
	var ids: Array[NotaPegada.Id] = [
		NotaPegada.Id.JABONES_Y_MANCHAS,
		NotaPegada.Id.INSTRUCCIONES_DE_LIMPIEZA,
		NotaPegada.Id.NO_TIRAR_PAPEL,
	]
	for indice in rutas.size():
		var hoja: MeshInstance3D = modelo.get_node(rutas[indice])
		var cuerpo: NotaDelLocal = auto_free(NotaDelLocal.new())
		cuerpo.id = ids[indice]
		cuerpo.mallas = [hoja]
		cuerpo.declarar(NotaPegada.de(ids[indice]))
		var original := hoja.get_active_material(1) as BaseMaterial3D
		assert_object(original.albedo_texture).is_not_null()
		assert_object(cuerpo.imagen()).is_same(original.albedo_texture)
		assert_array(cuerpo.dato().renglones()).is_empty()


func test_accionar_pide_la_lectura_de_su_hoja() -> void:  # AC-PLY-063
	var cuerpo: NotaDelLocal = auto_free(NotaDelLocal.new())
	var pedidos: Array[bool] = []
	cuerpo.apertura_pedida.connect(func() -> void: pedidos.append(true))
	cuerpo.accionar()
	assert_array(pedidos).contains_exactly([true])
