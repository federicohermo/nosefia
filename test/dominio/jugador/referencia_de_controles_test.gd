## La referencia de controles sin escena: qué líneas valen para lo que se mira y lo que se lleva,
## en qué orden, y cuándo el clic derecho cuenta con efecto.
##
## **Ni un `Node3D` en toda la suite.** La mira, la mano y el efecto del derecho entran ya
## traducidos, que es la prueba de que la regla vive en `dominio/`. Los casos recorren las
## combinaciones y afirman las líneas exactas, no sólo que alguna aparezca.
extends GdUnitTestSuite

const L := ReferenciaDeControles.Linea
const MIRA := ReferenciaDeControles.Mira
const DERECHO := ReferenciaDeControles.Derecho

## Los controles de fábrica, como los nombra el HUD. Acá son sólo texto: el dominio no lee el
## teclado ni el mouse.
const TECLA_DE_EXAMINAR := "E"
const BOTON_IZQUIERDO := "Click Izq"
const BOTON_DERECHO := "Click Der"

## Casilleros de la fila de adelante del producto de prueba, como en la suite de la caja.
const CASILLEROS := 8


func _lineas(
	con_la_mano: bool,
	mira: ReferenciaDeControles.Mira,
	derecho: ReferenciaDeControles.Derecho,
	suspendido: bool = false
) -> Array[ReferenciaDeControles.Linea]:
	return ReferenciaDeControles.lineas(con_la_mano, mira, derecho, suspendido)


## Las líneas escritas como las lee el jugador, con los controles de fábrica.
func _textos(lineas: Array[ReferenciaDeControles.Linea]) -> Array[String]:
	var controles := {
		ReglasDeLosObjetos.ACCION_EXAMINAR: TECLA_DE_EXAMINAR,
		ReglasDeLosObjetos.ACCION_AGARRAR: BOTON_IZQUIERDO,
		ReglasDelJugador.ACCION_USAR: BOTON_DERECHO,
	}
	var textos: Array[String] = []
	for linea in lineas:
		var accion := String(ReferenciaDeControles.accion(linea))
		textos.append(ReferenciaDeControles.texto(linea, controles[accion]))
	return textos


## El estante de un solo producto con esas unidades en el depósito.
func _estante(producto: Producto, en_deposito: int) -> Estante:
	var productos: Array[Producto] = [producto]
	var inventario := Inventario.new(productos, {producto.id: CASILLEROS})
	inventario.ingresar(producto, Inventario.Ubicacion.DEPOSITO, en_deposito)
	return Estante.new(inventario, productos)


func test_los_dos_ejemplos_de_la_ficha() -> void:  # AC-PLY-082
	# El lavatorio es fijo. Con la mano vacía, el derecho no tiene efecto sobre él; con el balde,
	# llenarlo es el par declarado.
	var uso := Uso.para_el_almacen()
	var vacia := ReferenciaDeControles.derecho_del_uso(
		uso.resolver(ObjetoDelAlmacen.SIN_ID, ReglasDeLaLimpieza.ID_DEL_LAVATORIO)
	)
	var con_el_balde := ReferenciaDeControles.derecho_del_uso(
		uso.resolver(ReglasDeLaLimpieza.ID_DEL_BALDE, ReglasDeLaLimpieza.ID_DEL_LAVATORIO)
	)
	assert_array(_textos(_lineas(false, MIRA.FIJO, vacia))).contains_exactly(["[E] Examinar"])
	assert_array(_textos(_lineas(true, MIRA.FIJO, con_el_balde))).contains_exactly(
		["[E] Examinar (mano)", "[Click Izq] Dejar", "[Click Der] Interactuar"]
	)


