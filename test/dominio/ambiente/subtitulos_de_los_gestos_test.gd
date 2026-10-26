## Qué pensamiento elige cada gesto, sin fijar su redacción.
extends GdUnitTestSuite

const R := ReglasDeLaLimpieza.Resultado
const T := ReglasDeLaBasura.Tiro
const S := SubtitulosDeLosGestos.Id
const BOLSA := preload("res://src/dominio/almacen/bolsa_de_basura_1.tres")
const JORNADA := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA


func _unidad() -> UnidadDeProducto:
	return UnidadDeProducto.new(Catalogo.de(Producto.Id.ACTRONCITO))


func _pista() -> Pista:
	for pista: Pista in CasoDeInvestigacion.de_la_partida().pistas:
		if pista.canal == Pista.Canal.LEVANTAR and not pista.origen.is_empty():
			return pista
	return null


func _objeto_de_la_pista() -> ObjetoDelAlmacen:
	var objeto := ObjetoDelAlmacen.new()
	objeto.id = _pista().origen
	return objeto


func test_lo_que_se_tira_piensa_salvo_bolsa_vencido_ticket_y_pista() -> void:  # AC-SUB-016
	var mopa := load("res://src/dominio/almacen/mopa.tres") as ObjetoDelAlmacen
	var jabon := load("res://src/dominio/almacen/jabon_azul.tres") as ObjetoDelAlmacen
	for tirado: ObjetoDelAlmacen in [_unidad(), jabon, mopa]:
		assert_int(SubtitulosDeLosGestos.al_tirar(tirado, T.TIRADO, JORNADA)).is_equal(S.MALA_IDEA)
	var vencida := _unidad()
	vencida.vencido = true
	for eximido: ObjetoDelAlmacen in [BOLSA, Ticket.new(), vencida, _objeto_de_la_pista()]:
		assert_int(SubtitulosDeLosGestos.al_tirar(eximido, T.TIRADO, _pista().jornada)).is_equal(
			S.NINGUNO
		)
	var caja := load("res://src/dominio/almacen/caja_de_reposicion.tres") as ObjetoDelAlmacen
	assert_int(SubtitulosDeLosGestos.al_tirar(caja, T.NO_ENTRA, JORNADA)).is_equal(
		S.CAJA_EN_EL_CONTENEDOR
	)
	assert_int(SubtitulosDeLosGestos.al_tirar(null, T.MANO_VACIA, JORNADA)).is_equal(S.NINGUNO)
	assert_int(SubtitulosDeLosGestos.al_tirar(_unidad(), T.TAPA_NO_ABIERTA, JORNADA)).is_equal(
		S.NINGUNO
	)


func test_lo_que_queda_afuera_piensa_salvo_el_ticket() -> void:  # AC-SUB-017
	for afuera: ObjetoDelAlmacen in [_unidad(), BOLSA]:
		assert_int(SubtitulosDeLosGestos.al_quedar_afuera(afuera)).is_equal(S.POR_LA_VENTANA)
	assert_int(SubtitulosDeLosGestos.al_quedar_afuera(Ticket.new())).is_equal(S.NINGUNO)
	assert_int(SubtitulosDeLosGestos.al_quedar_afuera(null)).is_equal(S.NINGUNO)


func test_la_mopa_sobre_una_mancha() -> void:  # AC-SUB-018
	assert_int(SubtitulosDeLosGestos.al_pasar_la_mopa(R.JABON_EQUIVOCADO, true)).is_equal(
		S.JABON_EQUIVOCADO
	)
	assert_int(SubtitulosDeLosGestos.al_pasar_la_mopa(R.SIN_JABON, true)).is_equal(S.MOPA_SIN_MOJAR)
	assert_int(SubtitulosDeLosGestos.al_pasar_la_mopa(R.MOPA_SECA, false)).is_equal(
		S.MOPA_SIN_MOJAR
	)
	assert_int(SubtitulosDeLosGestos.al_pasar_la_mopa(R.MOPA_SECA, true)).is_equal(S.MOPA_YA_SECA)
	for callado: R in [R.YA_ESTABA_LIMPIA, R.MANCHA_BORRADA, R.SIN_EFECTO]:
		assert_int(SubtitulosDeLosGestos.al_pasar_la_mopa(callado, true)).is_equal(S.NINGUNO)
	var pared := PisoDelLocal.Lugar.PARED_DEL_OTRO_INODORO
	assert_int(SubtitulosDeLosGestos.al_borrar(pared)).is_equal(S.PARED_DEL_OTRO_INODORO)
	for lugar: PisoDelLocal.Lugar in PisoDelLocal.Lugar.values():
		if lugar != pared:
			assert_int(SubtitulosDeLosGestos.al_borrar(lugar)).is_equal(S.NINGUNO)


