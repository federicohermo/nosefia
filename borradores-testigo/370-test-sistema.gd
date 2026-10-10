

class BolsaDoble:
	extends Node3D
	var datos := ObjetoDelAlmacen.new()


func test_sacar_entrega_el_mismo_cuerpo_sin_depositar_y_avisa_una_vez() -> void:  # AC-CLN-053
	var recolector := _recolector()
	for numero in range(1, 4):
		var cuerpo: BolsaDoble = auto_free(BolsaDoble.new())
		cuerpo.datos.id = ReglasDeLaBasura.id_de_la_bolsa(numero)
		recolector.bolsas.append(cuerpo)
	var sacadas: Array[TareaDeLaBasura.Tacho] = []
	recolector.bolsa_sacada.connect(
		func(tacho: TareaDeLaBasura.Tacho) -> void: sacadas.append(tacho)
	)
	var cuerpo := recolector.bolsas[0]
	assert_bool(recolector.sacar_bolsa(TareaDeLaBasura.Tacho.LOCAL)).is_true()
	assert_object(recolector.agarre.cuerpo_sostenido()).is_same(cuerpo)
	assert_array(sacadas).contains_exactly([TareaDeLaBasura.Tacho.LOCAL])
	assert_int(recolector.tarea().depositadas()).is_zero()
	assert_bool(recolector.sacar_bolsa(TareaDeLaBasura.Tacho.ESCRITORIO)).is_false()
	assert_bool(recolector.tarea().tiene_bolsa(TareaDeLaBasura.Tacho.ESCRITORIO)).is_true()
	recolector.agarre.entregar()
	assert_bool(recolector.sacar_bolsa(TareaDeLaBasura.Tacho.LOCAL)).is_false()
	assert_array(sacadas).has_size(1)
	assert_float(_turno.tiempo_restante()).is_equal(Reglas.DURACION_DEL_TURNO)
