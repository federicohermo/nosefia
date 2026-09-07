## La partida entera, ejercida sin levantar una escena.
##
## Es lo que hoy no se puede hacer y por eso existe el spec: cinco noches encadenadas, el legajo
## acumulando, y el despido alcanzado de verdad en vez de afirmado sobre un legajo construido a
## mano. Ningún caso de acá pide un frame ni un árbol de escena.
extends GdUnitTestSuite

## Los patrones que un archivo de `dominio/` no puede nombrar. Se buscan sobre el texto entero
## —código y comentarios— a propósito: es lo que hace que el caso no dependa de saber parsear
## GDScript, y nombrarlos en un comentario ya es una invitación a usarlos.
const PATRONES_IMPUROS := ["get_tree(", "get_node(", "_process(", "await", "Input.", "randi("]

const PARTIDA := "res://src/dominio/empleo/partida.gd"


func test_una_partida_nueva_arranca_en_la_primera_jornada() -> void:  # 016-AC3
	assert_int(Partida.nueva().jornada()).is_equal(ReglasDeLaPartida.PRIMERA_JORNADA)


func test_la_partida_guarda_el_legajo_que_recibio_y_no_una_copia() -> void:  # 016-AC3
	# Una copia dejaría al legajo restaurado del 019 sin efecto: la partida acumularía sobre
	# otro objeto y la historia guardada no despediría a nadie, en verde.
	var legajo := Legajo.con_apercibimientos(Reglas.APERCIBIMIENTOS_POR_AVISO)
	var partida := Partida.new(legajo)
	assert_object(partida.legajo()).is_same(legajo)
	assert_int(partida.apercibimientos()).is_equal(Reglas.APERCIBIMIENTOS_POR_AVISO)


func test_cerrar_una_jornada_avanza_y_anota_la_banda_en_el_legajo() -> void:  # 016-AC4
	var partida := Partida.nueva()
	_jugar(partida, 0)
	assert_int(partida.jornada()).is_equal(ReglasDeLaPartida.PRIMERA_JORNADA + 1)
	assert_int(partida.apercibimientos()).is_equal(Reglas.APERCIBIMIENTOS_POR_BANDA_GRAVE)


func test_dos_cierres_sin_abrir_en_el_medio_no_avanzan_dos_veces() -> void:  # 016-AC4
	# El reloj emite `turno_cerrado` una sola vez, pero la puerta es pública y el 017 la va a
	# tocar desde una pantalla. Sin el guard, un segundo cierre anota una jornada que nadie
	# jugó — y una banda grave de regalo.
	var partida := Partida.nueva()
	_jugar(partida, 0)
	partida.cerrar_la_jornada(0)
	assert_int(partida.jornada()).is_equal(ReglasDeLaPartida.PRIMERA_JORNADA + 1)
	assert_int(partida.apercibimientos()).is_equal(Reglas.APERCIBIMIENTOS_POR_BANDA_GRAVE)


func test_cerrar_sin_haber_abierto_no_hace_nada() -> void:  # 016-AC4
	var partida := Partida.nueva()
	partida.cerrar_la_jornada(0)
	assert_int(partida.jornada()).is_equal(ReglasDeLaPartida.PRIMERA_JORNADA)
	assert_int(partida.apercibimientos()).is_equal(0)
	assert_bool(partida.terminada()).is_false()


func test_abrir_la_jornada_entrega_el_turno_del_001_con_sus_obligatorias() -> void:  # 016-AC5
	var partida := Partida.nueva()
	var turno := partida.abrir_la_jornada()
	assert_float(turno.tiempo_restante()).is_equal(Reglas.DURACION_DEL_TURNO)
	assert_int(partida.obligatorias().size()).is_equal(Apertura.cantidad_de_obligatorias())
	assert_bool(turno.todas_cumplidas()).is_false()


