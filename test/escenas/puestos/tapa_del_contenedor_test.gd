## La hoja alterna con primario; el cuerpo descarta con primario cuando el dominio lo permite.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const BolsaEnLaMano := preload("res://test/escenas/bolsa_en_la_mano.gd")
const BASE := "Estructura/deposito_contenedor_grande_soporte/"
const TAPA := BASE + "deposito_contenedor_bisagra_izquierda/CuerpoDeLaTapa"

var _almacen: Node3D


func after_test() -> void:
	if is_instance_valid(_almacen):
		for tipo: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
			for audio: Node in _almacen.find_children("*", tipo, true, false):
				audio.call("stop")
				audio.set("stream", null)
		_almacen.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_almacen = null


func test_tapa_alterna_y_cuerpo_tira_solo_al_terminar_de_abrir() -> void:  # AC-CLN-035 AC-CLN-037
	_almacen = ALMACEN.instantiate()
	var almacen := _almacen
	add_child(almacen)
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	jugador.set_process(false)
	var tapa: Node3D = almacen.get_node(TAPA)
	tapa.set_physics_process(false)
	var bolsa := BolsaEnLaMano.preparar(almacen)
	var agarre: Agarre = almacen.get("_agarre")
	assert_bool(agarre.pedir_agarrar(bolsa.datos, bolsa)).is_true()
	_accion(tapa, false)
	assert_bool(tapa.call("recibe_objetos")).is_true()
	_accion(tapa, true)
	assert_bool(tapa.call("recibe_objetos")).is_false()
	assert_object(agarre.manos().sostenido()).is_same(bolsa.datos)
	assert_int(almacen.get("_recolector").tarea().depositadas()).is_zero()
	tapa.call("_physics_process", 1.0)
	_accion(almacen.get("_contenedor"), true)
	assert_object(agarre.manos().sostenido()).is_same(bolsa.datos)
	_accion(tapa, true)
	tapa.call("_physics_process", 0.1)
	assert_bool(tapa.call("recibe_objetos")).is_false()
	_accion(almacen.get("_contenedor"), true)
	assert_object(agarre.manos().sostenido()).is_same(bolsa.datos)
	tapa.call("_physics_process", 1.0)
	assert_bool(tapa.call("recibe_objetos")).is_true()
	assert_object(agarre.manos().sostenido()).is_same(bolsa.datos)
	_accion(tapa, false)
	_accion(almacen.get("_contenedor"), false)
	assert_bool(tapa.call("recibe_objetos")).is_true()
	assert_object(agarre.manos().sostenido()).is_same(bolsa.datos)
	assert_int(almacen.get("_recolector").tarea().depositadas()).is_zero()
	_accion(almacen.get("_contenedor"), true)
	assert_object(agarre.manos().sostenido()).is_null()
	assert_int(almacen.get("_recolector").tarea().depositadas()).is_equal(1)


func _accion(objetivo: Node3D, primario: bool) -> void:
	var jugador: Node3D = _almacen.get("_jugador")
	jugador.set("_enfocado", objetivo)
	var evento := InputEventAction.new()
	evento.action = ReglasDeLosObjetos.ACCION_AGARRAR if primario else ReglasDelJugador.ACCION_USAR
	evento.pressed = true
	jugador.call("_unhandled_input", evento)
