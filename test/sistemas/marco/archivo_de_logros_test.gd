## El archivo de los logros: lo que llega al disco vuelve igual, vive aparte de la partida y lo
## que no se puede leer deja todo bloqueado sin interrumpir a nadie.
extends GdUnitTestSuite

const L := Logros.Logro


func _archivo() -> ArchivoDeLogros:
	var archivo := ArchivoDeLogros.new()
	archivo.ruta = create_temp_dir("logros").path_join("logros.datos")
	# La carpeta temporal es una por suite: el caso anterior pudo dejar su archivo.
	archivo.borrar()
	return archivo


func _escribir_crudo(ruta: String, contenido: String) -> void:
	var crudo := FileAccess.open(ruta, FileAccess.WRITE)
	crudo.store_string(contenido)
	crudo.close()


func _todo_bloqueado(logros: Logros) -> bool:
	for logro: L in L.values():
		if logros.desbloqueado(logro):
			return false
	return true


func test_la_corrida_de_tests_no_apunta_al_archivo_del_usuario() -> void:
	assert_str(ArchivoDeLogros.ruta_por_defecto).is_not_equal(ArchivoDeLogros.RUTA_DEL_USUARIO)
	assert_str(ArchivoDeLogros.new().ruta).is_equal(ArchivoDeLogros.ruta_por_defecto)


func test_lo_escrito_vuelve_en_otro_arranque() -> void:  # AC-ACH-010
	var archivo := _archivo()
	var logros := Logros.new()
	logros.desbloquear(L.REBELDE)
	logros.alcanzar_final(Partida.Final.DESPEDIDO)
	logros.descubrir_pista("UNA_PISTA")
	assert_bool(archivo.escribir(logros)).is_true()
	var otro_arranque := ArchivoDeLogros.new()
	otro_arranque.ruta = archivo.ruta
	var leidos := otro_arranque.cargar()
	assert_bool(leidos.desbloqueado(L.REBELDE)).is_true()
	assert_bool(leidos.desbloqueado(L.A_LA_BASURA)).is_false()
	assert_bool(leidos.final_alcanzado(Partida.Final.DESPEDIDO)).is_true()
	assert_bool(leidos.pista_descubierta("UNA_PISTA")).is_true()


func test_sin_archivo_no_hay_nada_desbloqueado() -> void:  # AC-ACH-010
	assert_bool(_todo_bloqueado(_archivo().cargar())).is_true()


func test_un_archivo_ilegible_deja_todo_bloqueado_sin_fallar() -> void:  # AC-ACH-010
	var archivo := _archivo()
	_escribir_crudo(archivo.ruta, "esto no es un diccionario {{{")
	assert_bool(_todo_bloqueado(archivo.cargar())).is_true()
	_escribir_crudo(archivo.ruta, "[1, 2, 3]")
	assert_bool(_todo_bloqueado(archivo.cargar())).is_true()


func test_un_logro_que_el_catalogo_no_conoce_se_ignora() -> void:  # AC-ACH-010
	var archivo := _archivo()
	var datos := {Logros.CLAVE_DE_LOGROS: ["NO_EXISTE", L.keys()[L.REBELDE]]}
	_escribir_crudo(archivo.ruta, var_to_str(datos))
	var leidos := archivo.cargar()
	assert_bool(leidos.desbloqueado(L.REBELDE)).is_true()
	assert_bool(leidos.desbloqueado(L.A_LA_BASURA)).is_false()


func test_borrar_la_partida_no_toca_los_logros() -> void:  # AC-ACH-010
	var archivo := _archivo()
	var logros := Logros.new()
	logros.desbloquear(L.REBELDE)
	archivo.escribir(logros)
	var guardado := Guardado.new()
	guardado.ruta = archivo.ruta.get_base_dir().path_join("partida.guardado")
	guardado.escribir(PartidaSerializada.sanear({}))
	guardado.borrar()
	assert_bool(guardado.hay_guardado()).is_false()
	assert_bool(archivo.cargar().desbloqueado(L.REBELDE)).is_true()


func test_los_logros_viven_en_user_y_aparte_de_la_partida() -> void:  # AC-ACH-010
	# En la web, `user://` es el almacenamiento del navegador: lo mismo que hace sobrevivir al
	# guardado una recarga de la página.
	assert_str(ArchivoDeLogros.RUTA_DEL_USUARIO).starts_with("user://")
	assert_str(ArchivoDeLogros.RUTA_DEL_USUARIO).is_not_equal(Guardado.RUTA_DEL_USUARIO)
	assert_str(ArchivoDeLogros.RUTA_DEL_USUARIO).is_not_equal(
		ArchivoDePreferencias.RUTA_DEL_USUARIO
	)


func test_una_escritura_que_no_llega_al_disco_lo_dice() -> void:
	var archivo := ArchivoDeLogros.new()
	archivo.ruta = "user://carpeta_que_no_existe_%d/logros.datos" % OS.get_process_id()
	assert_bool(archivo.escribir(Logros.new())).is_false()
