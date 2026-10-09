## Los valores fijos de la basura, y las dos comparaciones que hacen que la tarea cueste caminar.
##
## **Ninguno de los dos casos afirma un número.** El trayecto no es una constante: es la
## consecuencia de que las bolsas no entren en las manos y de que el fondo no se vea desde el
## local. Subí las manos a 3 o bajá las bolsas a 1, y uno de los dos se pone rojo.
extends GdUnitTestSuite


func test_el_tiro_distingue_mano_caja_y_tapa_en_orden() -> void:  # AC-CLN-037
	assert_int(ReglasDeLaBasura.tiro(null, false)).is_equal(ReglasDeLaBasura.Tiro.MANO_VACIA)
	var caja := ObjetoDelAlmacen.new()
	caja.entra_en_el_contenedor = false
	for recibe: bool in [false, true]:
		assert_int(ReglasDeLaBasura.tiro(caja, recibe)).is_equal(ReglasDeLaBasura.Tiro.NO_ENTRA)
	var bolsa := ObjetoDelAlmacen.new()
	assert_int(ReglasDeLaBasura.tiro(bolsa, false)).is_equal(ReglasDeLaBasura.Tiro.TAPA_NO_ABIERTA)
	assert_int(ReglasDeLaBasura.tiro(bolsa, true)).is_equal(ReglasDeLaBasura.Tiro.TIRADO)


func test_la_tarea_no_se_puede_resolver_en_un_solo_viaje() -> void:  # AC-CLN-007
	(
		assert_int(ReglasDeLaBasura.BOLSAS_DE_LA_JORNADA)
		. override_failure_message(
			(
				"hay %d bolsas y %d manos: la basura se saca de un viaje"
				% [ReglasDeLaBasura.BOLSAS_DE_LA_JORNADA, ReglasDeLosObjetos.MANOS_DISPONIBLES]
			)
		)
		. is_greater(ReglasDeLosObjetos.MANOS_DISPONIBLES)
	)
	(
		assert_int(
			Trayecto.viajes(
				ReglasDeLaBasura.BOLSAS_DE_LA_JORNADA, ReglasDeLosObjetos.MANOS_DISPONIBLES
			)
		)
		. is_greater(1)
	)


func test_el_fondo_no_se_ve_desde_donde_se_hace_otra_tarea() -> void:  # AC-CLN-008
	(
		assert_float(ReglasDeLaBasura.DISTANCIA_MINIMA_AL_CONTENEDOR)
		. override_failure_message(
			(
				"el contenedor está a %.2f m y la mira alcanza %.2f m"
				% [
					ReglasDeLaBasura.DISTANCIA_MINIMA_AL_CONTENEDOR,
					ReglasDelJugador.ALCANCE_DE_LA_MIRA
				]
			)
		)
		. is_greater(ReglasDelJugador.ALCANCE_DE_LA_MIRA)
	)


func test_hay_un_id_distinto_por_bolsa_y_los_gobierna_el_balance() -> void:  # AC-CLN-007
	# Sin `id` distintos, depositar la misma bolsa tres veces cumpliría la tarea sin recorrer
	# nada — y ningún error lo diría.
	var ids := ReglasDeLaBasura.ids_de_las_bolsas()
	assert_int(ids.size()).is_equal(ReglasDeLaBasura.BOLSAS_DE_LA_JORNADA)
	var vistos: Array[StringName] = []
	for id in ids:
		assert_bool(vistos.has(id)).is_false()
		assert_str(id).is_not_equal(ObjetoDelAlmacen.SIN_ID)
		vistos.append(id)
