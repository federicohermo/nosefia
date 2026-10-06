extends GdUnitTestSuite

const Medicion := preload("res://test/performance/medir_ondas_del_balde.gd")
const Ondas := preload("res://src/escenas/objetos/ondas_del_balde.gd")


func test_el_protocolo_cubre_sus_seis_deltas_con_impulsos_y_aceleracion_variable() -> void:
	var deltas := {}
	var aceleraciones := {}
	var impulsos := 0
	for indice in Medicion.AVANCES_DEL_PROTOCOLO:
		var paso := Medicion.paso_del_protocolo(indice)
		deltas[paso["delta"]] = true
		aceleraciones[paso["aceleracion"]] = true
		impulsos += int(paso.has("centro"))
	assert_array(deltas.keys()).contains_exactly_in_any_order(
		[0.0, 1.0 / 144.0, 1.0 / 60.0, 1.0 / 30.0, 0.1, 0.2]
	)
	assert_int(impulsos).is_between(2, Medicion.AVANCES_DEL_PROTOCOLO - 1)
	assert_int(aceleraciones.size()).is_greater(1)


func test_el_protocolo_da_los_mismos_600_estados_dos_veces_y_mueve_el_agua() -> void:
	var primera := Medicion.correr_protocolo()
	var estados: PackedStringArray = primera["estados"]
	assert_int(estados.size()).is_equal(600)
	assert_dict(Medicion.correr_protocolo()).is_equal(primera)
	var distintos := {}
	for estado in estados:
		distintos[estado] = true
	assert_int(distintos.size()).is_greater(300)
	assert_float(primera["amplitud_maxima"]).is_greater(0.0)
	# El reinicio del final deja el campo como uno recién creado.
	var nuevo := Ondas.new()
	nuevo.preparar_muestras(Medicion.puntos_de_muestreo())
	assert_str(primera["tras_reiniciar"]).is_equal(Medicion.huella(Medicion.estado_en_bytes(nuevo)))
	assert_bool(estados.has(primera["tras_reiniciar"])).is_false()


func test_la_huella_cambia_con_un_solo_valor_del_estado() -> void:
	var ondas := Ondas.new()
	ondas.preparar_muestras(Medicion.puntos_de_muestreo())
	var centro := Ondas.LADO * Ondas.LADO / 2
	for nombre: String in ["_alturas", "_velocidades"]:
		var antes := Medicion.huella(Medicion.estado_en_bytes(ondas))
		var buffer: PackedFloat32Array = ondas.get(nombre)
		buffer[centro] += 0.001
		(
			assert_str(Medicion.huella(Medicion.estado_en_bytes(ondas)))
			. override_failure_message("la huella no ve un cambio en " + nombre)
			. is_not_equal(antes)
		)


func test_las_pasadas_de_tiempo_dejan_el_campo_activo_y_su_mediana() -> void:
	var tiempos := Medicion.medir_pasadas(3, 20)
	var pasadas: Array[float] = []
	pasadas.assign(tiempos["pasadas_ms"])
	assert_int(pasadas.size()).is_equal(3)
	pasadas.sort()
	assert_float(pasadas[0]).is_greater_equal(0.0)
	assert_float(tiempos["mediana_ms"]).is_equal(pasadas[1])
	assert_float(tiempos["amplitud_final"]).is_greater(0.0)
	var valores: Array[float] = [90, 2, 3, 1, 4]
	assert_float(Medicion.mediana(valores)).is_equal(3.0)
