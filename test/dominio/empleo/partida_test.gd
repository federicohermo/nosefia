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
const COMPLETA := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA


func test_una_partida_nueva_arranca_en_la_primera_jornada() -> void:
	assert_int(Partida.nueva().jornada()).is_equal(ReglasDeLaPartida.PRIMERA_JORNADA)


func test_la_partida_guarda_el_legajo_que_recibio_y_no_una_copia() -> void:  # AC-EMP-012
	# Una copia dejaría al legajo restaurado sin efecto: la partida acumularía sobre
	# otro objeto y la historia guardada no despediría a nadie, en verde.
	var legajo := Legajo.con_medios(
		(Reglas.APERCIBIMIENTOS_POR_AVISO) * Reglas.MEDIOS_POR_APERCIBIMIENTO
	)
	var partida := Partida.new(legajo)
	assert_object(partida.legajo()).is_same(legajo)
	assert_int(partida.apercibimientos()).is_equal(Reglas.APERCIBIMIENTOS_POR_AVISO)


func test_una_partida_restaurada_a_un_aviso_del_tope_despide_con_un_aviso() -> void:  # AC-EMP-012
	var medios := (
		(Reglas.APERCIBIMIENTOS_HASTA_EL_DESPIDO - Reglas.APERCIBIMIENTOS_POR_AVISO)
		* Reglas.MEDIOS_POR_APERCIBIMIENTO
	)
	var partida := Partida.desde(
		{"jornada": ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA, "medios": medios}
	)
	_jugar(partida, Consecuencias.CUMPLIDAS_MINIMAS_PARA_AVISO)
	assert_int(partida.final()).is_equal(Partida.Final.DESPEDIDO)


func test_una_partida_guardada_sigue_en_su_jornada_y_con_su_legajo() -> void:
	var guardada := (
		PartidaSerializada
		. sanear(
			{
				PartidaSerializada.clave(PartidaSerializada.Campo.JORNADA):
				ReglasDeLaPartida.PRIMERA_JORNADA + 2,
				PartidaSerializada.clave(PartidaSerializada.Campo.MEDIOS):
				Reglas.APERCIBIMIENTOS_POR_AVISO * Reglas.MEDIOS_POR_APERCIBIMIENTO,
			}
		)
	)
	var partida := Partida.desde(guardada)
	assert_int(partida.jornada()).is_equal(ReglasDeLaPartida.PRIMERA_JORNADA + 2)
	assert_int(partida.apercibimientos()).is_equal(Reglas.APERCIBIMIENTOS_POR_AVISO)
	assert_bool(partida.terminada()).is_false()


func test_un_diccionario_vacio_da_una_partida_nueva() -> void:
	var partida := Partida.desde({})
	assert_int(partida.jornada()).is_equal(Partida.nueva().jornada())
	assert_int(partida.apercibimientos()).is_equal(Partida.nueva().apercibimientos())


func test_cerrar_una_jornada_avanza_y_anota_la_banda_en_el_legajo() -> void:
	var partida := Partida.desde({"jornada": COMPLETA})
	_jugar(partida, 0)
	assert_int(partida.jornada()).is_equal(COMPLETA + 1)
	assert_int(partida.apercibimientos()).is_equal(Reglas.APERCIBIMIENTOS_POR_BANDA_GRAVE)


func test_dos_cierres_sin_abrir_en_el_medio_no_avanzan_dos_veces() -> void:  # AC-EMP-011
	# El reloj emite `turno_cerrado` una sola vez, pero la puerta es pública y el 017 la va a
	# tocar desde una pantalla. Sin el guard, un segundo cierre anota una jornada que nadie
	# jugó — y una banda grave de regalo.
	var partida := Partida.desde({"jornada": COMPLETA})
	_jugar(partida, 0)
	partida.cerrar_la_jornada(0)
	assert_int(partida.jornada()).is_equal(COMPLETA + 1)
	assert_int(partida.apercibimientos()).is_equal(Reglas.APERCIBIMIENTOS_POR_BANDA_GRAVE)


