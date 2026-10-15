## El gesto y su referencia comparten contexto puro; consultar no ejecuta el resultado.
extends GdUnitTestSuite

const R := preload("res://src/dominio/jugador/referencia_de_controles.gd")
const L := ReferenciaDeControles.Linea
const M := ReferenciaDeControles.Mira


func _lineas(
	mano: bool, mira: R.Mira, contexto: R.Contexto, suspendido: bool = false
) -> Array[R.Linea]:
	return R.lineas(mano, mira, contexto, suspendido)


func _textos(lineas: Array[R.Linea]) -> Array[String]:
	var textos: Array[String] = []
	for linea in lineas:
		var accion := String(R.accion(linea))
		var controles := {
			ReglasDeLosObjetos.ACCION_EXAMINAR: "E",
			ReglasDeLosObjetos.ACCION_AGARRAR: "Click Izq",
			ReglasDelJugador.ACCION_USAR: "Click Der"
		}
		textos.append(R.texto(linea, controles[accion]))
	return textos


func _caja(cuantas: int) -> ContenidoDeLaCaja:
	var producto := Catalogo.de(Producto.Id.ACTRONCITO)
	var productos: Array[Producto] = [producto]
	var inventario := Inventario.new(productos, {producto.id: 8})
	inventario.ingresar(producto, Inventario.Ubicacion.DEPOSITO, cuantas)
	return ContenidoDeLaCaja.new(producto, Estante.new(inventario, productos))


func test_lavatorio_y_caja_muestran_los_ejemplos_exactos() -> void:  # AC-PLY-082
	var uso := Uso.para_el_almacen()
	assert_array(_textos(_lineas(false, M.FIJO, R.Contexto.new()))).contains_exactly(
		["[E] Examinar"]
	)
	var contexto := R.contexto_del_uso(
		uso.resolver(ReglasDeLaLimpieza.ID_DEL_BALDE, ReglasDeLaLimpieza.ID_DEL_LAVATORIO)
	)
	assert_array(_textos(_lineas(true, M.FIJO, contexto))).contains_exactly(
		["[E] Examinar (mano)", "[Click Izq] Llenar"]
	)
	(
		assert_array(_textos(_lineas(false, M.CAJA, R.contexto_de_la_caja(_caja(1), null))))
		. contains_exactly(["[E] Examinar", "[Click Izq] Agarrar", "[Click Der] Sacar producto"])
	)


func test_la_caja_ofrece_sacar_con_una_y_no_con_cero_sin_mutar() -> void:  # AC-PLY-083
	for cantidad: int in [0, 1]:
		var caja := _caja(cantidad)
		var contexto := R.contexto_de_la_caja(caja, null)
		assert_bool(_lineas(false, M.CAJA, contexto).has(L.SACAR_PRODUCTO)).is_equal(cantidad > 0)
		assert_int(caja.unidades()).is_equal(cantidad)
		assert_int(R.ruta(true, contexto, false)).is_equal(R.Ruta.GENERICA)


func test_devolver_consume_aun_con_caja_llena() -> void:  # AC-PLY-083 AC-PLY-097
	var unidad := UnidadDeProducto.new(Catalogo.de(Producto.Id.ACTRONCITO))
	for cantidad: int in [0, 1, 7, 8]:
		var caja := _caja(cantidad)
		var contexto := R.contexto_de_la_caja(caja, unidad)
		var esperadas: Array[R.Linea] = [L.EXAMINAR_LA_MANO]
		if cantidad < ReglasDelEstante.UNIDADES_POR_CAJA:
			esperadas.append(L.METER_PRODUCTO)
		assert_array(_lineas(true, M.CAJA, contexto)).contains_exactly(esperadas)
		assert_int(R.ruta(true, contexto, false)).is_equal(R.Ruta.PEDIR_USO)
		assert_int(R.ruta(false, contexto, false)).is_equal(R.Ruta.IGNORAR)
		assert_int(caja.unidades()).is_equal(cantidad)


func test_producto_ajeno_y_otra_caja_conservan_dejar() -> void:  # AC-PLY-083
	var caja := _caja(1)
	var otra := load("res://src/dominio/almacen/caja_de_reposicion.tres") as ObjetoDelAlmacen
	assert_object(otra).is_not_null()
	for sostenido: ObjetoDelAlmacen in [
		UnidadDeProducto.new(Catalogo.de(Producto.Id.MALBARDO)), otra
	]:
		var contexto := R.contexto_de_la_caja(caja, sostenido)
		assert_array(_textos(_lineas(true, M.CAJA, contexto))).contains_exactly(
			["[E] Examinar (mano)", "[Click Izq] Dejar"]
		)
		assert_int(R.ruta(false, contexto, false)).is_equal(R.Ruta.IGNORAR)


