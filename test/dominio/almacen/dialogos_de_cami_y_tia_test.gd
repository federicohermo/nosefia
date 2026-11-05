extends GdUnitTestSuite

const TERCERA := ReglasDeLaPartida.PRIMERA_JORNADA + 2
const CUARTA := ReglasDeLaPartida.PRIMERA_JORNADA + 3
const QUINTA := ReglasDeLaPartida.PRIMERA_JORNADA + 4
const SEXTA := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 3
const SEPTIMA := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 4
const PERSONAJE := DialogosDeCompradores.Personaje
const AMARILLO := "[color=#e4f850]"
const SEMILLAS := 40
## La marca del fragmento que el jugador pulsa en el mensaje de Cami.
const MARCA_DE_LA_PISTA := "[url=5A]"
## Lo que distingue a cada versión del mensaje 3 de Cami en la quinta.
const DEL_CAMINO_4A := "amor de persona"
const DEL_CAMINO_4B := "muy capa"
## La posición del mensaje 3 en la apertura de Cami de la quinta.
const MENSAJE_3_DE_CAMI := 2

## Cuántas entradas de apertura y de despedida trae cada guion propio.
const ENTRADAS := {
	"cami_tercera": [14, 3],
	"tin_tercera": [4, 1],
	"tia_cuarta": [2, 1],
	"cami_quinta": [9, 3],
	"tia_sexta": [3, 2],
}
## Dónde nombran el pedido las entradas de apertura de cada guion.
const PRIMER_PRODUCTO_DE_CAMI := 8
const SEGUNDO_PRODUCTO_DE_CAMI := 10
const OAAAA_DE_CAMI := 12


func _comprador(jornada: int, personaje: int, semilla: int = 5) -> Comprador:
	for comprador in Compradores.de_la_jornada(jornada, semilla):
		if comprador.personaje == personaje:
			return comprador
	return null


## Cami de la quinta con las pistas activas que se le dan: con 5A activa dice el mensaje de
## «actitudes extrañas de Peldaño», y sin ella no.
func _cami_de_la_quinta(semilla: int = 5, activas := PackedStringArray(["5A"])) -> Comprador:
	var cami := _comprador(QUINTA, PERSONAJE.CAMI, semilla)
	cami.pistas_activas = activas
	return cami


## Las pistas de la quinta que deja el camino de la cuarta: la hipótesis elegida o ninguna.
func _activas_por_el_camino(elegida: String) -> PackedStringArray:
	var expediente := Expediente.new(CasoDeInvestigacion.de_la_partida())
	if not elegida.is_empty():
		expediente.registrar(elegida)
		expediente.elegir(CUARTA, elegida)
	return expediente.pistas_activas(QUINTA)


func _cuantas_dicen(apertura: PackedStringArray, fragmento: String) -> int:
	var dicen := 0
	for entrada: String in apertura:
		if entrada.contains(fragmento):
			dicen += 1
	return dicen


func _entradas(dialogo: Dialogo) -> PackedStringArray:
	var entradas := PackedStringArray()
	while not dialogo.terminado():
		entradas.append(dialogo.entrada_actual())
		dialogo.avanzar()
	return entradas


func _apertura(comprador: Comprador) -> PackedStringArray:
	return _entradas(
		comprador.dialogos.inicial(
			comprador.personaje, comprador.pedido(), comprador.pistas_activas
		)
	)


func _despedida(comprador: Comprador) -> PackedStringArray:
	return _entradas(comprador.dialogos.despedida(comprador.personaje, comprador.pedido()))


## El producto presentado como en el pedido, sin la frase que lo rodea.
func _presentado(lista: Array[Producto]) -> String:
	var venta := Venta.new()
	for producto in lista:
		venta.agregar(producto, 1)
	return (
		DialogosDeCompradores
		. apertura_predeterminada(venta)
		. entrada_actual()
		. trim_prefix(DialogosDeCompradores.SALUDO + "Quiero ")
		. trim_suffix(".")
	)


func _sin_marcadores(entradas: PackedStringArray) -> void:
	for entrada: String in entradas:
		assert_str(entrada).not_contains("{").not_contains("}")
		assert_str(entrada).not_contains("[producto").not_contains("[pedido")


