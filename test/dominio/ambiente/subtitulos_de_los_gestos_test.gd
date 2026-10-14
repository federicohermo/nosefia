## Lo que piensa el protagonista cuando un gesto le sale mal, y la mopa berreta una sola vez.
extends GdUnitTestSuite

const R := ReglasDeLaLimpieza.Resultado
const T := ReglasDeLaBasura.Tiro
const MALA_IDEA := "Me parece que eso fue una mala idea…"
const CAJA := (
	"La caja es bastante grande para el contenedor. Rebalsaría. Además, Enrique me pidió que no"
	+ " tire las cajas de productos, ni siquiera las vacías."
)
const VENTANA := "Si Enrique se entera de que estoy tirando cosas por la ventana, me mata."
const JABON := "Esto no está funcionando… Creo que no estoy usando el jabón correcto."
const SIN_MOJAR := "Necesitaría mojar la mopa en agua con jabón."
const YA_SECA := "Ya se secó la mopa…"
const BERRETA := "Dios mío, qué mopa berreta. Se seca a los tres segundos. Literal."
const PARED := "Se ve que alguien no tuvo tiempo de apuntar bien…"
const BOLSA := preload("res://src/dominio/almacen/bolsa_de_basura_1.tres")


func _unidad() -> UnidadDeProducto:
	return UnidadDeProducto.new(Catalogo.de(Producto.Id.ACTRONCITO))


func test_lo_que_se_tira_piensa_salvo_la_bolsa_y_el_ticket() -> void:  # AC-SUB-016
	var mopa := load("res://src/dominio/almacen/mopa.tres") as ObjetoDelAlmacen
	var jabon := load("res://src/dominio/almacen/jabon_azul.tres") as ObjetoDelAlmacen
	for tirado: ObjetoDelAlmacen in [_unidad(), jabon, mopa]:
		assert_str(SubtitulosDeLosGestos.al_tirar(tirado, T.TIRADO)).is_equal(MALA_IDEA)
	assert_str(SubtitulosDeLosGestos.al_tirar(BOLSA, T.TIRADO)).is_empty()
	assert_str(SubtitulosDeLosGestos.al_tirar(Ticket.new(), T.TIRADO)).is_empty()
	var caja := load("res://src/dominio/almacen/caja_de_reposicion.tres") as ObjetoDelAlmacen
	assert_str(SubtitulosDeLosGestos.al_tirar(caja, T.NO_ENTRA)).is_equal(CAJA)
	assert_str(SubtitulosDeLosGestos.al_tirar(null, T.MANO_VACIA)).is_empty()
	assert_str(SubtitulosDeLosGestos.al_tirar(_unidad(), T.TAPA_NO_ABIERTA)).is_empty()


func test_lo_que_queda_afuera_piensa_salvo_el_ticket() -> void:  # AC-SUB-017
	for afuera: ObjetoDelAlmacen in [_unidad(), BOLSA]:
		assert_str(SubtitulosDeLosGestos.al_quedar_afuera(afuera)).is_equal(VENTANA)
	assert_str(SubtitulosDeLosGestos.al_quedar_afuera(Ticket.new())).is_empty()
	assert_str(SubtitulosDeLosGestos.al_quedar_afuera(null)).is_empty()


func test_la_mopa_sobre_una_mancha() -> void:  # AC-SUB-018
	for resultado: R in [R.JABON_EQUIVOCADO, R.SIN_JABON]:
		assert_str(SubtitulosDeLosGestos.al_pasar_la_mopa(resultado, true)).is_equal(JABON)
	assert_str(SubtitulosDeLosGestos.al_pasar_la_mopa(R.MOPA_SECA, false)).is_equal(SIN_MOJAR)
	assert_str(SubtitulosDeLosGestos.al_pasar_la_mopa(R.MOPA_SECA, true)).is_equal(YA_SECA)
	for callado: R in [R.YA_ESTABA_LIMPIA, R.MANCHA_BORRADA, R.SIN_EFECTO]:
		assert_str(SubtitulosDeLosGestos.al_pasar_la_mopa(callado, true)).is_empty()
	var pared := PisoDelLocal.Lugar.PARED_DEL_OTRO_INODORO
	assert_str(SubtitulosDeLosGestos.al_borrar(pared)).is_equal(PARED)
	for lugar: PisoDelLocal.Lugar in PisoDelLocal.Lugar.values():
		if lugar != pared:
			assert_str(SubtitulosDeLosGestos.al_borrar(lugar)).is_empty()


func test_la_mopa_berreta_sale_una_vez_por_partida() -> void:  # AC-SUB-019
	var gestos := SubtitulosDeLosGestos.new()
	var partida := Partida.nueva()
	assert_str(gestos.al_secarse_la_mopa(partida, false)).is_equal(BERRETA)
	assert_bool(partida.mopa_secada()).is_true()
	assert_str(gestos.al_secarse_la_mopa(partida, false)).is_empty()
	assert_str(SubtitulosDeLosGestos.new().al_secarse_la_mopa(Partida.nueva(), false)).is_equal(
		BERRETA
	)


func test_durante_un_examen_la_mopa_berreta_espera_y_no_se_duplica() -> void:  # AC-SUB-019
	var gestos := SubtitulosDeLosGestos.new()
	var partida := Partida.nueva()
	assert_str(gestos.al_terminar_el_examen(partida)).is_empty()
	assert_str(gestos.al_secarse_la_mopa(partida, true)).is_empty()
	assert_str(gestos.al_secarse_la_mopa(partida, true)).is_empty()
	assert_bool(partida.mopa_secada()).is_false()
	assert_str(gestos.al_terminar_el_examen(partida)).is_equal(BERRETA)
	assert_bool(partida.mopa_secada()).is_true()
	assert_str(gestos.al_terminar_el_examen(partida)).is_empty()


func test_el_cierre_descarta_la_mopa_berreta_pendiente() -> void:  # AC-SUB-019
	var gestos := SubtitulosDeLosGestos.new()
	var partida := Partida.nueva()
	assert_str(gestos.al_secarse_la_mopa(partida, true)).is_empty()
	gestos.descartar()
	assert_str(gestos.al_terminar_el_examen(partida)).is_empty()
	assert_bool(partida.mopa_secada()).is_false()
	assert_str(gestos.al_secarse_la_mopa(partida, false)).is_equal(BERRETA)
