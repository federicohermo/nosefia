## La línea de subtítulo: un pensamiento que se ve entero, se desvanece y se va, y el texto fijo
## del examen, que no se va hasta que lo sueltan.
extends GdUnitTestSuite

const BOLSA := "Una bolsa de basura."
const JORGILLO := "Un alfajor Jorgillo."
const MANI := "Una barra de Cosa de Maní."
const LECTOR := (
	"El lector de código de barras. Si le paso un producto, lo va a anotar en el programa"
	+ " generador de tickets de la caja."
)
const MOPA := "Una mopa para limpiar las manchas del local."

## Sólo para comparar las muestras redondeadas de duración, sin anticipar el final.
const TOLERANCIA := 0.001


func test_un_pensamiento_nuevo_reemplaza_al_visible() -> void:  # AC-SUB-001
	var linea := Subtitulo.new()
	linea.pensar(BOLSA)
	assert_str(linea.texto()).is_equal(BOLSA)
	linea.pensar(JORGILLO)
	assert_str(linea.texto()).is_equal(JORGILLO)
	assert_float(linea.opacidad()).is_equal(1.0)


func test_el_pensamiento_cumple_todo_el_desvanecido() -> void:  # AC-SUB-004
	var fin := 10.0 / 3.0
	for avance: float in [fin - 0.0005, fin, fin + 0.0005]:
		var linea := Subtitulo.new()
		linea.pensar(BOLSA)
		linea.avanzar(avance)
		if avance < fin:
			assert_str(linea.texto()).is_equal(BOLSA)
			assert_float(linea.opacidad()).is_greater(0.0)
		else:
			assert_str(linea.texto()).is_empty()
			assert_float(linea.opacidad()).is_zero()


func test_sin_nada_la_linea_esta_vacia_y_un_texto_vacio_no_la_cambia() -> void:  # AC-SUB-003
	var linea := Subtitulo.new()
	assert_str(linea.texto()).is_empty()
	assert_float(linea.opacidad()).is_equal(0.0)
	linea.pensar("")
	assert_str(linea.texto()).is_empty()
	linea.pensar(BOLSA)
	linea.avanzar(1.0)
	linea.pensar("")
	assert_str(linea.texto()).is_equal(BOLSA)
	# Sigue su curso: el gesto sin texto no le devolvió el tiempo.
	linea.avanzar(7.0 / 3.0)
	assert_str(linea.texto()).is_empty()


func test_la_duracion_crece_con_el_largo_desde_un_piso() -> void:  # AC-SUB-004
	var casos := {
		"a": 2.0,
		"abcdefg": 2.0,
		"abcdefgh": 2.0333,
		"abcdefghijklmno": 2.5,
		BOLSA: 2.8333,
		MANI: 3.2333,
		LECTOR: 9.3,
	}
	for texto: String in casos:
		(
			assert_float(Subtitulo.duracion(texto))
			. override_failure_message("«%s» dura %f" % [texto, Subtitulo.duracion(texto)])
			. is_equal_approx(casos[texto], TOLERANCIA)
		)
	assert_int(MANI.length()).is_equal(26)
	assert_int(LECTOR.length()).is_equal(117)
	assert_float(Subtitulo.duracion(LECTOR)).is_greater(Subtitulo.duracion(BOLSA))


func test_cada_pensamiento_se_vacia_al_terminar_su_desvanecido() -> void:  # AC-SUB-004
	var casos := {
		"a": 2.5, "abcdefgh": 38.0 / 15.0, BOLSA: 10.0 / 3.0, MANI: 56.0 / 15.0, LECTOR: 9.8
	}
	for texto: String in casos:
		var linea := Subtitulo.new()
		linea.pensar(texto)
		linea.avanzar(casos[texto] - 0.01)
		assert_str(linea.texto()).override_failure_message("«%s» se fue antes" % texto).is_equal(
			texto
		)
		linea.avanzar(0.01)
		assert_str(linea.texto()).override_failure_message("«%s» no se fue" % texto).is_empty()


func test_entero_desvanecido_y_vacio() -> void:  # AC-SUB-005
	var linea := Subtitulo.new()
	linea.pensar(BOLSA)
	linea.avanzar(2.82)
	assert_str(linea.texto()).is_equal(BOLSA)
	assert_float(linea.opacidad()).is_equal(1.0)
	linea.avanzar(0.13)
	var a_los_295 := linea.opacidad()
	linea.avanzar(3.083 - 2.95)
	assert_str(linea.texto()).is_equal(BOLSA)
	assert_float(linea.opacidad()).is_greater(0.0)
	assert_float(linea.opacidad()).is_less(1.0)
	assert_float(linea.opacidad()).is_less_equal(a_los_295)
	linea.avanzar(10.0 / 3.0 - 3.083)
	assert_str(linea.texto()).is_empty()
	assert_float(linea.opacidad()).is_equal(0.0)


func test_un_avance_de_una_vez_vacia_y_cero_o_negativo_no_cambian_nada() -> void:  # AC-SUB-005
	var linea := Subtitulo.new()
	linea.pensar(BOLSA)
	linea.avanzar(0.0)
	linea.avanzar(-5.0)
	linea.avanzar(2.82)
	assert_float(linea.opacidad()).is_equal(1.0)
	var otra := Subtitulo.new()
	otra.pensar(BOLSA)
	otra.avanzar(10.0)
	assert_str(otra.texto()).is_empty()
	assert_float(otra.opacidad()).is_equal(0.0)


func test_repetir_empieza_de_nuevo_sin_sumar() -> void:  # AC-SUB-006
	var linea := Subtitulo.new()
	linea.pensar(BOLSA)
	linea.avanzar(2.0)
	linea.pensar(BOLSA)
	assert_float(linea.opacidad()).is_equal(1.0)
	linea.avanzar(2.82)
	assert_float(linea.opacidad()).is_equal(1.0)
	linea.avanzar(10.0 / 3.0 - 2.82)
	assert_str(linea.texto()).is_empty()


func test_el_texto_fijo_no_se_desvanece_y_soltarlo_lo_vacia() -> void:  # AC-SUB-007
	var linea := Subtitulo.new()
	linea.pensar(BOLSA)
	linea.fijar(MOPA)
	assert_str(linea.texto()).is_equal(MOPA)
	assert_float(linea.opacidad()).is_equal(1.0)
	linea.avanzar(60.0)
	assert_str(linea.texto()).is_equal(MOPA)
	assert_float(linea.opacidad()).is_equal(1.0)
	linea.soltar()
	assert_str(linea.texto()).is_empty()
	assert_float(linea.opacidad()).is_equal(0.0)


func test_soltar_vacia_tambien_un_pensamiento_a_medio_desvanecer() -> void:  # AC-SUB-009
	var linea := Subtitulo.new()
	linea.pensar(BOLSA)
	linea.avanzar(3.0)
	assert_float(linea.opacidad()).is_less(1.0)
	linea.soltar()
	assert_str(linea.texto()).is_empty()
	assert_float(linea.opacidad()).is_equal(0.0)
