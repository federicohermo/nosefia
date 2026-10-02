## Los valores fijos de limpiar: qué jabón borra cada mancha, cómo se nombra cada útil y de qué
## color se ve cada cosa.
##
## **Ningún caso afirma un color exacto**: afirman lo que el jugador tiene que poder leer. Un test
## que dijera `Color(0.3, 0.46, 0.16)` se pondría en rojo al retocar un tono sin que nada esté mal.
extends GdUnitTestSuite

## Cuánto pueden separarse los tres canales de un gris, y lo más claro que puede ser un marrón.
const TOLERANCIA_DEL_GRIS := 0.05
const LO_MAS_CLARO_DEL_MARRON := 0.5
## Lo más oscuro que puede ser un canal del agua celeste: «bien clara», dice la ficha.
const LO_MAS_OSCURO_DEL_CELESTE := 0.6


func test_cada_jabon_borra_un_solo_tipo_de_mancha() -> void:  # AC-CLN-014
	# Un solo jabón por tipo y un tipo por jabón: con dos tipos que pidieran el mismo, un balde
	# alcanzaría para dos manchas distintas y el viaje al inodoro se ahorraría sin que nada avise.
	var pedidos := {}
	for tipo: ReglasDeLaLimpieza.TipoDeMancha in ReglasDeLaLimpieza.TipoDeMancha.values():
		assert_bool(ReglasDeLaLimpieza.AGUA_QUE_BORRA.has(tipo)).is_true()
		pedidos[ReglasDeLaLimpieza.AGUA_QUE_BORRA[tipo]] = tipo
	assert_int(pedidos.size()).is_equal(ReglasDeLaLimpieza.TipoDeMancha.size())
	var borra := ReglasDeLaLimpieza.AGUA_QUE_BORRA
	assert_int(borra[ReglasDeLaLimpieza.TipoDeMancha.MOHO]).is_equal(ReglasDeLaLimpieza.Agua.AZUL)
	assert_int(borra[ReglasDeLaLimpieza.TipoDeMancha.CACA]).is_equal(ReglasDeLaLimpieza.Agua.ROSA)
	assert_int(borra[ReglasDeLaLimpieza.TipoDeMancha.POLVO]).is_equal(
		ReglasDeLaLimpieza.Agua.AMARILLO
	)


func test_ninguna_mancha_se_borra_con_agua_sola_ni_con_la_mopa_seca() -> void:  # AC-CLN-014
	for tipo: ReglasDeLaLimpieza.TipoDeMancha in ReglasDeLaLimpieza.TipoDeMancha.values():
		var pedida: ReglasDeLaLimpieza.Agua = ReglasDeLaLimpieza.AGUA_QUE_BORRA[tipo]
		assert_int(pedida).is_not_equal(ReglasDeLaLimpieza.Agua.NINGUNA)
		assert_int(pedida).is_not_equal(ReglasDeLaLimpieza.Agua.LIMPIA)


func test_cada_jabon_se_reconoce_por_su_id_y_lo_demas_no_tine() -> void:
	# El `id` es el que declara el `.tres` del bidón, y la mano entra como `id`: si no coincidieran,
	# el jabón no teñiría nunca y el balde se quedaría celeste sin un solo error.
	var tintes := {}
	for id: StringName in ReglasDeLaLimpieza.JABONES:
		tintes[ReglasDeLaLimpieza.agua_del_jabon(id)] = id
	(
		assert_array(tintes.keys())
		. contains_exactly_in_any_order(
			[
				ReglasDeLaLimpieza.Agua.AZUL,
				ReglasDeLaLimpieza.Agua.ROSA,
				ReglasDeLaLimpieza.Agua.AMARILLO,
			]
		)
	)
	for otro: StringName in [
		ReglasDeLaLimpieza.ID_DE_LA_MOPA,
		ReglasDeLaLimpieza.ID_DEL_BALDE,
		ObjetoDelAlmacen.SIN_ID,
		&"lata_de_tomate",
	]:
		assert_int(ReglasDeLaLimpieza.agua_del_jabon(otro)).is_equal(
			ReglasDeLaLimpieza.Agua.NINGUNA
		)


func test_los_ids_de_la_limpieza_son_distintos_y_ninguno_es_la_mano_vacia() -> void:
	# Con `SIN_ID` como `id` de la mopa, limpiar con las manos vacías funcionaría.
	var ids: Array[StringName] = [
		ReglasDeLaLimpieza.ID_DE_LA_MOPA,
		ReglasDeLaLimpieza.ID_DEL_BALDE,
		ReglasDeLaLimpieza.ID_DEL_LAVATORIO,
		ReglasDeLaLimpieza.ID_DEL_INODORO,
		Uso.MANCHA,
	]
	for id: StringName in ReglasDeLaLimpieza.JABONES:
		ids.append(id)
	var distintos := {}
	for id in ids:
		assert_str(String(id)).is_not_equal(String(ObjetoDelAlmacen.SIN_ID))
		distintos[id] = true
	assert_int(distintos.size()).is_equal(ids.size())