func _entradas_de(comprador: Comprador, clave: String) -> Array:
	var cantidades: Array = ENTRADAS[clave]
	return [_apertura(comprador), cantidades[0], _despedida(comprador), cantidades[1]]


func _atencion(comprador: Comprador) -> Atencion:
	comprador.horario = Vector2(0.0, 1000.0)
	return Atencion.new(comprador, Apertura.inventario_con_faltantes({}, {}, Catalogo.todos()))


func test_cami_de_la_tercera_dice_sus_entradas_y_nombra_su_pedido() -> void:  # AC-CTR-154
	var cami := _comprador(TERCERA, PERSONAJE.CAMI)
	var entradas := _entradas_de(cami, "cami_tercera")
	assert_int(entradas[0].size()).is_equal(entradas[1])
	assert_int(entradas[2].size()).is_equal(entradas[3])
	_sin_marcadores(entradas[0])
	_sin_marcadores(entradas[2])
	var productos := cami.pedido().productos()
	var apertura: PackedStringArray = entradas[0]
	assert_str(apertura[PRIMER_PRODUCTO_DE_CAMI]).contains(_presentado([productos[0]]))
	assert_str(apertura[SEGUNDO_PRODUCTO_DE_CAMI]).contains(_presentado([productos[1]]))
	assert_str(apertura[OAAAA_DE_CAMI]).contains(AMARILLO + "Oaaaa[/color]")
	assert_int(productos[2].id).is_equal(Producto.Id.OAAAA)


func test_en_la_apertura_de_cami_solo_los_nombres_van_en_amarillo() -> void:  # AC-CTR-154
	var cami := _comprador(TERCERA, PERSONAJE.CAMI)
	var apertura := _apertura(cami)
	for indice in apertura.size():
		var esperado := 0
		if indice in [PRIMER_PRODUCTO_DE_CAMI, SEGUNDO_PRODUCTO_DE_CAMI, OAAAA_DE_CAMI]:
			esperado = 1
		assert_int(apertura[indice].count(AMARILLO)).is_equal(esperado)
		assert_int(apertura[indice].count("[/color]")).is_equal(esperado)


func test_cami_de_la_tercera_vende_una_vez_y_se_retira_tras_despedirse() -> void:  # AC-CTR-154
	var cami := _comprador(TERCERA, PERSONAJE.CAMI)
	var inventario := Apertura.inventario_con_faltantes({}, {}, Catalogo.todos())
	var estante := Estante.new(inventario, Catalogo.todos())
	cami.horario = Vector2(0.0, 1000.0)
	var atencion := Atencion.new(cami, inventario)
	atencion.interactuar(null)
	while not atencion.puede_abandonar():
		atencion.interactuar(null)
	for producto in cami.pedido().productos():
		atencion.interactuar(estante.retirar(producto))
	assert_int(atencion.interactuar(Ticket.new(cami.pedido().productos()))).is_equal(
		RecepcionDeCompra.Resultado.COMPLETA
	)
	assert_bool(atencion.vendida()).is_true()
	var entradas := 0
	while not atencion.despachada() and entradas <= ENTRADAS["cami_tercera"][1]:
		entradas += 1
		atencion.interactuar(null)
	assert_int(entradas).is_equal(ENTRADAS["cami_tercera"][1])
	assert_bool(atencion.despachada()).is_true()


func test_tin_de_la_tercera_dice_sus_entradas_y_nombra_sus_tres_productos() -> void:  # AC-CTR-155
	var tin := _comprador(TERCERA, PERSONAJE.TIN)
	var entradas := _entradas_de(tin, "tin_tercera")
	assert_int(entradas[0].size()).is_equal(entradas[1])
	assert_int(entradas[2].size()).is_equal(entradas[3])
	_sin_marcadores(entradas[0])
	_sin_marcadores(entradas[2])
	var productos := tin.pedido().productos()
	var apertura: PackedStringArray = entradas[0]
	assert_str(apertura[2]).contains(_presentado([productos[0]]))
	assert_str(apertura[3]).contains(_presentado([productos[0]]))
	assert_str(apertura[3]).contains(_presentado([productos[1]]))
	assert_str(apertura[3]).contains(_presentado([productos[2]]))
	assert_int(apertura[2].count(AMARILLO)).is_equal(1)
	assert_int(apertura[3].count(AMARILLO)).is_equal(3)