func test_cerrar_sin_haber_abierto_no_hace_nada() -> void:  # AC-EMP-011
	var partida := Partida.nueva()
	partida.cerrar_la_jornada(0)
	assert_int(partida.jornada()).is_equal(ReglasDeLaPartida.PRIMERA_JORNADA)
	assert_int(partida.apercibimientos()).is_equal(0)
	assert_bool(partida.terminada()).is_false()


func test_abrir_la_jornada_entrega_el_turno_del_001_con_sus_obligatorias() -> void:
	var partida := Partida.nueva()
	var turno := partida.abrir_la_jornada()
	assert_float(turno.tiempo_restante()).is_equal(Reglas.DURACION_DEL_TURNO)
	assert_int(partida.obligatorias().size()).is_equal(
		Apertura.cantidad_de_obligatorias(partida.jornada())
	)
	assert_bool(turno.todas_cumplidas()).is_false()


func test_cada_jornada_abre_un_turno_nuevo_y_tareas_nuevas() -> void:
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


func test_una_partida_que_termino_no_vuelve_a_abrir_una_jornada() -> void:  # AC-EMP-010
	# El ciclo ya guarda esto antes de llamar, pero la puerta es pública y el 017 la toca desde
	# una pantalla. Sin el guard, una noche de regalo avanzaría una partida ya terminada.
	var partida := Partida.desde({"jornada": COMPLETA})
	_jugar(partida, 0)
	_jugar(partida, 0)
	assert_int(partida.final()).is_equal(Partida.Final.DESPEDIDO)
	var jornada_del_despido := partida.jornada()
	var apercibimientos_del_despido := partida.apercibimientos()
	assert_object(partida.abrir_la_jornada()).is_null()
	partida.cerrar_la_jornada(Apertura.cantidad_de_obligatorias(partida.jornada()))
	assert_int(partida.jornada()).is_equal(jornada_del_despido)
	assert_int(partida.apercibimientos()).is_equal(apercibimientos_del_despido)
	assert_int(partida.final()).is_equal(Partida.Final.DESPEDIDO)


func test_todas_las_jornadas_impecables_terminan_la_partida_sin_despido() -> void:  # AC-EMP-008
	var partida := Partida.nueva()
	for _jornada in range(ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA):
		_jugar(partida, Apertura.cantidad_de_obligatorias(partida.jornada()))
	assert_bool(partida.terminada()).is_true()
	assert_int(partida.final()).is_equal(Partida.Final.CONTRATO_CUMPLIDO)
	assert_bool(partida.legajo().despedido()).is_false()
	assert_int(partida.jornada()).is_equal(
		ReglasDeLaPartida.PRIMERA_JORNADA + ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA - 1
	)


func test_dos_jornadas_graves_seguidas_terminan_la_partida_con_despido() -> void:  # AC-EMP-004
	# **La regla más cara del juego, ejercida de punta a punta por primera vez.** Hasta este
	# spec el legajo moría con la escena y `despedido()` no podía devolver `true` jugando.
	var partida := Partida.desde({"jornada": COMPLETA})
	_jugar(partida, 0)
	_jugar(partida, 0)
	assert_bool(partida.terminada()).is_true()
	assert_int(partida.final()).is_equal(Partida.Final.DESPEDIDO)


func test_con_el_despido_en_la_ultima_jornada_gana_el_despido() -> void:  # AC-EMP-009
	# Las dos condiciones a la vez: la última noche cerrada grave sobre dos apercibimientos ya
	# encima. Terminar la partida «cumplida» ahí sería felicitar a alguien recién echado.
	var partida := Partida.nueva()
	for _jornada in range(ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA - 2):
		_jugar(partida, Apertura.cantidad_de_obligatorias(partida.jornada()))
	_jugar(partida, 0)
	assert_bool(partida.es_la_ultima_jornada()).is_true()
	_jugar(partida, 0)
	assert_int(partida.final()).is_equal(Partida.Final.DESPEDIDO)


