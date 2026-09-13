## El ciclo, ejercido sin levantar ninguna escena.
##
## Ningún caso de acá usa `scene_runner` ni entra el nodo al árbol: se instancia con
## `auto_free(CicloDeJornadas.new())` y las noches se agotan llamándole `_process()` al reloj a
## mano. Eso no es un truco del test: es la prueba de que adentro del ciclo no quedó ninguna
## regla del juego, porque una regla habría necesitado un frame de verdad para ejercerse.
##
## La partida completa se corre a fuerza de reloj y no llamando a la partida directo: es el
## único camino que verifica que las tres piezas están cableadas entre sí.
extends GdUnitTestSuite

## Los nombres que el ciclo **no** puede pronunciar. Los tres deciden algo —cuánto pesa una
## jornada, dónde está el corte, cuántas noches hay— y el ciclo sólo traduce.
const NOMBRES_QUE_DECIDEN := ["Legajo", "Consecuencias", "ReglasDeLaPartida"]

const CICLO := "res://src/sistemas/marco/ciclo_de_jornadas.gd"

var _aperturas: int = 0
var _cierres: int = 0
var _terminadas: int = 0
var _ultima_jornada_cerrada: int = 0
var _final_publicado: int = Partida.Final.EN_CURSO


func before_test() -> void:
	_aperturas = 0
	_cierres = 0
	_terminadas = 0
	_ultima_jornada_cerrada = 0
	_final_publicado = Partida.Final.EN_CURSO


func test_arrancar_deja_el_reloj_corriendo_con_las_tareas_alcanzables() -> void:  # 016-AC9
	# Que `obligatoria()` conteste es lo que le deja al 008 una tarea que completar: si el ciclo
	# le pasara al reloj una lista distinta de la que cuenta el turno, completar devolvería
	# `true` sin que las cumplidas suban, sin error y sin rojo.
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	_ciclo_arrancado(Partida.nueva(), reloj)
	assert_bool(reloj.corriendo()).is_true()
	assert_object(reloj.obligatoria(Tarea.Tipo.REPONER)).is_not_null()
	assert_int(_aperturas).is_equal(1)


func test_la_partida_entera_cierra_cada_jornada_incluida_la_ultima() -> void:  # 016-AC10
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	var ciclo := _ciclo_arrancado(Partida.nueva(), reloj)
	_jugar_la_noche_impecable(reloj)
	(
		assert_int(_terminadas)
		. override_failure_message("la partida se dio por terminada en la primera jornada")
		. is_equal(0)
	)
	for _jornada in range(ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA - 1):
		ciclo.abrir_la_jornada()
		_jugar_la_noche_impecable(reloj)
	(
		assert_int(_cierres)
		. override_failure_message("la última jornada cerró sin avisar: se cerraron %d" % _cierres)
		. is_equal(ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA)
	)
	assert_int(_ultima_jornada_cerrada).is_equal(ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA)
	assert_int(_terminadas).is_equal(1)
	assert_int(_final_publicado).is_equal(Partida.Final.CONTRATO_CUMPLIDO)


func test_sobre_una_partida_terminada_no_se_abre_nada_ni_se_emite_nada() -> void:  # 016-AC10
	# El despido corta la partida a la segunda noche grave, y desde ahí el ciclo es una puerta
	# cerrada: sin esto, la pantalla del 017 reabriría la jornada 3 de una partida terminada.
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	var ciclo := _ciclo_arrancado(Partida.nueva(), reloj)
	_agotar_la_noche(reloj)
	ciclo.abrir_la_jornada()
	_agotar_la_noche(reloj)
	assert_int(_final_publicado).is_equal(Partida.Final.DESPEDIDO)
	assert_int(_terminadas).is_equal(1)
	var aperturas_antes := _aperturas
	assert_bool(ciclo.abrir_la_jornada()).is_false()
	assert_int(_aperturas).is_equal(aperturas_antes)
	assert_int(_terminadas).is_equal(1)


func test_el_ciclo_no_decide_como_pesa_una_jornada() -> void:  # 016-AC11
	# Traduce y no decide. Un `match` de bandas acá sería la misma regla escrita dos veces, y la
	# copia de `sistemas/` es la que se desincroniza sin que ningún gate lo note.
	var texto := FileAccess.get_file_as_string(CICLO)
	for nombre: String in NOMBRES_QUE_DECIDEN:
		(
			assert_bool(texto.contains(nombre))
			. override_failure_message(
				"`ciclo_de_jornadas.gd` nombra `%s`: está decidiendo" % nombre
			)
			. is_false()
		)


## Un ciclo ya arrancado sobre esa partida y ese reloj, con las tres señales anotadas.
func _ciclo_arrancado(partida: Partida, reloj: RelojDelTurno) -> CicloDeJornadas:
	var ciclo: CicloDeJornadas = auto_free(CicloDeJornadas.new())
	ciclo.jornada_abierta.connect(_anotar_apertura)
	ciclo.jornada_cerrada.connect(_anotar_cierre)
	ciclo.partida_terminada.connect(_anotar_final)
	ciclo.arrancar(partida, reloj)
	return ciclo


## Agota el turno de una sola vez: el factor del `Ritmo` convierte los segundos reales en los de
## ficción, así que un `_process` con la noche entera adentro alcanza y sobra.
##
## Sin completar nada, o sea la banda grave: es el camino corto al despido.
func _agotar_la_noche(reloj: RelojDelTurno) -> void:
	reloj._process(Reglas.DURACION_DEL_TURNO / Ritmo.SEGUNDOS_DE_TURNO_POR_SEGUNDO_REAL)


## Las cinco obligatorias cumplidas y después la noche agotada.
##
## Las tareas se piden por `obligatoria()` y no se construyen acá: una copia se completaría
## devolviendo `true` sin que las cumplidas del turno suban, y la noche cerraría grave igual.
func _jugar_la_noche_impecable(reloj: RelojDelTurno) -> void:
	for tipo: Tarea.Tipo in Tarea.Tipo.values():
		reloj.completar(reloj.obligatoria(tipo))
	_agotar_la_noche(reloj)


func _anotar_apertura(_jornada: int) -> void:
	_aperturas += 1


func _anotar_cierre(jornada: int, _cumplidas: int) -> void:
	_cierres += 1
	_ultima_jornada_cerrada = jornada


func _anotar_final(final: Partida.Final) -> void:
	_terminadas += 1
	_final_publicado = final