func test_las_siete_lineas_salen_en_el_orden_de_la_ficha() -> void:  # AC-PLY-082
	# El orden del enum es el de la ficha: nada las reordena después.
	var todas: Array[ReferenciaDeControles.Linea] = [
		L.EXAMINAR_LA_MANO,
		L.EXAMINAR,
		L.AGARRAR,
		L.DEJAR,
		L.INTERACTUAR,
		L.SACAR_PRODUCTO,
		L.METER_PRODUCTO,
	]
	for indice in todas.size():
		assert_int(todas[indice]).is_equal(indice)
	var textos: Array[String] = []
	for linea in todas:
		textos.append(ReferenciaDeControles.texto(linea, "X"))
	(
		assert_array(textos)
		. contains_exactly(
			[
				"[X] Examinar (mano)",
				"[X] Examinar",
				"[X] Agarrar",
				"[X] Dejar",
				"[X] Interactuar",
				"[X] Sacar producto",
				"[X] Meter producto",
			]
		)
	)


func test_la_caja_del_deposito_saca_mete_o_nada() -> void:  # AC-PLY-083
	var actroncito := Catalogo.de(Producto.Id.ACTRONCITO)
	var con_una := ContenidoDeLaCaja.new(actroncito, _estante(actroncito, 1))
	var vacia := ContenidoDeLaCaja.new(actroncito, _estante(actroncito, 0))
	var unidad := UnidadDeProducto.new(actroncito)
	(
		assert_array(
			_textos(
				_lineas(
					false,
					MIRA.CAJA,
					ReferenciaDeControles.derecho_de_la_caja(con_una.derecho_posible(null))
				)
			)
		)
		. contains_exactly(["[E] Examinar", "[Click Izq] Agarrar", "[Click Der] Sacar producto"])
	)
	(
		assert_array(
			_textos(
				_lineas(
					false,
					MIRA.CAJA,
					ReferenciaDeControles.derecho_de_la_caja(vacia.derecho_posible(null))
				)
			)
		)
		. contains_exactly(["[E] Examinar", "[Click Izq] Agarrar"])
	)
	var casi_llena := ContenidoDeLaCaja.new(
		actroncito, _estante(actroncito, ReglasDelEstante.UNIDADES_POR_CAJA - 1)
	)
	var llena := ContenidoDeLaCaja.new(
		actroncito, _estante(actroncito, ReglasDelEstante.UNIDADES_POR_CAJA)
	)
	(
		assert_array(
			_textos(
				_lineas(
					true,
					MIRA.CAJA,
					ReferenciaDeControles.derecho_de_la_caja(casi_llena.derecho_posible(unidad))
				)
			)
		)
		. contains_exactly(
			["[E] Examinar (mano)", "[Click Izq] Dejar", "[Click Der] Meter producto"]
		)
	)
	(
		assert_array(
			_textos(
				_lineas(
					true,
					MIRA.CAJA,
					ReferenciaDeControles.derecho_de_la_caja(llena.derecho_posible(unidad))
				)
			)
		)
		. contains_exactly(["[E] Examinar (mano)", "[Click Izq] Dejar"])
	)


func test_otro_producto_u_otra_caja_no_tienen_derecho_sobre_la_caja() -> void:  # AC-PLY-083
	var actroncito := Catalogo.de(Producto.Id.ACTRONCITO)
	var caja := ContenidoDeLaCaja.new(actroncito, _estante(actroncito, 1))
	var otra := UnidadDeProducto.new(Catalogo.de(Producto.Id.DUREXTRA))
	var llevada := load("res://src/dominio/almacen/caja_de_reposicion.tres") as ObjetoDelAlmacen
	assert_object(llevada).is_not_null()
	for sostenido: ObjetoDelAlmacen in [otra, llevada]:
		var derecho := ReferenciaDeControles.derecho_de_la_caja(caja.derecho_posible(sostenido))
		assert_array(_textos(_lineas(true, MIRA.CAJA, derecho))).contains_exactly(
			["[E] Examinar (mano)", "[Click Izq] Dejar"]
		)


