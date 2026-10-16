extends GdUnitTestSuite

const RUTA := "res://assets/dialogos/compradores_jornada_2.tres"
const FEDE: Array[String] = [
	"Hola, ¿qué tal? Qué tarde se hizo… me alegra que todavía esté abierto el negocio.",
	(
		"Salí tardísimo del trabajo y no tuve un buen día. No vendimos suficiente. "
		+ "Por eso busco un momento de tranquilidad y placer, ¿vos entendes?"
	),
	"Quiero una botella de jabón Poético, una lata de papitas Progres y unos preservativos Duronga."
]
const FINAL_FEDE: Array[String] = [
	(
		"¡Guau, salió la colección de los productos del Chiqui Tapia! No me había dado cuenta. "
		+ "Ese señor es mi ídolo. Siempre me da los mejores tips."
	),
	"Gracias, compañero. Cuando quieras podes venir a casa y los probamos juntos."
]
const MIA: Array[String] = [
	"Hola… ¿me darías un vino Terminator, un Fernet God y una cajita de Actroncito?"
]
const FINAL_MIA: Array[String] = [
	"Zzzzzz.zzzzz.zzzzz",
	"Perdon, me quedé dormida... ¿En dónde estaba?",
	"Ah sí, gracias… Espero que esto me ayude a dormir mejor…"
]


func _guion() -> DialogosDeCompradores:
	var guion := load(RUTA) as DialogosDeCompradores
	assert_object(guion).is_not_null()
	return guion


func _entradas(dialogo: Dialogo) -> PackedStringArray:
	var entradas := PackedStringArray()
	while not dialogo.terminado():
		entradas.append(dialogo.entrada_actual())
		dialogo.avanzar()
	return entradas


func _sin_color(entradas: PackedStringArray) -> PackedStringArray:
	var texto := PackedStringArray()
	for entrada: String in entradas:
		texto.append(entrada.replace("[color=#e4f850]", "").replace("[/color]", ""))
	return texto


func test_los_nueve_guiones_productivos_conservan_sus_cuatro_bloques() -> void:  # AC-CTR-058
	var guion := _guion()
	if guion == null:
		return
	(
		assert_array(
			Array(_sin_color(_entradas(guion.inicial(DialogosDeCompradores.Personaje.FEDE))))
		)
		. is_equal(Array(FEDE))
	)
	assert_array(Array(_entradas(guion.despedida(DialogosDeCompradores.Personaje.FEDE)))).is_equal(
		Array(FINAL_FEDE)
	)
	(
		assert_array(
			Array(_sin_color(_entradas(guion.inicial(DialogosDeCompradores.Personaje.MIA))))
		)
		. is_equal(Array(MIA))
	)
	assert_array(Array(_entradas(guion.despedida(DialogosDeCompradores.Personaje.MIA)))).is_equal(
		Array(FINAL_MIA)
	)


# AC-CTR-059, AC-CTR-036
func test_los_seis_productos_se_destacan_solo_en_amarillo() -> void:
	var guion := _guion()
	if guion == null:
		return
	for personaje: int in [
		DialogosDeCompradores.Personaje.FEDE, DialogosDeCompradores.Personaje.MIA
	]:
		var entradas := _entradas(guion.inicial(personaje))
		assert_array(Array(entradas)).is_not_empty()
		if entradas.is_empty():
			continue
		var pedido := entradas[-1]
		var nombres := (
			["Poético", "Progres", "Duronga"]
			if personaje == DialogosDeCompradores.Personaje.FEDE
			else ["Terminator", "Fernet God", "Actroncito"]
		)
		assert_int(pedido.count("[color=#e4f850]")).is_equal(3)
		assert_int(pedido.count("[/color]")).is_equal(3)
		for nombre: String in nombres:
			assert_str(pedido).contains("[color=#e4f850]%s[/color]" % nombre)
		for texto: String in entradas:
			assert_str(texto).not_contains("[b]").not_contains("[url").not_contains("c99cf4")
	var primero := load("res://assets/dialogos/compradores_jornada_1.tres") as DialogosDeCompradores
	assert_str(primero.inicial(DialogosDeCompradores.Personaje.TIN).entrada_actual()).contains(
		"[b]"
	)


func test_cada_atencion_tiene_cursor_independiente_del_recurso_compartido() -> void:  # AC-CTR-063
	var guion := _guion()
	if guion == null:
		return
	var izquierda := guion.inicial(DialogosDeCompradores.Personaje.FEDE)
	var derecha := guion.inicial(DialogosDeCompradores.Personaje.FEDE)
	assert_object(izquierda).is_not_same(derecha)
	izquierda.avanzar()
	assert_str(derecha.entrada_actual()).is_equal(FEDE[0])
	assert_str(izquierda.entrada_actual()).is_equal(FEDE[1])
	assert_str(guion.inicial(DialogosDeCompradores.Personaje.FEDE).entrada_actual()).is_equal(
		FEDE[0]
	)


# AC-CTR-001 AC-CTR-057 AC-CTR-041
func test_la_seleccion_productiva_de_jornada_dos_usa_su_fabrica_y_guion() -> void:
	var compradores := Compradores.de_la_jornada(2)
	assert_int(compradores.size()).is_equal(2)
	assert_str(compradores[0].nombre()).is_equal("Fede")
	assert_str(compradores[1].nombre()).is_equal("Mía")
	var guion := _guion()
	for comprador: Comprador in compradores:
		assert_object(comprador.dialogos).is_same(guion)
	var nuevos := Compradores.de_la_jornada(2)
	assert_object(nuevos[0]).is_not_same(compradores[0])
	assert_object(nuevos[0].pedido()).is_not_same(compradores[0].pedido())
