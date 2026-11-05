## Lo de una pista que se suelta en el piso del depósito queda sobre el piso.
##
## Son los objetos más finos que se llevan en la mano: la colilla y la llave miden dos centímetros,
## el papel menos. Una caída de la mano llega al piso a varios centímetros por cuadro de física,
## más que su grosor, y si el motor no la sigue entre cuadros el objeto cruza el piso y se pierde.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const COLILLA := preload("res://src/escenas/objetos/colilla.tscn")
const LLAVE := preload("res://src/escenas/objetos/llave.tscn")
const DOCUMENTO := preload("res://src/escenas/objetos/documento_impreso.tscn")

## Piso libre del depósito, lejos de los muebles y sin nada encima. Es el que mide
## `producto_soltado_test.gd`.
const PISO_LIBRE := Vector3(4.18, 0.0, -8.95)

## Desde qué altura sobre el piso se suelta, en metros: la de la mano.
const ALTURA_DE_LA_CAIDA := 1.5

## Cuánto puede bajar el centro por debajo del plano del piso, en metros.
const HUNDIMIENTO := 0.05

## Cuánto se mira la caída, en segundos de física. Alcanza para caer, rebotar y asentarse.
const SEGUNDOS_DE_LA_CAIDA := 2


func _almacen() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	almacen.set(
		"_partida",
		Partida.desde({"jornada": ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1, "medios": 0})
	)
	add_child(almacen)
	await get_tree().physics_frame
	return almacen


func _piso_en(almacen: Node3D, punto: Vector3) -> Dictionary:
	var consulta := PhysicsRayQueryParameters3D.create(
		punto + Vector3.UP * 3.0, punto + Vector3.DOWN * 3.0
	)
	return almacen.get_world_3d().direct_space_state.intersect_ray(consulta)


## Suelta el objeto de plano sobre el piso libre y devuelve lo más abajo que llegó su centro.
func _caida_de(escena: PackedScene) -> Dictionary:
	var almacen := await _almacen()
	var golpe := _piso_en(almacen, PISO_LIBRE)
	# La premisa: el rayo pega en un piso horizontal. Si el local cambia, esto sale rojo en vez de
	# probar una caída sobre otra cosa.
	assert_bool(golpe.is_empty()).is_false()
	assert_bool(golpe["normal"].y > 0.99).is_true()
	var piso: float = golpe["position"].y
	var objeto: ObjetoAgarrable = escena.instantiate()
	almacen.add_child(objeto)
	objeto.global_position = Vector3(PISO_LIBRE.x, piso + ALTURA_DE_LA_CAIDA, PISO_LIBRE.z)
	objeto.linear_velocity = Vector3.ZERO
	objeto.angular_velocity = Vector3.ZERO
	var minima := objeto.global_position.y
	for cuadro in SEGUNDOS_DE_LA_CAIDA * Engine.physics_ticks_per_second:
		await get_tree().physics_frame
		minima = minf(minima, objeto.global_position.y)
	return {"piso": piso, "minima": minima}


func test_la_colilla_soltada_no_atraviesa_el_piso() -> void:
	var caida := await _caida_de(COLILLA)
	(
		assert_float(caida["minima"])
		. override_failure_message(
			"La colilla bajó hasta %.3f y el piso está en %.3f" % [caida["minima"], caida["piso"]]
		)
		. is_greater_equal(caida["piso"] - HUNDIMIENTO)
	)


func test_la_llave_soltada_no_atraviesa_el_piso() -> void:
	var caida := await _caida_de(LLAVE)
	(
		assert_float(caida["minima"])
		. override_failure_message(
			"La llave bajó hasta %.3f y el piso está en %.3f" % [caida["minima"], caida["piso"]]
		)
		. is_greater_equal(caida["piso"] - HUNDIMIENTO)
	)


func test_el_documento_soltado_no_atraviesa_el_piso() -> void:
	var caida := await _caida_de(DOCUMENTO)
	(
		assert_float(caida["minima"])
		. override_failure_message(
			"El documento bajó hasta %.3f y el piso está en %.3f" % [caida["minima"], caida["piso"]]
		)
		. is_greater_equal(caida["piso"] - HUNDIMIENTO)
	)
