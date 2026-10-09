func test_solo_las_bolsas_y_los_tickets_se_tiran_sin_llamado() -> void:  # AC-CLN-050
	for id: StringName in ReglasDeLaBasura.ids_de_las_bolsas():
		var bolsa := ObjetoDelAlmacen.new()
		bolsa.id = id
		assert_bool(ReglasDelCierre.se_tira_sin_llamado(bolsa)).is_true()
	var productos: Array[Producto] = [Catalogo.de(Producto.Id.ACTRONCITO)]
	assert_bool(ReglasDelCierre.se_tira_sin_llamado(Ticket.new(productos))).is_true()


func test_unidad_utiles_y_datos_ausentes_no_son_exentos() -> void:  # AC-CLN-050
	assert_bool(ReglasDelCierre.se_tira_sin_llamado(null)).is_false()
	var unidad := UnidadDeProducto.new(Catalogo.de(Producto.Id.ACTRONCITO))
	assert_bool(ReglasDelCierre.se_tira_sin_llamado(unidad)).is_false()
	var ids: Array[StringName] = [ReglasDeLaLimpieza.ID_DE_LA_MOPA, ReglasDeLaLimpieza.ID_DEL_BALDE]
	ids.append_array(ReglasDeLaLimpieza.JABONES.keys())
	for id: StringName in ids:
		var util := ObjetoDelAlmacen.new()
		util.id = id
		assert_bool(ReglasDelCierre.se_tira_sin_llamado(util)).is_false()
