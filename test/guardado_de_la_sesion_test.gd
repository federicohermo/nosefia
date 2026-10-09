## El hook puede arrancar y limpiar una sesión nueva sin consultar una carpeta inexistente.
extends GdUnitTestSuite

const HOOK := preload("res://test/guardado_de_la_sesion.gd")


func test_limpiar_una_sesion_nueva_no_emite_errores() -> void:
	var hook := HOOK.new()
	hook.carpeta = "user://sonda_hook_nuevo_%d" % OS.get_process_id()
	assert_bool(DirAccess.dir_exists_absolute(hook.carpeta)).is_false()
	await assert_error(func() -> void: hook._borrar_la_carpeta()).is_success()
	assert_bool(DirAccess.dir_exists_absolute(hook.carpeta)).is_false()


func test_limpiar_retira_su_guardado_y_conserva_la_carpeta_vecina() -> void:
	var hook := HOOK.new()
	hook.carpeta = "user://sonda_hook_existente_%d" % OS.get_process_id()
	var vecina := hook.carpeta + "_vecina"
	DirAccess.make_dir_recursive_absolute(hook.carpeta)
	DirAccess.make_dir_recursive_absolute(vecina)
	var archivo := FileAccess.open(hook.carpeta.path_join("partida.guardado"), FileAccess.WRITE)
	archivo.store_string("guardado de la sonda")
	archivo.close()
	await assert_error(func() -> void: hook._borrar_la_carpeta()).is_success()
	assert_bool(DirAccess.dir_exists_absolute(hook.carpeta)).is_false()
	assert_bool(DirAccess.dir_exists_absolute(vecina)).is_true()
	DirAccess.remove_absolute(vecina)