func test_cada_tipo_de_mancha_se_ve_de_su_color() -> void:  # AC-CLN-015
	var colores := ReglasDeLaLimpieza.COLOR_DE_LA_MANCHA
	var moho: Color = colores[ReglasDeLaLimpieza.TipoDeMancha.MOHO]
	assert_float(moho.g).is_greater(moho.r)
	assert_float(moho.g).is_greater(moho.b)
	var caca: Color = colores[ReglasDeLaLimpieza.TipoDeMancha.CACA]
	assert_float(caca.r).is_greater(caca.g)
	assert_float(caca.g).is_greater(caca.b)
	assert_float(caca.v).is_less(LO_MAS_CLARO_DEL_MARRON)
	var polvo: Color = colores[ReglasDeLaLimpieza.TipoDeMancha.POLVO]
	assert_float(absf(polvo.r - polvo.g)).is_less(TOLERANCIA_DEL_GRIS)
	assert_float(absf(polvo.g - polvo.b)).is_less(TOLERANCIA_DEL_GRIS)
	assert_float(absf(polvo.r - polvo.b)).is_less(TOLERANCIA_DEL_GRIS)


func test_el_agua_sin_jabon_es_celeste_y_bien_clara() -> void:  # AC-CLN-019
	var agua: Color = ReglasDeLaLimpieza.COLOR_DEL_AGUA[ReglasDeLaLimpieza.Agua.LIMPIA]
	assert_float(agua.b).is_greater_equal(agua.g)
	assert_float(agua.b).is_greater(agua.r)
	for canal: float in [agua.r, agua.g, agua.b]:
		assert_float(canal).is_greater_equal(LO_MAS_OSCURO_DEL_CELESTE)


func test_el_agua_de_cada_jabon_se_distingue_de_las_demas() -> void:  # AC-CLN-020
	# Es lo único que dice qué jabón tiene el balde: dos aguas iguales serían dos jabones que el
	# jugador no puede distinguir mirando.
	var colores: Array[Color] = []
	for agua: ReglasDeLaLimpieza.Agua in [
		ReglasDeLaLimpieza.Agua.LIMPIA,
		ReglasDeLaLimpieza.Agua.AZUL,
		ReglasDeLaLimpieza.Agua.ROSA,
		ReglasDeLaLimpieza.Agua.AMARILLO,
	]:
		assert_bool(ReglasDeLaLimpieza.COLOR_DEL_AGUA.has(agua)).is_true()
		var color: Color = ReglasDeLaLimpieza.COLOR_DEL_AGUA[agua]
		for otro in colores:
			assert_bool(color.is_equal_approx(otro)).is_false()
		colores.append(color)


func test_cada_util_carga_con_el_id_de_su_constante_y_se_levanta() -> void:  # AC-CLN-018
	# Un `id` que no coincide no rompe nada: el gesto simplemente no pasa nunca. Es la única forma
	# de que el `.tres` de cada útil y la regla que lo nombra no se separen en silencio.
	var utiles := {
		"mopa": ReglasDeLaLimpieza.ID_DE_LA_MOPA,
		"balde": ReglasDeLaLimpieza.ID_DEL_BALDE,
	}
	for id: StringName in ReglasDeLaLimpieza.JABONES:
		utiles[String(id)] = id
	for archivo: String in utiles:
		var datos := load("res://src/dominio/almacen/%s.tres" % archivo) as ObjetoDelAlmacen
		(
			assert_object(datos)
			. override_failure_message("`%s.tres` no carga o no es un objeto del almacén" % archivo)
			. is_not_null()
		)
		if datos == null:
			continue
		assert_str(String(datos.id)).is_equal(String(utiles[archivo]))
		assert_bool(datos.es_levantable()).is_true()


func test_el_balde_se_lleva_inclinado_treinta_grados_hacia_la_vista() -> void:  # AC-PLY-050
	# Positiva es la boca hacia la vista: al revés, el agua queda del lado de afuera y no se ve.
	var inclinacion := rad_to_deg(ReglasDeLaLimpieza.INCLINACION_DEL_BALDE_EN_LA_MANO)
	assert_float(inclinacion).is_equal_approx(30.0, 0.001)
