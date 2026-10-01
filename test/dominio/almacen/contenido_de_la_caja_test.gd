## La caja del depósito como la ve la noche: cuántas unidades tiene, qué hace el clic sobre ella
## y qué dice al examinarla.
##
## **Ni un `Node3D` en toda la suite.** Lo que la caja decide se ejerce con un inventario y un
## estante armados a mano, que es la prueba de que vive en `dominio/`.
##
## Los casos que miden aritmética arman un solo producto con los casilleros que necesitan, y no
## leen el local: así mover una fila en el modelo no pone en rojo un solo caso de acá. Los que
## miden el texto sí leen el catálogo, porque el nombre que se lee es el suyo.
extends GdUnitTestSuite

const CONTENIDO := "res://src/dominio/almacen/contenido_de_la_caja.gd"

## Casilleros de la fila de adelante del producto de prueba: tantos como una caja. Sacar no los
## mira (BR-STK-017); los miran colocar y los vendibles, que los casos cuentan contra este número.
const CASILLEROS := 8

## Desde este número un entero escrito en el código es balance y no estructura: el `0` y el `1`
## son el vacío y el paso de a una unidad.
const PRIMERA_CIFRA_DE_BALANCE := 2


## Un producto del catálogo, con su nombre y su sonoridad de verdad.
func _producto(id: Producto.Id) -> Producto:
	return Catalogo.de(id)


## El inventario de un solo producto, con esas unidades en el depósito y en la góndola.
func _inventario(producto: Producto, en_deposito: int, en_gondola: int = 0) -> Inventario:
	var productos: Array[Producto] = [producto]
	var inventario := Inventario.new(productos, {producto.id: CASILLEROS})
	inventario.ingresar(producto, Inventario.Ubicacion.DEPOSITO, en_deposito)
	inventario.ingresar(producto, Inventario.Ubicacion.GONDOLA, en_gondola)
	return inventario


## Un estante de un solo producto, sobre un inventario como el de arriba.
func _estante(producto: Producto, en_deposito: int, en_gondola: int = 0) -> Estante:
	var productos: Array[Producto] = [producto]
	return Estante.new(_inventario(producto, en_deposito, en_gondola), productos)


## La caja de ese producto sobre el estante de la noche.
func _caja(producto: Producto, estante: Estante) -> ContenidoDeLaCaja:
	return ContenidoDeLaCaja.new(producto, estante)


func test_la_jornada_abre_con_cada_caja_llena() -> void:  # AC-STK-036
	# Las cinco jornadas y no sólo la primera: todas abren con la caja llena, y la que hace
	# faltar algo también, porque lo que falta está en la góndola y no en la caja.
	var casilleros: Dictionary[Producto.Id, int] = {}
	for producto in Catalogo.todos():
		casilleros[producto.id] = CASILLEROS
	for vez in ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA:
		var jornada := ReglasDeLaPartida.PRIMERA_JORNADA + vez
		var inventario := Apertura.inventario_de_la_jornada(jornada, casilleros)
		var estante := Estante.new(inventario, Catalogo.todos())
		for producto in Catalogo.todos():
			(
				assert_int(_caja(producto, estante).unidades())
				. override_failure_message(
					"jornada %d: la caja de %s no abre llena" % [jornada, producto.nombre]
				)
				. is_equal(ReglasDelEstante.UNIDADES_POR_CAJA)
			)


func test_sacar_resta_colocar_no_cambia_y_vender_resta() -> void:  # AC-STK-036
	# A la góndola le faltan 5: colocar una no la llena, y quedan 3 para vender.
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var inventario := _inventario(actroncito, ReglasDelEstante.UNIDADES_POR_CAJA, 3)
	var aceptados: Array[Producto] = [actroncito]
	var estante := Estante.new(inventario, aceptados)
	var caja := _caja(actroncito, estante)
	var unidad := caja.sacar()
	assert_object(unidad).is_not_null()
	assert_int(caja.unidades()).is_equal(ReglasDelEstante.UNIDADES_POR_CAJA - 1)
	assert_int(estante.colocar_unidad(unidad)).is_equal(Estante.Rechazo.NINGUNO)
	assert_int(caja.unidades()).is_equal(ReglasDelEstante.UNIDADES_POR_CAJA - 1)
	# La venta descuenta del depósito, y la caja dice una menos: son el mismo número.
	var venta := Venta.new()
	venta.agregar(actroncito, 1)
	assert_bool(inventario.cobrar(venta)).is_true()
	assert_int(caja.unidades()).is_equal(ReglasDelEstante.UNIDADES_POR_CAJA - 2)
	assert_int(caja.unidades()).is_equal(estante.unidades_en_deposito(actroncito))


