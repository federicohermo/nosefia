## Cuándo se lee la hora en el reloj de mesa, que es una regla del juego y no un detalle de la
## escena.
##
## Escrita en el script del nodo, esta regla nacería sin test y con los siete nodos en verde:
## `gate_de_tests.py` no mira `escenas/`, y está medido —la misma sonda con la regla puesta allá
## contestó `sin hallazgos`—. Acá el test es barato y obligatorio.
##
## Nada de esto pide un frame: el número de jornada y lo que queda del turno entran por
## parámetro, que es lo que permite probar la noche en que el reloj falla sin jugar tres.
extends GdUnitTestSuite

const RELOJ := "res://src/dominio/jornada/reloj_de_mesa.gd"

## Los patrones que rompen la propiedad que hace útil a esta capa: cada uno pide un árbol de
## escena, o un sorteo que no se puede reproducir.
const PATRONES_IMPUROS := ["get_tree(", "get_node(", "_process(", "await", "randi("]

## Un segundo de ficción a cada lado del corte. Alcanza para distinguir los dos lados sin
## depender de cómo redondee nadie.
const UN_SEGUNDO := 1.0


func test_la_noche_en_que_falla_se_lee_hasta_la_mitad_y_despues_no() -> void:  # AC-SHF-012
	# Con un segundo más que la mitad todavía se lee, y lo que se lee es la hora de la noche:
	# `"01:59"` con doce horas desde las 20:00. Con la mitad justa, nada.
	var falla := Reglas.JORNADA_EN_QUE_FALLA_EL_RELOJ
	var mitad := Reglas.DURACION_DEL_TURNO / 2.0
	assert_str(RelojDeMesa.lectura(falla, mitad + UN_SEGUNDO)).is_equal("01:59")
	assert_str(RelojDeMesa.lectura(falla, mitad)).is_empty()
	assert_str(RelojDeMesa.lectura(falla, mitad - UN_SEGUNDO)).is_empty()


func test_las_otras_noches_leen_la_hora_el_turno_entero() -> void:  # AC-SHF-012
	# Las anteriores, las posteriores y la que todavía nadie declaró: el reloj falla **una** noche
	# y vuelve. Se recorren las tres con el turno entero, con la mitad justa y con un segundo,
	# que es el borde que la noche que falla deja vacío.
	var falla := Reglas.JORNADA_EN_QUE_FALLA_EL_RELOJ
	var jornadas := [RelojDeMesa.JORNADA_SIN_DECLARAR, falla + 1, falla + 2]
	var restantes := [Reglas.DURACION_DEL_TURNO, Reglas.DURACION_DEL_TURNO / 2.0, UN_SEGUNDO]
	for jornada: int in jornadas:
		for restante: float in restantes:
			(
				assert_str(RelojDeMesa.lectura(jornada, restante))
				. override_failure_message(
					"la jornada %d con %.0f restantes no lee la hora" % [jornada, restante]
				)
				. is_equal(Marcador.hora(restante))
			)
			assert_str(RelojDeMesa.lectura(jornada, restante)).is_not_empty()


func test_el_reloj_que_fallo_no_dice_que_fallo() -> void:  # AC-SHF-013
	# La cadena vacía y no `"08:00"` ni un `"--:--"`: con el turno agotado la noche que falla,
	# el display sigue apagado. Darse cuenta es parte de lo que la noche cobra.
	var falla := Reglas.JORNADA_EN_QUE_FALLA_EL_RELOJ
	assert_str(RelojDeMesa.lectura(falla, 0.0)).is_empty()
	assert_str(RelojDeMesa.lectura(falla, 0.0)).is_not_equal(Marcador.hora(0.0))


func test_un_reloj_al_que_nadie_le_declaro_jornada_anda() -> void:
	# Es el estado del primer cuadro, antes de que el ciclo abra la noche. Sin esta garantía el
	# reloj arrancaría en blanco y el síntoma —«el reloj no anda»— no nombraría al cableado.
	(
		assert_int(RelojDeMesa.JORNADA_SIN_DECLARAR)
		. override_failure_message("la jornada sin declarar es la que falla")
		. is_not_equal(Reglas.JORNADA_EN_QUE_FALLA_EL_RELOJ)
	)
	var sin_declarar := RelojDeMesa.JORNADA_SIN_DECLARAR
	assert_bool(RelojDeMesa.hora_visible(sin_declarar, Reglas.DURACION_DEL_TURNO)).is_true()


func test_el_reloj_de_mesa_es_puro_y_no_pide_una_escena() -> void:
	var texto := FileAccess.get_file_as_string(RELOJ)
	assert_str(texto).is_not_empty()
	assert_str(texto).not_contains("extends Node")
	for patron: String in PATRONES_IMPUROS:
		(
			assert_bool(texto.contains(patron))
			. override_failure_message(
				"`reloj_de_mesa.gd` nombra `%s`: dejó de ser dominio" % patron
			)
			. is_false()
		)
