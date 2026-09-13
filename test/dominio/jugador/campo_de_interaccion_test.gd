extends GdUnitTestSuite

const Campo := preload("res://src/dominio/jugador/campo_de_interaccion.gd")


func test_sin_candidatos_no_hay_objetivo() -> void:  # 038-AC1
	assert_int(Campo.elegir([])).is_equal(Foco.SIN_OBJETIVO)


func test_el_techo_angular_se_acepta() -> void:  # 038-AC2
	var candidato := Campo.Candidato.new(
		1, 1.0, ReglasDelJugador.DESVIO_MAXIMO_DE_LA_MIRA, true, true
	)
	assert_int(Campo.elegir([candidato])).is_equal(1)


func test_un_grado_sobre_el_techo_se_rechaza() -> void:  # 038-AC2
	var desvio := ReglasDelJugador.DESVIO_MAXIMO_DE_LA_MIRA + deg_to_rad(1.0)
	assert_int(Campo.elegir([Campo.Candidato.new(1, 1.0, desvio, true, true)])).is_equal(
		Foco.SIN_OBJETIVO
	)


func test_el_centrado_gana_a_un_candidato_mas_cercano() -> void:  # 038-AC3
	var centrado := Campo.Candidato.new(1, 1.44, 0.0, true, true)
	var cercano := Campo.Candidato.new(2, 0.85, deg_to_rad(13.7), true, true)
	assert_int(Campo.elegir([cercano, centrado])).is_equal(1)
	assert_int(Campo.elegir([centrado, cercano])).is_equal(1)


func test_a_igual_desvio_gana_el_mas_cercano() -> void:  # 038-AC4
	var lejano := Campo.Candidato.new(1, 1.5, 0.1, true, true)
	var cercano := Campo.Candidato.new(2, 0.5, 0.1, true, true)
	assert_int(Campo.elegir([lejano, cercano])).is_equal(2)
	assert_int(Campo.elegir([cercano, lejano])).is_equal(2)


func test_el_empate_total_conserva_el_primero() -> void:  # 038-AC4
	var primero := Campo.Candidato.new(1, 1.0, 0.1, true, true)
	var segundo := Campo.Candidato.new(2, 1.0, 0.1, true, true)
	assert_int(Campo.elegir([primero, segundo])).is_equal(1)
	assert_int(Campo.elegir([segundo, primero])).is_equal(2)


func test_un_cuerpo_sin_grupo_no_gana() -> void:  # 038-AC5
	var ajeno := Campo.Candidato.new(1, 0.5, 0.0, false, true)
	var valido := Campo.Candidato.new(2, 1.0, 0.1, true, true)
	assert_int(Campo.elegir([ajeno])).is_equal(Foco.SIN_OBJETIVO)
	assert_int(Campo.elegir([ajeno, valido])).is_equal(2)


func test_un_cuerpo_tapado_no_gana_aunque_este_centrado() -> void:  # 038-AC6
	var tapado := Campo.Candidato.new(1, 0.5, 0.0, true, false)
	var visible := Campo.Candidato.new(2, 1.0, 0.1, true, true)
	assert_int(Campo.elegir([tapado])).is_equal(Foco.SIN_OBJETIVO)
	assert_int(Campo.elegir([tapado, visible])).is_equal(2)


func test_el_objeto_excluido_no_gana() -> void:  # 038-AC7
	var sostenido := Campo.Candidato.new(1, 0.5, 0.0, true, true)
	var libre := Campo.Candidato.new(2, 1.0, 0.1, true, true)
	assert_int(Campo.elegir([sostenido], sostenido.id)).is_equal(Foco.SIN_OBJETIVO)
	assert_int(Campo.elegir([sostenido, libre], sostenido.id)).is_equal(2)
	assert_int(Campo.elegir([sostenido, libre], libre.id)).is_equal(1)


func test_el_limite_de_alcance_se_acepta() -> void:  # 038-AC8
	var candidato := Campo.Candidato.new(1, ReglasDelJugador.ALCANCE_DE_LA_MIRA, 0.0, true, true)
	assert_int(Campo.elegir([candidato])).is_equal(1)


func test_un_centimetro_fuera_del_alcance_se_rechaza() -> void:  # 038-AC8
	var distancia := ReglasDelJugador.ALCANCE_DE_LA_MIRA + 0.01
	var lejano := Campo.Candidato.new(1, distancia, 0.0, true, true)
	var cercano := Campo.Candidato.new(2, 1.0, 0.1, true, true)
	assert_int(Campo.elegir([lejano])).is_equal(Foco.SIN_OBJETIVO)
	assert_int(Campo.elegir([lejano, cercano])).is_equal(2)
