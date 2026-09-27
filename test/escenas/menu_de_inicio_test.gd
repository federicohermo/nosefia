## El menú de inicio: que el juego abre en él y que muestra lo que contesta el dominio.
extends GdUnitTestSuite

const ESCENA_DEL_MENU := "res://src/escenas/menu_de_inicio.tscn"
const TEXTOS_FUERA_DE_LA_WEB: Array[String] = [
	"NUEVO JUEGO",
	"CONTINUAR",
	"CONFIGURACIONES",
	"LOGROS",
	"SALIR",
]
const HABILITADOS_FUERA_DE_LA_WEB: Array[String] = ["NUEVO JUEGO", "SALIR"]


func _menu() -> Control:
	var menu: Control = auto_free(load(ESCENA_DEL_MENU).instantiate())
	add_child(menu)
	return menu


func test_el_juego_abre_en_el_menu() -> void:  # AC-SAV-012
	assert_str(ProjectSettings.get_setting("application/run/main_scene")).is_equal(ESCENA_DEL_MENU)
	assert_object(_menu()).is_not_null()


func test_muestra_los_cinco_botones_y_habilita_dos() -> void:
	var textos: Array[String] = []
	var habilitados: Array[String] = []
	for boton: Button in _menu().find_children("*", "Button", true, false):
		if boton.visible:
			textos.append(boton.text)
			if not boton.disabled:
				habilitados.append(boton.text)
	assert_array(textos).is_equal(TEXTOS_FUERA_DE_LA_WEB)
	assert_array(habilitados).is_equal(HABILITADOS_FUERA_DE_LA_WEB)


func test_el_menu_no_declara_estilos_propios() -> void:
	var texto := FileAccess.get_file_as_string(ESCENA_DEL_MENU)
	assert_str(texto).contains("res://assets/ui/manada/tema.tres")
	assert_str(texto).contains("res://assets/ui/manada/fondo_inicio.png")
	assert_str(texto).not_contains("theme_override_")
