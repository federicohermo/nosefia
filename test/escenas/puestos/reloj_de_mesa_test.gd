## El nodo del reloj de mesa: que pinte lo que dice el dominio, y nada más.
##
## **La escena se instancia y no se entra al árbol**, igual que las otras suites de `escenas/`:
## el script no tiene `_ready()` y `text` se lee sin un frame. Que alcance con eso es la prueba
## de que adentro del nodo no quedó ninguna regla — una regla habría necesitado un cuadro de
## verdad para ejercerse.
extends GdUnitTestSuite

const ESCENA := "res://src/escenas/puestos/reloj_de_mesa.tscn"

## El script del nodo se preloadea para poder tiparlo: los scripts de `escenas/` son cáscara y
## no declaran `class_name`, así que sin esto el tipo estático sería `Label3D` y llamarle
## `declarar_jornada()` no compilaría. Es la misma forma que documenta `.claude/rules/tests.md`.
const RelojDeMesaDelLocal := preload("res://src/escenas/puestos/reloj_de_mesa.gd")

## Un segundo de ficción a cada lado del corte de la mitad del turno.
const UN_SEGUNDO := 1.0


func test_el_display_dice_exactamente_lo_que_contesta_el_dominio() -> void:
	var reloj := _reloj()
	var jornada := RelojDeMesa.JORNADA_SIN_DECLARAR
	var restante := Reglas.DURACION_DEL_TURNO
	reloj.declarar_jornada(jornada)
	reloj.mostrar_tiempo(restante)
	assert_str(reloj.text).is_equal(RelojDeMesa.lectura(jornada, restante))
	assert_str(reloj.text).is_not_empty()


func test_pasada_la_mitad_de_la_noche_que_falla_el_display_queda_en_blanco() -> void:
	# El nodo no sabe que falló: le pregunta al dominio y copia. Con un texto de reemplazo
	# escrito acá, el reloj apagado estaría avisando que está apagado, y darse cuenta es parte
	# de lo que la noche cobra.
	var reloj := _reloj()
	var falla := Reglas.JORNADA_EN_QUE_FALLA_EL_RELOJ
	var pasada_la_mitad := Reglas.DURACION_DEL_TURNO / 2.0 - UN_SEGUNDO
	reloj.declarar_jornada(falla)
	reloj.mostrar_tiempo(pasada_la_mitad)
	assert_str(reloj.text).is_equal(RelojDeMesa.lectura(falla, pasada_la_mitad))
	assert_str(reloj.text).is_empty()


func test_el_display_no_cambia_de_tono_en_la_ultima_media_hora() -> void:  # AC-SHF-015
	# La franja de aviso no existe más: el tono es uno solo, de la primera lectura a la última.
	var reloj := _reloj()
	reloj.declarar_jornada(RelojDeMesa.JORNADA_SIN_DECLARAR)
	var tono := reloj.modulate
	for restante: float in [Reglas.DURACION_DEL_TURNO, 1800.0, UN_SEGUNDO, 0.0]:
		reloj.mostrar_tiempo(restante)
		assert_that(reloj.modulate).is_equal(tono)


func test_el_display_no_gira_hacia_la_camara() -> void:  # AC-SHF-017
	# Sin `billboard` el label se lee de frente al escritorio y no desde la góndola.
	assert_int(_reloj().billboard).is_equal(BaseMaterial3D.BILLBOARD_DISABLED)


func _reloj() -> RelojDeMesaDelLocal:
	return auto_free(load(ESCENA).instantiate())
