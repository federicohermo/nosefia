extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")

var _almacenes: Array[Node3D] = []


func after_test() -> void:
	get_tree().paused = false
	for almacen in _almacenes:
		almacen.get_node("Servicios/AudioDelAlmacen/Reproductor").silenciar()
		almacen.queue_free()
	_almacenes.clear()
	for _cuadro in 4:
		await get_tree().process_frame


func _panel() -> PanelDeLaVentanilla:
	# La animación se ejerce sobre la interfaz cableada del juego y su modo real de pausa.
	var almacen: Node3D = ALMACEN.instantiate()
	almacen.set("_partida", Partida.nueva())
	_almacenes.append(almacen)
	add_child(almacen)
	almacen.get_node("Jugador").set_physics_process(false)
	almacen.get_node("Servicios/RelojDelTurno").set_process(false)
	return almacen.get_node("Estructura/Ventanilla").get("panel")


func test_ambas_animaciones_conservan_ocho_png_ordenados_y_exposiciones() -> void:  # AC-CTR-042
	for nombre: String in ["martin", "tiago"]:
		var frames: SpriteFrames = load("res://assets/characters/%s/idle.tres" % nombre)
		assert_int(frames.get_frame_count(&"idle")).is_equal(8)
		assert_bool(frames.get_animation_loop(&"idle")).is_true()
		assert_float(frames.get_animation_speed(&"idle")).is_equal(2.0)
		for indice in 8:
			var textura := frames.get_frame_texture(&"idle", indice)
			assert_str(textura.resource_path).ends_with("/%02d.png" % (indice + 1))
			assert_that(textura.get_size()).is_equal(Vector2(1086, 1448))
			assert_bool(textura.get_image().detect_alpha() != Image.ALPHA_NONE).is_true()
			assert_float(frames.get_frame_duration(&"idle", indice)).is_equal(1.0)


# AC-CTR-036, AC-PLY-079
func test_muestra_ambos_compradores_dialogo_y_clic_izquierdo_sin_botones() -> void:
	var panel := _panel()
	assert_object(panel.get_node_or_null("Fisico/Comprador")).is_null()
	var sprite := _almacenes.back().get_node("Estructura/Ventanilla/Comprador") as AnimatedSprite3D
	assert_object(sprite).is_not_null()
	if sprite == null:
		return
	var clicks: Array[bool] = []
	panel.comprador_pulsado.connect(func() -> void: clicks.append(true))
	for intervalo: float in [120.0, 360.0]:
		var almacen: Node3D = _almacenes.back()
		(almacen.get("_reloj") as RelojDelTurno).avanzar(intervalo)
		var atencion: Atencion = almacen.get("_atenciones").atencion()
		var comprador := atencion.comprador()
		atencion.interactuar(null)
		panel.mostrar(atencion)
		assert_bool(sprite.is_visible_in_tree()).is_true()
		assert_str(sprite.sprite_frames.resource_path).contains(
			"martin" if comprador.personaje == DialogosDeCompradores.Personaje.MARTIN else "tiago"
		)
		var texto := panel.get_node("Fisico/Dialogo/Texto") as RichTextLabel
		assert_str(texto.text).is_equal(atencion.dialogo().entrada_actual())
		assert_bool(texto.bbcode_enabled).is_true()
		assert_bool((panel.get("_cobrar") as Button).is_visible_in_tree()).is_false()
		assert_bool((panel.get("_despachar") as Button).is_visible_in_tree()).is_false()
		var blanco := panel.get_node("Fisico/Blanco") as Control
		var clic := InputEventMouseButton.new()
		clic.pressed = true
		clic.button_index = MOUSE_BUTTON_RIGHT
		blanco.gui_input.emit(clic)
		assert_array(clicks).is_empty()
		clic.button_index = MOUSE_BUTTON_LEFT
		blanco.gui_input.emit(clic)
		assert_array(clicks).has_size(1)
		clicks.clear()
		panel.mostrar_sin_nadie()
		assert_bool(sprite.is_visible_in_tree()).is_true()
		assert_bool(texto.is_visible_in_tree()).is_false()


func test_animan_los_dos_y_la_pausa_conserva_el_cuadro() -> void:  # AC-CTR-042
	var panel := _panel()
	var sprite := _almacenes.back().get_node("Estructura/Ventanilla/Comprador") as AnimatedSprite3D
	assert_object(sprite).is_not_null()
	if sprite == null:
		return
	for intervalo: float in [120.0, 360.0]:
		var almacen: Node3D = _almacenes.back()
		(almacen.get("_reloj") as RelojDelTurno).avanzar(intervalo)
		panel.mostrar(almacen.get("_atenciones").atencion())
		sprite.set_frame_and_progress(0, 0.99)
		await get_tree().create_timer(0.1).timeout
		assert_int(sprite.frame).is_not_equal(0)
		get_tree().paused = true
		var cuadro := sprite.frame
		var progreso := sprite.frame_progress
		await get_tree().create_timer(0.1, true).timeout
		assert_int(sprite.frame).is_equal(cuadro)
		assert_float(sprite.frame_progress).is_equal(progreso)
		get_tree().paused = false
		panel.ocultar()
		assert_bool(sprite.is_visible_in_tree()).is_true()


func test_esperan_en_el_mundo_con_la_interfaz_cerrada() -> void:  # AC-CTR-042
	var panel := _panel()
	var almacen: Node3D = _almacenes.back()
	var puesto: Node3D = almacen.get_node("Estructura/Ventanilla")
	var sprite := puesto.get_node_or_null("Comprador") as AnimatedSprite3D
	assert_object(sprite).is_not_null()
	if sprite == null:
		return
	var reloj: RelojDelTurno = almacen.get("_reloj")
	assert_bool(sprite.visible).is_false()
	for intervalo: float in [120.0, 240.0]:
		reloj.avanzar(intervalo)
		assert_bool(panel.visible).is_false()
		assert_bool(sprite.is_visible_in_tree()).is_true()
		assert_int(sprite.billboard).is_equal(BaseMaterial3D.BILLBOARD_ENABLED)
		assert_bool(sprite.no_depth_test).is_false()
		assert_bool(sprite.fixed_size).is_false()
		sprite.set_frame_and_progress(0, 0.99)
		await get_tree().create_timer(0.1).timeout
		assert_int(sprite.frame).is_not_equal(0)
		reloj.avanzar(120.0)
		assert_bool(sprite.visible).is_false()
