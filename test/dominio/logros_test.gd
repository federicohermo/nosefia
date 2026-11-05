## Los logros: cuándo se ganan, que se ganan una sola vez y que lo guardado vuelve igual, sin
## levantar una escena.
extends GdUnitTestSuite

const ReglasDelCierre := preload("res://src/dominio/almacen/reglas_del_cierre.gd")
const L := Logros.Logro
const T := Tarea.Tipo
const F := Partida.Final
const HABITACION := ReglasDelCierre.Habitacion


func _registro() -> RegistroDeVentas:
	var inventario := Inventario.new(Catalogo.todos())
	var atender := TareaDeAtender.new([] as Array[Comprador], inventario)
	return RegistroDeVentas.new(Catalogo.todos(), atender)


func _antecedentes_con(fallas: int, tipo: T) -> Antecedentes:
	var antecedentes := Antecedentes.new()
	for _noche in fallas:
		antecedentes.anotar_noche([tipo], [] as Array[Partida.Llamado], 0)
	return antecedentes


func test_el_catalogo_tiene_nueve_logros_con_nombre_propio() -> void:  # AC-ACH-001
	assert_int(L.values().size()).is_equal(9)
	var vistos: Array[String] = []
	for logro: L in L.values():
		var nombre := Logros.nombre(logro)
		assert_str(nombre).is_not_empty()
		assert_bool(vistos.has(nombre)).is_false()
		vistos.append(nombre)


func test_sin_archivo_los_nueve_estan_bloqueados() -> void:  # AC-ACH-001
	var logros := Logros.new()
	for logro: L in L.values():
		assert_bool(logros.desbloqueado(logro)).is_false()


func test_un_logro_se_gana_una_sola_vez() -> void:  # AC-ACH-002
	var logros := Logros.new()
	assert_bool(logros.desbloquear(L.REBELDE)).is_true()
	assert_bool(logros.desbloqueado(L.REBELDE)).is_true()
	assert_bool(logros.desbloquear(L.REBELDE)).is_false()
	assert_bool(logros.desbloqueado(L.A_LA_BASURA)).is_false()


func test_estamos_al_pedo_pide_el_tope_y_no_una_unidad_antes() -> void:  # AC-ACH-005
	var registro := _registro()
	var producto := registro.productos()[0]
	for _i in RegistroDeVentas.TOPE_POR_FILA - 1:
		registro.sumar(producto)
	assert_bool(Logros.estamos_al_pedo(registro)).is_false()
	registro.sumar(producto)
	assert_bool(Logros.estamos_al_pedo(registro)).is_true()
	registro.restar(producto)
	assert_bool(Logros.estamos_al_pedo(registro)).is_false()


func test_empleado_ejemplar_pide_contrato_cumplido_y_cero_medios() -> void:  # AC-ACH-006
	assert_bool(Logros.empleado_ejemplar(F.CONTRATO_CUMPLIDO, 0)).is_true()
	assert_bool(Logros.empleado_ejemplar(F.CONTRATO_CUMPLIDO, 1)).is_false()
	assert_bool(Logros.empleado_ejemplar(F.DESPEDIDO, 0)).is_false()
	assert_bool(Logros.empleado_ejemplar(F.EN_CURSO, 0)).is_false()


func test_pesima_primera_impresion_es_un_despido_de_la_prueba() -> void:  # AC-ACH-007
	var ultima_de_la_prueba := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA - 1
	assert_bool(Logros.pesima_primera_impresion(F.DESPEDIDO, ultima_de_la_prueba)).is_true()
	(
		assert_bool(
			Logros.pesima_primera_impresion(F.DESPEDIDO, ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA)
		)
		. is_false()
	)
	assert_bool(Logros.pesima_primera_impresion(F.EN_CURSO, ultima_de_la_prueba)).is_false()
	(
		assert_bool(Logros.pesima_primera_impresion(F.CONTRATO_CUMPLIDO, ultima_de_la_prueba))
		. is_false()
	)


func test_el_talon_de_aquiles_cuenta_una_misma_tarea() -> void:  # AC-ACH-008
	(
		assert_bool(Logros.talon_de_aquiles(_antecedentes_con(Logros.FALLAS_DEL_TALON, T.CAJA)))
		. is_true()
	)
	(
		assert_bool(Logros.talon_de_aquiles(_antecedentes_con(Logros.FALLAS_DEL_TALON - 1, T.CAJA)))
		. is_false()
	)


func test_el_talon_de_aquiles_no_suma_tareas_distintas() -> void:  # AC-ACH-008
	var antecedentes := Antecedentes.new()
	for _noche in Logros.FALLAS_DEL_TALON - 1:
		antecedentes.anotar_noche([T.CAJA, T.REPONER], [] as Array[Partida.Llamado], 0)
	assert_bool(Logros.talon_de_aquiles(antecedentes)).is_false()


