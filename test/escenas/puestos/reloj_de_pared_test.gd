## El nodo del reloj: que pinte lo que dice el dominio, y nada más.
##
## **La escena se instancia y no se entra al árbol**, igual que las otras suites de `escenas/`:
## el script no tiene `_ready()` y `text` y `modulate` se leen sin un frame. Que alcance con eso
## es la prueba de que adentro del nodo no quedó ninguna regla — una regla habría necesitado un
## cuadro de verdad para ejercerse.
extends GdUnitTestSuite

const ESCENA := "res://src/escenas/puestos/reloj_de_pared.tscn"

## El script del nodo se preloadea para poder tiparlo: los scripts de `escenas/` son cáscara y
## no declaran `class_name`, así que sin esto el tipo estático sería `Label3D` y llamarle
## `declarar_jornada()` no compilaría. Es la misma forma que documenta `.claude/rules/tests.md`.
const RelojDeParedDelLocal := preload("res://src/escenas/puestos/reloj_de_pared.gd")

## Un segundo de ficción a cada lado del corte de la mitad del turno.
const UN_SEGUNDO := 1.0


func test_la_esfera_dice_exactamente_lo_que_contesta_el_dominio() -> void:  # 032-AC6
	var reloj := _reloj()
	var jornada := RelojDePared.JORNADA_SIN_DECLARAR
	var restante := Reglas.DURACION_DEL_TURNO
	reloj.declarar_jornada(jornada)
	reloj.mostrar_tiempo(restante)
	assert_str(reloj.text).is_equal(RelojDePared.lectura(jornada, restante))
	assert_str(reloj.text).is_not_empty()


func test_pasada_la_mitad_de_la_jornada_que_rompe_la_esfera_queda_en_blanco() -> void:  # 032-AC6
	# El nodo no sabe que se rompió: le pregunta al dominio y copia. Con un texto de reemplazo
	# escrito acá, el reloj roto estaría avisando que está roto, y darse cuenta es parte de lo
	# que la noche cobra.
	var reloj := _reloj()
	var rompe := Reglas.JORNADA_EN_QUE_SE_ROMPE_EL_RELOJ_DE_PARED
	var pasada_la_mitad := Reglas.DURACION_DEL_TURNO / 2.0 - UN_SEGUNDO
	reloj.declarar_jornada(rompe)
	reloj.mostrar_tiempo(pasada_la_mitad)
	assert_str(reloj.text).is_equal(RelojDePared.lectura(rompe, pasada_la_mitad))
	assert_str(reloj.text).is_empty()


func test_el_tono_cambia_cuando_el_dominio_dice_que_hay_que_apurarse() -> void:  # 032-AC6
	# El umbral no se reimplementa acá: se le pregunta a `Marcador`, que es el que lo tiene con
	# test. Los dos lados se prueban para que el caso no pase con un color fijo.
	var reloj := _reloj()
	reloj.declarar_jornada(RelojDePared.JORNADA_SIN_DECLARAR)

	var tranquilo := Reglas.DURACION_DEL_TURNO
	assert_bool(Marcador.en_aviso(tranquilo)).is_false()
	reloj.mostrar_tiempo(tranquilo)
	assert_that(reloj.modulate).is_equal(Color.WHITE)

	var apurado := Marcador.SEGUNDOS_DE_AVISO
	assert_bool(Marcador.en_aviso(apurado)).is_true()
	reloj.mostrar_tiempo(apurado)
	assert_that(reloj.modulate).is_not_equal(Color.WHITE)


func _reloj() -> RelojDeParedDelLocal:
	return auto_free(load(ESCENA).instantiate())
