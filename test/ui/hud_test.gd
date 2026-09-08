## Qué NO dibuja el HUD.
##
## El 007 le había puesto un veredicto de cierre, y con la placa del 017 serían dos lugares
## diciendo cómo cerró la noche: el que quedara desactualizado no daría rojo, porque
## `gate_de_tests.py` no mira `ui/`. Esta suite es lo único ejecutable que lo impide.
extends GdUnitTestSuite

const HUD := "res://src/ui/hud.gd"

## Lo que el veredicto del 007 traía consigo. El segundo es el que importa: traducir la banda a
## palabras es una regla del juego, y acá arriba nace sin test.
const RASTROS_DEL_VEREDICTO := ["mostrar_veredicto", "consecuencia_de"]


func test_el_hud_no_dibuja_el_veredicto_del_cierre() -> void:  # 017-AC11
	var texto := FileAccess.get_file_as_string(HUD)
	assert_str(texto).is_not_empty()
	for rastro: String in RASTROS_DEL_VEREDICTO:
		(
			assert_bool(texto.contains(rastro))
			. override_failure_message(
				"`hud.gd` nombra `%s`: el cierre se dice en dos lugares" % rastro
			)
			. is_false()
		)


func test_el_hud_sigue_pintando_lo_que_si_es_suyo() -> void:  # 017-AC11
	# El par del caso de arriba: sin esto, borrar el archivo entero lo dejaría en verde.
	var texto := FileAccess.get_file_as_string(HUD)
	assert_str(texto).contains("func mostrar_tareas")
	assert_str(texto).contains("func mostrar_apercibimientos")
