## Los íconos de wifi de la barra de estado del celular: conectado con wifi, y el de sin conexión
## en su lugar mientras no hay.
extends GdUnitTestSuite

const ESCENA := preload("res://src/ui/diegetica/pantalla_del_celular.tscn")


func _pantalla() -> PantallaDelCelular:
	var pantalla: PantallaDelCelular = auto_free(ESCENA.instantiate())
	add_child(pantalla)
	return pantalla


func _icono(pantalla: PantallaDelCelular) -> TextureRect:
	return pantalla.find_child("SinWifi", true, false) as TextureRect


func test_con_wifi_no_se_ve_el_icono_de_sin_conexion() -> void:  # AC-ANO-025
	var pantalla := _pantalla()
	assert_bool(_icono(pantalla).visible).is_false()
	pantalla.barra_de_estado().mostrar_el_wifi(true)
	assert_bool(_icono(pantalla).visible).is_false()


func test_sin_wifi_se_ve_y_al_volver_el_wifi_se_va() -> void:  # AC-ANO-025
	var pantalla := _pantalla()
	pantalla.barra_de_estado().mostrar_el_wifi(false)
	assert_bool(_icono(pantalla).visible).is_true()
	assert_object(_icono(pantalla).texture).is_not_null()
	pantalla.barra_de_estado().mostrar_el_wifi(true)
	assert_bool(_icono(pantalla).visible).is_false()


func test_el_icono_no_cambia_con_el_celular_abierto_o_cerrado() -> void:  # AC-ANO-025
	var pantalla := _pantalla()
	pantalla.barra_de_estado().mostrar_el_wifi(false)
	var telefono: Control = pantalla.get("_telefono")
	for abierto: bool in [true, false]:
		telefono.visible = abierto
		assert_bool(_icono(pantalla).visible).is_true()


func _conectado(pantalla: PantallaDelCelular) -> TextureRect:
	return pantalla.find_child("Wifi", true, false) as TextureRect


func test_sin_wifi_el_de_sin_conexion_reemplaza_al_conectado() -> void:  # AC-INV-196
	var pantalla := _pantalla()
	pantalla.barra_de_estado().mostrar_el_wifi(true)
	assert_bool(_conectado(pantalla).visible).is_true()
	assert_object(_conectado(pantalla).texture).is_not_null()
	pantalla.barra_de_estado().mostrar_el_wifi(false)
	assert_bool(_conectado(pantalla).visible).is_false()
	assert_bool(_icono(pantalla).visible).is_true()
	pantalla.barra_de_estado().mostrar_el_wifi(true)
	assert_bool(_conectado(pantalla).visible).is_true()
	assert_bool(_icono(pantalla).visible).is_false()


func test_sin_conexion_ocupa_el_lugar_del_conectado_y_la_hora_no_cambia() -> void:  # AC-INV-196
	var pantalla := _pantalla()
	pantalla.barra_de_estado().mostrar_tiempo(Reglas.DURACION_DEL_TURNO / 2.0)
	var hora: Label = pantalla.find_child("Hora", true, false)
	var leida := hora.text
	await get_tree().process_frame
	await get_tree().process_frame
	var lugar := _conectado(pantalla).get_global_rect()
	pantalla.barra_de_estado().mostrar_el_wifi(false)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_vector(_icono(pantalla).get_global_rect().position).is_equal(lugar.position)
	assert_str(hora.text).is_equal(leida)