func test_tia_de_la_cuarta_y_la_sexta_nombran_el_pedido_entero() -> void:  # AC-CTR-156
	for caso: Array in [[CUARTA, "tia_cuarta"], [SEXTA, "tia_sexta"]]:
		for semilla in range(1, SEMILLAS + 1):
			var tia := _comprador(caso[0], PERSONAJE.TIA, semilla)
			var entradas := _entradas_de(tia, caso[1])
			assert_int(entradas[0].size()).is_equal(entradas[1])
			assert_int(entradas[2].size()).is_equal(entradas[3])
			_sin_marcadores(entradas[0])
			var apertura: PackedStringArray = entradas[0]
			var pedido := _presentado(tia.pedido().productos())
			assert_str(apertura[-1]).contains(pedido)
			assert_int(apertura[-1].count(AMARILLO)).is_equal(tia.pedido().productos().size())
			assert_int(apertura[0].count(AMARILLO)).is_zero()


func test_cami_de_la_quinta_dice_sus_entradas_y_nombra_el_pedido_entero() -> void:  # AC-CTR-157
	for semilla in range(1, SEMILLAS + 1):
		var cami := _cami_de_la_quinta(semilla)
		var entradas := _entradas_de(cami, "cami_quinta")
		assert_int(entradas[0].size()).is_equal(entradas[1])
		assert_int(entradas[2].size()).is_equal(entradas[3])
		_sin_marcadores(entradas[0])
		var apertura: PackedStringArray = entradas[0]
		assert_str(apertura[-2]).contains(_presentado(cami.pedido().productos()))
		assert_int(apertura[-2].count(AMARILLO)).is_equal(cami.pedido().productos().size())


func test_cami_de_la_quinta_dice_un_solo_mensaje_3_segun_el_camino() -> void:  # AC-CTR-170
	for semilla in range(1, SEMILLAS + 1):
		var por_4a := _apertura(_cami_de_la_quinta(semilla, _activas_por_el_camino("2A")))
		var por_4b := _apertura(_cami_de_la_quinta(semilla, _activas_por_el_camino("2B")))
		var sin_camino := _apertura(_cami_de_la_quinta(semilla, _activas_por_el_camino("")))
		assert_str(por_4a[MENSAJE_3_DE_CAMI]).contains(DEL_CAMINO_4A)
		assert_int(_cuantas_dicen(por_4a, DEL_CAMINO_4A)).is_equal(1)
		assert_int(_cuantas_dicen(por_4a, DEL_CAMINO_4B)).is_zero()
		assert_str(por_4b[MENSAJE_3_DE_CAMI]).contains(DEL_CAMINO_4B)
		assert_int(_cuantas_dicen(por_4b, DEL_CAMINO_4B)).is_equal(1)
		assert_int(_cuantas_dicen(por_4b, DEL_CAMINO_4A)).is_zero()
		assert_array(Array(sin_camino)).is_equal(Array(por_4b))


func test_solo_ellos_tienen_guion_propio_y_los_demas_usan_el_predeterminado() -> void:  # AC-CTR-158
	var con_guion := {
		TERCERA: [PERSONAJE.CAMI, PERSONAJE.TIN],
		CUARTA: [PERSONAJE.TIA],
		QUINTA: [PERSONAJE.CAMI],
		SEXTA: [PERSONAJE.TIA],
		SEPTIMA: [],
	}
	for jornada: int in con_guion:
		for comprador in Compradores.de_la_jornada(jornada, 3):
			var propio: bool = comprador.personaje in con_guion[jornada]
			assert_bool(comprador.dialogos != null).is_equal(propio)
			if propio:
				continue
			var atencion := _atencion(comprador)
			atencion.interactuar(null)
			assert_str(atencion.dialogo().entrada_actual()).starts_with(
				DialogosDeCompradores.SALUDO + "Quiero "
			)


