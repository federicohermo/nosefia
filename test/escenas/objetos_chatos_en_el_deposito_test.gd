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


## Lo que el almacén hace al soltar: mira dónde queda quieto. Devuelve cuándo se aquietó.
func _esperar_a_que_se_aquiete(almacen: Node3D, objeto: RigidBody3D) -> void:
	almacen.call("_vigilar_si_queda_afuera", objeto)
	var cuadros := 0
	while not objeto.sleeping and cuadros < CUADROS_PARA_QUEDAR_QUIETO:
		await get_tree().physics_frame
		cuadros += 1
	await get_tree().physics_frame
	await get_tree().physics_frame


func _linea(almacen: Node3D) -> String:
	return (almacen.get("_hud").get("_subtitulo") as Label).text


## Suelta `objeto` sobre el piso del depósito, a `lugar` en x y z, y afirma que se queda ahí.
func _afirmar_que_apoyado_en_el_deposito_no_sale_por_la_ventana(
	almacen: Node3D, objeto: RigidBody3D, lugar: Vector2
) -> void:
	var piso := _piso_del_deposito(almacen)
	objeto.global_position = Vector3(lugar.x, piso + ALTURA_DE_LA_SUELTA, lugar.y)
	objeto.linear_velocity = Vector3.ZERO
	objeto.angular_velocity = Vector3.ZERO
	await _afirmar_que_queda_en_el_deposito(almacen, objeto)


func _afirmar_que_queda_en_el_deposito(almacen: Node3D, objeto: RigidBody3D) -> void:
	await _esperar_a_que_se_aquiete(almacen, objeto)
	var habitaciones: Node3D = almacen.get("_habitaciones")
	# La premisa: se aquietó, y cerca del piso. Si quedara sobre un mueble, no probaría nada.
	assert_bool(objeto.sleeping).is_true()
	assert_float(objeto.global_position.y - _piso_del_deposito(almacen)).is_less(0.2)
	assert_int(habitaciones.de(objeto.global_position)).is_equal(
		ReglasDelCierre.Habitacion.DEPOSITO
	)
	assert_str(_linea(almacen)).is_not_equal(SubtitulosDeLosGestos.texto(S.POR_LA_VENTANA))


func test_la_palanca_en_su_lugar_del_deposito_no_sale_por_la_ventana() -> void:
	var almacen := await _almacen()
	await _afirmar_que_queda_en_el_deposito(almacen, almacen.get("_palanca"))


func test_la_palanca_soltada_en_el_piso_del_deposito_no_sale_por_la_ventana() -> void:
	var almacen := await _almacen()
	var palanca: RigidBody3D = almacen.get("_palanca")
	var lugar := Vector2(palanca.global_position.x + 1.0, palanca.global_position.z - 1.0)
	await _afirmar_que_apoyado_en_el_deposito_no_sale_por_la_ventana(almacen, palanca, lugar)


func test_la_llave_en_su_lugar_del_deposito_no_sale_por_la_ventana() -> void:
	var almacen := await _almacen()
	await _afirmar_que_queda_en_el_deposito(almacen, almacen.get("_llave"))


func test_la_llave_soltada_en_el_piso_del_deposito_no_sale_por_la_ventana() -> void:
	var almacen := await _almacen()
	var llave: RigidBody3D = almacen.get("_llave")
	var lugar := Vector2(llave.global_position.x - 1.0, llave.global_position.z - 1.0)
	await _afirmar_que_apoyado_en_el_deposito_no_sale_por_la_ventana(almacen, llave, lugar)