func test_sobre_una_caja_nunca_sale_interactuar() -> void:  # AC-PLY-083
	# Aunque algo contestara que el derecho tiene efecto, la caja sólo admite sacar o meter.
	for con_la_mano: bool in [false, true]:
		var lineas := _lineas(con_la_mano, MIRA.CAJA, DERECHO.INTERACTUAR)
		assert_bool(lineas.has(L.INTERACTUAR)).is_false()
	# Y sacar o meter fuera de una caja no se leen nunca.
	for derecho: ReferenciaDeControles.Derecho in [DERECHO.SACAR, DERECHO.METER]:
		for mira: ReferenciaDeControles.Mira in [MIRA.FIJO, MIRA.LEVANTABLE, MIRA.NADA]:
			var lineas := _lineas(derecho == DERECHO.METER, mira, derecho)
			assert_bool(lineas.has(L.SACAR_PRODUCTO) or lineas.has(L.METER_PRODUCTO)).is_false()


func test_un_par_declarado_cuenta_aunque_el_uso_vaya_a_rechazarse() -> void:  # AC-PLY-084
	# La mopa mojada con otro jabón sobre una mancha y el balde lleno sobre el lavatorio: el par
	# existe y eso alcanza. Averiguarlo no toca la mopa ni el balde.
	var piso := PisoDelLocal.de_la_jornada()
	piso.usar(ReglasDeLaLimpieza.ID_DEL_BALDE, ReglasDeLaLimpieza.ID_DEL_LAVATORIO)
	piso.usar(&"jabon_amarillo", ReglasDeLaLimpieza.ID_DEL_BALDE)
	piso.usar(ReglasDeLaLimpieza.ID_DE_LA_MOPA, ReglasDeLaLimpieza.ID_DEL_BALDE)
	var agua := piso.mopa().agua()
	var carga := piso.mopa().carga_restante()
	var balde := piso.balde().agua()
	var uso := Uso.para_el_almacen()
	for par: Array in [
		[ReglasDeLaLimpieza.ID_DE_LA_MOPA, Uso.MANCHA],
		[ReglasDeLaLimpieza.ID_DEL_BALDE, ReglasDeLaLimpieza.ID_DEL_LAVATORIO],
	]:
		var derecho := ReferenciaDeControles.derecho_del_uso(uso.resolver(par[0], par[1]))
		assert_int(derecho).is_equal(DERECHO.INTERACTUAR)
		assert_bool(_lineas(true, MIRA.FIJO, derecho).has(L.INTERACTUAR)).is_true()
	assert_int(piso.mopa().agua()).is_equal(agua)
	assert_float(piso.mopa().carga_restante()).is_equal(carga)
	assert_int(piso.balde().agua()).is_equal(balde)


func test_el_lector_lleno_cuenta_y_no_anota() -> void:  # AC-PLY-084
	var unidad := UnidadDeProducto.new(Catalogo.de(Producto.Id.ACTRONCITO))
	var generador := GeneradorDeTickets.para_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA)
	while generador.anotar(unidad) == GeneradorDeTickets.Resultado.ANOTADO:
		pass
	var antes := generador.renglones().size()
	var derecho := ReferenciaDeControles.derecho_del_lector(unidad, not generador.es_manual())
	assert_int(derecho).is_equal(DERECHO.INTERACTUAR)
	assert_int(generador.renglones().size()).is_equal(antes)


func test_con_la_mano_vacia_lo_que_recibe_algo_no_tiene_derecho() -> void:  # AC-PLY-084
	var uso := Uso.para_el_almacen()
	for destino: StringName in [
		ReglasDeLaLimpieza.ID_DEL_LAVATORIO,
		ReglasDeLaLimpieza.ID_DEL_INODORO,
		ReglasDeLaLimpieza.ID_DEL_BALDE,
		Uso.MANCHA,
	]:
		var derecho := ReferenciaDeControles.derecho_del_uso(
			uso.resolver(ObjetoDelAlmacen.SIN_ID, destino)
		)
		assert_int(derecho).override_failure_message(destino).is_equal(DERECHO.NINGUNO)
		assert_int(ReferenciaDeControles.derecho_del_descarte(null, destino)).is_equal(
			DERECHO.NINGUNO
		)
	assert_int(ReferenciaDeControles.derecho_del_lector(null, true)).is_equal(DERECHO.NINGUNO)
	assert_array(_textos(_lineas(false, MIRA.FIJO, DERECHO.NINGUNO))).contains_exactly(
		["[E] Examinar"]
	)


