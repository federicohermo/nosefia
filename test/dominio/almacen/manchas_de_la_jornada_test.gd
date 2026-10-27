## Las manchas que trae cada jornada y cuándo queda limpia la noche: lo que no entra en la suite
## del piso, que llegó a su tope de métodos.
extends GdUnitTestSuite

const ReglasDelCierre := preload("res://src/dominio/almacen/reglas_del_cierre.gd")

const MOPA := ReglasDeLaLimpieza.ID_DE_LA_MOPA
const BALDE := ReglasDeLaLimpieza.ID_DEL_BALDE
const LAVATORIO := ReglasDeLaLimpieza.ID_DEL_LAVATORIO
const INODORO := ReglasDeLaLimpieza.ID_DEL_INODORO

const POLVO := ReglasDeLaLimpieza.TipoDeMancha.POLVO
const MOHO := ReglasDeLaLimpieza.TipoDeMancha.MOHO
const CACA := ReglasDeLaLimpieza.TipoDeMancha.CACA
const LOCAL := ReglasDelCierre.Habitacion.LOCAL
const DEPOSITO := ReglasDelCierre.Habitacion.DEPOSITO
const BANO := ReglasDelCierre.Habitacion.BANO
const CUARTITO := ReglasDelCierre.Habitacion.CUARTITO
const PISO := PisoDelLocal.Superficie.PISO
const PARED := PisoDelLocal.Superficie.PARED
const TECHO := PisoDelLocal.Superficie.TECHO

## La tabla de la ficha, fila por fila: `[tipo, habitación, superficie]` de cada mancha. Es la del
## contrato, escrita sin lugares: el caso compara qué hay, no cómo se llama cada sitio.
const FICHA := {
	3:
	[
		[POLVO, LOCAL, PISO],
		[POLVO, LOCAL, PARED],
		[MOHO, DEPOSITO, PARED],
		[CACA, BANO, PISO],
	],
	4:
	[
		[POLVO, LOCAL, PISO],
		[POLVO, LOCAL, PISO],
		[POLVO, LOCAL, PISO],
		[MOHO, DEPOSITO, PARED],
		[MOHO, DEPOSITO, PARED],
		[CACA, BANO, PISO],
		[CACA, BANO, PARED],
	],
	5:
	[
		[POLVO, LOCAL, PISO],
		[POLVO, LOCAL, PISO],
		[POLVO, LOCAL, PISO],
		[MOHO, DEPOSITO, PARED],
		[MOHO, DEPOSITO, PARED],
		[POLVO, BANO, PISO],
		[MOHO, BANO, TECHO],
		[CACA, BANO, PISO],
	],
	6:
	[
		[POLVO, LOCAL, PISO],
		[POLVO, LOCAL, PARED],
		[MOHO, LOCAL, PARED],
		[CACA, LOCAL, PISO],
		[POLVO, DEPOSITO, PISO],
		[MOHO, DEPOSITO, PARED],
		[POLVO, BANO, PISO],
		[CACA, BANO, PISO],
		[CACA, BANO, PARED],
	],
	7:
	[
		[POLVO, LOCAL, PISO],
		[POLVO, LOCAL, TECHO],
		[MOHO, LOCAL, TECHO],
		[POLVO, DEPOSITO, PISO],
		[POLVO, DEPOSITO, PISO],
		[MOHO, CUARTITO, TECHO],
		[MOHO, CUARTITO, TECHO],
		[MOHO, BANO, PARED],
		[CACA, BANO, TECHO],
		[CACA, BANO, PISO],
	],
	8:
	[
		[POLVO, LOCAL, PISO],
		[POLVO, LOCAL, PISO],
		[POLVO, LOCAL, PARED],
		[POLVO, DEPOSITO, PARED],
		[MOHO, DEPOSITO, PARED],
		[MOHO, BANO, TECHO],
		[MOHO, BANO, TECHO],
		[CACA, BANO, PISO],
		[CACA, BANO, PARED],
		[CACA, BANO, PARED],
		[CACA, BANO, PISO],
	],
}


## El jabón que borra ese tipo de mancha, sacado de las reglas y no copiado.
static func _jabon_de(
	tipo: ReglasDeLaLimpieza.TipoDeMancha, jornada: int = ReglasDeLaPartida.PRIMERA_JORNADA
) -> StringName:
	if tipo == MOHO and jornada == AnomaliasDeLaJornada.JORNADA_SIN_AZUL:
		return UnidadDeProducto.new(Catalogo.de(Producto.Id.POETICO)).id
	for jabon: StringName in ReglasDeLaLimpieza.JABONES:
		if ReglasDeLaLimpieza.JABONES[jabon] == ReglasDeLaLimpieza.AGUA_QUE_BORRA[tipo]:
			return jabon
	return &""


## Vacía el balde, lo llena, lo tiñe del jabón de esa mancha, moja la mopa y la pasa.
static func _borrar(piso: PisoDelLocal, lugar: PisoDelLocal.Lugar) -> ReglasDeLaLimpieza.Resultado:
	piso.usar(BALDE, INODORO)
	piso.usar(BALDE, LAVATORIO)
	piso.usar(_jabon_de(piso.mancha_de(lugar).tipo(), piso.jornada()), BALDE)
	piso.usar(MOPA, BALDE)
	return piso.pasar(MOPA, lugar)


