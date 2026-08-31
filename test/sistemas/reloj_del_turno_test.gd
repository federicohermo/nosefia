## El reloj de la escena, ejercido sin levantar ninguna escena.
##
## Ningún caso de acá usa `scene_runner` ni entra el nodo al árbol: se instancia con
## `auto_free(RelojDelTurno.new())` y se le llama `_process()` a mano con el `delta` que se
## quiera. Eso no es un truco del test: es la prueba de que adentro del reloj no quedó ninguna
## regla del juego, porque una regla habría necesitado un frame de verdad para ejercerse.
##
## Lo que queda del presupuesto se lee del `Turno` que arma el propio test y no de un getter del
## reloj: el reloj es el único dueño del turno mientras la escena corre, y abrirle una puerta
## para mirarlo desde afuera sería exactamente lo que este spec cierra.
##
## Los turnos son chicos —`100.0`, `12.0`— y no de ocho horas: el factor de `Ritmo` los agota en
## uno o dos `_process`, así que el cierre se prueba en dos líneas.
extends GdUnitTestSuite

var _turno: Turno = null
var _cierres: int = 0
var _cumplidas_al_cerrar: int = 0
var _completadas: int = 0
var _cumplidas_al_completar: int = 0
var _consumos: int = 0
var _restante_publicado: float = 0.0


func before_test() -> void:
	_turno = null
	_cierres = 0
	_cumplidas_al_cerrar = 0
	_completadas = 0
	_cumplidas_al_completar = 0
	_consumos = 0
	_restante_publicado = 0.0


func _reloj_arrancado(presupuesto: float, obligatorias: Array[Tarea]) -> RelojDelTurno:
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	reloj.tiempo_consumido.connect(_anotar_consumo)
	reloj.tarea_completada.connect(_anotar_completada)
	reloj.turno_cerrado.connect(_anotar_cierre)
	_turno = Turno.new(presupuesto, obligatorias)
	reloj.arrancar(_turno, obligatorias)
	return reloj


func _sin_obligatorias() -> Array[Tarea]:
	var ninguna: Array[Tarea] = []
	return ninguna


func _anotar_consumo(restante: float) -> void:
	_consumos += 1
	_restante_publicado = restante


func _anotar_completada(cumplidas: int) -> void:
	_completadas += 1
	_cumplidas_al_completar = cumplidas


func _anotar_cierre(cumplidas: int) -> void:
	_cierres += 1
	_cumplidas_al_cerrar = cumplidas


func test_un_cuadro_consume_el_delta_ya_escalado_por_el_ritmo() -> void:
	# Medio segundo real son doce de turno. Que dé 88 y no 99.5 es lo que verifica que el reloj
	# escala; que no dé 76 es lo que verifica que llama a `consumir()` una vez y no dos.
	var reloj := _reloj_arrancado(100.0, _sin_obligatorias())
	reloj._process(0.5)
	assert_float(_turno.tiempo_restante()).is_equal(88.0)


func test_dos_cuadros_consumen_el_doble() -> void:
	var reloj := _reloj_arrancado(100.0, _sin_obligatorias())
	reloj._process(0.5)
	reloj._process(0.5)
	assert_float(_turno.tiempo_restante()).is_equal(76.0)


func test_un_reloj_sin_arrancar_no_esta_corriendo() -> void:
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	assert_bool(reloj.corriendo()).is_false()


func test_un_reloj_sin_arrancar_aguanta_un_cuadro_sin_romperse() -> void:
	# La escena existe antes de que alguien le pase un turno, así que el primer cuadro llega
	# igual. Sin el guard, el modo de falla es un error de nulo en el arranque del juego.
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	reloj.tiempo_consumido.connect(_anotar_consumo)
	reloj._process(0.5)
	assert_int(_consumos).is_equal(0)


