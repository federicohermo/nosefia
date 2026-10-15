## El archivo de las preferencias: lo que llega al disco vuelve igual, y lo que no se puede leer
## devuelve los defectos sin interrumpir a nadie.
extends GdUnitTestSuite

const C := Preferencias.Campo


func _archivo() -> ArchivoDePreferencias:
	var archivo := ArchivoDePreferencias.new()
	archivo.ruta = create_temp_dir("preferencias").path_join("preferencias.datos")
	# La carpeta temporal es una por suite: el caso anterior pudo dejar su archivo.
	archivo.borrar()
	return archivo


func _escribir_crudo(ruta: String, contenido: String) -> void:
	var crudo := FileAccess.open(ruta, FileAccess.WRITE)
	crudo.store_string(contenido)
	crudo.close()


func _en_su_defecto(preferencias: Preferencias) -> bool:
	var defecto := Preferencias.new()
	for campo: Preferencias.Campo in Preferencias.CAMPOS:
		if not is_equal_approx(preferencias.valor(campo), defecto.valor(campo)):
			return false
	return true


func test_la_corrida_de_tests_no_apunta_al_archivo_del_usuario() -> void:
	assert_str(ArchivoDePreferencias.ruta_por_defecto).is_not_equal(
		ArchivoDePreferencias.RUTA_DEL_USUARIO
	)
	assert_str(ArchivoDePreferencias.new().ruta).is_equal(ArchivoDePreferencias.ruta_por_defecto)


func test_lo_escrito_vuelve_en_otro_arranque_con_los_cinco_valores() -> void:  # AC-CFG-012
	var archivo := _archivo()
	var preferencias := Preferencias.new()
	preferencias.poner(C.EFECTOS, 40.0)
	preferencias.poner(C.MUSICA, 30.0)
	preferencias.poner(C.BRILLO, 60.0)
	preferencias.poner(C.SENSIBILIDAD, 1.5)
	preferencias.poner(C.TEXTOS, 1.2)
	assert_bool(archivo.escribir(preferencias)).is_true()
	var otro_arranque := ArchivoDePreferencias.new()
	otro_arranque.ruta = archivo.ruta
	var leidas := otro_arranque.cargar()
	for campo: Preferencias.Campo in Preferencias.CAMPOS:
		assert_float(leidas.valor(campo)).is_equal_approx(preferencias.valor(campo), 1e-6)


func test_sin_archivo_vuelven_los_defectos() -> void:  # AC-CFG-014
	assert_bool(_en_su_defecto(_archivo().cargar())).is_true()


func test_un_archivo_ilegible_devuelve_los_defectos_sin_fallar() -> void:  # AC-CFG-014
	var archivo := _archivo()
	_escribir_crudo(archivo.ruta, "esto no es un diccionario {{{")
	assert_bool(_en_su_defecto(archivo.cargar())).is_true()
	_escribir_crudo(archivo.ruta, "[1, 2, 3]")
	assert_bool(_en_su_defecto(archivo.cargar())).is_true()


func test_un_campo_malo_en_el_disco_vuelve_a_su_defecto() -> void:  # AC-CFG-014
	var archivo := _archivo()
	_escribir_crudo(archivo.ruta, var_to_str({"musica": 30.0, "efectos": 150.0}))
	var leidas := archivo.cargar()
	assert_float(leidas.valor(C.MUSICA)).is_equal_approx(30.0, 1e-6)
	assert_float(leidas.valor(C.EFECTOS)).is_equal_approx(100.0, 1e-6)
	assert_float(leidas.valor(C.TEXTOS)).is_equal_approx(1.0, 1e-6)


func test_borrar_el_guardado_de_la_partida_no_toca_las_preferencias() -> void:  # AC-CFG-011
	var archivo := _archivo()
	var preferencias := Preferencias.new()
	preferencias.poner(C.MUSICA, 30.0)
	archivo.escribir(preferencias)
	var guardado := Guardado.new()
	guardado.ruta = archivo.ruta.get_base_dir().path_join("partida.guardado")
	guardado.escribir(PartidaSerializada.sanear({}))
	assert_bool(guardado.hay_guardado()).is_true()
	guardado.borrar()
	assert_bool(guardado.hay_guardado()).is_false()
	assert_float(archivo.cargar().valor(C.MUSICA)).is_equal_approx(30.0, 1e-6)


func test_las_preferencias_viven_en_user_y_aparte_de_la_partida() -> void:  # AC-CFG-011
	# En la web, `user://` es el almacenamiento del navegador: lo mismo que hace sobrevivir al
	# guardado una recarga de la página.
	assert_str(ArchivoDePreferencias.RUTA_DEL_USUARIO).starts_with("user://")
	assert_str(ArchivoDePreferencias.RUTA_DEL_USUARIO).is_not_equal(Guardado.RUTA_DEL_USUARIO)


func test_una_escritura_que_no_llega_al_disco_lo_dice() -> void:
	var archivo := ArchivoDePreferencias.new()
	archivo.ruta = "user://carpeta_que_no_existe_%d/preferencias.datos" % OS.get_process_id()
	assert_bool(archivo.escribir(Preferencias.new())).is_false()
