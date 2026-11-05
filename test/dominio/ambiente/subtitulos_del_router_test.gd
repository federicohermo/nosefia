## Qué piensa el protagonista al hacer clic sobre el router y qué dice al examinarlo.
extends GdUnitTestSuite

const S := SubtitulosDeLosGestos.Id


func test_el_clic_sobre_el_router_piensa_segun_su_estado() -> void:  # AC-SUB-034
	var corte := AnomaliasDeLaJornada.Corte
	var estado := WifiDelLocal.Estado
	var sin_luz := SubtitulosDeLosGestos.al_usar_el_router(corte.CORTADO, estado.SIN_ENERGIA)
	assert_int(sin_luz).is_equal(S.SIN_LUZ)
	var antes := SubtitulosDeLosGestos.al_usar_el_router(corte.SIN_CORTE, estado.CON_WIFI)
	assert_int(antes).is_equal(S.ROUTER_ANTES_DEL_CORTE)
	var devuelto := SubtitulosDeLosGestos.al_usar_el_router(corte.RESTAURADO, estado.CON_WIFI)
	assert_int(devuelto).is_equal(S.ROUTER_YA_RESTAURADO)
	for sin_arreglar: WifiDelLocal.Estado in [estado.DESCOMPUESTO, estado.APAGADO]:
		var pensado := SubtitulosDeLosGestos.al_usar_el_router(corte.RESTAURADO, sin_arreglar)
		assert_int(pensado).is_equal(S.NINGUNO)


func test_examinar_el_router_dice_su_texto_en_un_renglon() -> void:  # AC-SUB-034
	var texto := SubtitulosAlExaminar.de_lo_fijo(SubtitulosAlExaminar.ROUTER)
	assert_str(texto).is_not_empty()
	assert_array(texto.split("\n")).has_size(1)
