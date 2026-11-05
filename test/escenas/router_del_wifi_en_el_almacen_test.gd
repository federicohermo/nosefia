## El router del almacén: sus luces, su clic y lo que piensa, según el corte de luz. Qué estado
## corresponde lo prueba el dominio; acá, que el local lo traduzca.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const RelojDePrueba := preload("res://test/reloj_de_prueba.gd")
const TABLERO := "Estructura/tableroluz/StaticBody3D"
const ROUTER := "Estructura/Router"
const S := SubtitulosDeLosGestos.Id
const LUCES := WifiDelLocal.Luces


func after_test() -> void:
	get_tree().paused = false


func _local(jornada: int = AnomaliasDeLaJornada.JORNADA_DEL_CORTE) -> Node3D:
	var local: Node3D = auto_free(ALMACEN.instantiate())
	local.set("_partida", Partida.desde({"jornada": jornada, "medios": 0}))
	add_child(local)
	local.get("_jugador").set_physics_process(false)
	local.get("_reloj").set_process(false)
	return local


func _cortar(local: Node3D) -> void:
	var hora := Vector2i(AnomaliasDeLaJornada.HORA_DEL_CORTE, AnomaliasDeLaJornada.MINUTO_DEL_CORTE)
	RelojDePrueba.avanzar_hasta(local.get("_reloj"), hora)


func _restaurar(local: Node3D) -> void:
	local.get_node(TABLERO).accionar()


func _linea(local: Node3D) -> String:
	return (local.get("_hud").get("_subtitulo") as Label).text


func _luces(local: Node3D) -> Texture2D:
	var router: Node3D = local.get_node(ROUTER)
	var materiales: Array = router.get("_con_luces")
	assert_array(materiales).is_not_empty()
	return (materiales[0] as StandardMaterial3D).albedo_texture


func _textura(local: Node3D, luces: LUCES) -> Texture2D:
	var router: Node3D = local.get_node(ROUTER)
	match luces:
		LUCES.APAGADAS:
			return router.get("textura_apagada")
		LUCES.ROJAS:
			return router.get("textura_roja")
	return router.get("textura_verde")


func _sin_wifi_en_el_celular(local: Node3D) -> bool:
	var pantalla: PantallaDelCelular = local.get("_pantalla_del_celular")
	return (pantalla.find_child("SinWifi", true, false) as TextureRect).visible


## Lo que se ve del wifi: las luces del router, el ícono del celular y lo que sabe el dominio.
func _vista(local: Node3D) -> Array:
	var mostradas := LUCES.VERDES
	for luces: LUCES in [LUCES.APAGADAS, LUCES.ROJAS]:
		if _luces(local) == _textura(local, luces):
			mostradas = luces
	return [
		mostradas, _sin_wifi_en_el_celular(local), (local.get("_wifi") as WifiDelLocal).hay_wifi()
	]


func _esperado(luces: LUCES) -> Array:
	return [luces, luces != LUCES.VERDES, luces == LUCES.VERDES]


func test_el_router_abre_con_las_luces_verdes_y_conectado() -> void:  # AC-ANO-021
	var local := _local()
	assert_array(_vista(local)).is_equal(_esperado(LUCES.VERDES))
	assert_object(_textura(local, LUCES.VERDES)).is_not_same(_textura(local, LUCES.APAGADAS))
	assert_object(_textura(local, LUCES.APAGADAS)).is_not_same(_textura(local, LUCES.ROJAS))


func test_el_corte_apaga_las_luces_y_la_luz_las_pone_rojas() -> void:  # AC-ANO-021, AC-ANO-025
	var local := _local()
	_cortar(local)
	assert_array(_vista(local)).is_equal(_esperado(LUCES.APAGADAS))
	_restaurar(local)
	assert_array(_vista(local)).is_equal(_esperado(LUCES.ROJAS))


func test_apagar_y_prender_devuelve_el_wifi_y_el_icono() -> void:  # AC-ANO-022, AC-ANO-025
	var local := _local()
	_cortar(local)
	_restaurar(local)
	var router: Node3D = local.get_node(ROUTER)
	router.accionar()
	assert_array(_vista(local)).is_equal(_esperado(LUCES.APAGADAS))
	assert_str(_linea(local)).is_empty()
	router.accionar()
	assert_array(_vista(local)).is_equal(_esperado(LUCES.VERDES))
	assert_str(_linea(local)).is_empty()


func test_devuelto_el_wifi_el_clic_piensa_y_no_lo_cambia() -> void:  # AC-ANO-023, AC-SUB-034
	var local := _local()
	_cortar(local)
	_restaurar(local)
	var router: Node3D = local.get_node(ROUTER)
	router.accionar()
	router.accionar()
	for _clic in 2:
		router.accionar()
		assert_array(_vista(local)).is_equal(_esperado(LUCES.VERDES))
		assert_str(_linea(local)).is_equal(SubtitulosDeLosGestos.texto(S.ROUTER_YA_RESTAURADO))


func test_sin_luz_el_clic_piensa_sin_luz_y_no_lo_cambia() -> void:  # AC-ANO-023, AC-SUB-034
	var local := _local()
	_cortar(local)
	local.get_node(ROUTER).accionar()
	assert_str(_linea(local)).is_equal(SubtitulosDeLosGestos.texto(S.SIN_LUZ))
	assert_array(_vista(local)).is_equal(_esperado(LUCES.APAGADAS))


func test_antes_del_corte_o_en_otra_jornada_el_clic_no_lo_apaga() -> void:  # AC-ANO-023
	var jornadas: Array[int] = [
		AnomaliasDeLaJornada.JORNADA_DEL_CORTE,
		AnomaliasDeLaJornada.JORNADA_DEL_CORTE + 1,
	]
	for jornada in jornadas:
		var local := _local(jornada)
		local.get_node(ROUTER).accionar()
		assert_str(_linea(local)).is_equal(SubtitulosDeLosGestos.texto(S.ROUTER_ANTES_DEL_CORTE))
		assert_array(_vista(local)).is_equal(_esperado(LUCES.VERDES))


func test_examinar_el_router_dice_su_texto_sin_tocarlo() -> void:  # AC-SUB-034
	var local := _local()
	var router: Node3D = local.get_node(ROUTER)
	var texto: String = local.get("_jugador").texto_al_examinar_de(router)
	assert_str(texto).is_equal(SubtitulosAlExaminar.de_lo_fijo(SubtitulosAlExaminar.ROUTER))
	assert_array(_vista(local)).is_equal(_esperado(LUCES.VERDES))