func test_el_agua_sola_pide_jabon_y_al_secarse_lo_avisa() -> void:  # AC-SUB-018
	var mopa := Mopa.new()
	mopa.enjuagar()
	var mancha := Mancha.new(ReglasDeLaLimpieza.TipoDeMancha.POLVO)
	(
		assert_int(SubtitulosDeLosGestos.al_pasar_la_mopa(mancha.borrar_con(mopa), mopa.se_mojo()))
		. is_equal(S.MOPA_SIN_MOJAR)
	)
	assert_bool(mancha.esta_limpia()).is_false()
	assert_bool(mopa.desgastar(ReglasDeLaLimpieza.DURACION_DE_LA_CARGA, 0.0)).is_true()
	(
		assert_int(SubtitulosDeLosGestos.al_pasar_la_mopa(mancha.borrar_con(mopa), mopa.se_mojo()))
		. is_equal(S.MOPA_YA_SECA)
	)
	assert_bool(mancha.esta_limpia()).is_false()


func test_la_mopa_berreta_sale_una_vez_por_partida() -> void:  # AC-SUB-019
	var gestos := SubtitulosDeLosGestos.new()
	var partida := Partida.nueva()
	assert_int(gestos.al_secarse_la_mopa(partida, false)).is_equal(S.MOPA_BERRETA)
	assert_bool(partida.mopa_secada()).is_true()
	assert_int(gestos.al_secarse_la_mopa(partida, false)).is_equal(S.NINGUNO)
	assert_int(SubtitulosDeLosGestos.new().al_secarse_la_mopa(Partida.nueva(), false)).is_equal(
		S.MOPA_BERRETA
	)


func test_durante_un_examen_la_mopa_berreta_espera_y_no_se_duplica() -> void:  # AC-SUB-019
	var gestos := SubtitulosDeLosGestos.new()
	var partida := Partida.nueva()
	assert_int(gestos.al_terminar_el_examen(partida)).is_equal(S.NINGUNO)
	assert_int(gestos.al_secarse_la_mopa(partida, true)).is_equal(S.NINGUNO)
	assert_int(gestos.al_secarse_la_mopa(partida, true)).is_equal(S.NINGUNO)
	assert_bool(partida.mopa_secada()).is_false()
	assert_int(gestos.al_terminar_el_examen(partida)).is_equal(S.MOPA_BERRETA)
	assert_bool(partida.mopa_secada()).is_true()
	assert_int(gestos.al_terminar_el_examen(partida)).is_equal(S.NINGUNO)


func test_el_cierre_descarta_la_mopa_berreta_pendiente() -> void:  # AC-SUB-019
	var gestos := SubtitulosDeLosGestos.new()
	var partida := Partida.nueva()
	assert_int(gestos.al_secarse_la_mopa(partida, true)).is_equal(S.NINGUNO)
	gestos.descartar()
	assert_int(gestos.al_terminar_el_examen(partida)).is_equal(S.NINGUNO)
	assert_bool(partida.mopa_secada()).is_false()
	assert_int(gestos.al_secarse_la_mopa(partida, false)).is_equal(S.MOPA_BERRETA)


func test_cada_id_tiene_texto_salvo_ninguno() -> void:  # AC-SUB-018
	assert_str(SubtitulosDeLosGestos.texto(S.NINGUNO)).is_empty()
	for id: S in S.values():
		if id != S.NINGUNO:
			assert_str(SubtitulosDeLosGestos.texto(id)).is_not_empty()


