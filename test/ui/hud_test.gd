## Qué NO dibuja el HUD.
##
## Le habían puesto un veredicto de cierre, y con la placa de cierre serían dos lugares
## diciendo cómo cerró la noche: el que quedara desactualizado no daría rojo, porque
## `gate_de_tests.py` no mira `ui/`. Esta suite es lo único ejecutable que lo impide.
extends GdUnitTestSuite

const HUD := "res://src/ui/hud.gd"

const ESCENA_DEL_HUD := "res://src/ui/hud.tscn"

const CARPETA_DE_UI := "res://src/ui"

## Lo que se fue con la hora. Los dos colores estaban **sólo** acá —medido con un `grep` sobre
## `src`, `test` y `project.godot`—, y murieron con la franja de aviso.
const RASTROS_DE_LA_HORA := [
	"mostrar_tiempo",
	"TEXTO_DEL_TIEMPO",
	"COLOR_TRANQUILO",
	"COLOR_DE_AVISO",
	"Marcador.hora",
]

## Las suites que este spec escribe. Ninguna puede cargar una escena de la computadora: el 009
## todavía no existe, y una suite que la cargara pasaría por abortar antes de afirmar nada.
const SUITES_DEL_RELOJ_DE_MESA := [
	"res://test/dominio/jornada/reloj_de_mesa_test.gd",
	"res://test/escenas/puestos/reloj_de_mesa_test.gd",
	"res://test/ui/hud_test.gd",
]

## La carpeta que el 009 va a estrenar. Se arma partida a propósito: esta suite es una de las que
## se mira a sí misma, y con el nombre escrito de una pieza el caso se encontraría acá y daría
## rojo contra su propio verificador.
const CARPETA_DE_LA_COMPUTADORA := "ui/" + "diegetica"

## Lo que ese veredicto traía consigo. El segundo es el que importa: traducir la banda a
## palabras es una regla del juego, y acá arriba nace sin test.
const RASTROS_DEL_VEREDICTO := ["mostrar_veredicto", "consecuencia_de"]

## El tema de la UI de Manada, el mismo que aplica la computadora.
const TEMA := "res://assets/ui/manada/tema.tres"

## Lo que delataría el texto de la caja armado acá: sus palabras, su cuenta y quien la lleva.
const RASTROS_DEL_TEXTO_DE_LA_CAJA := [
	"Una caja con", "Entra", "ContenidoDeLaCaja", "UNIDADES_POR_CAJA"
]


func test_el_hud_no_dibuja_el_veredicto_del_cierre() -> void:
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


func test_el_hud_sigue_pintando_lo_que_si_es_suyo() -> void:
	# El par del caso de arriba: sin esto, borrar el archivo entero lo dejaría en verde.
	var texto := FileAccess.get_file_as_string(HUD)
	assert_str(texto).contains("func mostrar_tareas")
	assert_str(texto).contains("func mostrar_apercibimientos")


func test_la_hora_se_fue_del_hud_con_todo_lo_que_traia() -> void:
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


func test_la_escena_del_hud_perdio_el_reloj_y_conserva_los_otros_dos() -> void:
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


func test_la_hora_no_vuelve_a_entrar_a_la_pantalla_por_la_ventana() -> void:
	# La hora se lee en un solo lugar, el reloj de mesa del local: ni la computadora ni ninguna
	# pantalla de esta capa le preguntan al dominio por ella. El caso mira la capa entera y no
	# sólo el HUD, que es lo que lo deja puesto cuando `ui/` crezca.
	var culpables: Array[String] = []
	var mirados := 0
	for ruta in _scripts_de(CARPETA_DE_UI):
		mirados += 1
		if FileAccess.get_file_as_string(ruta).contains("RelojDeMesa"):
			culpables.append(ruta)
	(
		assert_int(mirados)
		. override_failure_message("la recorrida no abrió un solo archivo de `src/ui/`")
		. is_greater(0)
	)
	(
		assert_array(culpables)
		. override_failure_message(
			"estos archivos de `ui/` le preguntan al reloj de mesa: %s" % ", ".join(culpables)
		)
		. is_empty()
	)


func test_ninguna_suite_de_este_spec_carga_la_computadora_del_009() -> void:
	# Una escena que no existe se carga como `null` y el caso **aborta antes de afirmar**, lo que
	# gdUnit4 reporta como `PASSED`. Es la peor de las tres formas en que un verde miente acá.
	for suite: String in SUITES_DEL_RELOJ_DE_MESA:
		var texto := FileAccess.get_file_as_string(suite)
		(
			assert_str(texto)
			. override_failure_message("la suite `%s` no existe o está vacía" % suite)
			. is_not_empty()
		)
		assert_str(texto).not_contains(CARPETA_DE_LA_COMPUTADORA)


func test_el_subtitulo_usa_el_tema_de_manada_sin_fuente_ni_color_propios() -> void:
	# La identidad de la UI de Manada, la misma que aplica la computadora. Una fuente o un color
	# propios serían un segundo estilo, que se separa del tema sin que nada se ponga en rojo.
	var hud: Hud = auto_free(load(ESCENA_DEL_HUD).instantiate())
	add_child(hud)
	var subtitulo := hud.get_node_or_null("Subtitulo") as Label
	assert_object(subtitulo).is_not_null()
	if subtitulo == null:
		return
	assert_object(subtitulo.theme).is_not_null()
	if subtitulo.theme == null:
		return
	assert_str(subtitulo.theme.resource_path).is_equal(TEMA)
	assert_bool(subtitulo.has_theme_font_override("font")).is_false()
	assert_bool(subtitulo.has_theme_color_override("font_color")).is_false()
	var tema: Theme = load(TEMA)
	assert_str(tema.default_font.resource_path).contains("unscii-16")
	assert_object(subtitulo.get_theme_font("font")).is_same(tema.default_font)
	assert_that(subtitulo.get_theme_color("font_color")).is_equal(
		tema.get_color("font_color", "Label")
	)
	# No retiene al jugador: el mouse lo atraviesa y el examen se cierra con la E, como siempre.
	assert_int(subtitulo.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


func test_el_hud_pinta_el_subtitulo_que_le_llega_y_lo_vacia() -> void:
	var hud: Hud = auto_free(load(ESCENA_DEL_HUD).instantiate())
	add_child(hud)
	var subtitulo: Label = hud.get_node("Subtitulo")
	assert_str(subtitulo.text).is_empty()
	hud.mostrar_subtitulo("Una caja con 8 cajitas de Actroncito.")
	assert_str(subtitulo.text).is_equal("Una caja con 8 cajitas de Actroncito.")
	hud.vaciar_subtitulo()
	assert_str(subtitulo.text).is_empty()


func test_el_hud_no_arma_el_texto_de_la_caja() -> void:
	# El texto lo arma la caja en `dominio/`, donde tiene test. Armado acá, cuántas le entran a
	# una caja sería una regla del juego en una capa que el gate de tests no mira.
	var texto := FileAccess.get_file_as_string(HUD)
	assert_str(texto).is_not_empty()
	for rastro: String in RASTROS_DEL_TEXTO_DE_LA_CAJA:
		(
			assert_bool(texto.contains(rastro))
			. override_failure_message("`hud.gd` nombra `%s`: arma el texto de la caja" % rastro)
			. is_false()
		)


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