func test_cada_jornada_abre_un_turno_nuevo_y_tareas_nuevas() -> void:  # 016-AC5
	# **El caso que cierra el bug caro de reabrir.** Si la jornada 2 arrancara con las tareas de
	# la 1, las que ya estaban completadas seguirían completadas: la noche siguiente empezaría
	# ganada, sin un solo error y sin un solo rojo.
	var partida := Partida.nueva()
	var primer_turno := partida.abrir_la_jornada()
	var primeras: Array[Tarea] = partida.obligatorias()
	partida.cerrar_la_jornada(0)
	var segundo_turno := partida.abrir_la_jornada()
	assert_object(segundo_turno).is_not_same(primer_turno)
	for tarea in partida.obligatorias():
		(
			assert_bool(primeras.has(tarea))
			. override_failure_message(
				"la jornada 2 recibió la misma instancia de `Tarea` que la 1"
			)
			. is_false()
		)


func test_cinco_jornadas_impecables_terminan_la_partida_sin_despido() -> void:  # 016-AC6
	var partida := Partida.nueva()
	for _jornada in range(ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA):
		_jugar(partida, Apertura.cantidad_de_obligatorias())
	assert_bool(partida.terminada()).is_true()
	assert_int(partida.final()).is_equal(Partida.Final.CONTRATO_CUMPLIDO)
	assert_bool(partida.legajo().despedido()).is_false()


func test_dos_jornadas_graves_seguidas_terminan_la_partida_con_despido() -> void:  # 016-AC6
	# **La regla más cara del juego, ejercida de punta a punta por primera vez.** Hasta este
	# spec el legajo moría con la escena y `despedido()` no podía devolver `true` jugando.
	var partida := Partida.nueva()
	_jugar(partida, 0)
	_jugar(partida, 0)
	assert_bool(partida.terminada()).is_true()
	assert_int(partida.final()).is_equal(Partida.Final.DESPEDIDO)


func test_con_el_despido_en_la_ultima_jornada_gana_el_despido() -> void:  # 016-AC6
	# Las dos condiciones a la vez: la última noche cerrada grave sobre dos apercibimientos ya
	# encima. Terminar la partida «cumplida» ahí sería felicitar a alguien recién echado.
	var partida := Partida.nueva()
	for _jornada in range(ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA - 2):
		_jugar(partida, Apertura.cantidad_de_obligatorias())
	_jugar(partida, 0)
	assert_bool(partida.es_la_ultima_jornada()).is_true()
	_jugar(partida, 0)
	assert_int(partida.final()).is_equal(Partida.Final.DESPEDIDO)


func test_la_partida_tiene_tres_finales() -> void:  # 016-AC7
	# En curso, contrato cumplido y despido. Un cuarto sin decidir dónde se alcanza dejaría a
	# `terminada()` contestando que sí sobre un estado que nadie escribió.
	assert_int(Partida.Final.size()).is_equal(3)


func test_solo_la_ultima_jornada_es_la_ultima() -> void:  # 016-AC7
	var partida := Partida.nueva()
	assert_bool(partida.es_la_ultima_jornada()).is_false()
	for _jornada in range(ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA - 1):
		_jugar(partida, Apertura.cantidad_de_obligatorias())
	assert_bool(partida.es_la_ultima_jornada()).is_true()


func test_la_partida_es_pura_y_no_pide_una_escena() -> void:  # 016-AC8
	# Es lo que hace que los diez casos de arriba corran en milisegundos y sin árbol. El gate de
	# capas mira lo mismo; acá se afirma para que el rojo diga cuál patrón entró.
	var texto := FileAccess.get_file_as_string(PARTIDA)
	assert_str(texto).not_contains("extends Node")
	for patron: String in PATRONES_IMPUROS:
		(
			assert_bool(texto.contains(patron))
			. override_failure_message("`partida.gd` nombra `%s`: dejó de ser dominio" % patron)
			. is_false()
		)


## Una jornada jugada entera: se abre y se cierra con las tareas que se le declaren cumplidas.
func _jugar(partida: Partida, cumplidas: int) -> void:
	partida.abrir_la_jornada()
	partida.cerrar_la_jornada(cumplidas)