## Lo que trae la jornada, como filas comparables con las de la ficha.
static func _filas(piso: PisoDelLocal) -> Array:
	var filas := []
	for lugar: PisoDelLocal.Lugar in piso.lugares():
		(
			filas
			. append(
				[
					piso.mancha_de(lugar).tipo(),
					PisoDelLocal.habitacion_de(lugar),
					PisoDelLocal.superficie_de(lugar),
				]
			)
		)
	return filas


## Cuántas manchas de polvo hay en el local en la fila de esa jornada de la ficha.
static func _polvo_del_local(jornada: int) -> int:
	var cuenta := 0
	for fila: Array in FICHA[jornada]:
		if fila[0] == POLVO and fila[1] == LOCAL:
			cuenta += 1
	return cuenta


func test_cada_jornada_trae_las_manchas_de_su_fila_en_la_ficha() -> void:  # AC-CLN-016
	for jornada: int in FICHA:
		var piso := PisoDelLocal.de_la_jornada(jornada)
		(
			assert_array(_filas(piso))
			. override_failure_message("la jornada %d no trae las manchas de la ficha" % jornada)
			. contains_exactly_in_any_order(FICHA[jornada])
		)


func test_las_ultimas_jornadas_ya_no_traen_las_de_la_cuarta() -> void:  # AC-CLN-016
	var cuarta := PisoDelLocal.de_la_jornada(4)
	for jornada: int in [6, 7, 8]:
		var piso := PisoDelLocal.de_la_jornada(jornada)
		assert_array(_filas(piso)).has_size(FICHA[jornada].size())
		assert_array(piso.lugares()).is_not_equal(cuarta.lugares())
		for lugar: PisoDelLocal.Lugar in piso.lugares():
			assert_bool(piso.mancha_de(lugar).esta_limpia()).is_false()


func test_un_lugar_que_la_noche_no_puso_no_tiene_mancha() -> void:  # AC-CLN-016
	var primera := PisoDelLocal.de_la_jornada(4)
	var segunda := PisoDelLocal.de_la_jornada(5)
	for lugar: PisoDelLocal.Lugar in segunda.lugares():
		assert_object(primera.mancha_de(lugar)).is_null()
		assert_int(primera.pasar(MOPA, lugar)).is_equal(ReglasDeLaLimpieza.Resultado.SIN_EFECTO)
	for lugar: PisoDelLocal.Lugar in primera.lugares():
		assert_object(segunda.mancha_de(lugar)).is_null()


func test_cada_lugar_declara_su_habitacion_y_su_superficie() -> void:  # AC-CLN-016
	assert_int(PisoDelLocal.LUGARES.size()).is_equal(PisoDelLocal.Lugar.size())
	for lugar: PisoDelLocal.Lugar in PisoDelLocal.Lugar.values():
		assert_int(PisoDelLocal.habitacion_de(lugar)).is_not_equal(
			ReglasDelCierre.Habitacion.AFUERA
		)
		assert_int(PisoDelLocal.superficie_de(lugar)).is_equal(PisoDelLocal.LUGARES[lugar][1])
		assert_int(PisoDelLocal.habitacion_de(lugar)).is_equal(PisoDelLocal.LUGARES[lugar][0])


func test_la_noche_queda_limpia_recien_con_su_ultima_mancha() -> void:  # AC-CLN-060
	for jornada: int in FICHA:
		var piso := PisoDelLocal.de_la_jornada(jornada)
		var lugares := piso.lugares()
		assert_int(lugares.size()).is_equal(FICHA[jornada].size())
		for indice in lugares.size():
			assert_bool(piso.esta_limpio()).is_false()
			assert_int(_borrar(piso, lugares[indice])).is_equal(
				ReglasDeLaLimpieza.Resultado.MANCHA_BORRADA
			)
		assert_bool(piso.esta_limpio()).is_true()


func test_las_del_mismo_tipo_y_habitacion_se_borran_por_separado() -> void:  # AC-CLN-060
	for jornada: int in FICHA:
		var piso := PisoDelLocal.de_la_jornada(jornada)
		var del_local: Array[PisoDelLocal.Lugar] = []
		for lugar: PisoDelLocal.Lugar in piso.lugares():
			if piso.mancha_de(lugar).tipo() == POLVO and PisoDelLocal.habitacion_de(lugar) == LOCAL:
				del_local.append(lugar)
		assert_int(del_local.size()).is_equal(_polvo_del_local(jornada))
		assert_int(_borrar(piso, del_local[0])).is_equal(
			ReglasDeLaLimpieza.Resultado.MANCHA_BORRADA
		)
		assert_bool(piso.mancha_de(del_local[1]).esta_limpia()).is_false()
		if del_local.size() == 3:
			assert_bool(piso.mancha_de(del_local[2]).esta_limpia()).is_false()
		# La misma mopa amarilla sigue sirviendo, pero cada pasada borra sólo la suya.
		assert_int(piso.pasar(MOPA, del_local[1])).is_equal(
			ReglasDeLaLimpieza.Resultado.MANCHA_BORRADA
		)
		if del_local.size() == 3:
			assert_bool(piso.mancha_de(del_local[2]).esta_limpia()).is_false()
		assert_int(piso.pasar(MOPA, del_local[0])).is_equal(
			ReglasDeLaLimpieza.Resultado.YA_ESTABA_LIMPIA
		)


func test_las_noches_que_no_piden_limpiar_abren_sin_manchas() -> void:  # AC-CLN-016
	for jornada: int in [1, 2]:
		var piso := PisoDelLocal.de_la_jornada(jornada)
		assert_array(piso.lugares()).is_empty()
		assert_bool(piso.esta_limpio()).is_true()
