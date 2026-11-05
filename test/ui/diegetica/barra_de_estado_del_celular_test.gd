## El ícono de wifi de la barra de estado del celular: sin conexión mientras no hay wifi.
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
	pantalla.mostrar_el_wifi(true)
	assert_bool(_icono(pantalla).visible).is_false()


func test_sin_wifi_se_ve_y_al_volver_el_wifi_se_va() -> void:  # AC-ANO-025
	var pantalla := _pantalla()
	pantalla.mostrar_el_wifi(false)
	assert_bool(_icono(pantalla).visible).is_true()
	assert_object(_icono(pantalla).texture).is_not_null()
	pantalla.mostrar_el_wifi(true)
	assert_bool(_icono(pantalla).visible).is_false()


func test_el_icono_no_cambia_con_el_celular_abierto_o_cerrado() -> void:  # AC-ANO-025
	var pantalla := _pantalla()
	pantalla.mostrar_el_wifi(false)
	var telefono: Control = pantalla.get("_telefono")
	for abierto: bool in [true, false]:
		telefono.visible = abierto
		assert_bool(_icono(pantalla).visible).is_true()
