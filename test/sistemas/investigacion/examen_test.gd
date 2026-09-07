## Examinar: acercar a la cara lo que se lleva, revelar lo que tenía abajo, y no revelarlo dos
## veces.
##
## Igual que `Agarre`, se ejerce sin árbol de escena. Lo que NO se prueba acá es que el jugador
## quede suspendido: `Examen` no conoce al jugador, avisa con `examen_iniciado` y quien se
## suspende es la cáscara. Esa mitad la mira `test/escenas/jugador_test.gd`.
extends GdUnitTestSuite

const Agarre := preload("res://src/sistemas/marco/agarre.gd")
const Examen := preload("res://src/sistemas/investigacion/examen.gd")
const ObjetoDelAlmacen := preload("res://src/dominio/almacen/objeto_del_almacen.gd")
const Revelacion := preload("res://src/dominio/investigacion/revelacion.gd")


func _agarre() -> Node:
	var agarre: Node = auto_free(Agarre.new())
	agarre.punto_de_carga = auto_free(Node3D.new())
	agarre.punto_de_soltado = auto_free(Node3D.new())
	agarre.punto_de_respaldo = auto_free(Node3D.new())
	return agarre


func _examen(agarre: Node) -> Node:
	var examen: Node = auto_free(Examen.new())
	examen.agarre = agarre
	examen.punto_de_examen = auto_free(Node3D.new())
	return examen


func _lata() -> Resource:
	var revelacion := Revelacion.new()
	revelacion.texto = "La fecha de vencimiento está tachada con marcador."
	var objeto := ObjetoDelAlmacen.new()
	objeto.id = &"lata_de_tomate"
	objeto.nombre = "Lata de tomate"
	objeto.revelacion = revelacion
	return objeto


func _puerta() -> Resource:
	var revelacion := Revelacion.new()
	revelacion.texto = "La cerradura es nueva y el marco no."
	var objeto := ObjetoDelAlmacen.new()
	objeto.id = &"puerta"
	objeto.nombre = "Puerta"
	objeto.levantable = false
	objeto.revelacion = revelacion
	return objeto


func _cuerpo() -> RigidBody3D:
	var padre: Node3D = auto_free(Node3D.new())
	var cuerpo := RigidBody3D.new()
	padre.add_child(cuerpo)
	return cuerpo


func test_sin_nada_en_la_mano_no_arranca_ningun_examen() -> void:  # 006-AC9
	var examen := _examen(_agarre())
	assert_bool(examen.iniciar()).is_false()
	assert_bool(examen.esta_examinando()).is_false()


func test_examinar_lo_que_se_lleva_lo_centra_y_avisa() -> void:  # 006-AC9
	var agarre := _agarre()
	var examen := _examen(agarre)
	var cuerpo := _cuerpo()
	agarre.pedir_agarrar(_lata(), cuerpo)
	var iniciados: Array[Node3D] = []
	examen.examen_iniciado.connect(func(nodo: Node3D) -> void: iniciados.append(nodo))
	assert_bool(examen.iniciar()).is_true()
	assert_object(cuerpo.get_parent()).is_same(examen.punto_de_examen)
	assert_vector(cuerpo.position).is_equal(Vector3.ZERO)
	assert_int(iniciados.size()).is_equal(1)
	assert_bool(examen.esta_examinando()).is_true()


func test_el_primer_examen_revela_y_el_segundo_ya_no() -> void:  # 006-AC9
	# El mordisco del spec: el reloj corre igual las dos veces, así que el segundo examen es
	# tiempo puro perdido. El `false` es lo que deja mostrarlo como algo ya leído.
	var agarre := _agarre()
	var examen := _examen(agarre)
	agarre.pedir_agarrar(_lata(), _cuerpo())
	var nuevos: Array[bool] = []
	examen.objeto_revelado.connect(
		func(_datos: Resource, es_nuevo: bool) -> void: nuevos.append(es_nuevo)
	)
	examen.iniciar()
	examen.terminar()
	examen.iniciar()
	assert_array(nuevos).contains_exactly([true, false])


func test_terminar_devuelve_el_objeto_a_la_mano_y_avisa() -> void:  # 006-AC9
	var agarre := _agarre()
	var examen := _examen(agarre)
	var cuerpo := _cuerpo()
	agarre.pedir_agarrar(_lata(), cuerpo)
	examen.iniciar()
	var terminados := [0]
	examen.examen_terminado.connect(func() -> void: terminados[0] += 1)
	examen.terminar()
	assert_bool(examen.esta_examinando()).is_false()
	assert_object(cuerpo.get_parent()).is_same(agarre.punto_de_carga)
	assert_int(terminados[0]).is_equal(1)


