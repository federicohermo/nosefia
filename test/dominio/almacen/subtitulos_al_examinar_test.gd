## La identidad elige el subtítulo; la redacción vive sólo en las tablas y los recursos.
extends GdUnitTestSuite

const UTILES: Dictionary[StringName, String] = {
	&"mopa": "res://src/dominio/almacen/mopa.tres",
	&"balde": "res://src/dominio/almacen/balde.tres",
	&"jabon_azul": "res://src/dominio/almacen/jabon_azul.tres",
	&"jabon_rosa": "res://src/dominio/almacen/jabon_rosa.tres",
	&"jabon_amarillo": "res://src/dominio/almacen/jabon_amarillo.tres",
	&"bolsa_de_basura_1": "res://src/dominio/almacen/bolsa_de_basura_1.tres",
	&"bolsa_de_basura_2": "res://src/dominio/almacen/bolsa_de_basura_2.tres",
	&"bolsa_de_basura_3": "res://src/dominio/almacen/bolsa_de_basura_3.tres",
}

const COLILLA := "res://src/dominio/investigacion/colilla.tres"

## Cuántos renglones tiene el texto de examinar de cada objeto en su ficha de Notion. Los que no
## figuran se ven en un solo renglón.
const DE_DOS_RENGLONES: Array[StringName] = [
	SubtitulosAlExaminar.INODORO,
	SubtitulosAlExaminar.COMPUTADORA,
	SubtitulosAlExaminar.CAJA_REGISTRADORA,
	SubtitulosAlExaminar.LECTOR,
	SubtitulosAlExaminar.ENTRADA_PRINCIPAL,
	SubtitulosAlExaminar.PUERTA_DEL_JEFE,
	&"jabon_azul",
	&"jabon_rosa",
	&"jabon_amarillo",
	SubtitulosAlExaminar.CAJA_DEL_PROVEEDOR,
]

## Y los que se ven en tres.
const DE_TRES_RENGLONES: Array[StringName] = [SubtitulosAlExaminar.CAJA_DE_MADERA]


func _textos_fijos_por_id() -> Dictionary:
	var textos := SubtitulosAlExaminar.DE_LO_DEMAS.duplicate()
	for nota: NotaPegada.Id in NotaPegada.Id.values():
		textos[SubtitulosAlExaminar.id_de_la_nota(nota)] = SubtitulosAlExaminar.DE_LAS_NOTAS[nota]
	for tacho: TareaDeLaBasura.Tacho in TareaDeLaBasura.Tacho.values():
		textos[SubtitulosAlExaminar.id_del_tacho(tacho)] = SubtitulosAlExaminar.DE_LOS_TACHOS[tacho]
	return textos


func test_cada_id_del_catalogo_tiene_un_subtitulo() -> void:  # AC-SUB-011
	assert_array(SubtitulosAlExaminar.DE_LOS_PRODUCTOS.keys()).contains_exactly_in_any_order(
		Producto.Id.values()
	)
	for id: Producto.Id in Producto.Id.values():
		var plantilla: String = SubtitulosAlExaminar.DE_LOS_PRODUCTOS[id]
		assert_str(plantilla).override_failure_message("%s no tiene texto" % id).is_not_empty()
		assert_str(SubtitulosAlExaminar.de_producto(id)).is_equal(
			plantilla % Catalogo.de(id).nombre
		)


func test_cada_unidad_elige_el_subtitulo_de_su_producto() -> void:  # AC-SUB-011
	for producto: Producto in Catalogo.todos():
		var unidad := UnidadDeProducto.new(producto)
		assert_int(unidad.producto.id).is_equal(producto.id)
		assert_str(unidad.texto_al_examinar()).is_equal(
			SubtitulosAlExaminar.de_producto(producto.id)
		)


func test_cada_util_y_bolsa_conserva_su_id_y_su_subtitulo() -> void:  # AC-SUB-012
	for id: StringName in UTILES:
		var objeto := load(UTILES[id]) as ObjetoDelAlmacen
		assert_object(objeto).override_failure_message("%s no carga" % id).is_not_null()
		assert_str(String(objeto.id)).is_equal(String(id))
		assert_str(objeto.subtitulo).is_not_empty()
		assert_str(objeto.texto_al_examinar()).is_equal(objeto.subtitulo)


