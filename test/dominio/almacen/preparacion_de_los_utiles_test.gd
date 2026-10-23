extends GdUnitTestSuite


func _utiles() -> Array[StringName]:
	var utiles: Array[StringName] = [&"mopa", &"balde"]
	utiles.append_array(ReglasDeLaLimpieza.JABONES.keys())
	return utiles


func _primera_que_limpia() -> int:
	var jornada := ReglasDeLaPartida.PRIMERA_JORNADA
	while not Apertura.pide(jornada, Tarea.Tipo.LIMPIAR):
		jornada += 1
	return jornada


## Hasta esa noche el cuartito está trabado. Preparar un útil antes suma una espera a una noche
## que todavía no lo usa.
func test_ninguna_noche_anterior_a_la_primera_que_limpia_prepara_un_util() -> void:
	for util: StringName in _utiles():
		for jornada: int in range(ReglasDeLaPartida.PRIMERA_JORNADA, _primera_que_limpia()):
			assert_bool(PreparacionDeLosUtiles.se_prepara(util, jornada)).is_false()
			if jornada > ReglasDeLaPartida.PRIMERA_JORNADA:
				(
					assert_bool(PreparacionDeLosUtiles.por_preparar(util, jornada - 1, jornada))
					. is_false()
				)


func test_la_transicion_a_la_primera_que_limpia_prepara_cada_util() -> void:
	for util: StringName in _utiles():
		(
			assert_bool(
				PreparacionDeLosUtiles.por_preparar(
					util, _primera_que_limpia() - 1, _primera_que_limpia()
				)
			)
			. is_true()
		)


## Quien retoma una partida guardada en esa noche no pasa por la transición: la carga los prepara.
func test_retomar_en_la_primera_que_limpia_prepara_cada_util_en_la_carga() -> void:
	for util: StringName in _utiles():
		assert_bool(PreparacionDeLosUtiles.se_prepara(util, _primera_que_limpia())).is_true()


## La carga de «Nuevo juego» es la que espera un jugador que recién llega, y la web le pone un tope
## de programas. Ahí ningún útil sale del cuartito: está trabado.
func test_la_primera_carga_no_prepara_ningun_util() -> void:
	for util: StringName in _utiles():
		(
			assert_bool(PreparacionDeLosUtiles.se_prepara(util, ReglasDeLaPartida.PRIMERA_JORNADA))
			. is_false()
		)


func test_lo_que_se_prepara_una_noche_se_sigue_preparando_hasta_el_final() -> void:
	for util: StringName in _utiles():
		var preparado := false
		for jornada: int in range(
			ReglasDeLaPartida.PRIMERA_JORNADA, ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA + 1
		):
			var ahora: bool = PreparacionDeLosUtiles.se_prepara(util, jornada)
			assert_bool(ahora or not preparado).is_true()
			preparado = ahora
		assert_bool(preparado).is_true()


## Entre noches no hay pantalla de carga: la jornada siguiente abre en la misma escena. Lo que la
## carga no preparó se prepara en la transición, antes de la noche que lo necesita.
func test_una_partida_seguida_llega_a_la_primera_que_limpia_con_los_utiles_preparados() -> void:
	for util: StringName in _utiles():
		var preparada := ReglasDeLaPartida.PRIMERA_JORNADA
		var listo := PreparacionDeLosUtiles.se_prepara(util, preparada)
		for siguiente: int in range(preparada + 1, _primera_que_limpia() + 1):
			if PreparacionDeLosUtiles.por_preparar(util, preparada, siguiente):
				listo = true
			preparada = siguiente
		assert_bool(listo).is_true()


func test_ningun_util_se_prepara_dos_veces_en_la_misma_partida() -> void:
	for util: StringName in _utiles():
		for carga: int in range(
			ReglasDeLaPartida.PRIMERA_JORNADA, ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA + 1
		):
			var veces := 1 if PreparacionDeLosUtiles.se_prepara(util, carga) else 0
			for siguiente: int in range(carga + 1, ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA + 1):
				if PreparacionDeLosUtiles.por_preparar(util, siguiente - 1, siguiente):
					veces += 1
			assert_int(veces).is_less_equal(1)
