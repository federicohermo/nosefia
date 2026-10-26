extends GdUnitTestSuite

const ReglasDelCierre := preload("res://src/dominio/almacen/reglas_del_cierre.gd")
const CLASE := ReglasDelCierre.Clase
const HABITACION := ReglasDelCierre.Habitacion
const JORNADA_COMUN := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA


func test_una_lista_vacia_no_produce_motivos() -> void:  # AC-CLN-042
	var estados: Array[ReglasDelCierre.Estado] = []
	assert_bool(ReglasDelCierre.hay_desorden(estados, JORNADA_COMUN)).is_false()
	assert_bool(ReglasDelCierre.hay_objetos_afuera(estados)).is_false()


func test_una_unidad_suelta_desordena_cualquier_habitacion() -> void:  # AC-CLN-041
	var desorden: Array[bool] = [true, true, true, false, true]
	for habitacion: ReglasDelCierre.Habitacion in HABITACION.values():
		for en_mano: bool in [false, true]:
			var estados: Array[ReglasDelCierre.Estado] = [
				ReglasDelCierre.Estado.new(CLASE.UNIDAD_SUELTA, habitacion, en_mano)
			]
			assert_bool(ReglasDelCierre.hay_desorden(estados, JORNADA_COMUN)).is_equal(
				desorden[habitacion] and not en_mano
			)
			assert_bool(ReglasDelCierre.hay_objetos_afuera(estados)).is_equal(
				habitacion == HABITACION.AFUERA and not en_mano
			)


func test_una_caja_sola_queda_ordenada_en_el_deposito_y_en_el_local() -> void:  # AC-CLN-042
	var desorden: Array[bool] = [false, false, true, false, true]
	for habitacion: ReglasDelCierre.Habitacion in HABITACION.values():
		for en_mano: bool in [false, true]:
			var estados: Array[ReglasDelCierre.Estado] = [
				ReglasDelCierre.Estado.new(CLASE.CAJA, habitacion, en_mano)
			]
			assert_bool(ReglasDelCierre.hay_desorden(estados, JORNADA_COMUN)).is_equal(
				desorden[habitacion] and not en_mano
			)
			assert_bool(ReglasDelCierre.hay_objetos_afuera(estados)).is_equal(
				habitacion == HABITACION.AFUERA and not en_mano
			)


func test_un_util_solo_queda_ordenado_en_el_cuartito() -> void:  # AC-CLN-042
	var desorden: Array[bool] = [true, true, true, false, false]
	for habitacion: ReglasDelCierre.Habitacion in HABITACION.values():
		for en_mano: bool in [false, true]:
			var estados: Array[ReglasDelCierre.Estado] = [
				ReglasDelCierre.Estado.new(CLASE.UTIL_DE_LIMPIEZA, habitacion, en_mano)
			]
			assert_bool(ReglasDelCierre.hay_desorden(estados, JORNADA_COMUN)).is_equal(
				desorden[habitacion] and not en_mano
			)
			assert_bool(ReglasDelCierre.hay_objetos_afuera(estados)).is_equal(
				habitacion == HABITACION.AFUERA and not en_mano
			)


func test_los_otros_objetos_adentro_no_producen_desorden() -> void:  # AC-CLN-042, AC-CLN-044
	var desorden: Array[bool] = [false, false, false, false, false]
	for habitacion: ReglasDelCierre.Habitacion in HABITACION.values():
		for en_mano: bool in [false, true]:
			var estados: Array[ReglasDelCierre.Estado] = [
				ReglasDelCierre.Estado.new(CLASE.OTRO, habitacion, en_mano)
			]
			assert_bool(ReglasDelCierre.hay_desorden(estados, JORNADA_COMUN)).is_equal(
				desorden[habitacion] and not en_mano
			)
			assert_bool(ReglasDelCierre.hay_objetos_afuera(estados)).is_equal(
				habitacion == HABITACION.AFUERA and not en_mano
			)


