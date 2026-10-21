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


func test_cada_util_ya_se_preparo_en_una_carga_anterior_a_la_primera_que_limpia() -> void:
	for util: StringName in _utiles():
		var antes := false
		for jornada: int in range(ReglasDeLaPartida.PRIMERA_JORNADA, _primera_que_limpia()):
			antes = antes or PreparacionDeLosUtiles.se_prepara(util, jornada)
		assert_bool(antes).is_true()


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
