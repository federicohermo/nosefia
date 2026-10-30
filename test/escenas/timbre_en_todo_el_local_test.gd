## El timbre del comprador se oye desde el local, el baño y el depósito, con las paredes y los
## emisores del almacén de verdad, y no queda en silencio por mucho que lo tapen.
extends GdUnitTestSuite

const ESCENA_DEL_ALMACEN := "res://src/escenas/almacen.tscn"
const REPRODUCTOR := "Servicios/AudioDelAlmacen/Reproductor"
const ReglasDelCierre := preload("res://src/dominio/almacen/reglas_del_cierre.gd")

var _almacen: Node3D
var _reproductor: ReproductorDeSonidos


func before_test() -> void:
	_almacen = auto_free(load(ESCENA_DEL_ALMACEN).instantiate())
	add_child(_almacen)
	for _cuadro in 3:
		await get_tree().physics_frame
	_reproductor = _almacen.get_node(REPRODUCTOR)


## El centro del primer volumen de un cuarto, en coordenadas del mundo.
func _oido_en(cuartos: Array[AABB]) -> Vector3:
	var habitaciones: Node3D = _almacen.get("_habitaciones")
	return habitaciones.to_global(cuartos[0].get_center())


## El corte del pasa-bajos del bus por el que sale la voz, o sin corte si no filtra.
func _corte(voz: AudioStreamPlayer3D) -> float:
	var indice := AudioServer.get_bus_index(voz.bus)
	for efecto in range(AudioServer.get_bus_effect_count(indice)):
		var filtro := AudioServer.get_bus_effect(indice, efecto) as AudioEffectLowPassFilter
		if filtro != null:
			return filtro.cutoff_hz
	return ApagadoPorObstaculos.SIN_CORTE_HZ


func test_el_timbre_se_oye_desde_el_local_el_bano_y_el_deposito() -> void:
	var habitaciones: Node3D = _almacen.get("_habitaciones")
	var fila := _reproductor.tabla().de(
		EntradaSonora.Evento.TIMBRE_DEL_COMPRADOR, EntradaSonora.Sonoridad.NINGUNA
	)
	assert_bool(_reproductor.pedir(EntradaSonora.Evento.TIMBRE_DEL_COMPRADOR)).is_true()
	var voz: AudioStreamPlayer3D = null
	for candidata in _reproductor.voces_en_el_espacio():
		if candidata.stream != null:
			voz = candidata
	assert_object(voz).is_not_null()
	# Un aviso que se oye de todo el local no apaga como el resto de los sonidos del espacio.
	assert_int(fila.obstaculos_maximos).is_less(ApagadoPorObstaculos.MAXIMO)
	var apagado_a_lo_sumo := (
		fila.volumen_db + ApagadoPorObstaculos.volumen_db(fila.obstaculos_maximos)
	)
	var cuartos := {
		ReglasDelCierre.Habitacion.LOCAL: habitaciones.local,
		ReglasDelCierre.Habitacion.BANO: habitaciones.bano,
		ReglasDelCierre.Habitacion.DEPOSITO: habitaciones.deposito,
	}
	for cuarto: ReglasDelCierre.Habitacion in cuartos:
		var oido := _oido_en(cuartos[cuarto])
		assert_int(habitaciones.de(oido)).is_equal(cuarto)
		_reproductor.actualizar_apagado(oido, 10.0)
		(
			assert_float(voz.volume_db)
			. override_failure_message("el timbre queda en silencio en el cuarto %d" % cuarto)
			. is_greater_equal(apagado_a_lo_sumo)
		)
		assert_float(_corte(voz)).is_greater(
			ApagadoPorObstaculos.corte_hz(ApagadoPorObstaculos.MAXIMO)
		)
		# Más lejos suena más bajo por la atenuación del motor, que no lo corta antes de llegar.
		assert_bool(voz.attenuation_model != AudioStreamPlayer3D.ATTENUATION_DISABLED).is_true()
		var lejania := voz.global_position.distance_to(oido)
		assert_bool(voz.max_distance == 0.0 or lejania < voz.max_distance).is_true()


func test_el_bano_y_el_deposito_estan_tapados_del_timbre() -> void:
	var habitaciones: Node3D = _almacen.get("_habitaciones")
	assert_bool(_reproductor.pedir(EntradaSonora.Evento.TIMBRE_DEL_COMPRADOR)).is_true()
	var voz: AudioStreamPlayer3D = null
	for candidata in _reproductor.voces_en_el_espacio():
		if candidata.stream != null:
			voz = candidata
	for cuartos: Array[AABB] in [habitaciones.bano, habitaciones.deposito]:
		var tapan := _reproductor.obstaculos_entre(_oido_en(cuartos), voz.global_position, null)
		assert_int(tapan).is_greater(0)
