## Un objeto chato apoyado en el piso del depósito sigue en el depósito: no «sale por la ventana».
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const ReglasDelCierre := preload("res://src/dominio/almacen/reglas_del_cierre.gd")
const S := SubtitulosDeLosGestos.Id

## Cuadros de física que se espera a que lo soltado se aquiete: más que el tiempo que mira el
## almacén (10 s a 60 Hz), para que el aviso, si va a salir, ya haya salido.
const CUADROS_PARA_QUEDAR_QUIETO := 720

## Desde cuánto más arriba del piso se suelta, en metros.
const ALTURA_DE_LA_SUELTA := 0.3

## Cuánto más arriba del piso puede quedar algo apoyado, en metros. Más que eso quedó sobre un
## mueble, y el caso no prueba el piso.
const ALTURA_MAXIMA_APOYADO := 0.2


func _almacen() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	almacen.set("_partida", Partida.desde({"jornada": ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA}))
	add_child(almacen)
	await get_tree().physics_frame
	almacen.get("_jugador").set_physics_process(false)
	return almacen


## El piso del depósito, derivado de la escena: de ahí arrancan sus volúmenes.
func _piso_del_deposito(almacen: Node3D) -> float:
	var habitaciones: Node3D = almacen.get("_habitaciones")
	return habitaciones.to_global(Vector3(0.0, habitaciones.deposito[0].position.y, 0.0)).y


func _habitacion_de(almacen: Node3D, objeto: Node3D) -> int:
	return almacen.get("_habitaciones").de(objeto.global_position)


func _altura_sobre_el_piso(almacen: Node3D, objeto: Node3D) -> float:
	return objeto.global_position.y - _piso_del_deposito(almacen)


func _quieto(objeto: RigidBody3D) -> bool:
	return objeto.sleeping or objeto.freeze


func _linea(almacen: Node3D) -> String:
	return (almacen.get("_hud").get("_subtitulo") as Label).text


## Lo que el almacén hace al soltar: mira dónde queda quieto. Espera a que se aquiete.
func _vigilar_hasta_que_se_aquiete(almacen: Node3D, objeto: RigidBody3D) -> void:
	almacen.call("_vigilar_si_queda_afuera", objeto)
	var cuadros := 0
	while not _quieto(objeto) and cuadros < CUADROS_PARA_QUEDAR_QUIETO:
		await get_tree().physics_frame
		cuadros += 1
	await get_tree().physics_frame
	await get_tree().physics_frame


## Suelta `objeto` sobre el piso del depósito, en `lugar` (x, z), y espera a que se aquiete.
func _soltar_en_el_piso(almacen: Node3D, objeto: RigidBody3D, lugar: Vector2) -> void:
	objeto.freeze = false
	objeto.sleeping = false
	objeto.global_position = Vector3(
		lugar.x, _piso_del_deposito(almacen) + ALTURA_DE_LA_SUELTA, lugar.y
	)
	objeto.linear_velocity = Vector3.ZERO
	objeto.angular_velocity = Vector3.ZERO
	await _vigilar_hasta_que_se_aquiete(almacen, objeto)


func test_la_palanca_en_su_lugar_del_deposito_no_sale_por_la_ventana() -> void:
	var almacen := await _almacen()
	var palanca: RigidBody3D = almacen.get("_palanca")
	await _vigilar_hasta_que_se_aquiete(almacen, palanca)
	assert_bool(_quieto(palanca)).is_true()
	assert_float(_altura_sobre_el_piso(almacen, palanca)).is_less(ALTURA_MAXIMA_APOYADO)
	assert_int(_habitacion_de(almacen, palanca)).is_equal(ReglasDelCierre.Habitacion.DEPOSITO)
	assert_str(_linea(almacen)).is_not_equal(SubtitulosDeLosGestos.texto(S.POR_LA_VENTANA))


func test_la_palanca_soltada_en_el_piso_del_deposito_no_sale_por_la_ventana() -> void:
	var almacen := await _almacen()
	var palanca: RigidBody3D = almacen.get("_palanca")
	var lugar := Vector2(palanca.global_position.x + 1.0, palanca.global_position.z - 1.0)
	await _soltar_en_el_piso(almacen, palanca, lugar)
	assert_bool(_quieto(palanca)).is_true()
	assert_float(_altura_sobre_el_piso(almacen, palanca)).is_less(ALTURA_MAXIMA_APOYADO)
	assert_int(_habitacion_de(almacen, palanca)).is_equal(ReglasDelCierre.Habitacion.DEPOSITO)
	assert_str(_linea(almacen)).is_not_equal(SubtitulosDeLosGestos.texto(S.POR_LA_VENTANA))


func test_la_llave_en_su_lugar_del_deposito_no_sale_por_la_ventana() -> void:
	var almacen := await _almacen()
	var llave: RigidBody3D = almacen.get("_llave")
	await _vigilar_hasta_que_se_aquiete(almacen, llave)
	assert_bool(_quieto(llave)).is_true()
	assert_float(_altura_sobre_el_piso(almacen, llave)).is_less(ALTURA_MAXIMA_APOYADO)
	assert_int(_habitacion_de(almacen, llave)).is_equal(ReglasDelCierre.Habitacion.DEPOSITO)
	assert_str(_linea(almacen)).is_not_equal(SubtitulosDeLosGestos.texto(S.POR_LA_VENTANA))


func test_la_llave_soltada_en_el_piso_del_deposito_no_sale_por_la_ventana() -> void:
	var almacen := await _almacen()
	var llave: RigidBody3D = almacen.get("_llave")
	var lugar := Vector2(llave.global_position.x - 1.0, llave.global_position.z - 1.0)
	await _soltar_en_el_piso(almacen, llave, lugar)
	assert_bool(_quieto(llave)).is_true()
	assert_float(_altura_sobre_el_piso(almacen, llave)).is_less(ALTURA_MAXIMA_APOYADO)
	assert_int(_habitacion_de(almacen, llave)).is_equal(ReglasDelCierre.Habitacion.DEPOSITO)
	assert_str(_linea(almacen)).is_not_equal(SubtitulosDeLosGestos.texto(S.POR_LA_VENTANA))