func test_la_caja_vacia_no_da_aunque_la_gondola_tenga_lugar() -> void:  # AC-STK-016
	# Dos unidades en el depósito y la fila entera vacía: salen las dos, y a la góndola todavía
	# le quedan 6 casilleros sin una unidad que los espere.
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var estante := _estante(actroncito, 2)
	var caja := _caja(actroncito, estante)
	assert_object(caja.sacar()).is_not_null()
	assert_object(caja.sacar()).is_not_null()
	assert_int(caja.unidades()).is_zero()
	(
		assert_int(
			(
				estante.cupo(actroncito)
				- estante.unidades_en_gondola(actroncito)
				- estante.reservadas(actroncito)
			)
		)
		. is_equal(6)
	)
	assert_object(caja.sacar()).is_null()
	assert_int(caja.unidades()).is_zero()
	assert_int(estante.reservadas(actroncito)).is_equal(2)


func test_la_caja_que_se_lleva_no_da_nada() -> void:  # AC-STK-016
	# Todas las cajas comparten el mismo objeto del almacén: con cualquiera en la mano, el clic
	# sobre otra tampoco saca. Es lo que cobra el traslado.
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var caja := _caja(actroncito, _estante(actroncito, ReglasDelEstante.UNIDADES_POR_CAJA))
	var llevada := load("res://src/dominio/almacen/caja_de_reposicion.tres") as ObjetoDelAlmacen
	assert_object(llevada).is_not_null()
	assert_int(caja.uso(llevada)).is_equal(ContenidoDeLaCaja.Gesto.NADA)
	assert_int(caja.uso(null)).is_equal(ContenidoDeLaCaja.Gesto.SACAR)


func test_el_gesto_sale_de_lo_que_lleva_la_mano() -> void:  # AC-STK-038
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var caja := _caja(actroncito, _estante(actroncito, ReglasDelEstante.UNIDADES_POR_CAJA))
	var mopa := load("res://src/dominio/almacen/mopa.tres") as ObjetoDelAlmacen
	assert_object(mopa).is_not_null()
	var gestos := {
		"las manos vacías": [null, ContenidoDeLaCaja.Gesto.SACAR],
		"su producto": [UnidadDeProducto.new(actroncito), ContenidoDeLaCaja.Gesto.METER],
		"otra instancia de su producto":
		[
			UnidadDeProducto.new(Catalogo.de(Producto.Id.ACTRONCITO)),
			ContenidoDeLaCaja.Gesto.METER,
		],
		"otro producto":
		[UnidadDeProducto.new(_producto(Producto.Id.MALBARDO)), ContenidoDeLaCaja.Gesto.NADA],
		"la mopa": [mopa, ContenidoDeLaCaja.Gesto.NADA],
	}
	for mano: String in gestos:
		var sostenido: ObjetoDelAlmacen = gestos[mano][0]
		(
			assert_int(caja.uso(sostenido))
			. override_failure_message("con %s en la mano" % mano)
			. is_equal(gestos[mano][1])
		)


func test_sacar_devolver_y_sacar_pasa_por_siete_ocho_y_siete() -> void:  # AC-STK-039
	# A la góndola le faltan 6 y la caja tiene 8: lo que se puede sacar es la caja entera, y
	# la acompaña.
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var estante := _estante(actroncito, ReglasDelEstante.UNIDADES_POR_CAJA, 2)
	var caja := _caja(actroncito, estante)
	var lleno := ReglasDelEstante.UNIDADES_POR_CAJA
	var disponibles := estante.disponibles_para_retirar(actroncito)
	assert_int(disponibles).is_equal(lleno)
	var primera := caja.sacar()
	assert_int(caja.unidades()).is_equal(lleno - 1)
	assert_int(estante.disponibles_para_retirar(actroncito)).is_equal(disponibles - 1)
	assert_bool(caja.meter(primera)).is_true()
	assert_int(caja.unidades()).is_equal(lleno)
	assert_int(estante.disponibles_para_retirar(actroncito)).is_equal(disponibles)
	assert_object(caja.sacar()).is_not_null()
	assert_int(caja.unidades()).is_equal(lleno - 1)
	assert_int(estante.disponibles_para_retirar(actroncito)).is_equal(disponibles - 1)
	# Devolver no mueve mercadería: la unidad nunca había salido del depósito.
	assert_int(estante.unidades_en_deposito(actroncito)).is_equal(lleno)
	assert_int(estante.unidades_en_gondola(actroncito)).is_equal(2)


