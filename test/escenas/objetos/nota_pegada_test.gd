extends GdUnitTestSuite

const NotaDelLocal := preload("res://src/escenas/objetos/nota_pegada.gd")
const MODELO := preload("res://assets/models/SEPT_JUEGOS_PROTOTIPO.glb")


func test_el_texto_fisico_y_la_vista_presentan_el_mismo_dato() -> void:  # AC-PLY-068, AC-PLY-069
	var cuerpo: NotaDelLocal = auto_free(NotaDelLocal.new())
	cuerpo.id = NotaPegada.Id.TAREAS_A_REALIZAR
	cuerpo.titulo_del_papel = auto_free(Label3D.new())
	cuerpo.renglones_del_papel = auto_free(Label3D.new())
	cuerpo.renglones_del_papel.font = ThemeDB.fallback_font
	var dato := NotaPegada.tareas_a_realizar(
		[Tarea.new(Tarea.Tipo.SACAR_LA_BASURA), Tarea.new(Tarea.Tipo.LIMPIAR)]
	)
	cuerpo.declarar(dato)
	assert_object(cuerpo.dato()).is_same(dato)
	assert_str(cuerpo.titulo_del_papel.text).is_equal(dato.titulo())
	assert_str(cuerpo.renglones_del_papel.text).is_equal("1. Limpieza\n2. Tirar la basura")
	assert_str(cuerpo.renglones_del_papel.text).is_equal(NotaEncuadrada.texto_de_renglones(dato))
	assert_object(cuerpo.imagen()).is_null()


func test_las_cuatro_imagenes_vienen_del_frente_original() -> void:  # AC-PLY-070
	var modelo: Node3D = auto_free(MODELO.instantiate())
	var rutas: Array[String] = [
		"nota productos", "nota instrucciones", "nota baño inodoro", "nota baño inodoro 2"
	]
	var ids: Array[NotaPegada.Id] = [
		NotaPegada.Id.JABONES_Y_MANCHAS,
		NotaPegada.Id.INSTRUCCIONES_DE_LIMPIEZA,
		NotaPegada.Id.NO_TIRAR_PAPEL,
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


func _hoja_de_tareas(obligatorias: Array[Tarea]) -> NotaDelLocal:
	var cuerpo: NotaDelLocal = auto_free(NotaDelLocal.new())
	cuerpo.id = NotaPegada.Id.TAREAS_A_REALIZAR
	cuerpo.renglones_del_papel = Label3D.new()
	cuerpo.renglones_del_papel.font = ThemeDB.fallback_font
	cuerpo.add_child(cuerpo.renglones_del_papel)
	cuerpo.titulo_del_papel = auto_free(Label3D.new())
	cuerpo.declarar(NotaPegada.tareas_a_realizar(obligatorias))
	return cuerpo


func test_la_hoja_pegada_marca_la_tarea_cumplida_y_lo_pierde() -> void:  # AC-PLY-165
	var limpiar := Tarea.new(Tarea.Tipo.LIMPIAR)
	var basura := Tarea.new(Tarea.Tipo.SACAR_LA_BASURA)
	var obligatorias: Array[Tarea] = [limpiar, basura]
	var cuerpo := _hoja_de_tareas(obligatorias)
	assert_array(cuerpo.filas_con_tick()).is_empty()
	var texto := cuerpo.renglones_del_papel.text
	basura.completar()
	cuerpo.declarar(NotaPegada.tareas_a_realizar(obligatorias))
	assert_array(cuerpo.filas_con_tick()).contains_exactly([1])
	assert_str(cuerpo.renglones_del_papel.text).is_equal(texto)
	basura.descompletar()
	cuerpo.declarar(NotaPegada.tareas_a_realizar(obligatorias))
	assert_array(cuerpo.filas_con_tick()).is_empty()


func test_el_tick_pegado_es_rojo_a_la_izquierda_y_del_alto_del_renglon() -> void:  # AC-PLY-165
	var obligatorias := Apertura.obligatorias(ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA)
	obligatorias[1].completar()
	var cuerpo := _hoja_de_tareas(obligatorias)
	var papel := cuerpo.renglones_del_papel
	var tick: Sprite3D = cuerpo.ticks_visibles()[0]
	var alto := papel.font.get_height(papel.font_size) * papel.pixel_size
	assert_float(tick.texture.get_height() * tick.pixel_size).is_equal_approx(alto, 0.0001)
	assert_float(-tick.position.y).is_equal_approx(1.5 * alto, 0.0001)
	assert_float(tick.position.x + tick.texture.get_width() * tick.pixel_size / 2.0).is_less(0.0)
	assert_bool(tick.modulate == NotaEncuadrada.COLOR_DEL_TICK).is_true()
