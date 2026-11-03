## Cuándo se lee la hora en el reloj de pared, que es una regla del juego y no un detalle de la
## escena.
##
## Escrita en el script del nodo, esta regla nacería sin test y con los siete nodos en verde:
## `gate_de_tests.py` no mira `escenas/`, y está medido —la misma sonda con la regla puesta allá
## contestó `sin hallazgos`—. Acá el test es barato y obligatorio.
##
## Nada de esto pide un frame: el número de jornada y lo que queda del turno entran por
## parámetro, que es lo que permite probar la noche del corte sin jugar tres.
extends GdUnitTestSuite

const RELOJ := "res://src/dominio/jornada/reloj_de_mesa.gd"

## Los patrones que rompen la propiedad que hace útil a esta capa: cada uno pide un árbol de
## escena, o un sorteo que no se puede reproducir.
const PATRONES_IMPUROS := ["get_tree(", "get_node(", "_process(", "await", "randi("]

## Un segundo de ficción a cada lado del corte. Alcanza para distinguir los dos lados sin
## depender de cómo redondee nadie.
const UN_SEGUNDO := 1.0


func test_las_otras_noches_leen_la_hora_el_turno_entero() -> void:  # AC-SHF-062
	# Las de la partida que no son la del corte y la que todavía nadie declaró. Se recorren con el
	# turno entero, con la mitad justa y con un segundo.
	var primera := ReglasDeLaPartida.PRIMERA_JORNADA
	var ultima := primera + ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA - 1
	var jornadas: Array[int] = [RelojDeMesa.JORNADA_SIN_DECLARAR]
	for jornada in range(primera, ultima + 1):
		if jornada != AnomaliasDeLaJornada.JORNADA_DEL_CORTE:
			jornadas.append(jornada)
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


func test_la_noche_del_corte_se_detiene_en_la_hora_del_corte() -> void:  # AC-SHF-049, AC-SHF-050
	var jornada := AnomaliasDeLaJornada.JORNADA_DEL_CORTE
	var corte := AnomaliasDeLaJornada.SEGUNDOS_HASTA_EL_CORTE
	var detenida := (
		"%02d:%02d" % [AnomaliasDeLaJornada.HORA_DEL_CORTE, AnomaliasDeLaJornada.MINUTO_DEL_CORTE]
	)
	var antes := Reglas.DURACION_DEL_TURNO - (corte - UN_SEGUNDO)
	assert_str(RelojDeMesa.lectura(jornada, antes)).is_equal(Marcador.hora(antes))
	assert_str(RelojDeMesa.lectura(jornada, antes)).is_not_equal(detenida)
	for transcurrido: float in [corte, corte * 2.0]:
		var restante := Reglas.DURACION_DEL_TURNO - transcurrido
		assert_str(RelojDeMesa.lectura(jornada, restante)).is_equal(detenida)


func test_la_noche_del_corte_nunca_queda_en_blanco() -> void:  # AC-SHF-049
	# Con la mitad del turno, con un segundo menos y con el turno agotado: el reloj sigue en la hora
	# del corte, y no en blanco ni en la hora de cierre.
	var jornada := AnomaliasDeLaJornada.JORNADA_DEL_CORTE
	var detenida := Marcador.hora(AnomaliasDeLaJornada.restante_al_cortar())
	var mitad := Reglas.DURACION_DEL_TURNO / 2.0
	for restante: float in [mitad + UN_SEGUNDO, mitad, mitad - UN_SEGUNDO, 0.0]:
		assert_str(RelojDeMesa.lectura(jornada, restante)).is_equal(detenida)
	assert_str(RelojDeMesa.lectura(jornada, 0.0)).is_not_equal(Marcador.hora(0.0))


func test_la_noche_siguiente_al_corte_vuelve_a_leer_la_hora() -> void:  # AC-SHF-049
	var siguiente := AnomaliasDeLaJornada.JORNADA_DEL_CORTE + 1
	assert_str(RelojDeMesa.lectura(siguiente, 0.0)).is_equal(Marcador.hora(0.0))


func test_el_reloj_de_pared_es_puro_y_no_pide_una_escena() -> void:
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