func test_un_mismo_cierre_puede_tener_desorden_y_objetos_afuera() -> void:  # AC-CLN-046
	var estados: Array[ReglasDelCierre.Estado] = [
		ReglasDelCierre.Estado.new(CLASE.CAJA, HABITACION.BANO, false),
		ReglasDelCierre.Estado.new(CLASE.UNIDAD_SUELTA, HABITACION.AFUERA, false),
	]
	assert_bool(ReglasDelCierre.hay_desorden(estados, JORNADA_COMUN)).is_true()
	assert_bool(ReglasDelCierre.hay_objetos_afuera(estados)).is_true()
	estados.reverse()
	assert_bool(ReglasDelCierre.hay_desorden(estados, JORNADA_COMUN)).is_true()
	assert_bool(ReglasDelCierre.hay_objetos_afuera(estados)).is_true()


func test_una_bolsa_afuera_se_distingue_de_otro_objeto_afuera() -> void:  # AC-EMP-096
	for habitacion: ReglasDelCierre.Habitacion in HABITACION.values():
		for en_mano: bool in [false, true]:
			var estados: Array[ReglasDelCierre.Estado] = [
				ReglasDelCierre.Estado.new(CLASE.BOLSA, habitacion, en_mano)
			]
			assert_bool(ReglasDelCierre.hay_bolsa_afuera(estados)).is_equal(
				habitacion == HABITACION.AFUERA and not en_mano
			)
			assert_bool(ReglasDelCierre.hay_desorden(estados, JORNADA_COMUN)).is_false()
	for clase: ReglasDelCierre.Clase in [CLASE.CAJA, CLASE.UNIDAD_SUELTA, CLASE.OTRO]:
		var sin_bolsa: Array[ReglasDelCierre.Estado] = [
			ReglasDelCierre.Estado.new(clase, HABITACION.AFUERA, false)
		]
		assert_bool(ReglasDelCierre.hay_bolsa_afuera(sin_bolsa)).is_false()


func test_una_bolsa_afuera_entre_varios_cuerpos_se_encuentra() -> void:  # AC-EMP-096
	var estados: Array[ReglasDelCierre.Estado] = [
		ReglasDelCierre.Estado.new(CLASE.CAJA, HABITACION.AFUERA, false),
		ReglasDelCierre.Estado.new(CLASE.BOLSA, HABITACION.LOCAL, false),
		ReglasDelCierre.Estado.new(CLASE.BOLSA, HABITACION.AFUERA, false),
	]
	assert_bool(ReglasDelCierre.hay_bolsa_afuera(estados)).is_true()


func test_la_pertenencia_sale_del_punto_y_de_las_cuatro_regiones() -> void:  # AC-CLN-040
	var local: Array[AABB] = [AABB(Vector3.ZERO, Vector3(2, 3, 2))]
	var deposito: Array[AABB] = [AABB(Vector3(3, 0, 0), Vector3(2, 3, 2))]
	var bano: Array[AABB] = [AABB(Vector3(6, 0, 0), Vector3(2, 3, 2))]
	var cuartito: Array[AABB] = [AABB(Vector3(9, 0, 0), Vector3(2, 3, 2))]
	(
		assert_int(ReglasDelCierre.habitacion_de(Vector3(1, 1, 1), local, deposito, bano, cuartito))
		. is_equal(HABITACION.LOCAL)
	)
	(
		assert_int(ReglasDelCierre.habitacion_de(Vector3(4, 1, 1), local, deposito, bano, cuartito))
		. is_equal(HABITACION.DEPOSITO)
	)
	(
		assert_int(ReglasDelCierre.habitacion_de(Vector3(7, 1, 1), local, deposito, bano, cuartito))
		. is_equal(HABITACION.BANO)
	)
	(
		assert_int(
			ReglasDelCierre.habitacion_de(Vector3(10, 1, 1), local, deposito, bano, cuartito)
		)
		. is_equal(HABITACION.CUARTITO)
	)
	for afuera: Vector3 in [Vector3(-1, 1, 1), Vector3(1, -1, 1), Vector3(1, 4, 1)]:
		assert_int(ReglasDelCierre.habitacion_de(afuera, local, deposito, bano, cuartito)).is_equal(
			HABITACION.AFUERA
		)


