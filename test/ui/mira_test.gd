extends GdUnitTestSuite

const HUD := preload("res://src/ui/hud.tscn")


func test_la_mira_permanece_en_el_centro_al_cambiar_la_resolucion() -> void:  # 039-AC7
	var pantalla: SubViewport = auto_free(SubViewport.new())
	add_child(pantalla)
	var hud: Hud = HUD.instantiate()
	pantalla.add_child(hud)
	var mira: Control = hud.get_node_or_null("Mira")
	assert_object(mira).is_not_null()
	if mira == null:
		return
	for ancla in [mira.anchor_left, mira.anchor_top, mira.anchor_right, mira.anchor_bottom]:
		assert_float(ancla).is_equal(0.5)
	for resolucion in [Vector2i(800, 600), Vector2i(1920, 1080)]:
		pantalla.size = resolucion
		await get_tree().process_frame
		assert_vector(mira.position + mira.size / 2.0).is_equal(Vector2(resolucion) / 2.0)
		assert_bool(mira.visible).is_true()


func test_el_hud_expone_el_foco_y_cambia_el_color_sin_ocultar_la_mira() -> void:  # 039-AC8 039-AC6
	var hud: Hud = auto_free(HUD.instantiate())
	add_child(hud)
	assert_bool("foco_presente" in hud).is_true()
	if not "foco_presente" in hud:
		return
	var mira: ColorRect = hud.get_node("Mira")
	assert_bool(hud.get("foco_presente")).is_false()
	assert_bool(mira.color == IndicacionDelFoco.COLOR_SIN_FOCO).is_true()
	var objetivo: Node3D = auto_free(Node3D.new())
	hud.call("mostrar_foco", objetivo, 1.0)
	assert_bool(hud.get("foco_presente")).is_true()
	assert_bool(mira.color == IndicacionDelFoco.COLOR).is_true()
	hud.call("ocultar_foco")
	assert_bool(hud.get("foco_presente")).is_false()
	assert_bool(mira.color == IndicacionDelFoco.COLOR_SIN_FOCO).is_true()
	assert_bool(mira.visible).is_true()
	assert_vector(mira.size).is_equal(Vector2.ONE * IndicacionDelFoco.TAMANO_DE_MIRA)