func test_cada_cuadro_que_consume_publica_lo_que_queda() -> void:
	var reloj := _reloj_arrancado(100.0, _sin_obligatorias())
	reloj._process(0.5)
	assert_int(_consumos).is_equal(1)
	assert_float(_restante_publicado).is_equal(_turno.tiempo_restante())


func test_al_agotarse_el_presupuesto_el_turno_cierra_una_sola_vez() -> void:
	var reloj := _reloj_arrancado(12.0, _sin_obligatorias())
	reloj._process(1.0)
	assert_float(_turno.tiempo_restante()).is_equal(0.0)
	assert_bool(reloj.corriendo()).is_false()
	assert_int(_cierres).is_equal(1)
	assert_int(_cumplidas_al_cerrar).is_equal(0)


func test_despues_de_cerrar_el_reloj_deja_de_consumir_y_no_vuelve_a_avisar() -> void:
	# Sin el guard, el cierre se emitiría una vez por cuadro y quien lo escucha registraría la
	# jornada sesenta veces por segundo.
	var reloj := _reloj_arrancado(12.0, _sin_obligatorias())
	reloj._process(1.0)
	reloj._process(1.0)
	assert_int(_cierres).is_equal(1)
	assert_float(_turno.tiempo_restante()).is_equal(0.0)


func test_completar_una_obligatoria_devuelve_lo_que_dijo_el_dominio_y_avisa() -> void:
	var limpiar := Tarea.new(Tarea.Tipo.LIMPIAR)
	var obligatorias: Array[Tarea] = [limpiar]
	var reloj := _reloj_arrancado(Reglas.DURACION_DEL_TURNO, obligatorias)
	assert_bool(reloj.completar(limpiar)).is_true()
	assert_int(_completadas).is_equal(1)
	assert_int(_cumplidas_al_completar).is_equal(1)


func test_completar_dos_veces_la_misma_tarea_no_vuelve_a_avisar() -> void:
	var limpiar := Tarea.new(Tarea.Tipo.LIMPIAR)
	var obligatorias: Array[Tarea] = [limpiar]
	var reloj := _reloj_arrancado(Reglas.DURACION_DEL_TURNO, obligatorias)
	reloj.completar(limpiar)
	assert_bool(reloj.completar(limpiar)).is_false()
	assert_int(_completadas).is_equal(1)


func test_el_reloj_entrega_la_misma_instancia_de_tarea_que_recibio_el_turno() -> void:
	# Es la razón de existir de `obligatoria()`: el `Turno` no expone su lista, y completar una
	# copia devuelve `true` sin que `tareas_cumplidas()` suba — sin error y sin rojo.
	var obligatorias := Apertura.obligatorias()
	var reloj := _reloj_arrancado(Reglas.DURACION_DEL_TURNO, obligatorias)
	var reponer := reloj.obligatoria(Tarea.Tipo.REPONER)
	assert_object(reponer).is_same(_de_la_lista(obligatorias, Tarea.Tipo.REPONER))
	assert_bool(reloj.completar(reponer)).is_true()
	assert_int(_cumplidas_al_completar).is_equal(1)


func test_un_tipo_que_no_esta_entre_las_obligatorias_no_devuelve_ninguna_tarea() -> void:
	var limpiar := Tarea.new(Tarea.Tipo.LIMPIAR)
	var obligatorias: Array[Tarea] = [limpiar]
	var reloj := _reloj_arrancado(Reglas.DURACION_DEL_TURNO, obligatorias)
	assert_object(reloj.obligatoria(Tarea.Tipo.CAJA)).is_null()


## Busca por tipo y no por índice a propósito: que la lista salga ordenada como el `enum` es un
## detalle de `Apertura`, y atarlo acá haría fallar este caso el día que se reordene.
func _de_la_lista(obligatorias: Array[Tarea], tipo: Tarea.Tipo) -> Tarea:
	for tarea in obligatorias:
		if tarea.tipo() == tipo:
			return tarea
	return null
