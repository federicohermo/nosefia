## Qué NO dibuja el HUD.
##
## El 007 le había puesto un veredicto de cierre, y con la placa del 017 serían dos lugares
## diciendo cómo cerró la noche: el que quedara desactualizado no daría rojo, porque
## `gate_de_tests.py` no mira `ui/`. Esta suite es lo único ejecutable que lo impide.
extends GdUnitTestSuite

const HUD := "res://src/ui/hud.gd"

const ESCENA_DEL_HUD := "res://src/ui/hud.tscn"

const CARPETA_DE_UI := "res://src/ui"

## Lo que se fue con la hora. Los dos colores estaban **sólo** acá —medido con un `grep` sobre
## `src`, `test` y `project.godot`—, así que se mudaron al reloj de pared en vez de copiarse.
const RASTROS_DE_LA_HORA := [
	"mostrar_tiempo",
	"TEXTO_DEL_TIEMPO",
	"COLOR_TRANQUILO",
	"COLOR_DE_AVISO",
	"Marcador.reloj",
]

## Las suites que este spec escribe. Ninguna puede cargar una escena de la computadora: el 009
## todavía no existe, y una suite que la cargara pasaría por abortar antes de afirmar nada.
const SUITES_DEL_RELOJ_DE_PARED := [
	"res://test/dominio/jornada/reloj_de_pared_test.gd",
	"res://test/escenas/puestos/reloj_de_pared_test.gd",
	"res://test/ui/hud_test.gd",
]

## La carpeta que el 009 va a estrenar. Se arma partida a propósito: esta suite es una de las que
## se mira a sí misma, y con el nombre escrito de una pieza el caso se encontraría acá y daría
## rojo contra su propio verificador.
const CARPETA_DE_LA_COMPUTADORA := "ui/" + "diegetica"

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


func test_la_hora_se_fue_del_hud_con_todo_lo_que_traia() -> void:  # 032-AC5
	# Los dos colores mueren con la hora: no tenían otro cliente, así que dejarlos acá sería
	# código muerto que la próxima pantalla copiaría sin saber de dónde salió.
	var texto := FileAccess.get_file_as_string(HUD)
	assert_str(texto).is_not_empty()
	for rastro: String in RASTROS_DE_LA_HORA:
		(
			assert_bool(texto.contains(rastro))
			. override_failure_message("`hud.gd` todavía nombra `%s`" % rastro)
			. is_false()
		)


func test_la_escena_del_hud_perdio_el_reloj_y_conserva_los_otros_dos() -> void:  # 032-AC5
	# **El `node_paths` de la raíz pierde `"_reloj"` además del `Label`.** Si el nombre quedara
	# declarado apuntando a un nodo que ya no está, la escena carga sin un solo error y el juego
	# muere en el primer cuadro con un mensaje que no nombra al `.tscn`.
	var hud: CanvasLayer = auto_free(load(ESCENA_DEL_HUD).instantiate())
	(
		assert_bool(hud.has_node("Reloj"))
		. override_failure_message("`hud.tscn` todavía trae el `Label` de la hora")
		. is_false()
	)
	assert_bool(hud.has_node("Tareas")).is_true()
	assert_bool(hud.has_node("Apercibimientos")).is_true()
	assert_str(FileAccess.get_file_as_string(ESCENA_DEL_HUD)).not_contains("_reloj")


func test_la_hora_no_vuelve_a_entrar_a_la_pantalla_por_la_ventana() -> void:  # 032-AC9
	# La computadora del 009 va a mostrar la hora también, y va a vivir en la carpeta diegética.
	# Mientras no exista, nadie de esta capa puede preguntarle al reloj de pared: la hora se lee
	# en el local. El caso mira la capa entera y no sólo el HUD, que es lo que lo deja puesto
	# cuando `ui/` crezca.
	var culpables: Array[String] = []
	var mirados := 0
	for ruta in _scripts_de(CARPETA_DE_UI):
		mirados += 1
		if FileAccess.get_file_as_string(ruta).contains("RelojDePared"):
			culpables.append(ruta)
	(
		assert_int(mirados)
		. override_failure_message("la recorrida no abrió un solo archivo de `src/ui/`")
		. is_greater(0)
	)
	(
		assert_array(culpables)
		. override_failure_message(
			"estos archivos de `ui/` le preguntan al reloj de pared: %s" % ", ".join(culpables)
		)
		. is_empty()
	)


func test_ninguna_suite_de_este_spec_carga_la_computadora_del_009() -> void:  # 032-AC9
	# Una escena que no existe se carga como `null` y el caso **aborta antes de afirmar**, lo que
	# gdUnit4 reporta como `PASSED`. Es la peor de las tres formas en que un verde miente acá.
	for suite: String in SUITES_DEL_RELOJ_DE_PARED:
		var texto := FileAccess.get_file_as_string(suite)
		(
			assert_str(texto)
			. override_failure_message("la suite `%s` no existe o está vacía" % suite)
			. is_not_empty()
		)
		assert_str(texto).not_contains(CARPETA_DE_LA_COMPUTADORA)


## Todos los `.gd` de una carpeta, recorriendo las subcarpetas. `DirAccess` y no una lista a
## mano: una lista se olvida del archivo nuevo justo el día que el archivo nuevo aparece.
func _scripts_de(carpeta: String) -> Array[String]:
	var encontrados: Array[String] = []
	for nombre in DirAccess.get_files_at(carpeta):
		if nombre.ends_with(".gd"):
			encontrados.append(carpeta + "/" + nombre)
	for subcarpeta in DirAccess.get_directories_at(carpeta):
		encontrados.append_array(_scripts_de(carpeta + "/" + subcarpeta))
	return encontrados