func test_devolver_dos_veces_la_misma_unidad_no_suma_la_segunda() -> void:  # AC-STK-039
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var estante := _estante(actroncito, ReglasDelEstante.UNIDADES_POR_CAJA)
	var caja := _caja(actroncito, estante)
	var otra := caja.sacar()
	var unidad := caja.sacar()
	assert_bool(caja.meter(unidad)).is_true()
	assert_bool(caja.meter(unidad)).is_false()
	assert_int(caja.unidades()).is_equal(ReglasDelEstante.UNIDADES_POR_CAJA - 1)
	assert_int(estante.reservadas(actroncito)).is_equal(1)
	# La que sigue afuera es la otra: devolver una no anuló la de al lado.
	assert_bool(caja.meter(otra)).is_true()
	assert_int(caja.unidades()).is_equal(ReglasDelEstante.UNIDADES_POR_CAJA)


func test_la_caja_llena_no_recibe_y_la_unidad_sigue_afuera() -> void:  # AC-STK-040
	# Nueve en el depósito y una afuera: la caja tiene 8 y la unidad que salió no entra. Es lo
	# que pasa al agarrar una unidad de la góndola con la caja llena (BR-STK-034).
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var estante := _estante(actroncito, ReglasDelEstante.UNIDADES_POR_CAJA + 1)
	var caja := _caja(actroncito, estante)
	var unidad := caja.sacar()
	assert_int(caja.unidades()).is_equal(ReglasDelEstante.UNIDADES_POR_CAJA)
	assert_bool(caja.meter(unidad)).is_false()
	assert_int(caja.unidades()).is_equal(ReglasDelEstante.UNIDADES_POR_CAJA)
	assert_int(estante.reservadas(actroncito)).is_equal(1)


func test_la_caja_vacia_recibe_y_queda_en_uno() -> void:  # AC-STK-040
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var caja := _caja(actroncito, _estante(actroncito, 1))
	var unidad := caja.sacar()
	assert_int(caja.unidades()).is_zero()
	assert_bool(caja.meter(unidad)).is_true()
	assert_int(caja.unidades()).is_equal(1)


func test_otro_producto_o_nada_no_entra() -> void:  # AC-STK-038
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var malbardo := _producto(Producto.Id.MALBARDO)
	var productos: Array[Producto] = [actroncito, malbardo]
	var inventario := Inventario.new(
		productos, {actroncito.id: CASILLEROS, malbardo.id: CASILLEROS}
	)
	for producto in productos:
		inventario.ingresar(producto, Inventario.Ubicacion.DEPOSITO, 2)
	var estante := Estante.new(inventario, productos)
	var caja := _caja(actroncito, estante)
	var ajena := _caja(malbardo, estante).sacar()
	assert_object(ajena).is_not_null()
	assert_bool(caja.meter(ajena)).is_false()
	assert_bool(caja.meter(null)).is_false()
	assert_int(caja.unidades()).is_equal(2)
	assert_int(estante.reservadas(malbardo)).is_equal(1)


func test_el_texto_dice_cuantas_tiene_y_cuantas_entran() -> void:  # AC-STK-041
	# Cada fila sale de «las unidades de una caja menos lo que hay», y el nombre es el del
	# catálogo: Malbardo y no «cigarrillos Malbardo», que es como lo dice la ficha. Las cuatro
	# últimas son una por familia sonora: Terminator es una caja, y se cuenta en cartones.
	var filas := [
		[Producto.Id.ACTRONCITO, 8, "Una caja con 8 cajitas de Actroncito."],
		[Producto.Id.MALBARDO, 5, "Una caja con 5 cajitas de Malbardo. Entran 3 más."],
		[Producto.Id.ACTRONCITO, 7, "Una caja con 7 cajitas de Actroncito. Entra 1 más."],
		[Producto.Id.ACTRONCITO, 1, "Una caja con 1 cajita de Actroncito. Entran 7 más."],
		[Producto.Id.ACTRONCITO, 0, "Una caja con 0 cajitas de Actroncito. Entran 8 más."],
		[Producto.Id.LAYSNTT, 8, "Una caja con 8 paquetes de Laysntt."],
		[Producto.Id.CORACOLA, 1, "Una caja con 1 lata de Coracola. Entran 7 más."],
		[Producto.Id.TERMINATOR, 6, "Una caja con 6 cartones de Terminator. Entran 2 más."],
		[Producto.Id.FERNET_GOD, 1, "Una caja con 1 botella de Fernet God. Entran 7 más."],
	]
	assert_int(ReglasDelEstante.UNIDADES_POR_CAJA).is_equal(8)
	for fila: Array in filas:
		var producto := _producto(fila[0])
		var caja := _caja(producto, _estante(producto, fila[1]))
		assert_int(caja.unidades()).is_equal(fila[1])
		assert_str(caja.texto_del_examen()).is_equal(fila[2])


