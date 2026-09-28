## Aparta el guardado de la corrida de tests: ningún caso lee ni escribe la partida del usuario.
##
## Las escenas arman su guardado solas, con la ruta por defecto. Esta ruta se fija una vez,
## antes de la primera suite, y la carpeta se borra al terminar. Lo registra `project.godot`,
## en `gdunit4/hooks/session_hooks`.
##
## Cada caso arranca también sin guardado: un caso que cierra la noche escribe, y el siguiente
## que levanta el almacén arrancaría en otra jornada.
extends GdUnitTestSessionHook

const CARPETA := "user://guardado_de_los_tests"


func _init() -> void:
	super("Guardado de la sesión", "Aparta la partida del usuario de la corrida de tests.")


func startup(session: GdUnitTestSession) -> GdUnitResult:
	_borrar_la_carpeta()
	DirAccess.make_dir_recursive_absolute(CARPETA)
	Guardado.ruta_por_defecto = CARPETA.path_join("partida.guardado")
	session.test_event.connect(_al_llegar_un_evento)
	return GdUnitResult.success()


func shutdown(_session: GdUnitTestSession) -> GdUnitResult:
	_borrar_la_carpeta()
	return GdUnitResult.success()


func _al_llegar_un_evento(evento: GdUnitEvent) -> void:
	if evento.type() == GdUnitEvent.TESTCASE_BEFORE:
		Guardado.new().borrar()


func _borrar_la_carpeta() -> void:
	for archivo: String in DirAccess.get_files_at(CARPETA):
		DirAccess.remove_absolute(CARPETA.path_join(archivo))
	DirAccess.remove_absolute(CARPETA)
