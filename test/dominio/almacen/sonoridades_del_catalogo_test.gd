## Cómo suena cada producto del catálogo y cómo suenan las familias que se agregaron: la botella
## de vidrio, la caja de cereales y el balde vacío.
extends GdUnitTestSuite

## Los productos de cada familia sonora, de la columna «Familia sonora» de su ficha. Cada producto
## aparece en una sola.
const FAMILIAS := {
	EntradaSonora.Sonoridad.LATA: ["Arvecor", "Marranos", "Progres", "Pura-Cola"],
	EntradaSonora.Sonoridad.ENVOLTORIO_PLASTICO:
	[
		"Chisitos",
		"Cosa de Maní",
		"Don Saturados",
		"Laysnnt",
		"Macumbas",
		"Mayonchis",
		"Petisas",
	],
	EntradaSonora.Sonoridad.CAJITA:
	[
		"Actroncito",
		"Burbaloo",
		"Durextra",
		"Duronga",
		"Jorgillo",
		"Malbardo",
		"Oremos",
		"Saladick",
	],
	EntradaSonora.Sonoridad.CAJA: ["Amargadito", "Cindolor", "Oaaaa", "Terminator"],
	EntradaSonora.Sonoridad.BOTELLA_PLASTICA: ["Poético"],
	EntradaSonora.Sonoridad.BOTELLA_VIDRIO: ["Fernet God"],
	EntradaSonora.Sonoridad.CAJA_CEREALES:
	[
		"Feel Ricky Fort",
		"Flim Pof",
		"Frot Lups",
		"Marolini",
		"Pepito",
		"Uakalas",
		"Zucarachas",
	],
}

## Las sonoridades que ya tenían índice en los `.tres` antes de agregar estas, en su orden.
const SONORIDADES_PREVIAS: Array = [
	"NINGUNA",
	"LATA",
	"CAJITA",
	"CAJA",
	"ENVOLTORIO_PLASTICO",
	"BOTELLA_PLASTICA",
	"PAPEL",
	"BOLSA",
	"MOPA",
	"BALDE",
]


func _tabla() -> TablaDeSonidos:
	var tabla := TablaDeSonidos.desde_disco()
	(
		assert_object(tabla)
		. override_failure_message("`%s` no carga o no es una tabla" % TablaDeSonidos.RUTA)
		. is_not_null()
	)
	return tabla


static func _audio(entrada: EntradaSonora) -> String:
	if entrada == null or not entrada.tiene_sonido():
		return ""
	return entrada.variante(0).resource_path.get_file().get_basename()


func test_cada_producto_del_catalogo_suena_como_la_familia_de_su_ficha() -> void:
	for producto in Catalogo.todos():
		var familias: Array = []
		for familia: EntradaSonora.Sonoridad in FAMILIAS:
			if FAMILIAS[familia].has(producto.nombre):
				familias.append(familia)
		(
			assert_array(familias)
			. override_failure_message("%s no está en una sola familia" % producto.nombre)
			. has_size(1)
		)
		if familias.size() == 1:
			(
				assert_int(Catalogo.sonoridad_de(producto.id))
				. override_failure_message(producto.nombre)
				. is_equal(familias[0])
			)


func test_la_ficha_no_nombra_productos_que_el_catalogo_no_tiene() -> void:
	var nombres: Array[String] = []
	for producto in Catalogo.todos():
		nombres.append(producto.nombre)
	for familia: EntradaSonora.Sonoridad in FAMILIAS:
		for nombre: String in FAMILIAS[familia]:
			assert_array(nombres).contains([nombre])


func test_las_sonoridades_nuevas_van_al_final_y_las_previas_no_se_mueven() -> void:
	var nombres: Array = EntradaSonora.Sonoridad.keys()
	assert_array(nombres.slice(0, SONORIDADES_PREVIAS.size())).is_equal(SONORIDADES_PREVIAS)
	assert_array(nombres.slice(SONORIDADES_PREVIAS.size())).contains_exactly(
		["BOTELLA_VIDRIO", "CAJA_CEREALES", "BALDE_VACIO"]
	)