func test_las_jornadas_1_y_2_conservan_sus_guiones() -> void:  # AC-CTR-158
	for comprador in Compradores.de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA + 1):
		assert_object(comprador.dialogos).is_not_null()
	for comprador in Compradores.de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA):
		assert_object(comprador.dialogos).is_not_null()


func test_con_guion_propio_hablar_de_nuevo_recuerda_sin_repetir_la_apertura() -> void:  # AC-CTR-159
	var tia := _comprador(CUARTA, PERSONAJE.TIA)
	var atencion := _atencion(tia)
	atencion.interactuar(null)
	while not atencion.puede_abandonar():
		atencion.interactuar(null)
	atencion.interactuar(null)
	var recordatorio := DialogosDeCompradores.recordatorio(
		tia.pedido(), RecepcionDeCompra.new(tia.pedido())
	)
	assert_str(atencion.dialogo().entrada_actual()).is_equal(recordatorio.entrada_actual())


func test_la_misma_partida_repite_pedido_y_textos() -> void:  # AC-CTR-159
	for caso: Array in [
		[TERCERA, PERSONAJE.CAMI],
		[TERCERA, PERSONAJE.TIN],
		[CUARTA, PERSONAJE.TIA],
		[QUINTA, PERSONAJE.CAMI],
		[SEXTA, PERSONAJE.TIA],
	]:
		var una := _comprador(caso[0], caso[1], 11)
		var otra := _comprador(caso[0], caso[1], 11)
		assert_array(Array(_apertura(una))).is_equal(Array(_apertura(otra)))
		assert_array(Array(_despedida(una))).is_equal(Array(_despedida(otra)))


func test_cami_de_la_quinta_dice_el_mensaje_de_5a_solo_con_la_5a_activa() -> void:  # AC-CTR-157
	for semilla in range(1, SEMILLAS + 1):
		var con := _apertura(_cami_de_la_quinta(semilla))
		var sin := _apertura(_cami_de_la_quinta(semilla, PackedStringArray()))
		assert_int(con.size()).is_equal(ENTRADAS["cami_quinta"][0])
		assert_int(sin.size()).is_equal(ENTRADAS["cami_quinta"][0] - 1)
		var del_mensaje := -1
		for indice in con.size():
			if con[indice].contains(MARCA_DE_LA_PISTA):
				assert_int(del_mensaje).is_equal(-1)
				del_mensaje = indice
		assert_int(del_mensaje).is_greater_equal(0)
		var resto_con := Array(con)
		resto_con.remove_at(del_mensaje)
		resto_con.remove_at(MENSAJE_3_DE_CAMI)
		var resto_sin := Array(sin)
		resto_sin.remove_at(MENSAJE_3_DE_CAMI)
		assert_array(resto_sin).is_equal(resto_con)
		_sin_marcadores(sin)


func test_el_fragmento_de_la_pista_5a_va_en_lila_y_con_su_identidad() -> void:  # AC-INV-165
	var apertura := _apertura(_cami_de_la_quinta())
	var del_mensaje: Array[String] = []
	for texto: String in apertura:
		if texto.contains("[url="):
			del_mensaje.append(texto)
	assert_array(del_mensaje).has_size(1)
	if del_mensaje.is_empty():
		return
	var entrada := del_mensaje[0]
	assert_int(entrada.count(MARCA_DE_LA_PISTA)).is_equal(1)
	assert_int(entrada.count("[color=" + DialogosDeCompradores.LILA + "]")).is_equal(1)
	assert_int(entrada.count(AMARILLO)).is_zero()


func test_la_atencion_pasa_las_pistas_activas_del_comprador_a_su_apertura() -> void:  # AC-CTR-157
	for activas: PackedStringArray in [PackedStringArray(["5A"]), PackedStringArray()]:
		var cami := _cami_de_la_quinta(5, activas)
		var atencion := _atencion(cami)
		atencion.interactuar(null)
		var dicha := _entradas(atencion.dialogo())
		assert_array(Array(dicha)).is_equal(Array(_apertura(cami)))
		var con_fragmento := dicha.size() == ENTRADAS["cami_quinta"][0]
		assert_bool(con_fragmento).is_equal(not activas.is_empty())
