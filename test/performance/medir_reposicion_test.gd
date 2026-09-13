extends GdUnitTestSuite

const Medicion := preload("res://test/performance/medir_reposicion.gd")


func test_el_percentil_no_confunde_un_pico_con_la_mediana() -> void:  # 042-AC6
	var valores: Array[float] = [90, 2, 3, 1, 4]
	assert_float(Medicion.percentil(valores, 0.5)).is_equal(3.0)
	assert_float(Medicion.percentil(valores, 0.95)).is_equal(90.0)
	assert_float(valores[0]).is_equal(90.0)


func test_la_carga_conserva_cantidades_y_colisiones_reales() -> void:  # 042-AC6
	var medicion: Node3D = auto_free(Medicion.new())
	var modelo := BoxMesh.new()
	var forma := ConvexPolygonShape3D.new()
	forma.points = modelo.get_faces()
	medicion.modelos.assign([modelo, modelo])
	medicion.formas.assign([forma, forma])
	for cantidad in Medicion.CANTIDADES:
		for escenario: Medicion.Escenario in Medicion.Escenario.values():
			var lote: Node3D = auto_free(medicion.crear(cantidad, escenario))
			if escenario == Medicion.Escenario.ESTANTE:
				assert_int(lote.get_child_count()).is_equal(2)
				assert_int(lote.get_child(0).multimesh.instance_count).is_equal(cantidad / 2)
				assert_int(lote.get_child(1).multimesh.instance_count).is_equal(cantidad / 2)
			else:
				assert_int(lote.get_child_count()).is_equal(cantidad)
				assert_object(lote.get_child(0).get_node("Forma").shape).is_same(forma)
				assert_bool(lote.get_child(0).continuous_cd).is_true()
