## La carga en segundo plano, con una escena chica en lugar del almacén.
extends GdUnitTestSuite

const ESCENA_CHICA := "res://src/ui/interrupciones/pantalla_de_cierre.tscn"
const RUTA_QUE_NO_EXISTE := "res://no_existe.tscn"
const CUADROS_DE_ESPERA := 600
const CUADROS_DESPUES := 10

var _listas: Array[PackedScene] = []
var _fallos: int = 0


func _carga() -> CargaEnSegundoPlano:
	_listas.clear()
	_fallos = 0
	var carga: CargaEnSegundoPlano = auto_free(CargaEnSegundoPlano.new())
	carga.lista.connect(func(escena: PackedScene) -> void: _listas.append(escena))
	carga.fallo.connect(func() -> void: _fallos += 1)
	add_child(carga)
	return carga


func _esperar_respuestas(cuantas: int) -> void:
	for i: int in CUADROS_DE_ESPERA:
		if _listas.size() + _fallos >= cuantas:
			break
		await get_tree().process_frame
	for i: int in CUADROS_DESPUES:
		await get_tree().process_frame


func test_sin_pedido_el_progreso_es_cero() -> void:
	assert_float(_carga().progreso()).is_equal(0.0)


func test_una_escena_que_existe_emite_lista_una_sola_vez() -> void:
	var carga := _carga()
	carga.pedir(ESCENA_CHICA)
	await _esperar_respuestas(1)
	assert_int(_listas.size()).is_equal(1)
	assert_str(_listas[0].resource_path).is_equal(ESCENA_CHICA)
	assert_int(_fallos).is_equal(0)
	assert_float(carga.progreso()).is_equal(1.0)


func test_una_ruta_que_no_existe_emite_fallo_una_sola_vez() -> void:
	_carga().pedir(RUTA_QUE_NO_EXISTE)
	await _esperar_respuestas(1)
	assert_int(_fallos).is_equal(1)
	assert_int(_listas.size()).is_equal(0)


func test_un_pedido_con_la_carga_en_curso_no_arranca_otra() -> void:
	var carga := _carga()
	carga.pedir(ESCENA_CHICA)
	carga.pedir(ESCENA_CHICA)
	carga.pedir(RUTA_QUE_NO_EXISTE)
	await _esperar_respuestas(2)
	assert_int(_listas.size()).is_equal(1)
	assert_int(_fallos).is_equal(0)


func test_despues_de_un_fallo_un_pedido_nuevo_vuelve_a_emitir() -> void:
	var carga := _carga()
	carga.pedir(RUTA_QUE_NO_EXISTE)
	await _esperar_respuestas(1)
	carga.pedir(RUTA_QUE_NO_EXISTE)
	await _esperar_respuestas(2)
	assert_int(_fallos).is_equal(2)
	carga.pedir(ESCENA_CHICA)
	await _esperar_respuestas(3)
	assert_int(_listas.size()).is_equal(1)


func test_liberarla_con_la_carga_en_curso_no_deja_la_carga_colgada() -> void:
	var carga := CargaEnSegundoPlano.new()
	carga.pedir(ESCENA_CHICA)
	carga.free()
	var estado := ResourceLoader.load_threaded_get_status(ESCENA_CHICA)
	assert_int(estado).is_equal(ResourceLoader.THREAD_LOAD_INVALID_RESOURCE)