func test_la_botella_de_vidrio_y_la_caja_de_cereales_alzan_y_dejan_con_lo_suyo() -> void:
	var tabla := _tabla()
	var propios := {
		EntradaSonora.Sonoridad.BOTELLA_VIDRIO: "BotellaVidrio",
		EntradaSonora.Sonoridad.CAJA_CEREALES: "CajaCereales",
	}
	for sonoridad: EntradaSonora.Sonoridad in propios:
		var alzar := tabla.de(EntradaSonora.Evento.OBJETO_AGARRADO, sonoridad)
		var dejar := tabla.de(EntradaSonora.Evento.OBJETO_SOLTADO, sonoridad)
		assert_str(_audio(alzar)).is_equal("SFX_OBJETO_%s_Alzar" % propios[sonoridad])
		assert_str(_audio(dejar)).is_equal("SFX_OBJETO_%s_Dejar" % propios[sonoridad])
		for evento: EntradaSonora.Evento in EntradaSonora.EVENTOS_DE_OBJETO:
			var fila := tabla.de(evento, sonoridad)
			assert_object(fila).is_not_null()
			if fila != null:
				assert_bool(fila.posicional).is_true()
		for evento: EntradaSonora.Evento in [
			EntradaSonora.Evento.PRODUCTO_COLOCADO, EntradaSonora.Evento.UNIDAD_DEVUELTA
		]:
			assert_object(tabla.de(evento, sonoridad).stream).is_same(dejar.stream)
	assert_array(tabla.pares_sin_fila()).is_empty()


func test_el_balde_vacio_alza_y_deja_lo_suyo_y_el_lleno_conserva_lo_suyo() -> void:
	var tabla := _tabla()
	var esperado := {
		EntradaSonora.Sonoridad.BALDE_VACIO:
		["SFX_OBJETO_Balde_AlzarVacio", "SFX_OBJETO_Balde_DejarVacio"],
		EntradaSonora.Sonoridad.BALDE: ["SFX_OBJETO_Balde_Alzar", "SFX_OBJETO_Balde_Dejar"],
	}
	for sonoridad: EntradaSonora.Sonoridad in esperado:
		var alzar := tabla.de(EntradaSonora.Evento.OBJETO_AGARRADO, sonoridad)
		assert_str(_audio(alzar)).is_equal(esperado[sonoridad][0])
		for evento: EntradaSonora.Evento in [
			EntradaSonora.Evento.OBJETO_SOLTADO,
			EntradaSonora.Evento.PRODUCTO_COLOCADO,
			EntradaSonora.Evento.UNIDAD_DEVUELTA,
		]:
			assert_str(_audio(tabla.de(evento, sonoridad))).is_equal(esperado[sonoridad][1])


func test_el_balde_suena_vacio_o_lleno_segun_tenga_agua() -> void:
	assert_int(EntradaSonora.sonoridad_del_balde(true)).is_equal(EntradaSonora.Sonoridad.BALDE)
	assert_int(EntradaSonora.sonoridad_del_balde(false)).is_equal(
		EntradaSonora.Sonoridad.BALDE_VACIO
	)


func test_la_mopa_deja_con_su_dejar_y_la_pasada_limpia_con_su_limpiar() -> void:
	var tabla := _tabla()
	for evento: EntradaSonora.Evento in EntradaSonora.EVENTOS_DE_OBJETO:
		if evento == EntradaSonora.Evento.OBJETO_AGARRADO:
			continue
		var fila := tabla.de(evento, EntradaSonora.Sonoridad.MOPA)
		assert_str(_audio(fila)).is_equal("SFX_OBJETO_Mopa_Dejar")
	assert_str(_audio(tabla.de(EntradaSonora.Evento.PASADA_DADA))).is_equal(
		"SFX_OBJETO_Mopa_Limpiar"
	)
	assert_str(_audio(tabla.de(EntradaSonora.Evento.PASADA_CON_JABON_EQUIVOCADO))).is_equal(
		"SFX_OBJETO_Mopa_Limpiar"
	)


func test_un_mensaje_recibido_tiene_un_solo_audio_sin_alternar() -> void:
	var fila := _tabla().de(EntradaSonora.Evento.MENSAJE_DEL_CELULAR)
	assert_object(fila).is_not_null()
	if fila == null:
		return
	assert_array(fila.variantes).is_empty()
	assert_int(fila.cantidad_de_variantes()).is_equal(1)
	assert_str(_audio(fila)).is_equal("SFX_INTERFAZ_Celular_Mensaje_Recibido")


func test_la_basura_suena_al_sacar_la_bolsa_y_al_desechar_y_no_al_depositarla() -> void:
	var tabla := _tabla()
	var sacar := tabla.de(EntradaSonora.Evento.BOLSA_SACADA)
	var desechar := tabla.de(EntradaSonora.Evento.OBJETO_DESECHADO)
	assert_str(_audio(sacar)).is_equal("SFX_OBJETO_Basura_SacarBolsa")
	assert_str(_audio(desechar)).is_equal("SFX_OBJETO_Basura_Contenedor")
	assert_str(desechar.senal).is_equal("objeto_tirado")
	assert_array(EntradaSonora.Evento.keys()).not_contains("BOLSA_DEPOSITADA")
	for entrada: EntradaSonora in tabla.entradas:
		assert_str(entrada.senal).is_not_equal("bolsa_depositada")