func test_cada_id_fijo_elige_su_subtitulo() -> void:  # AC-SUB-013
	var textos := _textos_fijos_por_id()
	assert_bool(textos.has(SubtitulosAlExaminar.ROUTER)).is_true()
	for id: StringName in textos:
		assert_str(textos[id]).override_failure_message("%s no tiene texto" % id).is_not_empty()
		assert_str(SubtitulosAlExaminar.de_lo_fijo(id)).is_equal(textos[id])


func test_las_cajas_del_proveedor_dicen_su_texto_y_no_el_de_un_producto() -> void:  # AC-SUB-050
	var cajas: Array[StringName] = [
		SubtitulosAlExaminar.CAJA_DEL_PROVEEDOR, SubtitulosAlExaminar.CAJA_DE_MADERA
	]
	var vistos: Array[String] = []
	for id in cajas:
		var texto := SubtitulosAlExaminar.de_lo_fijo(id)
		assert_str(texto).override_failure_message("%s no tiene texto" % id).is_not_empty()
		assert_bool(texto in vistos).is_false()
		vistos.append(texto)
		assert_int(texto.split("\n").size()).is_equal(_renglones_de_la_ficha(id))
	for producto: Producto in Catalogo.todos():
		assert_str(SubtitulosAlExaminar.de_producto(producto.id)).is_not_equal(vistos[0])
		assert_str(SubtitulosAlExaminar.de_producto(producto.id)).is_not_equal(vistos[1])


func test_lo_que_no_esta_en_la_tabla_no_dice_nada() -> void:  # AC-SUB-013
	for id: StringName in [&"", &"ventanilla", &"puerta_de_heladera", &"gondola", &"mancha"]:
		assert_str(SubtitulosAlExaminar.de_lo_fijo(id)).is_empty()


func test_el_texto_no_es_la_revelacion() -> void:  # AC-SUB-010
	var mopa := load(UTILES[&"mopa"]) as ObjetoDelAlmacen
	assert_bool(mopa.tiene_revelacion()).is_true()
	assert_str(mopa.texto_al_examinar()).not_contains(mopa.revelacion.texto)
	assert_str(mopa.texto_al_examinar()).is_equal(mopa.subtitulo)


func _renglones_de_la_ficha(id: StringName) -> int:
	if id in DE_TRES_RENGLONES:
		return 3
	if id in DE_DOS_RENGLONES:
		return 2
	var de_dos: Array[StringName] = [
		SubtitulosAlExaminar.id_de_la_nota(NotaPegada.Id.INSTRUCCIONES_DE_LIMPIEZA),
		SubtitulosAlExaminar.id_de_la_nota(NotaPegada.Id.JABONES_Y_MANCHAS),
		SubtitulosAlExaminar.id_de_la_nota(NotaPegada.Id.LOCAL_ORDENADO),
		SubtitulosAlExaminar.id_del_tacho(TareaDeLaBasura.Tacho.ESCRITORIO),
		SubtitulosAlExaminar.id_del_tacho(TareaDeLaBasura.Tacho.BANO),
	]
	return 2 if id in de_dos else 1


func _textos_de_examinar() -> Dictionary:
	var textos := _textos_fijos_por_id()
	for id: StringName in UTILES:
		textos[id] = (load(UTILES[id]) as ObjetoDelAlmacen).texto_al_examinar()
	textos[&"colilla"] = (load(COLILLA) as ObjetoDelAlmacen).texto_al_examinar()
	for producto: Producto in Catalogo.todos():
		textos[StringName(producto.nombre)] = SubtitulosAlExaminar.de_producto(producto.id)
	return textos


func test_cada_texto_de_examinar_se_corta_en_los_renglones_de_la_ficha() -> void:  # AC-SUB-031
	var textos := _textos_de_examinar()
	for id: StringName in textos:
		var renglones := (textos[id] as String).split("\n")
		(
			assert_int(renglones.size())
			. override_failure_message("%s: renglones distintos de los de la ficha" % id)
			. is_equal(_renglones_de_la_ficha(id))
		)
		for renglon in renglones:
			assert_str(renglon.strip_edges()).is_not_empty()
