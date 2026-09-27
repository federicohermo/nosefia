## Lo que suena del otro lado de una pared o de una puerta cerrada: cuántos obstáculos cuenta el
## reproductor y qué le pide a la voz.
##
## Los cuerpos entran al árbol y se espera un cuadro de física: antes, el rayo no los ve.
extends GdUnitTestSuite

const OIDO := Vector3(0, 1, 0)
const FUENTE := Vector3(0, 1, -4)
const PARED := Vector3(0, 1, -2)


## Un cuerpo con la puerta del dominio adentro, como la cáscara de la puerta del local.
class PuertaDePrueba:
	extends StaticBody3D

	var _puerta := Puerta.new()

	func puerta() -> Puerta:
		return _puerta


func test_la_pared_cuenta_y_la_puerta_solo_cerrada() -> void:  # AC-AMB-021
	var reproductor := _reproductor([] as Array[EntradaSonora])
	assert_int(reproductor.obstaculos_entre(OIDO, FUENTE, null)).is_equal(0)
	var pared := await _bloque(StaticBody3D.new())
	assert_int(reproductor.obstaculos_entre(OIDO, FUENTE, null)).is_equal(1)
	pared.queue_free()
	var puerta := (await _bloque(PuertaDePrueba.new())) as PuertaDePrueba
	assert_int(reproductor.obstaculos_entre(OIDO, FUENTE, null)).is_equal(1)
	puerta.puerta().alternar()
	assert_int(reproductor.obstaculos_entre(OIDO, FUENTE, null)).is_equal(0)


func test_el_objeto_que_suena_no_se_tapa_a_si_mismo() -> void:  # AC-AMB-021
	var reproductor := _reproductor([] as Array[EntradaSonora])
	var propio := await _bloque(StaticBody3D.new())
	assert_int(reproductor.obstaculos_entre(OIDO, FUENTE, propio)).is_equal(0)


func test_lo_que_encierra_al_sonido_no_lo_tapa() -> void:  # AC-AMB-021
	var reproductor := _reproductor([] as Array[EntradaSonora])
	var encierra := await _bloque(StaticBody3D.new())
	assert_int(reproductor.obstaculos_entre(OIDO, encierra.global_position, null)).is_equal(0)


func test_una_pared_de_dos_solidos_encimados_cuenta_una() -> void:  # AC-AMB-021
	var reproductor := _reproductor([] as Array[EntradaSonora])
	await _bloque(StaticBody3D.new())
	await _bloque(StaticBody3D.new())
	assert_int(reproductor.obstaculos_entre(OIDO, FUENTE, null)).is_equal(1)


func test_dos_paredes_del_mismo_solido_cuentan_dos() -> void:  # AC-AMB-021
	var reproductor := _reproductor([] as Array[EntradaSonora])
	var solido := await _bloque(StaticBody3D.new())
	var segunda := solido.get_child(0).duplicate() as CollisionShape3D
	segunda.position.z = (FUENTE.z - PARED.z) * 0.75
	solido.add_child(segunda)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_int(reproductor.obstaculos_entre(OIDO, FUENTE, null)).is_equal(2)


## Lo que sonó puede liberarse con su sonido todavía puesto.
func test_la_voz_se_sigue_apagando_aunque_se_borre_lo_que_sono() -> void:
	var entrada := _entrada(EntradaSonora.Evento.TIMBRE_DEL_COMPRADOR)
	entrada.posicional = true
	var reproductor := _reproductor([entrada] as Array[EntradaSonora])
	var objeto := RigidBody3D.new()
	add_child(objeto)
	objeto.global_position = FUENTE
	assert_bool(reproductor.recibir(EntradaSonora.Evento.TIMBRE_DEL_COMPRADOR, objeto)).is_true()
	objeto.free()
	await _bloque(StaticBody3D.new())
	reproductor.actualizar_apagado(OIDO, 1.0)
	var voz := reproductor.voces_en_el_espacio()[0]
	assert_float(voz.volume_db).is_equal_approx(ApagadoPorObstaculos.volumen_db(1.0), 0.001)


func test_aparecer_una_pared_apaga_sin_salto() -> void:  # AC-AMB-022
	var entrada := _entrada(EntradaSonora.Evento.TIMBRE_DEL_COMPRADOR)
	entrada.posicional = true
	var reproductor := _reproductor([entrada] as Array[EntradaSonora])
	var lugar: Node3D = auto_free(Node3D.new())
	add_child(lugar)
	lugar.global_position = FUENTE
	assert_bool(reproductor.recibir(EntradaSonora.Evento.TIMBRE_DEL_COMPRADOR, lugar)).is_true()
	var voz := reproductor.voces_en_el_espacio()[0]
	await _bloque(StaticBody3D.new())
	reproductor.actualizar_apagado(OIDO, 1.0 / 60.0)
	assert_float(voz.volume_db).is_less(0.0)
	assert_float(voz.volume_db).is_greater(ApagadoPorObstaculos.volumen_db(1.0))
	assert_float(_corte(voz)).is_greater(ApagadoPorObstaculos.corte_hz(1.0))
	reproductor.actualizar_apagado(OIDO, 1.0)
	assert_float(voz.volume_db).is_equal_approx(ApagadoPorObstaculos.volumen_db(1.0), 0.001)
	assert_float(_corte(voz)).is_equal_approx(ApagadoPorObstaculos.corte_hz(1.0), 0.001)


func test_lo_plano_no_se_apaga() -> void:  # AC-AMB-023
	var reproductor := _reproductor(
		[_entrada(EntradaSonora.Evento.TURNO_CERRADO)] as Array[EntradaSonora]
	)
	await _bloque(StaticBody3D.new())
	assert_bool(reproductor.pedir(EntradaSonora.Evento.TURNO_CERRADO)).is_true()
	reproductor.actualizar_apagado(OIDO, 1.0)
	var voz := reproductor.voces()[0]
	assert_float(voz.volume_db).is_equal(0.0)
	assert_str(voz.bus).is_equal(EntradaSonora.BUS_DE_EFECTOS)


func _bloque(cuerpo: StaticBody3D) -> StaticBody3D:
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(2, 2, 0.2)
	forma.shape = caja
	cuerpo.add_child(forma)
	add_child(auto_free(cuerpo))
	cuerpo.global_position = PARED
	await get_tree().physics_frame
	await get_tree().physics_frame
	return cuerpo


## El corte del pasa-bajos del bus por el que sale la voz, o sin corte si no filtra.
func _corte(voz: AudioStreamPlayer3D) -> float:
	var indice := AudioServer.get_bus_index(voz.bus)
	for efecto in range(AudioServer.get_bus_effect_count(indice)):
		var filtro := AudioServer.get_bus_effect(indice, efecto) as AudioEffectLowPassFilter
		if filtro != null:
			return filtro.cutoff_hz
	return ApagadoPorObstaculos.SIN_CORTE_HZ


func _entrada(evento: EntradaSonora.Evento) -> EntradaSonora:
	var entrada := EntradaSonora.new()
	entrada.evento = evento
	entrada.stream = AudioStreamGenerator.new()
	return entrada


func _reproductor(entradas: Array[EntradaSonora]) -> ReproductorDeSonidos:
	var reproductor: ReproductorDeSonidos = auto_free(ReproductorDeSonidos.new())
	add_child(reproductor)
	var tabla := TablaDeSonidos.new()
	tabla.entradas = entradas
	reproductor.arrancar(tabla)
	return reproductor
