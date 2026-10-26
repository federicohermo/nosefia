## El Reto 5 dice que las heladeras quedaron abiertas: su texto por n y puntos, su lugar en la
## devolución y su cuenta entre noches.
extends GdUnitTestSuite

const ReglasDelCierre := preload("res://src/dominio/almacen/reglas_del_cierre.gd")
const L := Partida.Llamado
const COMPLETA := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA
const SIN_DESPIDO := DevolucionDelJefe.MEDIOS_DEL_DESPIDO - 1


func _antecedentes(cuentas: Dictionary) -> Antecedentes:
	var llamados := {}
	for motivo: L in cuentas:
		llamados[L.keys()[motivo]] = cuentas[motivo]
	return (
		Antecedentes
		. desde(
			{
				Antecedentes.CLAVE_DE_FALLAS: {},
				Antecedentes.CLAVE_DE_LLAMADOS: llamados,
				Antecedentes.CLAVE_DE_NOCHES_SIN_SUMAR: 0,
			}
		)
	)


func _reto_5(n: int, medios: int) -> String:
	var llamados: Array[L] = [L.HELADERAS_ABIERTAS]
	var mensajes := DevolucionDelJefe.armar(
		COMPLETA, medios, _antecedentes({L.HELADERAS_ABIERTAS: n}), [], llamados
	)
	assert_int(mensajes.size()).is_equal(3)
	return mensajes[1]


func _noche(partida: Partida, con_heladeras: bool) -> void:
	partida.abrir_la_jornada()
	for tarea: Tarea in partida.obligatorias():
		tarea.completar()
	if con_heladeras:
		partida.anotar_llamado(L.HELADERAS_ABIERTAS)
	partida.cerrar_la_jornada(partida.obligatorias().size())


func _por_el_archivo(partida: Partida) -> Partida:
	return Partida.desde(str_to_var(var_to_str(PoliticaDeGuardado.datos(partida))))


func test_con_menos_de_cuatro_puntos_el_texto_sale_de_n() -> void:  # AC-EMP-098
	assert_str(_reto_5(1, SIN_DESPIDO)).is_equal(DevolucionDelJefe.HELADERAS[0])
	assert_str(_reto_5(2, SIN_DESPIDO)).is_equal(DevolucionDelJefe.HELADERAS[1])
	for n: int in [3, 4, 5, 8]:
		assert_str(_reto_5(n, SIN_DESPIDO)).is_equal(DevolucionDelJefe.HELADERAS[2])


func test_con_cuatro_puntos_dice_y_para_colmo_con_cualquier_n() -> void:  # AC-EMP-098
	for n: int in [1, 2, 3, 8]:
		assert_str(_reto_5(n, DevolucionDelJefe.MEDIOS_DEL_DESPIDO)).is_equal(
			DevolucionDelJefe.HELADERAS_Y_PARA_COLMO
		)


func test_sin_el_llamado_de_esa_noche_no_hay_reto_5() -> void:  # AC-EMP-098
	var ninguno: Array[L] = []
	var mensajes := DevolucionDelJefe.armar(
		COMPLETA, SIN_DESPIDO, _antecedentes({L.HELADERAS_ABIERTAS: 2}), [], ninguno
	)
	assert_int(mensajes.size()).is_equal(2)
	for texto: String in DevolucionDelJefe.HELADERAS:
		assert_bool(mensajes.has(texto)).is_false()


func test_los_cinco_llamados_traen_cinco_retos_en_orden() -> void:  # AC-EMP-098
	var llamados: Array[L] = [
		L.HELADERAS_ABIERTAS,
		L.LOCAL_DESORDENADO,
		L.OBJETO_AFUERA,
		L.OBJETO_TIRADO,
		L.PAPEL_EN_EL_INODORO
	]
	var antecedentes := _antecedentes(
		{
			L.PAPEL_EN_EL_INODORO: 1,
			L.OBJETO_TIRADO: 1,
			L.OBJETO_AFUERA: 2,
			L.LOCAL_DESORDENADO: 1,
			L.HELADERAS_ABIERTAS: 3,
		}
	)
	var mensajes := DevolucionDelJefe.armar(COMPLETA, 0, antecedentes, [], llamados)
	assert_int(mensajes.size()).is_equal(7)
	assert_str(mensajes[1]).is_equal(DevolucionDelJefe.PAPEL_1)
	assert_str(mensajes[2]).is_equal(DevolucionDelJefe.BASURA[0])
	assert_str(mensajes[3]).is_equal(DevolucionDelJefe.AFUERA[1])
	assert_str(mensajes[4]).is_equal(DevolucionDelJefe.DESORDEN[0])
	assert_str(mensajes[5]).is_equal(DevolucionDelJefe.HELADERAS[2])