func _cumplidas_salvo(jornada: int, pendiente: Tarea = null) -> Array[Tarea]:
	var obligatorias := Apertura.obligatorias(jornada)
	for tarea in obligatorias:
		if pendiente == null or tarea.tipo() != pendiente.tipo():
			tarea.completar()
	return obligatorias


func test_la_entrada_con_alguna_pendiente_piensa_en_las_noches_de_prueba() -> void:  # AC-SUB-024
	for jornada: int in range(
		ReglasDeLaPartida.PRIMERA_JORNADA, ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA
	):
		(
			assert_int(
				SubtitulosDeLosGestos.al_usar_la_entrada(jornada, Apertura.obligatorias(jornada))
			)
			. is_equal(S.PUERTA_CON_TAREAS_PENDIENTES)
		)
		for pendiente in Apertura.obligatorias(jornada):
			var tareas := _cumplidas_salvo(jornada, pendiente)
			assert_int(SubtitulosDeLosGestos.al_usar_la_entrada(jornada, tareas)).is_equal(
				S.PUERTA_CON_TAREAS_PENDIENTES
			)
		var hechas := _cumplidas_salvo(jornada)
		assert_int(SubtitulosDeLosGestos.al_usar_la_entrada(jornada, hechas)).is_equal(S.NINGUNO)
		assert_bool(hechas[0].descompletar()).is_true()
		assert_int(SubtitulosDeLosGestos.al_usar_la_entrada(jornada, hechas)).is_equal(
			S.PUERTA_CON_TAREAS_PENDIENTES
		)


func test_la_entrada_no_piensa_si_solo_falta_atencion_cerrada() -> void:  # AC-SHF-048
	for jornada: int in range(
		ReglasDeLaPartida.PRIMERA_JORNADA, ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA
	):
		var compradores := Compradores.de_la_jornada(jornada)
		var atender := TareaDeAtender.new(
			compradores, Apertura.inventario_con_faltantes({}, {}, Catalogo.todos())
		)
		var registro := RegistroDeVentas.new(Catalogo.todos(), atender)
		var sin_atencion := _cumplidas_salvo(jornada, Tarea.new(Tarea.Tipo.CAJA))
		(
			assert_int(
				SubtitulosDeLosGestos.al_usar_la_entrada(jornada, sin_atencion, atender, registro)
			)
			. is_equal(S.PUERTA_CON_TAREAS_PENDIENTES)
		)
		atender.avanzar(compradores[-1].horario.y)
		(
			assert_int(
				SubtitulosDeLosGestos.al_usar_la_entrada(jornada, sin_atencion, atender, registro)
			)
			. is_equal(S.NINGUNO)
		)
		for pendiente in Apertura.obligatorias(jornada):
			if pendiente.tipo() in [Tarea.Tipo.CAJA, Tarea.Tipo.REGISTRAR]:
				continue
			var tareas := _cumplidas_salvo(jornada, pendiente)
			(
				assert_int(
					SubtitulosDeLosGestos.al_usar_la_entrada(jornada, tareas, atender, registro)
				)
				. is_equal(S.PUERTA_CON_TAREAS_PENDIENTES)
			)
		var sin_registrar := _cumplidas_salvo(jornada, Tarea.new(Tarea.Tipo.REGISTRAR))
		assert_bool(registro.sumar(Catalogo.todos()[0])).is_true()
		(
			assert_int(
				SubtitulosDeLosGestos.al_usar_la_entrada(jornada, sin_registrar, atender, registro)
			)
			. is_equal(S.PUERTA_CON_TAREAS_PENDIENTES)
		)


func test_la_entrada_no_piensa_desde_la_primera_jornada_completa() -> void:  # AC-SUB-024
	var jornada := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA
	for obligatorias: Array[Tarea] in [Apertura.obligatorias(jornada), _cumplidas_salvo(jornada)]:
		assert_int(SubtitulosDeLosGestos.al_usar_la_entrada(jornada, obligatorias)).is_equal(
			S.NINGUNO
		)
