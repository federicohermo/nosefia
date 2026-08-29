## Verifica el CABLEADO, no el juego.
##
## Es el único test de este repo que no prueba una regla: prueba que Godot puede abrir este
## proyecto headless, que gdUnit4 se descubre y corre, y que el código de salida llega hasta
## `verificar.py`. O sea, prueba la tubería.
##
## Existe porque sin él esa tubería queda **sin ejercer hasta el primer spec**. El nodo `tests`
## se saltea mientras no haya un solo `*_test.gd`, así que un error en el paso que baja Godot en
## la CI, o en los flags del runner, no se vería en semanas — y se vería el peor día, cuando
## alguien está tratando de mergear otra cosa.
##
## No se borra cuando lleguen los tests de verdad: sigue siendo el que distingue «el juego está
## roto» de «la corrida no arrancó».
extends GdUnitTestSuite


func test_el_proyecto_se_llama_como_el_juego() -> void:
	# Lee de `project.godot` a través del motor, así que sólo pasa si el proyecto se cargó de
	# verdad. Un `assert_bool(true).is_true()` no distinguiría eso de un runner que arrancó en
	# un directorio vacío.
	assert_str(ProjectSettings.get_setting("application/config/name")).is_equal("No se fía")


func test_las_cuatro_capas_de_src_existen() -> void:
	# Si alguien renombra una capa, `gate_de_capas.py` deja de mirarla **en silencio**: su regla
	# se declara por prefijo de ruta, y un prefijo que no matchea nada no es un error. Esto es lo
	# que lo convierte en un rojo.
	for capa in ["dominio", "sistemas", "ui", "escenas"]:
		(
			assert_bool(DirAccess.dir_exists_absolute("res://src/%s" % capa))
			. override_failure_message(
				(
					"falta res://src/%s — si la capa se renombró, hay que actualizar CAPAS en lib/repo.py"
					% capa
				)
			)
			. is_true()
		)