func test_la_partida_tiene_tres_finales() -> void:
	# En curso, contrato cumplido y despido. Un cuarto sin decidir dónde se alcanza dejaría a
	# `terminada()` contestando que sí sobre un estado que nadie escribió.
	assert_int(Partida.Final.size()).is_equal(3)


func test_solo_la_ultima_jornada_es_la_ultima() -> void:  # AC-EMP-008
	var partida := Partida.nueva()
	assert_bool(partida.es_la_ultima_jornada()).is_false()
	for _jornada in range(ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA - 1):
		_jugar(partida, Apertura.cantidad_de_obligatorias(partida.jornada()))
	assert_bool(partida.es_la_ultima_jornada()).is_true()


func test_la_partida_es_pura_y_no_pide_una_escena() -> void:
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
	for tarea: Tarea in partida.obligatorias().slice(0, cumplidas):
		tarea.completar()
	partida.cerrar_la_jornada(cumplidas)


func test_la_ultima_de_la_prueba_cierra_con_cuatro_tres_y_dos() -> void:  # AC-SHF-027, AC-EMP-050
	var partida := Partida.desde({"jornada": 2, "medios": 0})
	var turno := partida.abrir_la_jornada()
	assert_int(partida.obligatorias().size()).is_equal(4)
	for tarea in partida.obligatorias():
		turno.completar(tarea)
	turno.consumir(Reglas.DURACION_DEL_TURNO)
	partida.cerrar_la_jornada(turno.tareas_cumplidas())
	assert_int(partida.medios()).is_zero()
	assert_int(partida.legajo().apercibimientos_de_la_prueba()).is_zero()
	assert_bool(partida.legajo().ultima_de_la_prueba_completa()).is_true()
	assert_int(Consecuencias.consecuencia_de(4, 4)).is_equal(Consecuencias.Banda.NINGUNA)

	for caso: Dictionary in [
		{"cumplidas": 3, "banda": Consecuencias.Banda.AVISO, "descuidos": 1},
		{"cumplidas": 2, "banda": Consecuencias.Banda.GRAVE, "descuidos": 2}
	]:
		var otra := Partida.desde({"jornada": 2, "medios": 0})
		assert_int(otra.jornada()).is_equal(2)
		var otro_turno := otra.abrir_la_jornada()
		assert_int(otra.obligatorias().size()).is_equal(4)
		var cumplidas: int = caso["cumplidas"]
		for indice in cumplidas:
			otro_turno.completar(otra.obligatorias()[indice])
		otro_turno.consumir(Reglas.DURACION_DEL_TURNO)
		assert_int(otro_turno.tareas_cumplidas()).is_equal(cumplidas)
		var banda := Consecuencias.consecuencia_de(
			otro_turno.tareas_cumplidas(), otra.obligatorias().size()
		)
		assert_int(banda).is_equal(caso["banda"])
		otra.cerrar_la_jornada(otro_turno.tareas_cumplidas())
		var descuidos: int = caso["descuidos"]
		assert_int(otra.legajo().apercibimientos_de_la_prueba()).is_equal(
			descuidos * Reglas.APERCIBIMIENTOS_POR_FALLA_DE_LA_PRUEBA
		)
		assert_bool(otra.legajo().ultima_de_la_prueba_completa()).is_false()
		assert_int(otra.medios()).is_zero()


func _cerrar_con(partida: Partida, sin_cumplir: Array[Tarea.Tipo], llamados: Array) -> void:
	partida.abrir_la_jornada()
	var cumplidas := 0
	for tarea: Tarea in partida.obligatorias():
		if not sin_cumplir.has(tarea.tipo()):
			tarea.completar()
			cumplidas += 1
	for llamado: Partida.Llamado in llamados:
		partida.anotar_llamado(llamado)
	partida.cerrar_la_jornada(cumplidas)


