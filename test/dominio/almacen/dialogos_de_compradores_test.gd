extends GdUnitTestSuite

const TEXTOS := preload("res://assets/dialogos/compradores_jornada_1.tres")


func test_el_pedido_y_los_nombres_destacados_salen_de_la_ficha() -> void:  # AC-CTR-036
	var martin: Dialogo = TEXTOS.inicial(DialogosDeCompradores.Personaje.MARTIN)
	assert_str(martin.entrada_actual()).contains("[b][color=#e4f850]Coracola")
	assert_str(martin.entrada_actual()).not_contains("Pura-Cola")
	martin.avanzar()
	assert_str(martin.entrada_actual()).contains("[b][color=#e4f850]Malbardo")
	martin.avanzar()
	assert_bool(martin.terminado()).is_false()
	martin.avanzar()
	assert_bool(martin.terminado()).is_true()
	var tiago: Dialogo = TEXTOS.inicial(DialogosDeCompradores.Personaje.TIAGO)
	assert_str(tiago.entrada_actual()).contains("dos paquetes de [b][color=#cbdc48]zucarachas")
	assert_str(tiago.entrada_actual()).contains("Pepito argento")
	assert_bool(TEXTOS.inicial(DialogosDeCompradores.Personaje.MARTIN).terminado()).is_false()


func test_rechazo_y_recordatorio_enumeran_el_pedido() -> void:  # AC-CTR-037
	var tiago := Compradores.de_la_jornada(1)[1]
	var rechazo: Dialogo = TEXTOS.recordatorio(tiago.personaje, true)
	assert_str(rechazo.entrada_actual()).starts_with("Yo no pedí esto. Quiero dos")
	assert_str(rechazo.entrada_actual()).contains("Zucarachas")
	assert_str(rechazo.entrada_actual()).contains("pepito argento")
	rechazo.avanzar()
	assert_bool(rechazo.terminado()).is_true()


func test_despedida_de_tiago_conserva_sus_cuatro_entradas() -> void:  # AC-CTR-039
	var dialogo: Dialogo = TEXTOS.despedida(DialogosDeCompradores.Personaje.TIAGO)
	assert_str(dialogo.entrada_actual()).is_equal("Gracias, tenía mucha hambre.")
	dialogo.avanzar()
	assert_str(dialogo.entrada_actual()).contains("empleado anterior")
	dialogo.avanzar()
	assert_str(dialogo.entrada_actual()).contains("Enrique Peldaño")
	dialogo.avanzar()
	assert_str(dialogo.entrada_actual()).contains("11 ****-****")
	dialogo.avanzar()
	assert_bool(dialogo.terminado()).is_true()
