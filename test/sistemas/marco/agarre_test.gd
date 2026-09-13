## `Agarre` se ejerce con `Agarre.new()` y sin árbol de escena, y eso es una decisión medida.
##
## Está en el `research.md` del 006: `global_transform` fuera del árbol tira un error del motor y
## devuelve la identidad, así que un sistema que colocara con eso pasaría el test **por
## casualidad**. Reparentar, emitir señales y `freeze` sí funcionan sin árbol — por eso `Agarre`
## reparenta y escribe `position` local, y por eso esto se puede probar.
##
## Las señales se cuentan con un cierre sobre un `Array` y no con `assert_signal`: lo que hay que
## afirmar es «una vez y no dos», y un contador lo dice sin await.
extends GdUnitTestSuite

const Agarre := preload("res://src/sistemas/marco/agarre.gd")
const Manos := preload("res://src/dominio/almacen/manos.gd")
const ObjetoDelAlmacen := preload("res://src/dominio/almacen/objeto_del_almacen.gd")


func _cableado() -> Node:
	# Los tres puntos son cableado de la escena, así que acá se arman a mano: el test tiene que
	# poder decir dónde quedó el objeto sin depender de `jugador.tscn`.
	var agarre: Node = auto_free(Agarre.new())
	agarre.punto_de_carga = auto_free(Node3D.new())
	agarre.punto_de_soltado = auto_free(Node3D.new())
	agarre.punto_de_respaldo = auto_free(Node3D.new())
	return agarre


func _lata() -> Resource:
	var objeto := ObjetoDelAlmacen.new()
	objeto.id = &"lata_de_tomate"
	objeto.nombre = "Lata de tomate"
	return objeto


func _cuerpo() -> RigidBody3D:
	# Un `RigidBody3D` y no un `Node3D` pelado a propósito: lo que se agarra en el juego simula
	# física, y congelarla al levantarlo es parte de lo que este sistema traduce.
	#
	# Sólo el padre entra en `auto_free`: el cuerpo termina colgado de él o de uno de los tres
	# puntos, que también se liberan, y registrar los dos sería liberarlo dos veces.
	var padre: Node3D = auto_free(Node3D.new())
	var cuerpo := RigidBody3D.new()
	padre.add_child(cuerpo)
	cuerpo.position = Vector3(3.0, 0.0, -2.0)
	return cuerpo


func test_agarrar_cuelga_el_objeto_del_punto_de_carga() -> void:  # 006-AC7
	var agarre := _cableado()
	var cuerpo := _cuerpo()
	var avisos: Array[Node3D] = []
	agarre.objeto_agarrado.connect(func(nodo: Node3D) -> void: avisos.append(nodo))
	assert_bool(agarre.pedir_agarrar(_lata(), cuerpo)).is_true()
	assert_object(cuerpo.get_parent()).is_same(agarre.punto_de_carga)
	assert_vector(cuerpo.position).is_equal(Vector3.ZERO)
	assert_int(avisos.size()).is_equal(1)


func test_agarrar_congela_la_fisica_de_lo_que_se_lleva() -> void:  # 006-AC7
	# Sin esto el objeto se cae de la mano en el mismo cuadro en que se lo levanta, y el
	# síntoma —«no se puede agarrar nada»— no nombra a la física.
	var agarre := _cableado()
	var cuerpo := _cuerpo()
	agarre.pedir_agarrar(_lata(), cuerpo)
	assert_bool(cuerpo.freeze).is_true()


func test_con_las_manos_llenas_se_rechaza_y_no_se_mueve_nada() -> void:  # 006-AC7
	var agarre := _cableado()
	agarre.pedir_agarrar(_lata(), _cuerpo())
	var otro := _cuerpo()
	var padre_de_antes := otro.get_parent()
	var motivos: Array[int] = []
	agarre.agarre_rechazado.connect(func(motivo: int) -> void: motivos.append(motivo))
	assert_bool(agarre.pedir_agarrar(_lata(), otro)).is_false()
	assert_array(motivos).contains_exactly([Manos.Rechazo.MANOS_LLENAS])
	assert_object(otro.get_parent()).is_same(padre_de_antes)


func test_lo_sostenido_se_puede_mover_a_otro_punto_sin_soltarlo() -> void:  # 006-AC7
	# Es lo que usa `Examen` para acercar a la cara lo que se lleva. Quien reparenta es siempre
	# quien tiene el nodo: si `Examen` lo hiciera por su cuenta, habría dos piezas moviendo el
	# mismo objeto y ninguna de las dos sabría dónde lo dejó la otra.
	var agarre := _cableado()
	var cuerpo := _cuerpo()
	var otro_lado: Node3D = auto_free(Node3D.new())
	agarre.pedir_agarrar(_lata(), cuerpo)
	assert_object(agarre.mover_lo_sostenido(otro_lado)).is_same(cuerpo)
	assert_object(cuerpo.get_parent()).is_same(otro_lado)
	assert_object(agarre.manos().sostenido()).is_not_null()
	assert_object(agarre.devolver_a_la_mano()).is_same(cuerpo)
	assert_object(cuerpo.get_parent()).is_same(agarre.punto_de_carga)


func test_con_las_manos_vacias_no_hay_nada_que_mover() -> void:  # 006-AC7
	var agarre := _cableado()
	assert_object(agarre.mover_lo_sostenido(auto_free(Node3D.new()))).is_null()
	assert_object(agarre.devolver_a_la_mano()).is_null()