func test_rotar_gira_lo_que_se_examina() -> void:  # 006-AC9
	# Girar el objeto es lo que permite leer la etiqueta de atrás, así que el `basis` tiene que
	# cambiar de verdad: una rotación que no se aplica se ve como «el mouse no hace nada».
	var agarre := _agarre()
	var examen := _examen(agarre)
	var cuerpo := _cuerpo()
	agarre.pedir_agarrar(_lata(), cuerpo)
	examen.iniciar()
	var antes := cuerpo.basis
	examen.rotar(Vector2(120.0, 60.0))
	assert_bool(cuerpo.basis.is_equal_approx(antes)).is_false()


func test_rotar_sin_examinar_nada_no_rompe() -> void:  # 006-AC9
	# El mouse se mueve todo el tiempo, también cuando no hay nada en la mano: si esto fallara,
	# el juego se caería al caminar mirando alrededor.
	var examen := _examen(_agarre())
	examen.rotar(Vector2(120.0, 60.0))
	assert_bool(examen.esta_examinando()).is_false()


func test_lo_fijo_enfocado_se_piensa_sin_agarrarlo() -> void:  # 006-AC9
	# La E sobre una puerta no la levanta: revela lo que se nota mirándola y no suspende a
	# nadie, porque no hay nada que rotar. Es el pensamiento, no el examen.
	var agarre := _agarre()
	var examen := _examen(agarre)
	var revelados: Array[Resource] = []
	examen.objeto_revelado.connect(
		func(datos: Resource, _es_nuevo: bool) -> void: revelados.append(datos)
	)
	var iniciados := [0]
	examen.examen_iniciado.connect(func(_nodo: Node3D) -> void: iniciados[0] += 1)
	var puerta := _puerta()
	assert_bool(examen.iniciar(puerta)).is_false()
	assert_array(revelados).contains_exactly([puerta])
	assert_int(iniciados[0]).is_equal(0)
	assert_object(agarre.manos().sostenido()).is_null()
	assert_bool(examen.esta_examinando()).is_false()


func test_lo_que_se_lleva_le_gana_a_lo_enfocado() -> void:  # 006-AC9
	# Con algo en la mano, la E examina lo que se lleva aunque la mira esté sobre otra cosa: si
	# fuera al revés, no habría forma de mirar lo que se levantó sin soltarlo primero.
	var agarre := _agarre()
	var examen := _examen(agarre)
	var lata := _lata()
	agarre.pedir_agarrar(lata, _cuerpo())
	var revelados: Array[Resource] = []
	examen.objeto_revelado.connect(
		func(datos: Resource, _es_nuevo: bool) -> void: revelados.append(datos)
	)
	assert_bool(examen.iniciar(_puerta())).is_true()
	assert_array(revelados).contains_exactly([lata])


func test_examinar_dos_veces_seguidas_sin_terminar_no_reabre_nada() -> void:  # 006-AC9
	var agarre := _agarre()
	var examen := _examen(agarre)
	agarre.pedir_agarrar(_lata(), _cuerpo())
	assert_bool(examen.iniciar()).is_true()
	assert_bool(examen.iniciar()).is_false()


func test_el_clic_mientras_se_examina_devuelve_el_objeto_a_la_mano() -> void:  # 006-AC9
	# Si el clic llegara a `Agarre`, soltaría contra la cámara algo que está pegado a la cara, y
	# este sistema seguiría apuntando a un nodo que ya no está en la mano: girando el mouse
	# rotaría una lata tirada en el piso.
	var agarre := _agarre()
	var examen := _examen(agarre)
	var cuerpo := _cuerpo()
	agarre.pedir_agarrar(_lata(), cuerpo)
	examen.iniciar()
	assert_bool(examen.atajar_el_clic()).is_true()
	assert_bool(examen.esta_examinando()).is_false()
	assert_object(agarre.manos().sostenido()).is_not_null()
	assert_object(cuerpo.get_parent()).is_same(agarre.punto_de_carga)


func test_sin_examinar_nada_el_clic_pasa_de_largo() -> void:  # 006-AC9
	var examen := _examen(_agarre())
	assert_bool(examen.atajar_el_clic()).is_false()


func test_la_e_alterna_entre_examinar_y_volver() -> void:  # 006-AC9
	# Que la misma tecla abra y cierre es un `if` sobre el estado del examen, y ese estado vive
	# acá: si el `if` estuviera en la escena, sería una regla del juego sin test.
	var agarre := _agarre()
	var examen := _examen(agarre)
	agarre.pedir_agarrar(_lata(), _cuerpo())
	examen.alternar()
	assert_bool(examen.esta_examinando()).is_true()
	examen.alternar()
	assert_bool(examen.esta_examinando()).is_false()
