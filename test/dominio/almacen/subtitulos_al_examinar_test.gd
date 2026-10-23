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
	assert_int(textos.size()).is_equal(19)
	for id: StringName in textos:
		assert_str(textos[id]).override_failure_message("%s no tiene texto" % id).is_not_empty()
		assert_str(SubtitulosAlExaminar.de_lo_fijo(id)).is_equal(textos[id])


func test_lo_que_no_esta_en_la_tabla_no_dice_nada() -> void:  # AC-SUB-013
	for id: StringName in [&"", &"ventanilla", &"puerta_de_heladera", &"gondola", &"mancha"]:
		assert_str(SubtitulosAlExaminar.de_lo_fijo(id)).is_empty()


func test_el_texto_no_es_la_revelacion() -> void:  # AC-SUB-010
	var mopa := load(UTILES[&"mopa"]) as ObjetoDelAlmacen
	assert_bool(mopa.tiene_revelacion()).is_true()
	assert_str(mopa.texto_al_examinar()).not_contains(mopa.revelacion.texto)
	assert_str(mopa.texto_al_examinar()).is_equal(mopa.subtitulo)