func test_soltar_al_frente_lleva_el_objeto_al_punto_de_soltado() -> void:  # 006-AC8
	var agarre := _cableado()
	var cuerpo := _cuerpo()
	agarre.pedir_agarrar(_lata(), cuerpo)
	var avisos: Array[Node3D] = []
	agarre.objeto_soltado.connect(func(nodo: Node3D) -> void: avisos.append(nodo))
	assert_object(agarre.soltar(true)).is_same(cuerpo)
	assert_object(cuerpo.get_parent()).is_same(agarre.punto_de_soltado)
	assert_vector(cuerpo.position).is_equal(Vector3.ZERO)
	assert_bool(cuerpo.freeze).is_false()
	assert_int(avisos.size()).is_equal(1)
	assert_object(agarre.manos().sostenido()).is_null()


func test_soltar_sin_lugar_adelante_lo_deja_en_el_respaldo() -> void:  # 006-AC8
	# El respaldo está a los pies del jugador: es donde va lo que se suelta cuando adelante hay
	# una pared. Sin él, soltar contra una estantería empuja el objeto adentro del mundo.
	var agarre := _cableado()
	var cuerpo := _cuerpo()
	agarre.pedir_agarrar(_lata(), cuerpo)
	agarre.soltar(false)
	assert_object(cuerpo.get_parent()).is_same(agarre.punto_de_respaldo)


func test_vaciar_las_manos_vacias_no_avisa_nada() -> void:  # 006-AC8
	# Lo llaman el cierre de la jornada y la suspensión del jugador, que pueden pasar con las
	# manos ya vacías: un aviso ahí haría que el HUD anuncie que se soltó algo que no existía.
	var agarre := _cableado()
	var avisos: Array[Node3D] = []
	agarre.objeto_soltado.connect(func(nodo: Node3D) -> void: avisos.append(nodo))
	agarre.vaciar_las_manos()
	assert_int(avisos.size()).is_equal(0)


func test_vaciar_las_manos_llenas_deja_lo_que_habia_en_el_respaldo() -> void:  # 006-AC8
	var agarre := _cableado()
	var cuerpo := _cuerpo()
	agarre.pedir_agarrar(_lata(), cuerpo)
	agarre.vaciar_las_manos()
	assert_object(cuerpo.get_parent()).is_same(agarre.punto_de_respaldo)
	assert_object(agarre.manos().sostenido()).is_null()


func test_el_clic_agarra_y_despues_suelta() -> void:  # 006-AC7
	# El mismo botón hace las dos cosas, y cuál de las dos toca NO lo decide la escena: es un
	# `if` sobre el estado de las manos, y las manos viven abajo.
	var agarre := _cableado()
	var cuerpo := _cuerpo()
	agarre.alternar(_lata(), cuerpo)
	assert_object(agarre.manos().sostenido()).is_not_null()
	agarre.alternar(null, null)
	assert_object(agarre.manos().sostenido()).is_null()
	assert_object(cuerpo.get_parent()).is_same(agarre.punto_de_soltado)


func test_agarrar_suspende_y_soltar_restaura_colisiones() -> void:  # 040-AC1
	var agarre := _cableado()
	var cuerpo := _cuerpo()
	cuerpo.collision_layer = 13
	cuerpo.collision_mask = 22
	agarre.pedir_agarrar(_lata(), cuerpo)
	assert_int(cuerpo.collision_layer).is_zero()
	assert_int(cuerpo.collision_mask).is_zero()
	agarre.soltar(true)
	assert_int(cuerpo.collision_layer).is_equal(13)
	assert_int(cuerpo.collision_mask).is_equal(22)


func test_dos_agarres_con_examen_restauran_sus_colisiones() -> void:  # 040-AC2
	var agarre := _cableado()
	var cuerpo := _cuerpo()
	var examen: Examen = auto_free(Examen.new())
	examen.agarre = agarre
	examen.punto_de_examen = auto_free(Node3D.new())
	for capa: int in [5, 18]:
		cuerpo.collision_layer = capa
		cuerpo.collision_mask = capa + 2
		assert_bool(agarre.pedir_agarrar(_lata(), cuerpo)).is_true()
		assert_bool(examen.iniciar()).is_true()
		assert_int(cuerpo.collision_layer).is_zero()
		assert_int(cuerpo.collision_mask).is_zero()
		examen.terminar()
		assert_int(cuerpo.collision_layer).is_zero()
		assert_int(cuerpo.collision_mask).is_zero()
		agarre.soltar(true)
		assert_int(cuerpo.collision_layer).is_equal(capa)
		assert_int(cuerpo.collision_mask).is_equal(capa + 2)


func test_vaciar_restaura_colisiones() -> void:  # 040-AC3
	var agarre := _cableado()
	var cuerpo := _cuerpo()
	cuerpo.collision_layer = 9
	cuerpo.collision_mask = 12
	agarre.pedir_agarrar(_lata(), cuerpo)
	agarre.vaciar_las_manos()
	assert_int(cuerpo.collision_layer).is_equal(9)
	assert_int(cuerpo.collision_mask).is_equal(12)


func test_agarrar_y_soltar_un_nodo_sin_colisiones() -> void:  # 040-AC4
	var agarre := _cableado()
	var nodo := Node3D.new()
	assert_bool(agarre.pedir_agarrar(_lata(), nodo)).is_true()
	assert_object(agarre.soltar(true)).is_same(nodo)
	assert_object(nodo.get_parent()).is_same(agarre.punto_de_soltado)
