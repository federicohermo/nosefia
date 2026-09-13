## La obligatoria de la basura: qué bolsa cuenta, dónde, y qué pasa si se deja a mitad de camino.
##
## **Ni un `Node3D` en toda la suite.** La posición entra como número, igual que el tiempo en el
## 001: es lo que hace que «la regla depende de una distancia física» no obligue al dominio a
## saber de física.
extends GdUnitTestSuite

## Una distancia bien adentro de la zona y otra bien afuera, para que ningún caso dependa de
## dónde está exactamente el borde — de eso habla `trayecto_test.gd`.
const ADENTRO := 0.0
const AFUERA := 50.0

const ID_AJENO := &"caja_de_fideos"


func _tarea() -> TareaDeLaBasura:
	return TareaDeLaBasura.de_la_jornada()


func _ids() -> Array[StringName]:
	return ReglasDeLaBasura.ids_de_las_bolsas()


func test_la_jornada_arranca_con_las_bolsas_del_balance_y_ninguna_depositada() -> void:
	# 015-AC4
	var tarea := _tarea()
	assert_int(tarea.bolsas()).is_equal(ReglasDeLaBasura.BOLSAS_DE_LA_JORNADA)
	assert_int(tarea.depositadas()).is_equal(0)
	assert_bool(tarea.completada()).is_false()


func test_lejos_del_descarte_no_cuenta() -> void:  # 015-AC4
	# **La posición decide**: es la mitad del spec que impide resolver la tarea sin caminar.
	var tarea := _tarea()
	assert_int(tarea.depositar(_ids()[0], AFUERA)).is_equal(
		TareaDeLaBasura.Resultado.FUERA_DE_LA_ZONA
	)
	assert_int(tarea.depositadas()).is_equal(0)


func test_dejarla_a_mitad_de_camino_no_la_quema() -> void:  # 015-AC4
	# La misma bolsa, adentro, sí deposita. Sin esto un tropiezo en el pasillo dejaría la
	# obligatoria imposible de cerrar esa noche y el jugador sin saber por qué.
	var tarea := _tarea()
	var bolsa := _ids()[0]
	tarea.depositar(bolsa, AFUERA)
	assert_int(tarea.depositar(bolsa, ADENTRO)).is_equal(TareaDeLaBasura.Resultado.DEPOSITADA)
	assert_int(tarea.depositadas()).is_equal(1)


func test_la_misma_bolsa_dos_veces_no_cuenta_dos() -> void:  # 015-AC4
	# Con `id` repetidos contando de a dos, la tarea se cerraría llevando una sola bolsa al
	# fondo y volviendo a soltarla — o sea, sin los tres viajes.
	var tarea := _tarea()
	var bolsa := _ids()[0]
	assert_int(tarea.depositar(bolsa, ADENTRO)).is_equal(TareaDeLaBasura.Resultado.DEPOSITADA)
	assert_int(tarea.depositar(bolsa, ADENTRO)).is_equal(TareaDeLaBasura.Resultado.YA_DEPOSITADA)
	assert_int(tarea.depositadas()).is_equal(1)


func test_un_objeto_ajeno_no_es_basura() -> void:  # 015-AC4
	var tarea := _tarea()
	assert_int(tarea.depositar(ID_AJENO, ADENTRO)).is_equal(TareaDeLaBasura.Resultado.NO_ES_BASURA)
	assert_int(tarea.depositar(ObjetoDelAlmacen.SIN_ID, ADENTRO)).is_equal(
		TareaDeLaBasura.Resultado.NO_ES_BASURA
	)
	assert_int(tarea.depositadas()).is_equal(0)


func test_la_tarea_se_completa_recien_con_la_ultima_bolsa() -> void:  # 015-AC4
	var tarea := _tarea()
	var ids := _ids()
	for indice in range(ids.size() - 1):
		tarea.depositar(ids[indice], ADENTRO)
		(
			assert_bool(tarea.completada())
			. override_failure_message(
				"la tarea se completó con %d de %d bolsas" % [indice + 1, ids.size()]
			)
			. is_false()
		)
	tarea.depositar(ids[-1], ADENTRO)
	assert_bool(tarea.completada()).is_true()


func test_cada_jornada_arranca_con_la_basura_adentro() -> void:  # 015-AC4
	# Instancias nuevas y no las mismas: con una compartida, lo depositado anoche llegaría
	# depositado esta noche y la obligatoria se cumpliría sola a partir de la segunda.
	var una := _tarea()
	una.depositar(_ids()[0], ADENTRO)
	assert_int(_tarea().depositadas()).is_equal(0)


func test_un_id_repetido_en_la_lista_no_agranda_la_tarea() -> void:  # 015-AC4
	# Con el mismo `id` dos veces, la tarea pediría dos bolsas y se cerraría con una: el jugador
	# haría un viaje menos sin que nada lo diga.
	var repetida := TareaDeLaBasura.new([&"bolsa", &"bolsa"] as Array[StringName])
	assert_int(repetida.bolsas()).is_equal(1)