func test_cerrar_anota_las_cuentas_de_la_noche() -> void:  # AC-EMP-059
	var partida := Partida.desde({"jornada": ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA})
	partida.abrir_la_jornada()
	for tarea: Tarea in partida.obligatorias():
		if tarea.tipo() in [Tarea.Tipo.CAJA, Tarea.Tipo.REGISTRAR]:
			tarea.completar()
	# Cumplida y descumplida antes del cierre: vale el estado al cerrar.
	var limpiar: Tarea = null
	for tarea: Tarea in partida.obligatorias():
		if tarea.tipo() == Tarea.Tipo.LIMPIAR:
			limpiar = tarea
	limpiar.completar()
	limpiar.descompletar()
	partida.anotar_llamado(Partida.Llamado.PAPEL_EN_EL_INODORO)
	partida.anotar_llamado(Partida.Llamado.PAPEL_EN_EL_INODORO)
	partida.cerrar_la_jornada(2)
	var cuentas := partida.antecedentes()
	assert_int(cuentas.fallas(Tarea.Tipo.REPONER)).is_equal(1)
	assert_int(cuentas.fallas(Tarea.Tipo.LIMPIAR)).is_equal(1)
	assert_int(cuentas.fallas(Tarea.Tipo.CAJA)).is_zero()
	assert_int(cuentas.fallas(Tarea.Tipo.REGISTRAR)).is_zero()
	assert_int(cuentas.llamados(Partida.Llamado.PAPEL_EN_EL_INODORO)).is_equal(1)
	assert_bool(cuentas.hubo_llamados()).is_true()
	assert_int(cuentas.noches_sin_sumar()).is_zero()
	partida.cerrar_la_jornada(5)
	assert_int(partida.antecedentes().fallas(Tarea.Tipo.REPONER)).is_equal(1)
	_cerrar_con(partida, [], [])
	assert_int(partida.antecedentes().noches_sin_sumar()).is_equal(1)
	_cerrar_con(partida, [], [])
	assert_int(partida.antecedentes().noches_sin_sumar()).is_equal(2)
	_cerrar_con(partida, [], [Partida.Llamado.OBJETO_AFUERA])
	assert_int(partida.antecedentes().noches_sin_sumar()).is_zero()
	assert_int(partida.antecedentes().fallas(Tarea.Tipo.REPONER)).is_equal(1)


func test_las_devoluciones_se_concatenan_y_vuelven_del_guardado() -> void:  # AC-EMP-066, AC-SAV-024
	var partida := Partida.desde({"jornada": ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA})
	assert_array(partida.mensajes_del_jefe()).is_empty()
	_cerrar_con(partida, [Tarea.Tipo.REPONER], [Partida.Llamado.PAPEL_EN_EL_INODORO])
	var primera := (
		DevolucionDelJefe.new(ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA, partida).mensajes()
	)
	_cerrar_con(partida, [Tarea.Tipo.REPONER], [])
	var segunda := (
		DevolucionDelJefe.new(ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1, partida).mensajes()
	)
	var esperado := PackedStringArray(primera + segunda)
	assert_array(partida.mensajes_del_jefe()).is_equal(esperado)
	var retomada := Partida.desde(PoliticaDeGuardado.datos(partida))
	assert_int(retomada.jornada()).is_equal(ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 2)
	assert_array(retomada.mensajes_del_jefe()).is_equal(esperado)
	assert_int(retomada.antecedentes().fallas(Tarea.Tipo.REPONER)).is_equal(2)
	assert_int(retomada.antecedentes().llamados(Partida.Llamado.PAPEL_EN_EL_INODORO)).is_equal(1)
	assert_bool(retomada.antecedentes().hubo_llamados()).is_true()
	assert_int(retomada.antecedentes().noches_sin_sumar()).is_equal(
		partida.antecedentes().noches_sin_sumar()
	)
	_cerrar_con(retomada, [Tarea.Tipo.REPONER], [])
	(
		assert_bool(
			(
				DevolucionDelJefe
				. new(ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 2, retomada)
				. mensajes()[1]
				. begins_with("De nuevo quedaron algunas")
			)
		)
		. is_true()
	)
