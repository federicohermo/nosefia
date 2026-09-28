## Ningún test lee ni escribe la partida del usuario, aunque levante el almacén y cierre la noche.
##
## Lo sostiene el gancho de sesión `test/guardado_de_la_sesion.gd`. Sin él, este caso da rojo.
extends GdUnitTestSuite

const ESCENA_DEL_ALMACEN := "res://src/escenas/almacen.tscn"
const SEGUNDOS_REALES_DE_UN_TURNO := (
	Reglas.DURACION_DEL_TURNO / Ritmo.SEGUNDOS_DE_TURNO_POR_SEGUNDO_REAL
)


func _huella_del_usuario() -> String:
	if not FileAccess.file_exists(Guardado.RUTA_DEL_USUARIO):
		return "sin archivo"
	return FileAccess.get_file_as_string(Guardado.RUTA_DEL_USUARIO)


func test_cerrar_una_noche_no_toca_la_partida_del_usuario() -> void:
	assert_str(Guardado.ruta_por_defecto).is_not_equal(Guardado.RUTA_DEL_USUARIO)
	assert_str(Guardado.new().ruta).is_not_equal(Guardado.RUTA_DEL_USUARIO)
	var antes := _huella_del_usuario()
	var almacen: Node3D = auto_free(load(ESCENA_DEL_ALMACEN).instantiate())
	add_child(almacen)
	await get_tree().process_frame
	var reloj: RelojDelTurno = almacen.get("_reloj")
	reloj._process(SEGUNDOS_REALES_DE_UN_TURNO)
	await get_tree().process_frame
	assert_bool((almacen.get("_pantalla") as PantallaDeCierre).visible).is_true()
	assert_str(_huella_del_usuario()).is_equal(antes)
	assert_bool(FileAccess.file_exists(Guardado.ruta_por_defecto)).is_true()


## Los dos casos que siguen van juntos y en este orden: el primero deja un guardado, y el
## segundo afirma que no lo hereda.
func test_un_caso_deja_un_guardado_en_la_carpeta_de_la_sesion() -> void:
	assert_bool(Guardado.new().escribir(PartidaSerializada.sanear({}))).is_true()
	assert_bool(Guardado.new().hay_guardado()).is_true()


func test_el_caso_siguiente_arranca_sin_guardado() -> void:
	assert_bool(Guardado.new().hay_guardado()).is_false()
