## La tapa abierta con algo en la mano ofrece lo mismo que el cuerpo; en los demás casos alterna.
extends GdUnitTestSuite

const R := ReferenciaDeControles
const L := ReferenciaDeControles.Linea
const M := ReferenciaDeControles.Mira


func test_la_tapa_abierta_con_algo_en_la_mano_ofrece_lo_mismo_que_el_cuerpo() -> void:  # AC-CLN-036
	var cuerpo := R.contexto_del_contenedor(true)
	var tapa := R.contexto_de_la_tapa(true, true, true)
	assert_array(R.lineas(true, M.FIJO, tapa, false)).contains_exactly(
		R.lineas(true, M.FIJO, cuerpo, false)
	)
	assert_int(R.ruta(true, tapa, false)).is_equal(R.ruta(true, cuerpo, false))
	assert_int(R.ruta(false, tapa, false)).is_equal(R.Ruta.IGNORAR)


func test_la_tapa_alterna_con_la_mano_vacia_o_si_no_esta_abierta_del_todo() -> void:  # AC-CLN-034
	var casos: Array[Array] = [
		[true, false, false, L.CERRAR],
		[true, false, true, L.CERRAR],
		[false, false, false, L.ABRIR],
		[false, false, true, L.ABRIR],
		[true, true, false, L.CERRAR],
	]
	for caso in casos:
		var tapa := R.contexto_de_la_tapa(caso[0], caso[1], caso[2])
		assert_int(R.ruta(true, tapa, false)).is_equal(R.Ruta.ACCIONAR)
		assert_array(R.lineas(caso[2], M.FIJO, tapa, false)).contains([caso[3]])