func test_el_ticket_sobre_el_inodoro_cuenta_y_sobre_el_lavatorio_no() -> void:  # AC-PLY-084
	var ticket := Ticket.new()
	(
		assert_int(
			ReferenciaDeControles.derecho_del_descarte(ticket, ReglasDeLaLimpieza.ID_DEL_INODORO)
		)
		. is_equal(DERECHO.INTERACTUAR)
	)
	(
		assert_int(
			ReferenciaDeControles.derecho_del_descarte(ticket, ReglasDeLaLimpieza.ID_DEL_LAVATORIO)
		)
		. is_equal(DERECHO.NINGUNO)
	)
	var unidad := UnidadDeProducto.new(Catalogo.de(Producto.Id.ACTRONCITO))
	(
		assert_int(
			ReferenciaDeControles.derecho_del_descarte(unidad, ReglasDeLaLimpieza.ID_DEL_INODORO)
		)
		. is_equal(DERECHO.NINGUNO)
	)


func test_la_puerta_trabada_y_el_programa_manual() -> void:  # AC-PLY-084
	# Lo fijo que abre o alterna cuenta siempre: la puerta trabada también, que avisa.
	assert_array(_textos(_lineas(false, MIRA.FIJO, DERECHO.INTERACTUAR))).contains_exactly(
		["[E] Examinar", "[Click Der] Interactuar"]
	)
	# Con el programa manual el lector no está, y la unidad en la mano no cuenta.
	var unidad := UnidadDeProducto.new(Catalogo.de(Producto.Id.ACTRONCITO))
	assert_int(ReferenciaDeControles.derecho_del_lector(unidad, false)).is_equal(DERECHO.NINGUNO)
	# Lo que no es una unidad tampoco cuenta sobre el lector.
	assert_int(ReferenciaDeControles.derecho_del_lector(Ticket.new(), true)).is_equal(
		DERECHO.NINGUNO
	)


func test_el_tacho_con_bolsa_y_la_mano_vacia_cuenta_sin_perder_la_bolsa() -> void:  # AC-PLY-085
	var tarea := TareaDeLaBasura.de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA + 1)
	var tacho := TareaDeLaBasura.Tacho.values()[0] as TareaDeLaBasura.Tacho
	assert_bool(tarea.tiene_bolsa(tacho)).is_true()
	var bolsas := tarea.bolsas()
	var derecho := ReferenciaDeControles.derecho_del_tacho(tarea.tiene_bolsa(tacho), false)
	assert_int(derecho).is_equal(DERECHO.INTERACTUAR)
	assert_array(_textos(_lineas(false, MIRA.FIJO, derecho))).contains_exactly(
		["[E] Examinar", "[Click Der] Interactuar"]
	)
	assert_bool(tarea.tiene_bolsa(tacho)).is_true()
	assert_int(tarea.bolsas()).is_equal(bolsas)
	assert_str(tarea.sacar(tacho, false)).is_equal(String(ObjetoDelAlmacen.SIN_ID))
	# Sin bolsa, o con la mano ocupada, no hay línea del derecho.
	assert_int(ReferenciaDeControles.derecho_del_tacho(false, false)).is_equal(DERECHO.NINGUNO)
	assert_int(ReferenciaDeControles.derecho_del_tacho(true, true)).is_equal(DERECHO.NINGUNO)


