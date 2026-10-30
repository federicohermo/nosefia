## El padrón de compradores: quiénes vienen esta noche, y que no los elija el azar.
##
## **Lo que este archivo afirma es que la lista es fija.** Un sorteo acá haría que el mismo
## balance diera noches distintas y que ningún test de la ventanilla se pudiera escribir sin
## sembrar una semilla — o sea, que la tarea de atender dejara de ser medible.
extends GdUnitTestSuite

# Ninguna noche de la partida usa el padrón: la primera pasada la última lo ejerce.
const POSTERIOR := ReglasDeLaPartida.PRIMERA_JORNADA + ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA


func test_la_jornada_trae_los_compradores_que_pide_el_balance() -> void:  # AC-CTR-001
	assert_int(Compradores.de_la_jornada(POSTERIOR).size()).is_equal(
		ReglasDeLaVentanilla.COMPRADORES_POR_JORNADA
	)


func test_el_padron_no_se_sortea() -> void:  # AC-CTR-001
	# Dos llamadas seguidas dan los mismos nombres en el mismo orden. Con un sorteo adentro esto
	# pasaría de casualidad una de cada tantas corridas, que es peor que fallar siempre.
	var una := Compradores.de_la_jornada(POSTERIOR)
	var otra := Compradores.de_la_jornada(POSTERIOR)
	var nombres_de_una: Array[String] = []
	var nombres_de_otra: Array[String] = []
	for comprador in una:
		nombres_de_una.append(comprador.nombre())
	for comprador in otra:
		nombres_de_otra.append(comprador.nombre())
	assert_array(nombres_de_una).is_equal(nombres_de_otra)


func test_cada_jornada_recibe_compradores_propios() -> void:  # AC-CTR-001
	# Instancias nuevas y no las mismas: con un padrón compartido, la atención de anoche llegaría
	# despachada y la tarea se cumpliría sola a partir de la segunda jornada.
	var una := Compradores.de_la_jornada(POSTERIOR)
	var otra := Compradores.de_la_jornada(POSTERIOR)
	assert_object(una[0]).is_not_same(otra[0])
	assert_object(una[0].pedido()).is_not_same(otra[0].pedido())


func test_alguien_paga_distinto_de_lo_que_marca_la_caja() -> void:
	# Es la única forma que tiene el juego de mentir en vivo, y por eso está en el padrón y no
	# librada al azar: un padrón donde todos pagan justo deja la ventanilla sin nada que mirar.
	var inventario := Inventario.new(Catalogo.todos())
	var diferentes := 0
	for comprador in Compradores.de_la_jornada(POSTERIOR):
		if Atencion.new(comprador, inventario).diferencia() != 0:
			diferentes += 1
	assert_int(diferentes).is_greater(0)


func test_el_padron_miente_de_los_dos_lados() -> void:  # AC-CTR-004
	# Uno que paga de más y otro de menos: con un solo signo, la diferencia se leería sin mirar.
	var inventario := Inventario.new(Catalogo.todos())
	var de_mas := 0
	var de_menos := 0
	for comprador: Comprador in Compradores.padron():
		var diferencia := Atencion.new(comprador, inventario).diferencia()
		if diferencia > 0:
			de_mas += 1
		elif diferencia < 0:
			de_menos += 1
	assert_int(de_mas).is_greater(0)
	assert_int(de_menos).is_greater(0)


func test_todo_lo_que_se_pide_existe_en_el_catalogo() -> void:
	# Un pedido con un producto que el inventario no conoce responde 0 unidades y cae por el
	# camino de «no alcanza el stock»: el comprador quedaría imposible de cobrar toda la noche.
	for comprador in Compradores.de_la_jornada(POSTERIOR):
		var pedido := comprador.pedido()
		(
			assert_array(pedido.productos())
			. override_failure_message("`%s` no pide nada" % comprador.nombre())
			. is_not_empty()
		)
		for producto in pedido.productos():
			assert_object(Catalogo.de(producto.id)).is_not_null()


func test_las_jornadas_sin_agenda_propia_usan_el_padron() -> void:  # AC-CTR-001
	for jornada: int in [POSTERIOR]:
		var compradores := Compradores.de_la_jornada(jornada)
		assert_str(compradores[0].nombre()).is_equal("Marta")
		for comprador in compradores:
			assert_bool(comprador.tiene_horario()).is_false()


func test_el_padron_y_las_jornadas_sin_agenda_conservan_el_pedido_de_ruben() -> void:  # AC-CTR-041
	var listas: Array[Array] = [Compradores.padron()]
	for jornada: int in [POSTERIOR]:
		listas.append(Compradores.de_la_jornada(jornada))
	for lista in listas:
		var ruben: Comprador = lista[1]
		assert_str(ruben.nombre()).is_equal("Rubén")
		assert_int(ruben.pedido().productos().size()).is_equal(2)
		assert_int(ruben.pedido().unidades_de(Catalogo.de(Producto.Id.BURBALOO))).is_equal(1)
		assert_int(ruben.pedido().unidades_de(Catalogo.de(Producto.Id.DUREXTRA))).is_equal(2)
		assert_int(ruben.paga() - ruben.pedido().total()).is_equal(-500)
