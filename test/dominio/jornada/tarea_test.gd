## Una tarea sola: recuerda su tipo, y completarla dos veces no la completa dos veces. De ese
## `false` del segundo intento se agarra `Turno` para no tener que llevar su propio registro de
## cuáles ya cumplió.
extends GdUnitTestSuite


func test_una_tarea_nueva_no_esta_completada() -> void:
	var limpiar := Tarea.new(Tarea.Tipo.LIMPIAR)
	assert_bool(limpiar.completada()).is_false()


func test_una_tarea_nueva_recuerda_su_tipo() -> void:
	var basura := Tarea.new(Tarea.Tipo.SACAR_LA_BASURA)
	assert_int(basura.tipo()).is_equal(Tarea.Tipo.SACAR_LA_BASURA)


func test_completar_una_tarea_pendiente_la_marca_y_avisa_que_pudo() -> void:
	var caja := Tarea.new(Tarea.Tipo.CAJA)
	assert_bool(caja.completar()).is_true()
	assert_bool(caja.completada()).is_true()


func test_completar_una_tarea_ya_completada_no_cambia_nada() -> void:
	var registrar := Tarea.new(Tarea.Tipo.REGISTRAR)
	registrar.completar()
	assert_bool(registrar.completar()).is_false()
	assert_bool(registrar.completada()).is_true()