func test_dos_noches_con_heladeras_se_guardan_y_la_siguiente_dice_n_3() -> void:  # AC-EMP-099
	var partida := Partida.desde({"jornada": COMPLETA})
	_noche(partida, true)
	_noche(partida, false)
	_noche(partida, true)
	var retomada := _por_el_archivo(partida)
	assert_int(retomada.antecedentes().llamados(L.HELADERAS_ABIERTAS)).is_equal(2)
	assert_bool(retomada.antecedentes().hubo_llamados()).is_true()
	_noche(retomada, true)
	assert_int(retomada.antecedentes().llamados(L.HELADERAS_ABIERTAS)).is_equal(3)
	assert_bool(retomada.mensajes_del_jefe().has(DevolucionDelJefe.HELADERAS[2])).is_true()


func test_un_guardado_sin_el_motivo_lo_lleva_en_cero_y_conserva_los_otros() -> void:  # AC-EMP-099
	var llamados := {L.keys()[L.PAPEL_EN_EL_INODORO]: 2}
	var partida := Partida.desde({"jornada": COMPLETA, "llamados": llamados})
	assert_int(partida.antecedentes().llamados(L.HELADERAS_ABIERTAS)).is_zero()
	assert_int(partida.antecedentes().llamados(L.PAPEL_EN_EL_INODORO)).is_equal(2)
	_noche(partida, true)
	assert_bool(partida.mensajes_del_jefe().has(DevolucionDelJefe.HELADERAS[0])).is_true()


func test_un_valor_de_otro_tipo_se_ignora_sin_descartar_los_demas() -> void:  # AC-EMP-099
	var llamados := {
		L.keys()[L.HELADERAS_ABIERTAS]: "dos",
		L.keys()[L.PAPEL_EN_EL_INODORO]: 2,
	}
	var partida := Partida.desde({"jornada": COMPLETA, "llamados": llamados})
	assert_int(partida.antecedentes().llamados(L.HELADERAS_ABIERTAS)).is_zero()
	assert_int(partida.antecedentes().llamados(L.PAPEL_EN_EL_INODORO)).is_equal(2)


func test_una_heladera_abierta_pesa_medio_y_trae_el_reto_5() -> void:  # AC-CLN-075
	var abierta := Partida.desde({"jornada": COMPLETA})
	_noche(abierta, true)
	assert_int(abierta.medios()).is_equal(Reglas.MEDIOS_POR_LLAMADO)
	assert_bool(abierta.mensajes_del_jefe().has(DevolucionDelJefe.HELADERAS[0])).is_true()
	var cerrada := Partida.desde({"jornada": COMPLETA})
	_noche(cerrada, false)
	assert_int(cerrada.medios()).is_zero()
	assert_bool(cerrada.mensajes_del_jefe().has(DevolucionDelJefe.HELADERAS[0])).is_false()


func test_en_la_prueba_una_heladera_abierta_no_suma_medios() -> void:  # AC-CLN-075
	var partida := Partida.nueva()
	_noche(partida, true)
	assert_int(partida.medios()).is_zero()
	assert_bool(partida.antecedentes().hubo_llamados()).is_false()


func test_heladera_desorden_y_objeto_afuera_son_tres_motivos_de_una_vez() -> void:  # AC-CLN-074
	var partida := Partida.desde({"jornada": COMPLETA})
	partida.abrir_la_jornada()
	for tarea: Tarea in partida.obligatorias():
		tarea.completar()
	var cajas: Array[ReglasDelCierre.Clase] = [ReglasDelCierre.Clase.CAJA]
	partida.clases_de_desorden = cajas
	for _vez in 2:
		partida.anotar_llamado(L.OBJETO_AFUERA)
		partida.anotar_llamado(L.HELADERAS_ABIERTAS)
	assert_int(partida.llamados().size()).is_equal(3)
	partida.cerrar_la_jornada(partida.obligatorias().size())
	assert_int(partida.medios()).is_equal(3 * Reglas.MEDIOS_POR_LLAMADO)