func test_sin_regiones_declaradas_el_punto_queda_afuera() -> void:  # AC-CLN-040
	var vacia: Array[AABB] = []
	assert_int(ReglasDelCierre.habitacion_de(Vector3.ZERO, vacia, vacia, vacia, vacia)).is_equal(
		HABITACION.AFUERA
	)


func test_dos_partes_separadas_no_incluyen_el_hueco_entre_ellas() -> void:  # AC-CLN-040
	var vacia: Array[AABB] = []
	var bano: Array[AABB] = [
		AABB(Vector3.ZERO, Vector3(1, 2, 1)),
		AABB(Vector3(3, 0, 0), Vector3(1, 2, 1)),
	]
	for parte: AABB in bano:
		(
			assert_int(ReglasDelCierre.habitacion_de(parte.get_center(), vacia, vacia, bano, vacia))
			. is_equal(HABITACION.BANO)
		)
	var hueco := Vector3(2, 1, 0.5)
	assert_bool(bano[0].has_point(hueco)).is_false()
	assert_bool(bano[1].has_point(hueco)).is_false()
	assert_bool(bano[0].merge(bano[1]).has_point(hueco)).is_true()
	assert_int(ReglasDelCierre.habitacion_de(hueco, vacia, vacia, bano, vacia)).is_equal(
		HABITACION.AFUERA
	)


func test_el_techo_alto_y_el_paso_no_agrandan_el_resto_del_bano() -> void:  # AC-CLN-040
	var vacia: Array[AABB] = []
	var bano: Array[AABB] = [
		AABB(Vector3.ZERO, Vector3(2, 2, 2)),
		AABB(Vector3(0, 0, 2), Vector3(2, 4, 2)),
		AABB(Vector3(2, 0, 2.75), Vector3(1, 2, 0.5)),
	]
	for parte: AABB in bano:
		(
			assert_int(ReglasDelCierre.habitacion_de(parte.get_center(), vacia, vacia, bano, vacia))
			. is_equal(HABITACION.BANO)
		)
	var envolvente := bano[0].merge(bano[1]).merge(bano[2])
	for afuera: Vector3 in [Vector3(1, 3, 1), Vector3(2.5, 1, 2.5)]:
		for parte: AABB in bano:
			assert_bool(parte.has_point(afuera)).is_false()
		assert_bool(envolvente.has_point(afuera)).is_true()
		assert_int(ReglasDelCierre.habitacion_de(afuera, vacia, vacia, bano, vacia)).is_equal(
			HABITACION.AFUERA
		)


func test_solo_las_bolsas_y_los_tickets_se_tiran_sin_llamado() -> void:  # AC-CLN-050
	for id: StringName in ReglasDeLaBasura.ids_de_las_bolsas():
		var bolsa := ObjetoDelAlmacen.new()
		bolsa.id = id
		assert_bool(ReglasDelCierre.esta_eximido(bolsa, false)).is_true()
	var productos: Array[Producto] = [Catalogo.de(Producto.Id.ACTRONCITO)]
	assert_bool(ReglasDelCierre.esta_eximido(Ticket.new(productos), false)).is_true()


func test_unidad_utiles_y_datos_ausentes_no_son_exentos() -> void:  # AC-CLN-050
	assert_bool(ReglasDelCierre.esta_eximido(null, false)).is_false()
	var unidad := UnidadDeProducto.new(Catalogo.de(Producto.Id.ACTRONCITO))
	assert_bool(ReglasDelCierre.esta_eximido(unidad, false)).is_false()
	var ids: Array[StringName] = [ReglasDeLaLimpieza.ID_DE_LA_MOPA, ReglasDeLaLimpieza.ID_DEL_BALDE]
	ids.append_array(ReglasDeLaLimpieza.JABONES.keys())
	for id: StringName in ids:
		var util := ObjetoDelAlmacen.new()
		util.id = id
		assert_bool(ReglasDelCierre.esta_eximido(util, false)).is_false()


