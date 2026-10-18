## La música del menú: una sola voz, por el bus de la música, desde el menú hasta que el almacén
## toma el control.
##
## Ningún caso afirma que suena: en headless el driver no mezcla. Se mira qué quedó pedido.
extends GdUnitTestSuite

const ESCENA_DEL_MENU := "res://src/escenas/menu_de_inicio.tscn"
const TEMA := "MUS_MenuPrincipal.ogg"
const ESPERA_DE_LA_ENTRADA_MS := 3000


## Lo que el menú llama al entregar el control, sin cargar el almacén entero.
class AlmacenFalso:
	extends Node3D

	var anuncios: int = 0

	func anunciar_la_noche() -> void:
		anuncios += 1


## Retiene el fin del calentamiento para comprobar el tema antes de entregar el control.
class CalentamientoEnEspera:
	extends CalentamientoDeShaders

	var escena: Node3D

	func calentar(almacen: Node3D) -> void:
		escena = almacen


var _ruta: String


func before_test() -> void:
	_ruta = create_temp_dir("musica_del_menu").path_join("partida.guardado")


func after_test() -> void:
	var ajuste: AjusteDePreferencias = auto_free(AjusteDePreferencias.new())
	add_child(ajuste)
	ajuste.aplicar(Preferencias.new())


func _menu() -> Control:
	var menu: Control = auto_free(load(ESCENA_DEL_MENU).instantiate())
	(menu.get("_guardado") as Guardado).ruta = _ruta
	add_child(menu)
	return menu


## Las voces del menú que tienen pedido el tema.
static func _voces_del_tema(menu: Control) -> Array[AudioStreamPlayer]:
	var voces: Array[AudioStreamPlayer] = []
	for voz: AudioStreamPlayer in menu.find_children("*", "AudioStreamPlayer", true, false):
		if voz.stream != null and voz.stream.resource_path.get_file() == TEMA:
			voces.append(voz)
	return voces


func test_el_menu_pide_su_tema_en_bucle_por_la_musica() -> void:
	var voces := _voces_del_tema(_menu())
	assert_int(voces.size()).is_equal(1)
	if voces.size() != 1:
		return
	assert_str(voces[0].bus).is_equal(EntradaSonora.BUS_DE_MUSICA)
	assert_bool(voces[0].stream.get("loop")).is_true()
	assert_int(voces[0].playback_type).is_equal(AudioServer.PLAYBACK_TYPE_STREAM)


func test_con_la_musica_guardada_en_cero_el_tema_sale_callado() -> void:
	var guardadas := Preferencias.new()
	guardadas.poner(Preferencias.Campo.MUSICA, 0.0)
	assert_bool(ArchivoDePreferencias.new().escribir(guardadas)).is_true()
	var menu: Control = auto_free(load(ESCENA_DEL_MENU).instantiate())
	(menu.get("_guardado") as Guardado).ruta = _ruta
	var silencios_al_crear_la_voz: Array[bool] = []
	menu.child_entered_tree.connect(
		func(hijo: Node) -> void:
			if hijo is AudioStreamPlayer:
				var indice := AudioServer.get_bus_index(EntradaSonora.BUS_DE_MUSICA)
				silencios_al_crear_la_voz.append(AudioServer.is_bus_mute(indice))
	)
	add_child(menu)
	assert_array(silencios_al_crear_la_voz).is_equal([true])
	assert_int(_voces_del_tema(menu).size()).is_equal(1)
	var bus := AudioServer.get_bus_index(EntradaSonora.BUS_DE_MUSICA)
	assert_bool(AudioServer.is_bus_mute(bus)).is_true()


func test_configuraciones_y_reintentar_la_carga_conservan_la_misma_voz() -> void:
	var menu := _menu()
	menu.set_process(false)
	var voces := _voces_del_tema(menu)
	assert_int(voces.size()).is_equal(1)
	if voces.size() != 1:
		return
	var voz := voces[0]
	var tema := voz.stream
	menu.call("_abrir_las_configuraciones")
	menu.call("_al_cerrar_las_configuraciones")
	menu.call("entrar_al_almacen")
	menu.call("_al_fallar_la_carga")
	menu.call("entrar_al_almacen")
	assert_array(_voces_del_tema(menu)).is_equal([voz])
	assert_object(voz.stream).is_same(tema)


func test_el_tema_sigue_durante_el_calentamiento_hasta_su_senal_de_fin() -> void:
	var menu := _menu()
	menu.set_process(false)
	var voces := _voces_del_tema(menu)
	assert_int(voces.size()).is_equal(1)
	if voces.size() != 1:
		return
	var voz := voces[0]
	var tema := voz.stream
	var modelo := AlmacenFalso.new()
	var escena := PackedScene.new()
	assert_int(escena.pack(modelo)).is_equal(OK)
	modelo.free()
	menu.set("_almacen", escena)
	var calentamiento: CalentamientoEnEspera = CalentamientoEnEspera.new()
	menu.add_child(calentamiento)
	menu.set("_calentamiento", calentamiento)
	var anterior := get_tree().current_scene
	menu.call("_calentar_el_almacen")
	var almacen: AlmacenFalso = auto_free(calentamiento.escena)
	assert_object(almacen).is_not_null()
	assert_int(almacen.process_mode).is_equal(Node.PROCESS_MODE_DISABLED)
	assert_int(almacen.anuncios).is_zero()
	assert_array(_voces_del_tema(menu)).is_equal([voz])
	assert_object(voz.stream).is_same(tema)
	var musica_cortada_al_salir: Array[bool] = []
	voz.tree_exiting.connect(func() -> void: musica_cortada_al_salir.append(voz.stream == null))
	calentamiento.terminado.emit()
	# La barra se llena y se sostiene llena antes de entregar el control.
	var limite := Time.get_ticks_msec() + ESPERA_DE_LA_ENTRADA_MS
	while (
		(get_tree().current_scene != almacen or musica_cortada_al_salir.is_empty())
		and Time.get_ticks_msec() < limite
	):
		await get_tree().process_frame
	assert_object(get_tree().current_scene).is_same(almacen)
	get_tree().current_scene = anterior
	assert_int(almacen.anuncios).is_equal(1)
	assert_int(almacen.process_mode).is_equal(Node.PROCESS_MODE_INHERIT)
	assert_array(musica_cortada_al_salir).is_equal([true])


func test_entregar_el_control_al_almacen_corta_el_tema() -> void:
	var menu := _menu()
	menu.set_process(false)
	var voces := _voces_del_tema(menu)
	assert_int(voces.size()).is_equal(1)
	if voces.size() != 1:
		return
	var anterior := get_tree().current_scene
	var almacen: Node = auto_free(AlmacenFalso.new())
	get_tree().root.add_child(almacen)
	menu.call("_entrar", almacen)
	get_tree().current_scene = anterior
	assert_object(voces[0].stream).is_null()
	assert_int((almacen as AlmacenFalso).anuncios).is_equal(1)
