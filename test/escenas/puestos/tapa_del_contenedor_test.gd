## La hoja conserva el derecho y consume el izquierdo, con el permiso del dominio.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const BASE := "Estructura/deposito_contenedor_soporte/"
const TAPA := BASE + "deposito_contenedor_bisagra_tapa/CuerpoDeLaTapa"

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


func test_el_izquierdo_en_la_hoja_tira_solo_al_terminar_de_abrir() -> void:  # AC-CLN-035 AC-CLN-037
	_almacen = ALMACEN.instantiate()
	var almacen := _almacen
	add_child(almacen)
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	jugador.set_process(false)
	var tapa: Node3D = almacen.get_node(TAPA)
	tapa.set_physics_process(false)
	var bolsa: ObjetoAgarrable = almacen.get_node("Objetos/BolsaDeBasura1")
	var agarre: Agarre = almacen.get("_agarre")
	assert_bool(agarre.pedir_agarrar(bolsa.datos, bolsa)).is_true()
	tapa.call("usar")
	assert_object(tapa.call("interactuar")).is_null()
	assert_object(agarre.manos().sostenido()).is_same(bolsa.datos)
	tapa.call("_physics_process", 1.0)
	tapa.call("usar")
	tapa.call("_physics_process", 0.1)
	assert_bool(tapa.call("recibe_objetos")).is_false()
	tapa.call("interactuar")
	assert_object(agarre.manos().sostenido()).is_same(bolsa.datos)
	tapa.call("_physics_process", 1.0)
	assert_bool(tapa.call("recibe_objetos")).is_true()
	assert_object(agarre.manos().sostenido()).is_same(bolsa.datos)
	tapa.call("interactuar")
	assert_object(agarre.manos().sostenido()).is_null()
	assert_int(almacen.get("_recolector").tarea().depositadas()).is_equal(1)
