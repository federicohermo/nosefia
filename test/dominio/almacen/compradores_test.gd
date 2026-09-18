## El padrón de compradores: quiénes vienen esta noche, y que no los elija el azar.
##
## **Lo que este archivo afirma es que la lista es fija.** Un sorteo acá haría que el mismo
## balance diera noches distintas y que ningún test de la ventanilla se pudiera escribir sin
## sembrar una semilla — o sea, que la tarea de atender dejara de ser medible.
extends GdUnitTestSuite

const COMPRADORES := "res://src/dominio/almacen/compradores.gd"


func test_la_jornada_trae_los_compradores_que_pide_el_balance() -> void:  # 013-AC8
	assert_int(Compradores.de_la_jornada().size()).is_equal(
		ReglasDeLaVentanilla.COMPRADORES_POR_JORNADA
	)


func test_el_padron_no_se_sortea() -> void:  # 013-AC8
	# Dos llamadas seguidas dan los mismos nombres en el mismo orden. Con un sorteo adentro esto
	# pasaría de casualidad una de cada tantas corridas, que es peor que fallar siempre.
	var una := Compradores.de_la_jornada()
	var otra := Compradores.de_la_jornada()
	var nombres_de_una: Array[String] = []
	var nombres_de_otra: Array[String] = []
	for comprador in una:
		nombres_de_una.append(comprador.nombre())
	for comprador in otra:
		nombres_de_otra.append(comprador.nombre())
	assert_array(nombres_de_una).is_equal(nombres_de_otra)


func test_el_padron_no_llama_al_azar() -> void:  # 013-AC8
	var texto := FileAccess.get_file_as_string(COMPRADORES)
	assert_str(texto).is_not_empty()
	for patron in ["randi", "randf", "shuffle", "pick_random"]:
		(
			assert_bool(texto.contains(patron))
			. override_failure_message("`compradores.gd` nombra `%s`: el azar no entra" % patron)
			. is_false()
		)


func test_cada_jornada_recibe_compradores_propios() -> void:  # 013-AC8
	# Instancias nuevas y no las mismas: con un padrón compartido, la atención de anoche llegaría
	# despachada y la tarea se cumpliría sola a partir de la segunda jornada.
	var una := Compradores.de_la_jornada()
	var otra := Compradores.de_la_jornada()
	assert_object(una[0]).is_not_same(otra[0])
	assert_object(una[0].pedido()).is_not_same(otra[0].pedido())


func test_alguien_paga_distinto_de_lo_que_marca_la_caja() -> void:  # 013-AC8
	# Es la única forma que tiene el juego de mentir en vivo, y por eso está en el padrón y no
	# librada al azar: un padrón donde todos pagan justo deja la ventanilla sin nada que mirar.
	var inventario := Inventario.new(Catalogo.todos())
	var diferentes := 0
	for comprador in Compradores.de_la_jornada():
		if Atencion.new(comprador, inventario).diferencia() != 0:
			diferentes += 1
	assert_int(diferentes).is_greater(0)


func test_todo_lo_que_se_pide_existe_en_el_catalogo() -> void:  # 013-AC8
	# Un pedido con un producto que el inventario no conoce responde 0 unidades y cae por el
	# camino de «no alcanza el stock»: el comprador quedaría imposible de cobrar toda la noche.
	for comprador in Compradores.de_la_jornada():
		var pedido := comprador.pedido()
		(
			assert_array(pedido.productos())
			. override_failure_message("`%s` no pide nada" % comprador.nombre())
			. is_not_empty()
		)
		for producto in pedido.productos():
			assert_object(Catalogo.de(producto.id)).is_not_null()