func test_las_cajas_toleradas_en_el_local_no_desordenan_y_una_mas_si() -> void:  # AC-CLN-070
	var toleradas := ReglasDelCierre.CAJAS_TOLERADAS_EN_EL_LOCAL
	var estados: Array[ReglasDelCierre.Estado] = [_caja(HABITACION.DEPOSITO)]
	for _caja_en_el_local in toleradas:
		estados.append(_caja(HABITACION.LOCAL))
	assert_bool(ReglasDelCierre.hay_desorden(estados, JORNADA_COMUN)).is_false()
	estados.append(_caja(HABITACION.LOCAL))
	assert_bool(ReglasDelCierre.hay_desorden(estados, JORNADA_COMUN)).is_true()


func test_una_caja_en_el_bano_desordena_sola_o_con_otra_en_el_local() -> void:  # AC-CLN-070
	var sola: Array[ReglasDelCierre.Estado] = [_caja(HABITACION.BANO)]
	assert_bool(ReglasDelCierre.hay_desorden(sola, JORNADA_COMUN)).is_true()
	var con_una_en_el_local: Array[ReglasDelCierre.Estado] = [
		_caja(HABITACION.LOCAL), _caja(HABITACION.BANO)
	]
	assert_bool(ReglasDelCierre.hay_desorden(con_una_en_el_local, JORNADA_COMUN)).is_true()
	con_una_en_el_local.reverse()
	assert_bool(ReglasDelCierre.hay_desorden(con_una_en_el_local, JORNADA_COMUN)).is_true()


func test_la_caja_sostenida_ocupa_la_unica_permitida() -> void:  # AC-CLN-070
	var sola: Array[ReglasDelCierre.Estado] = [_caja(HABITACION.LOCAL, true)]
	assert_bool(ReglasDelCierre.hay_desorden(sola, JORNADA_COMUN)).is_false()
	var con_una_en_el_deposito: Array[ReglasDelCierre.Estado] = [
		_caja(HABITACION.DEPOSITO), _caja(HABITACION.LOCAL, true)
	]
	assert_bool(ReglasDelCierre.hay_desorden(con_una_en_el_deposito, JORNADA_COMUN)).is_false()
	var en_el_bano: Array[ReglasDelCierre.Estado] = [_caja(HABITACION.BANO, true)]
	assert_bool(ReglasDelCierre.hay_desorden(en_el_bano, JORNADA_COMUN)).is_false()
	var con_una_en_el_local: Array[ReglasDelCierre.Estado] = [
		_caja(HABITACION.LOCAL), _caja(HABITACION.LOCAL, true)
	]
	assert_bool(ReglasDelCierre.hay_desorden(con_una_en_el_local, JORNADA_COMUN)).is_true()
	con_una_en_el_local.reverse()
	assert_bool(ReglasDelCierre.hay_desorden(con_una_en_el_local, JORNADA_COMUN)).is_true()


func test_otro_cuerpo_sostenido_no_ocupa_la_permitida() -> void:  # AC-CLN-070
	var estados: Array[ReglasDelCierre.Estado] = [
		_caja(HABITACION.LOCAL),
		ReglasDelCierre.Estado.new(CLASE.UTIL_DE_LIMPIEZA, HABITACION.LOCAL, true),
	]
	assert_bool(ReglasDelCierre.hay_desorden(estados, JORNADA_COMUN)).is_false()


func test_una_caja_tolerada_no_tapa_una_unidad_suelta() -> void:  # AC-CLN-070
	var estados: Array[ReglasDelCierre.Estado] = [
		_caja(HABITACION.LOCAL),
		ReglasDelCierre.Estado.new(CLASE.UNIDAD_SUELTA, HABITACION.DEPOSITO, false)
	]
	assert_bool(ReglasDelCierre.hay_desorden(estados, JORNADA_COMUN)).is_true()
	estados.reverse()
	assert_bool(ReglasDelCierre.hay_desorden(estados, JORNADA_COMUN)).is_true()


func _caja(habitacion: ReglasDelCierre.Habitacion, en_mano: bool = false) -> ReglasDelCierre.Estado:
	return ReglasDelCierre.Estado.new(CLASE.CAJA, habitacion, en_mano)