func test_un_cuerpo_afuera_gana_y_uno_sostenido_o_eximido_no() -> void:  # AC-ACH-004
	assert_bool(Logros.y_se_marcho(HABITACION.AFUERA, false, false)).is_true()
	assert_bool(Logros.y_se_marcho(HABITACION.AFUERA, true, false)).is_false()
	assert_bool(Logros.y_se_marcho(HABITACION.AFUERA, false, true)).is_false()
	assert_bool(Logros.y_se_marcho(HABITACION.LOCAL, false, false)).is_false()
	assert_bool(Logros.y_se_marcho(HABITACION.DEPOSITO, false, false)).is_false()


func test_lo_guardado_vuelve_igual() -> void:  # AC-ACH-010
	var logros := Logros.new()
	logros.desbloquear(L.REBELDE)
	logros.desbloquear(L.MI_TALON_DE_AQUILES)
	var leidos := Logros.desde(logros.datos())
	for logro: L in L.values():
		assert_bool(leidos.desbloqueado(logro)).is_equal(logros.desbloqueado(logro))


func test_un_logro_desconocido_se_ignora_y_los_demas_se_conservan() -> void:  # AC-ACH-010
	var datos := Logros.new().datos()
	datos[Logros.CLAVE_DE_LOGROS] = ["NO_EXISTE", L.keys()[L.REBELDE], 7, null]
	var leidos := Logros.desde(datos)
	assert_bool(leidos.desbloqueado(L.REBELDE)).is_true()
	assert_bool(leidos.desbloqueado(L.A_LA_BASURA)).is_false()


func test_lo_ilegible_da_todo_bloqueado() -> void:  # AC-ACH-010
	for ilegible: Dictionary in [
		{},
		{Logros.CLAVE_DE_LOGROS: "REBELDE"},
		{Logros.CLAVE_DE_LOGROS: 3, Logros.CLAVE_DE_FINALES: {}, Logros.CLAVE_DE_PISTAS: 1},
	]:
		var leidos := Logros.desde(ilegible)
		for logro: L in L.values():
			assert_bool(leidos.desbloqueado(logro)).is_false()
		assert_bool(leidos.final_alcanzado(F.DESPEDIDO)).is_false()


func test_un_final_se_anota_una_vez_y_el_despedido_no_es_el_cumplido() -> void:  # AC-ACH-011
	var logros := Logros.new()
	assert_bool(logros.alcanzar_final(F.DESPEDIDO)).is_true()
	assert_bool(logros.alcanzar_final(F.DESPEDIDO)).is_false()
	assert_bool(logros.final_alcanzado(F.DESPEDIDO)).is_true()
	assert_bool(logros.final_alcanzado(F.CONTRATO_CUMPLIDO)).is_false()


func test_todo_final_de_la_partida_se_anota_y_cruza_el_archivo() -> void:  # AC-ACH-011
	for final: F in F.values():
		if final == F.EN_CURSO:
			continue
		var logros := Logros.new()
		assert_bool(Logros.finales().has(final)).is_true()
		assert_bool(logros.alcanzar_final(final)).is_true()
		assert_bool(Logros.desde(logros.datos()).final_alcanzado(final)).is_true()
		assert_str(Logros.nombre_del_final(final)).is_not_empty()


func test_una_partida_en_curso_no_es_un_final() -> void:  # AC-ACH-011
	var logros := Logros.new()
	assert_bool(logros.alcanzar_final(F.EN_CURSO)).is_false()
	assert_bool(logros.final_alcanzado(F.EN_CURSO)).is_false()


func test_una_pista_se_descubre_una_vez_y_los_finales_y_pistas_vuelven() -> void:  # AC-ACH-011
	var logros := Logros.new()
	logros.alcanzar_final(F.CONTRATO_CUMPLIDO)
	assert_bool(logros.descubrir_pista("PISTA_A")).is_true()
	assert_bool(logros.descubrir_pista("PISTA_A")).is_false()
	var leidos := Logros.desde(logros.datos())
	assert_bool(leidos.final_alcanzado(F.CONTRATO_CUMPLIDO)).is_true()
	assert_bool(leidos.final_alcanzado(F.DESPEDIDO)).is_false()
	assert_bool(leidos.pista_descubierta("PISTA_A")).is_true()
	assert_bool(leidos.pista_descubierta("PISTA_B")).is_false()


func test_un_final_desconocido_en_el_archivo_se_ignora() -> void:  # AC-ACH-011
	var datos := {Logros.CLAVE_DE_FINALES: ["NO_EXISTE", "EN_CURSO", F.keys()[F.DESPEDIDO]]}
	var leidos := Logros.desde(datos)
	assert_bool(leidos.final_alcanzado(F.DESPEDIDO)).is_true()
	assert_bool(leidos.final_alcanzado(F.EN_CURSO)).is_false()