func test_los_seis_pares_declaran_verbo_sin_consultar_agua_carga_o_jabon() -> void:  # AC-PLY-084
	var uso := Uso.para_el_almacen()
	var pares := [
		[&"balde", &"lavatorio", L.LLENAR],
		[&"balde", &"inodoro", L.VACIAR],
		[&"mopa", &"balde", L.MOJAR],
		[&"mopa", &"inodoro", L.MOJAR],
		[&"mopa", Uso.MANCHA, L.LIMPIAR]
	]
	for jabon: StringName in ReglasDeLaLimpieza.JABONES:
		pares.append([jabon, &"balde", L.VERTIR])
	for par: Array in pares:
		var contexto := R.contexto_del_uso(uso.resolver(par[0], par[1]))
		assert_array(_lineas(true, M.FIJO, contexto)).contains_exactly([L.EXAMINAR_LA_MANO, par[2]])
		assert_int(R.ruta(true, contexto, false)).is_equal(R.Ruta.PEDIR_USO)
		assert_int(R.ruta(false, contexto, false)).is_equal(R.Ruta.IGNORAR)
	assert_str(R.texto(L.VERTIR, "F")).is_equal("[F] Vertir")


func test_lector_ofrece_uso_con_cero_dos_y_tres_renglones() -> void:  # AC-PLY-084
	var unidad := UnidadDeProducto.new(Catalogo.de(Producto.Id.ACTRONCITO))
	for cantidad: int in [0, 2, 3]:
		var generador := GeneradorDeTickets.para_la_jornada(1)
		for indice in cantidad:
			generador.anotar(unidad)
		var contexto := R.contexto_del_lector(unidad, true)
		assert_array(_lineas(true, M.FIJO, contexto)).contains_exactly(
			[L.EXAMINAR_LA_MANO, L.INTERACTUAR]
		)
		assert_int(generador.renglones().size()).is_equal(cantidad)
		assert_int(R.ruta(false, contexto, false)).is_equal(R.Ruta.IGNORAR)


func test_lector_rechazable_consume_sin_ofrecer_lectura() -> void:  # AC-PLY-084
	var unidad := UnidadDeProducto.new(Catalogo.de(Producto.Id.ACTRONCITO))
	assert_array(_lineas(true, M.FIJO, R.contexto_del_lector(unidad, false))).contains_exactly(
		[L.EXAMINAR_LA_MANO, L.DEJAR]
	)
	assert_array(_lineas(false, M.FIJO, R.contexto_del_lector(null, true))).contains_exactly(
		[L.EXAMINAR]
	)
	var contexto := R.contexto_del_lector(Ticket.new(), true)
	assert_int(R.ruta(true, contexto, false)).is_equal(R.Ruta.PEDIR_USO)
	assert_bool(_lineas(true, M.FIJO, contexto).has(L.DEJAR)).is_false()


func test_ticket_solo_declara_descarte_sobre_inodoro() -> void:  # AC-PLY-084
	var ticket := Ticket.new()
	var contexto := R.contexto_del_descarte(ticket, ReglasDeLaLimpieza.ID_DEL_INODORO)
	assert_array(_lineas(true, M.FIJO, contexto)).contains_exactly(
		[L.EXAMINAR_LA_MANO, L.INTERACTUAR]
	)
	assert_int(R.ruta(false, contexto, false)).is_equal(R.Ruta.IGNORAR)
	assert_object(R.contexto_del_descarte(ticket, ReglasDeLaLimpieza.ID_DEL_LAVATORIO)).is_null()
	assert_object(R.contexto_del_descarte(null, ReglasDeLaLimpieza.ID_DEL_INODORO)).is_null()


func test_puerta_abierta_cierra_y_cerrada_o_trabada_abre_y_nota_mira() -> void:  # AC-PLY-084
	for abierta: bool in [false, true]:
		var contexto := R.contexto_de_lo_fijo(abierta)
		assert_array(_lineas(true, M.FIJO, contexto)).contains_exactly(
			[L.EXAMINAR_LA_MANO, L.CERRAR if abierta else L.ABRIR]
		)
		assert_int(R.ruta(true, contexto, false)).is_equal(R.Ruta.ACCIONAR)
		assert_int(R.ruta(false, contexto, false)).is_equal(R.Ruta.IGNORAR)
	assert_array(_lineas(false, M.FIJO, R.contexto_de_lo_fijo(false, true))).contains_exactly(
		[L.EXAMINAR, L.MIRAR]
	)


func test_tacho_solo_ofrece_extraccion_con_bolsa_y_mano_vacia_sin_sacarla() -> void:  # AC-PLY-085
	var tarea := TareaDeLaBasura.de_la_jornada(2)
	for mano: bool in [false, true]:
		for bolsa: bool in [false, true]:
			var contexto := R.contexto_del_tacho(bolsa, mano)
			assert_bool(_lineas(mano, M.FIJO, contexto).has(L.INTERACTUAR)).is_equal(
				bolsa and not mano
			)
			assert_bool(_lineas(mano, M.FIJO, contexto).has(L.DEJAR)).is_false()
			assert_int(R.ruta(false, contexto, false)).is_equal(R.Ruta.IGNORAR)
	assert_bool(tarea.tiene_bolsa(TareaDeLaBasura.Tacho.LOCAL)).is_true()
	assert_int(tarea.depositadas()).is_zero()