func test_la_cuenta_de_lo_que_entra_sale_de_lo_que_esta_afuera() -> void:  # AC-STK-041
	# Cinco en el depósito y dos en la mano: la caja tiene 3 y le entran 5. El texto cuenta la
	# caja y no el depósito.
	var malbardo := _producto(Producto.Id.MALBARDO)
	var caja := _caja(malbardo, _estante(malbardo, 5))
	caja.sacar()
	caja.sacar()
	assert_str(caja.texto_del_examen()).is_equal(
		"Una caja con 3 cajitas de Malbardo. Entran 5 más."
	)


func test_cada_familia_del_catalogo_se_cuenta_en_su_palabra() -> void:  # AC-STK-041
	# Recorre el catálogo y no una lista de productos: el día que un producto traiga una familia
	# sin palabra, el caso la nombra. Con una unidad va el singular, con dos el plural.
	var palabras := {
		EntradaSonora.Sonoridad.CAJITA: ["cajita", "cajitas"],
		EntradaSonora.Sonoridad.ENVOLTORIO_PLASTICO: ["paquete", "paquetes"],
		EntradaSonora.Sonoridad.LATA: ["lata", "latas"],
		EntradaSonora.Sonoridad.CAJA: ["cartón", "cartones"],
		EntradaSonora.Sonoridad.BOTELLA_PLASTICA: ["botella", "botellas"],
	}
	# La tabla del juego es la de la decisión, fila por fila.
	for familia: EntradaSonora.Sonoridad in palabras:
		assert_array(ContenidoDeLaCaja.NOMBRES_DE_LA_UNIDAD.get(familia, [])).is_equal(
			palabras[familia]
		)
	for producto in Catalogo.todos():
		var familia := Catalogo.sonoridad_de(producto.id)
		var nombre_de_la_familia: String = EntradaSonora.Sonoridad.find_key(familia)
		(
			assert_bool(ContenidoDeLaCaja.NOMBRES_DE_LA_UNIDAD.has(familia))
			. override_failure_message(
				"%s es %s, y esa familia no tiene palabra" % [producto.nombre, nombre_de_la_familia]
			)
			. is_true()
		)
		if not palabras.has(familia):
			continue
		var una := _caja(producto, _estante(producto, 1))
		assert_str(una.texto_del_examen()).is_equal(
			"Una caja con 1 %s de %s. Entran 7 más." % [palabras[familia][0], producto.nombre]
		)
		var dos := _caja(producto, _estante(producto, 2))
		assert_str(dos.texto_del_examen()).is_equal(
			"Una caja con 2 %s de %s. Entran 6 más." % [palabras[familia][1], producto.nombre]
		)


func test_cada_producto_del_catalogo_tiene_su_texto() -> void:
	# El texto lleva el nombre de cada producto y no queda vacío para ninguno: la caja que se
	# examina en el depósito es cualquiera de las del catálogo.
	for producto in Catalogo.todos():
		var caja := _caja(producto, _estante(producto, ReglasDelEstante.UNIDADES_POR_CAJA))
		(
			assert_str(caja.texto_del_examen())
			. override_failure_message("la caja de %s no dice su nombre" % producto.nombre)
			. ends_with(" de %s." % producto.nombre)
		)


func test_examinar_no_cambia_el_contenido() -> void:  # AC-STK-042
	var actroncito := _producto(Producto.Id.ACTRONCITO)
	var caja := _caja(actroncito, _estante(actroncito, ReglasDelEstante.UNIDADES_POR_CAJA))
	caja.sacar()
	var antes := caja.unidades()
	assert_int(antes).is_equal(ReglasDelEstante.UNIDADES_POR_CAJA - 1)
	var texto := caja.texto_del_examen()
	assert_str(texto).is_not_empty()
	assert_str(caja.texto_del_examen()).is_equal(texto)
	assert_int(caja.unidades()).is_equal(antes)


func test_el_tope_de_la_caja_no_se_escribe_otra_vez() -> void:
	# El 8 vive una sola vez, en las reglas del estante. Una copia acá seguiría diciendo 8 el
	# día que la caja traiga otra cosa, y la cuenta de lo que entra saldría mal sin un rojo.
	var texto := FileAccess.get_file_as_string(CONTENIDO)
	assert_str(texto).is_not_empty()
	var codigo := PackedStringArray()
	for linea in texto.split("\n"):
		codigo.append(linea.split("#")[0])
	var cifras := RegEx.create_from_string("\\b\\d+\\b").search_all("\n".join(codigo))
	var de_balance: Array[String] = []
	for cifra in cifras:
		if cifra.get_string().to_int() >= PRIMERA_CIFRA_DE_BALANCE:
			de_balance.append(cifra.get_string())
	(
		assert_array(de_balance)
		. override_failure_message("`contenido_de_la_caja.gd` escribe %s" % ", ".join(de_balance))
		. is_empty()
	)
	assert_str(texto).contains("ReglasDelEstante.UNIDADES_POR_CAJA")
