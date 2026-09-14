## Los ajustes del motor que el proyecto declara en vez de heredar.
##
## Se lee el archivo y no `ProjectSettings`. El motor contesta el valor heredado igual que el
## declarado. Preguntarle daría verde con `project.godot` vacío, que es el estado que este spec
## cierra.
##
## La excepción es el reloj de física, y el caso la explica adentro: su valor elegido coincide
## con el valor por defecto, así que el editor no lo guarda en el archivo.
extends GdUnitTestSuite

const PROYECTO := "res://project.godot"


## Parte el nombre del ajuste en el par `[sección] clave` con el que vive en el archivo.
## `physics/common/physics_interpolation` es la clave `common/physics_interpolation` de la sección
## `physics`. El corte va en el primer `/` porque así lo serializa el motor.
func _declarado(ajuste: String, por_defecto: Variant) -> Variant:
	var archivo := ConfigFile.new()
	(
		assert_int(archivo.load(PROYECTO))
		. override_failure_message("`%s` no se pudo leer como ConfigFile" % PROYECTO)
		. is_equal(OK)
	)
	var corte := ajuste.find("/")
	return archivo.get_value(ajuste.substr(0, corte), ajuste.substr(corte + 1), por_defecto)


func test_el_proyecto_declara_la_interpolacion_de_fisica_encendida() -> void:  # 044-AC1
	# Apagada, la posición avanza 60 veces por segundo contra una pantalla que dibuja 145. Eso
	# es el temblor que se reportó como caída de cuadros.
	(
		assert_bool(_declarado("physics/common/physics_interpolation", false))
		. override_failure_message(
			"falta `common/physics_interpolation=true` en la sección [physics] de project.godot"
		)
		. is_true()
	)


func test_el_reloj_de_fisica_corre_a_sesenta_pasos() -> void:  # 044-AC3
	# Este caso pregunta al motor, al revés que los otros tres. El editor no guarda un ajuste
	# igual a su valor por defecto. Medido: con `common/physics_ticks_per_second=60` escrito a
	# mano, `--import` borra la línea; con 90, la conserva. O sea que 60 no se puede declarar.
	#
	# El rojo llega igual. Cualquier valor distinto de 60 sí queda escrito en el archivo, y el
	# motor lo contesta acá. Es el número que `src/dominio/jugador/foco.gd` afirma en su
	# encabezado. Subirlo duplica los rayos que `_medir_candidato()` tira cada paso.
	(
		assert_int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 0))
		. override_failure_message("el reloj de física no corre a 60 pasos por segundo")
		. is_equal(60)
	)


func test_el_editor_y_la_web_dibujan_con_el_mismo_renderizador() -> void:  # 044-AC2
	# Los dos valores se mueven juntos. Con `gl_compatibility` declarado y `"Forward Plus"` en
	# `config/features`, el proyecto anuncia un renderizador que en web no existe.
	(
		assert_str(str(_declarado("rendering/renderer/rendering_method", "")))
		. override_failure_message(
			'falta `renderer/rendering_method="gl_compatibility"` en [rendering]'
		)
		. is_equal("gl_compatibility")
	)
	var anunciadas := PackedStringArray(_declarado("application/config/features", []))
	(
		assert_bool("Forward Plus" in anunciadas)
		. override_failure_message(
			'`config/features` todavía anuncia "Forward Plus", que en web no existe'
		)
		. is_false()
	)


func test_ninguna_plataforma_declara_un_renderizador_distinto_del_general() -> void:  # 044-AC2
	# Antes de este spec, `rendering_method.web` valía otra cosa que `rendering_method`. El editor
	# y la web mostraban sombras distintas.
	var general := str(_declarado("rendering/renderer/rendering_method", ""))
	for plataforma: String in ["web", "mobile"]:
		var ajuste := "rendering/renderer/rendering_method.%s" % plataforma
		(
			assert_str(str(_declarado(ajuste, general)))
			. override_failure_message(
				"`rendering_method.%s` difiere del renderizador general" % plataforma
			)
			. is_equal(general)
		)