func test_cuerpo_y_tapa_ofrecen_un_solo_primario_distinto() -> void:  # AC-PLY-086
	var cuerpo := R.contexto_del_contenedor(true)
	assert_array(_textos(_lineas(true, M.FIJO, cuerpo))).contains_exactly(
		["[E] Examinar (mano)", "[Click Izq] Interactuar"]
	)
	assert_int(R.ruta(true, cuerpo, false)).is_equal(R.Ruta.INTERACTUAR)
	for abierta: bool in [false, true]:
		var tapa := R.contexto_de_lo_fijo(abierta)
		assert_array(_lineas(true, M.FIJO, tapa)).contains_exactly(
			[L.EXAMINAR_LA_MANO, L.CERRAR if abierta else L.ABRIR]
		)
		assert_int(R.ruta(true, tapa, false)).is_equal(R.Ruta.ACCIONAR)


func test_sin_interaccion_declarada_conserva_agarrar_y_dejar() -> void:  # AC-PLY-087 AC-PLY-097
	var contexto := R.Contexto.new()
	assert_array(_lineas(false, M.NADA, contexto)).is_empty()
	assert_array(_lineas(true, M.NADA, contexto)).contains_exactly([L.EXAMINAR_LA_MANO, L.DEJAR])
	assert_array(_lineas(false, M.LEVANTABLE, contexto)).contains_exactly([L.EXAMINAR, L.AGARRAR])
	assert_int(R.ruta(true, contexto, false)).is_equal(R.Ruta.GENERICA)


func test_cada_verbo_usa_su_asignacion_y_sin_control_no_se_lee() -> void:  # AC-PLY-088
	for linea: R.Linea in [
		L.AGARRAR,
		L.DEJAR,
		L.INTERACTUAR,
		L.METER_PRODUCTO,
		L.ABRIR,
		L.CERRAR,
		L.MIRAR,
		L.HABLAR,
		L.ENTREGAR,
		L.LLENAR,
		L.VACIAR,
		L.VERTIR,
		L.MOJAR,
		L.LIMPIAR
	]:
		assert_str(String(R.accion(linea))).is_equal(ReglasDeLosObjetos.ACCION_AGARRAR)
	assert_str(String(R.accion(L.SACAR_PRODUCTO))).is_equal(ReglasDelJugador.ACCION_USAR)
	assert_str(R.texto(L.EXAMINAR_LA_MANO, "Q")).is_equal("[Q] Examinar (mano)")
	assert_str(R.texto(L.LLENAR, "F")).is_equal("[F] Llenar")
	assert_str(R.texto(L.LLENAR, "")).is_empty()


func test_suspender_vacia_referencia_y_bloquea_ambos_gestos() -> void:  # AC-PLY-089 AC-PLY-098
	for contexto: R.Contexto in [
		R.Contexto.new(),
		R.contexto_de_lo_fijo(),
		R.contexto_del_contenedor(true),
		R.contexto_primario(L.LIMPIAR)
	]:
		for mano: bool in [false, true]:
			for mira: R.Mira in M.values():
				assert_array(_lineas(mano, mira, contexto, true)).is_empty()
				assert_int(R.ruta(true, contexto, true)).is_equal(R.Ruta.IGNORAR)
				assert_int(R.ruta(false, contexto, true)).is_equal(R.Ruta.IGNORAR)


func test_foco_y_mano_se_resuelven_con_la_misma_lectura() -> void:  # AC-PLY-090
	assert_array(_lineas(false, M.FIJO, R.Contexto.new())).contains_exactly([L.EXAMINAR])
	(
		assert_array(
			_lineas(
				true,
				M.CAJA,
				R.contexto_de_la_caja(_caja(8), load("res://src/dominio/almacen/balde.tres"))
			)
		)
		. contains_exactly([L.EXAMINAR_LA_MANO, L.DEJAR])
	)


func test_hablar_y_entregar_solo_declaran_el_contexto_habilitado() -> void:  # AC-PLY-096
	for atendido: bool in [false, true]:
		for mano: bool in [false, true]:
			var contexto := R.contexto_de_atencion(true, atendido, mano)
			assert_int(contexto.primario).is_equal(L.ENTREGAR if atendido and mano else L.HABLAR)
			assert_bool(_lineas(mano, M.FIJO, contexto).has(L.DEJAR)).is_false()
	assert_int(R.contexto_de_atencion(false, true, true).ruta_primaria).is_equal(R.Ruta.GENERICA)