func test_lo_que_se_tira_al_contenedor_se_lee_dejar() -> void:  # AC-PLY-086
	# El cuerpo y la tapa del contenedor se usan siempre; con algo en la mano, el izquierdo es
	# «Dejar» aunque vaya a tirarlo, y ninguna línea dice tirar.
	var textos := _textos(_lineas(true, MIRA.FIJO, DERECHO.INTERACTUAR))
	assert_array(textos).contains_exactly(
		["[E] Examinar (mano)", "[Click Izq] Dejar", "[Click Der] Interactuar"]
	)
	for texto in textos:
		assert_str(texto.to_lower()).not_contains("tirar")


func test_sin_nada_que_hacer_nada() -> void:  # AC-PLY-087
	# La mira sin foco —también un casillero vacío, que la mira no enfoca con la mano vacía—.
	assert_array(_lineas(false, MIRA.NADA, DERECHO.NINGUNO)).is_empty()
	assert_array(_lineas(false, MIRA.NADA, DERECHO.INTERACTUAR)).is_empty()
	# La mopa mojada mirando el piso sin mancha: el piso no se enfoca.
	assert_array(_textos(_lineas(true, MIRA.NADA, DERECHO.INTERACTUAR))).contains_exactly(
		["[E] Examinar (mano)", "[Click Izq] Dejar"]
	)
	# Una unidad de la fila de adelante con la mano vacía se agarra, y el derecho no hace nada.
	assert_array(_textos(_lineas(false, MIRA.LEVANTABLE, DERECHO.NINGUNO))).contains_exactly(
		["[E] Examinar", "[Click Izq] Agarrar"]
	)


func test_el_control_sale_de_lo_que_llega_y_sin_nombre_no_hay_linea() -> void:  # AC-PLY-088
	assert_str(ReferenciaDeControles.texto(L.EXAMINAR_LA_MANO, "Q")).is_equal("[Q] Examinar (mano)")
	assert_str(ReferenciaDeControles.texto(L.DEJAR, "")).is_empty()
	assert_str(String(ReferenciaDeControles.accion(L.EXAMINAR))).is_equal(
		ReglasDeLosObjetos.ACCION_EXAMINAR
	)
	for linea: ReferenciaDeControles.Linea in [L.AGARRAR, L.DEJAR]:
		assert_str(String(ReferenciaDeControles.accion(linea))).is_equal(
			ReglasDeLosObjetos.ACCION_AGARRAR
		)
	for linea: ReferenciaDeControles.Linea in [L.INTERACTUAR, L.SACAR_PRODUCTO, L.METER_PRODUCTO]:
		assert_str(String(ReferenciaDeControles.accion(linea))).is_equal(
			String(ReglasDelJugador.ACCION_USAR)
		)


func test_suspendido_no_hay_ninguna_linea() -> void:  # AC-PLY-089
	for con_la_mano: bool in [false, true]:
		for mira: ReferenciaDeControles.Mira in MIRA.values():
			for derecho: ReferenciaDeControles.Derecho in DERECHO.values():
				assert_array(_lineas(con_la_mano, mira, derecho, true)).is_empty()
	# Al reanudar vuelve a armarse con la misma mano y la misma mira.
	assert_array(_lineas(true, MIRA.FIJO, DERECHO.INTERACTUAR)).contains_exactly(
		[L.EXAMINAR_LA_MANO, L.DEJAR, L.INTERACTUAR]
	)


func test_la_referencia_sale_solo_de_los_valores_que_recibe() -> void:  # AC-PLY-090
	# Una función pura de la mano y la mira: con los dos valores nuevos no queda nada de la
	# combinación anterior.
	var antes := _lineas(false, MIRA.FIJO, DERECHO.NINGUNO)
	var despues := _lineas(true, MIRA.CAJA, DERECHO.NINGUNO)
	assert_array(antes).contains_exactly([L.EXAMINAR])
	assert_array(despues).contains_exactly([L.EXAMINAR_LA_MANO, L.DEJAR])
	assert_array(_lineas(true, MIRA.CAJA, DERECHO.NINGUNO)).is_equal(despues)
