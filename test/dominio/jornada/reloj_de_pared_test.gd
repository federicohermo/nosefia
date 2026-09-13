## Cuándo se ve la hora, que es una regla del juego y no un detalle de la escena.
##
## Escrita en el script del nodo, esta regla nacería sin test y con los seis nodos en verde:
## `gate_de_tests.py` no mira `escenas/`, y está medido —la misma sonda con la regla puesta allá
## contestó `sin hallazgos`—. Acá el test es barato y obligatorio.
##
## Nada de esto pide un frame: el número de jornada y lo que queda del turno entran por
## parámetro, que es lo que permite probar la jornada en que el reloj se rompe sin jugar tres
## noches.
extends GdUnitTestSuite

const RELOJ := "res://src/dominio/jornada/reloj_de_pared.gd"

## Los patrones que rompen la propiedad que hace útil a esta capa: cada uno pide un árbol de
## escena, o un sorteo que no se puede reproducir.
const PATRONES_IMPUROS := ["get_tree(", "get_node(", "_process(", "await", "randi("]

## Un segundo de ficción a cada lado del corte. Alcanza para distinguir los dos lados sin
## depender de cómo redondee nadie.
const UN_SEGUNDO := 1.0


func test_antes_de_la_jornada_que_lo_rompe_la_hora_se_ve_toda_la_noche() -> void:  # 032-AC1
	# Se recorren todas las jornadas anteriores y no sólo la primera: el corte de la mitad del
	# turno vale para **una** noche, y aplicarlo antes dejaría al reloj roto desde el día uno.
	var rompe := Reglas.JORNADA_EN_QUE_SE_ROMPE_EL_RELOJ_DE_PARED
	for jornada in range(RelojDePared.JORNADA_SIN_DECLARAR, rompe):
		for restante in [Reglas.DURACION_DEL_TURNO, 0.0]:
			(
				assert_bool(RelojDePared.hora_visible(jornada, restante))
				. override_failure_message(
					"la jornada %d es anterior a la que rompe y ya no muestra la hora" % jornada
				)
				. is_true()
			)


func test_despues_de_romperse_no_se_arregla_mas() -> void:  # 032-AC1
	# Un reloj que volviera a andar la noche siguiente sería un reloj que se descompuso, no uno
	# roto: la tensión que este spec compra es que desde acá enterarse de la hora cuesta más.
	var rompe := Reglas.JORNADA_EN_QUE_SE_ROMPE_EL_RELOJ_DE_PARED
	for jornada in range(rompe + 1, rompe + ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA):
		(
			assert_bool(RelojDePared.hora_visible(jornada, Reglas.DURACION_DEL_TURNO))
			. override_failure_message("el reloj volvió a andar en la jornada %d" % jornada)
			. is_false()
		)


func test_la_noche_en_que_se_rompe_el_corte_es_la_mitad_del_turno() -> void:  # 032-AC2
	# La mitad se cuenta contra `DURACION_DEL_TURNO` y nunca contra un número escrito: el día que
	# la noche dure otra cosa, el reloj se sigue rompiendo a la mitad y no a las cuatro horas.
	var rompe := Reglas.JORNADA_EN_QUE_SE_ROMPE_EL_RELOJ_DE_PARED
	var mitad := Reglas.DURACION_DEL_TURNO / 2.0
	assert_bool(RelojDePared.hora_visible(rompe, mitad + UN_SEGUNDO)).is_true()
	assert_bool(RelojDePared.hora_visible(rompe, mitad - UN_SEGUNDO)).is_false()
	assert_bool(RelojDePared.hora_visible(rompe, 0.0)).is_false()


func test_la_lectura_es_la_del_marcador_mientras_se_vea_y_vacia_cuando_no() -> void:  # 032-AC3
	# El formato no se reimplementa acá: `Marcador.reloj()` ya decide cómo se lee un tiempo, y
	# una segunda copia se desincroniza el día que alguien cambie el formato en uno solo.
	var rompe := Reglas.JORNADA_EN_QUE_SE_ROMPE_EL_RELOJ_DE_PARED
	var mitad := Reglas.DURACION_DEL_TURNO / 2.0
	var visible := mitad + UN_SEGUNDO
	assert_str(RelojDePared.lectura(rompe, visible)).is_equal(Marcador.reloj(visible))
	assert_str(RelojDePared.lectura(rompe, mitad - UN_SEGUNDO)).is_empty()


func test_un_reloj_al_que_nadie_le_declaro_jornada_muestra_la_hora() -> void:  # 032-AC3
	# Es el estado del primer cuadro, antes de que el ciclo abra la noche. Sin esta garantía el
	# reloj arrancaría en blanco y el síntoma —«el reloj no anda»— no nombraría al cableado.
	(
		assert_int(RelojDePared.JORNADA_SIN_DECLARAR)
		. override_failure_message("el reloj nace roto: su jornada por defecto ya pasó el corte")
		. is_less(Reglas.JORNADA_EN_QUE_SE_ROMPE_EL_RELOJ_DE_PARED)
	)
	var sin_declarar := RelojDePared.JORNADA_SIN_DECLARAR
	assert_str(RelojDePared.lectura(sin_declarar, Reglas.DURACION_DEL_TURNO)).is_not_empty()


func test_el_reloj_de_pared_es_puro_y_no_pide_una_escena() -> void:  # 032-AC4
	var texto := FileAccess.get_file_as_string(RELOJ)
	assert_str(texto).is_not_empty()
	assert_str(texto).not_contains("extends Node")
	for patron: String in PATRONES_IMPUROS:
		(
			assert_bool(texto.contains(patron))
			. override_failure_message(
				"`reloj_de_pared.gd` nombra `%s`: dejó de ser dominio" % patron
			)
			. is_false()
		)


func test_el_espejo_de_este_spec_esta_escrito() -> void:  # 032-AC10
	# `verificar.py` en verde no se puede afirmar desde adentro de gdUnit4, pero sí lo que hace
	# fallar a su nodo `tdd`: que falte el espejo del archivo nuevo de `dominio/`.
	assert_bool(FileAccess.file_exists("res://" + RELOJ.trim_prefix("res://"))).is_true()
	(
		assert_bool(FileAccess.file_exists("res://test/dominio/jornada/reloj_de_pared_test.gd"))
		. is_true()
	)
