## La partida recuerda si la mopa ya se secó una vez, y lo guarda.
extends GdUnitTestSuite

const CLAVE := "mopa_secada"


func test_una_partida_nueva_no_tiene_la_marca() -> void:  # AC-SAV-026
	assert_bool(Partida.nueva().mopa_secada()).is_false()
	var partida := Partida.nueva()
	partida.anotar_mopa_secada()
	assert_bool(partida.mopa_secada()).is_true()


func test_la_marca_va_y_vuelve_por_el_guardado() -> void:  # AC-SAV-026
	var partida := Partida.nueva()
	partida.anotar_mopa_secada()
	var datos := PoliticaDeGuardado.datos(partida)
	assert_bool(datos[CLAVE] is bool).is_true()
	assert_bool(Partida.desde(datos).mopa_secada()).is_true()
	assert_bool(Partida.desde(PoliticaDeGuardado.datos(Partida.nueva())).mopa_secada()).is_false()


func test_un_guardado_sin_la_marca_o_con_otro_tipo_vuelve_sin_ella() -> void:  # AC-SAV-026
	var datos := PoliticaDeGuardado.datos(Partida.nueva())
	datos.erase(CLAVE)
	assert_bool(Partida.desde(datos).mopa_secada()).is_false()
	datos[CLAVE] = 1
	assert_bool(Partida.desde(datos).mopa_secada()).is_false()
