## El piso del local: las cuatro zonas, el trapeador y cuándo la tarea queda hecha.
##
## **Ni un `Node3D` en toda la suite.** Todo lo que un criterio de este spec afirma se ejerce acá,
## sin poner una sola mancha en la escena: es lo que hace que `mancha_en_el_piso.gd` pueda ser
## cáscara.
extends GdUnitTestSuite

## Un `id` que no es el del trapeador. Es la forma en que llega «tengo otra cosa en la mano».
const ID_DE_OTRO_OBJETO := &"caja_de_fideos"


func _piso() -> PisoDelLocal:
	return PisoDelLocal.de_la_jornada()


## Pasa el trapeador hasta dejar esa zona limpia, y devuelve el último resultado.
func _limpiar(piso: PisoDelLocal, zona: PisoDelLocal.Zona) -> PisoDelLocal.Resultado:
	var ultimo := PisoDelLocal.Resultado.YA_ESTABA_LIMPIA
	for _pasada in range(ReglasDeLaLimpieza.PASADAS_POR_MANCHA):
		ultimo = piso.pasar(zona, ReglasDeLaLimpieza.ID_DEL_TRAPEADOR)
	return ultimo


func test_la_jornada_arranca_con_una_mancha_por_zona() -> void:  # 014-AC3
	# Se cuenta contra el `enum` y nunca contra un `4` escrito acá: una quinta zona es una línea
	# en el `enum`, y una zona sin mancha sería un rincón que el jugador no tiene que visitar.
	var piso := _piso()
	assert_int(piso.zonas().size()).is_equal(PisoDelLocal.Zona.size())
	for zona: PisoDelLocal.Zona in PisoDelLocal.Zona.values():
		(
			assert_object(piso.mancha_de(zona))
			. override_failure_message("la zona %d arrancó sin mancha" % zona)
			. is_not_null()
		)


func test_las_pasadas_totales_salen_de_multiplicar_y_no_de_una_cuenta_a_mano() -> void:
	# 014-AC3
	# Un `12` escrito quedaría viejo el día que se agregue una zona o se rebalanceen las pasadas,
	# y el número seguiría pareciendo correcto.
	assert_int(_piso().pasadas_totales()).is_equal(
		PisoDelLocal.Zona.size() * ReglasDeLaLimpieza.PASADAS_POR_MANCHA
	)


func test_una_pasada_con_el_trapeador_es_una_pasada() -> void:  # 014-AC4
	var piso := _piso()
	assert_int(piso.pasar(PisoDelLocal.Zona.ENTRADA, ReglasDeLaLimpieza.ID_DEL_TRAPEADOR)).is_equal(
		PisoDelLocal.Resultado.PASADA
	)


func test_la_ultima_pasada_de_una_zona_avisa_que_la_mancha_desaparecio() -> void:  # 014-AC4
	# Son dos cosas distintas adelante del jugador —una mancha que se aclara y una que
	# desaparece— y aplanarlas daría un solo cartel para las dos.
	var piso := _piso()
	assert_int(_limpiar(piso, PisoDelLocal.Zona.ENTRADA)).is_equal(
		PisoDelLocal.Resultado.MANCHA_LIMPIADA
	)


func test_con_las_manos_vacias_no_se_limpia_nada() -> void:  # 014-AC5
	var piso := _piso()
	var antes := piso.pasadas_restantes(PisoDelLocal.Zona.ENTRADA)
	assert_int(piso.pasar(PisoDelLocal.Zona.ENTRADA, ObjetoDelAlmacen.SIN_ID)).is_equal(
		PisoDelLocal.Resultado.SIN_TRAPEADOR
	)
	assert_int(piso.pasadas_restantes(PisoDelLocal.Zona.ENTRADA)).is_equal(antes)


func test_con_otro_objeto_en_la_mano_tampoco() -> void:  # 014-AC5
	# Limpiar con la lata en la mano sería limpiar gratis: el trapeador ocupa la única mano, y
	# ésa es la mitad de la tarea que la vuelve imposible de intercalar.
	var piso := _piso()
	var antes := piso.pasadas_restantes(PisoDelLocal.Zona.PASILLO)
	assert_int(piso.pasar(PisoDelLocal.Zona.PASILLO, ID_DE_OTRO_OBJETO)).is_equal(
		PisoDelLocal.Resultado.SIN_TRAPEADOR
	)
	assert_int(piso.pasadas_restantes(PisoDelLocal.Zona.PASILLO)).is_equal(antes)


func test_sobre_una_zona_ya_limpia_avisa_que_ya_estaba_limpia() -> void:  # 014-AC5
	var piso := _piso()
	_limpiar(piso, PisoDelLocal.Zona.ENTRADA)
	assert_int(piso.pasar(PisoDelLocal.Zona.ENTRADA, ReglasDeLaLimpieza.ID_DEL_TRAPEADOR)).is_equal(
		PisoDelLocal.Resultado.YA_ESTABA_LIMPIA
	)


func test_el_piso_queda_limpio_recien_con_la_ultima_pasada_de_la_ultima_zona() -> void:
	# 014-AC6
	# Machacar sobre una mancha limpia no cierra nada: hay que haber estado en las cuatro zonas.
	var piso := _piso()
	var zonas := PisoDelLocal.Zona.values()
	for indice in range(zonas.size() - 1):
		_limpiar(piso, zonas[indice])
		(
			assert_bool(piso.esta_limpio())
			. override_failure_message(
				"el piso quedó limpio con %d de %d zonas" % [indice + 1, zonas.size()]
			)
			. is_false()
		)
	_limpiar(piso, zonas[-1])
	assert_bool(piso.esta_limpio()).is_true()


func test_una_zona_se_puede_dejar_por_la_mitad_y_retomar() -> void:  # 014-AC6
	# **Es la mitad que vuelve a limpiar parte de la tensión**: dos pasadas, irse a otra zona,
	# volver, y la mancha sigue esperando en una. Con una barra que hay que mantener apretada
	# esto no se podría escribir.
	var piso := _piso()
	piso.pasar(PisoDelLocal.Zona.PASILLO, ReglasDeLaLimpieza.ID_DEL_TRAPEADOR)
	piso.pasar(PisoDelLocal.Zona.PASILLO, ReglasDeLaLimpieza.ID_DEL_TRAPEADOR)
	piso.pasar(PisoDelLocal.Zona.DEPOSITO, ReglasDeLaLimpieza.ID_DEL_TRAPEADOR)
	var faltan := ReglasDeLaLimpieza.PASADAS_POR_MANCHA - 2
	assert_int(piso.pasadas_restantes(PisoDelLocal.Zona.PASILLO)).is_equal(faltan)
	assert_bool(piso.esta_limpio()).is_false()


func test_cada_jornada_arranca_con_el_piso_sucio() -> void:  # 014-AC6
	# Instancias nuevas y no las mismas: con un piso compartido, lo limpiado anoche llegaría
	# limpio esta noche y la obligatoria se cumpliría sola a partir de la segunda.
	var una := _piso()
	_limpiar(una, PisoDelLocal.Zona.ENTRADA)
	var otra := _piso()
	assert_int(otra.pasadas_restantes(PisoDelLocal.Zona.ENTRADA)).is_equal(
		ReglasDeLaLimpieza.PASADAS_POR_MANCHA
	)
