## Examinar: acercar a la cara lo que se lleva o lo que se mira, revelar lo que tenía abajo, y no
## revelarlo dos veces.
##
## Igual que `Agarre`, se ejerce sin árbol de escena. Lo que NO se prueba acá es que el jugador
## quede suspendido: `Examen` no conoce al jugador, avisa con `examen_iniciado` y quien se
## suspende es la cáscara. Esa mitad la mira `test/escenas/jugador_test.gd`.
extends GdUnitTestSuite

const Agarre := preload("res://src/sistemas/marco/agarre.gd")
const Examen := preload("res://src/sistemas/investigacion/examen.gd")
const ObjetoDelAlmacen := preload("res://src/dominio/almacen/objeto_del_almacen.gd")
const ReglasDeLosObjetos := preload("res://src/dominio/almacen/reglas_de_los_objetos.gd")
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


## Una caja del depósito con su malla, centrada en el origen como las del almacén. Los dos lados
## son los de las dos cajas que el almacén usa, medidos sobre su malla.
func _caja(lado: float) -> RigidBody3D:
	var cuerpo := _cuerpo()
	var malla := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = Vector3.ONE * lado
	malla.mesh = caja
	cuerpo.add_child(malla)
	return cuerpo


func _caja_grande() -> RigidBody3D:
	return _caja(0.607)


func _caja_chica() -> RigidBody3D:
	return _caja(0.4)


## Examina lo que se lleva y devuelve a qué distancia del ojo quedó.
func _distancia_examinando(examen: Node) -> float:
	examen.iniciar()
	return examen.punto_de_examen.position.length()


func test_la_caja_grande_se_examina_mas_lejos_que_la_chica() -> void:
	var distancias: Array[float] = []
	for caja: RigidBody3D in [_caja_chica(), _caja_grande()]:
		var agarre := _agarre()
		var examen := _examen(agarre)
		agarre.pedir_agarrar(_lata(), caja)
		var distancia := _distancia_examinando(examen)
		var radio := Vector3.ONE.length() * (caja.get_child(0).mesh as BoxMesh).size.x / 2.0
		assert_float(distancia).is_equal_approx(
			ReglasDeLosObjetos.distancia_de_examen(radio), 0.001
		)
		distancias.append(distancia)
	assert_float(distancias[0]).is_greater(ReglasDeLosObjetos.DISTANCIA_DE_EXAMEN)
	assert_float(distancias[1]).is_greater(distancias[0])


func test_lo_chico_se_examina_a_la_distancia_de_siempre() -> void:
	var agarre := _agarre()
	var examen := _examen(agarre)
	agarre.pedir_agarrar(_lata(), _caja(0.12))
	assert_float(_distancia_examinando(examen)).is_equal_approx(
		ReglasDeLosObjetos.DISTANCIA_DE_EXAMEN, 0.001
	)


func test_examinar_de_nuevo_la_misma_caja_da_la_misma_distancia() -> void:
	var agarre := _agarre()
	var examen := _examen(agarre)
	agarre.pedir_agarrar(_lata(), _caja_grande())
	var primera := _distancia_examinando(examen)
	examen.terminar()
	assert_float(_distancia_examinando(examen)).is_equal(primera)


func test_las_dos_cajas_vuelven_del_examen_a_la_cintura() -> void:
	# Vuelven al punto de donde salieron, que no es la mano derecha.
	for caja: RigidBody3D in [_caja_chica(), _caja_grande()]:
		var agarre := _agarre()
		var examen := _examen(agarre)
		var cintura: Node3D = auto_free(Node3D.new())
		agarre.pedir_agarrar(_lata(), caja)
		agarre.mover_lo_sostenido(cintura)
		examen.iniciar()
		examen.arrastrar(Vector2(120.0, 60.0), true)
		examen.terminar()
		assert_object(caja.get_parent()).is_same(cintura)
		assert_bool(caja.basis.is_equal_approx(Basis.IDENTITY)).is_true()
		agarre.soltar(true)


func test_sin_nada_en_la_mano_no_arranca_ningun_examen() -> void:
	var examen := _examen(_agarre())
	assert_bool(examen.iniciar()).is_false()
	assert_bool(examen.esta_examinando()).is_false()


func test_examinar_lo_que_se_lleva_lo_centra_y_avisa() -> void:
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


func test_el_primer_examen_revela_y_el_segundo_ya_no() -> void:
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


func test_terminar_devuelve_el_objeto_a_la_mano_y_avisa() -> void:
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


func test_el_mouse_gira_lo_examinado_solo_arrastrando() -> void:  # AC-INV-023
	var agarre := _agarre()
	var examen := _examen(agarre)
	var cuerpo := _cuerpo()
	agarre.pedir_agarrar(_lata(), cuerpo)
	examen.iniciar()
	var antes := cuerpo.basis
	examen.arrastrar(Vector2(120.0, 60.0), false)
	assert_bool(cuerpo.basis.is_equal_approx(antes)).is_true()
	examen.arrastrar(Vector2(120.0, 60.0), true)
	assert_bool(cuerpo.basis.is_equal_approx(antes)).is_false()


func test_las_teclas_giran_lo_examinado_sobre_los_dos_ejes() -> void:  # AC-INV-022
	var agarre := _agarre()
	var examen := _examen(agarre)
	var cuerpo := _cuerpo()
	agarre.pedir_agarrar(_lata(), cuerpo)
	examen.iniciar()
	var antes := cuerpo.basis
	examen.girar(Vector2.ZERO, 0.5)
	assert_bool(cuerpo.basis.is_equal_approx(antes)).is_true()
	examen.girar(Vector2.RIGHT, 0.5)
	var giro := ReglasDeLosObjetos.giro_del_examen(Vector2.RIGHT, 0.5)
	assert_bool(cuerpo.basis.is_equal_approx(antes.rotated(Vector3.UP, -giro.x))).is_true()
	var de_costado := cuerpo.basis
	examen.girar(Vector2(0.0, 1.0), 0.5)
	assert_bool(cuerpo.basis.is_equal_approx(de_costado.rotated(Vector3.RIGHT, giro.x))).is_true()


func test_girar_sin_examinar_nada_no_rompe() -> void:
	# El mouse y las teclas se mueven todo el tiempo, también caminando.
	var examen := _examen(_agarre())
	examen.arrastrar(Vector2(120.0, 60.0), true)
	examen.girar(Vector2.RIGHT, 0.5)
	assert_bool(examen.esta_examinando()).is_false()


func test_lo_fijo_enfocado_se_piensa_sin_agarrarlo() -> void:
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


func test_lo_que_se_lleva_le_gana_a_lo_enfocado() -> void:  # AC-INV-020
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
	var otro := _cuerpo()
	var padre := otro.get_parent()
	assert_bool(examen.iniciar(_puerta())).is_true()
	assert_array(revelados).contains_exactly([lata])
	examen.terminar()
	assert_bool(examen.iniciar(_lata(), otro)).is_true()
	assert_object(otro.get_parent()).is_same(padre)


func test_examinar_dos_veces_seguidas_sin_terminar_no_reabre_nada() -> void:
	var agarre := _agarre()
	var examen := _examen(agarre)
	agarre.pedir_agarrar(_lata(), _cuerpo())
	assert_bool(examen.iniciar()).is_true()
	assert_bool(examen.iniciar()).is_false()


func test_el_clic_mientras_se_examina_no_cierra_ni_suelta() -> void:  # AC-INV-024
	var agarre := _agarre()
	var examen := _examen(agarre)
	var cuerpo := _cuerpo()
	var lata := _lata()
	agarre.pedir_agarrar(lata, cuerpo)
	examen.iniciar()
	assert_bool(examen.atajar_el_clic()).is_true()
	assert_bool(examen.esta_examinando()).is_true()
	assert_object(agarre.manos().sostenido()).is_same(lata)
	assert_object(cuerpo.get_parent()).is_same(examen.punto_de_examen)
	examen.alternar()
	assert_bool(examen.esta_examinando()).is_false()


func test_sin_examinar_nada_el_clic_pasa_de_largo() -> void:
	var examen := _examen(_agarre())
	assert_bool(examen.atajar_el_clic()).is_false()


func test_la_e_alterna_entre_examinar_y_volver() -> void:
	# Que la misma tecla abra y cierre es un `if` sobre el estado del examen, y ese estado vive
	# acá: si el `if` estuviera en la escena, sería una regla del juego sin test.
	var agarre := _agarre()
	var examen := _examen(agarre)
	agarre.pedir_agarrar(_lata(), _cuerpo())
	examen.alternar()
	assert_bool(examen.esta_examinando()).is_true()
	examen.alternar()
	assert_bool(examen.esta_examinando()).is_false()


func test_sin_punto_de_examen_la_e_no_se_pasa_a_revelar_lo_enfocado() -> void:
	# Un punto sin cablear es un `.tscn` mal armado, y el camino de lo enfocado está abajo del
	# de lo que se lleva: sin este corte, la E con una lata en la mano revelaba la puerta que se
	# estaba mirando —lo contrario del orden que este sistema decide— y lo hacía sin un solo
	# error, así que el único síntoma era una revelación que no correspondía.
	var agarre := _agarre()
	var examen := _examen(agarre)
	examen.punto_de_examen = null
	agarre.pedir_agarrar(_lata(), _cuerpo())
	var revelados: Array[Resource] = []
	examen.objeto_revelado.connect(
		func(datos: Resource, _es_nuevo: bool) -> void: revelados.append(datos)
	)
	assert_bool(examen.iniciar(_puerta())).is_false()
	assert_array(revelados).is_empty()
	assert_bool(examen.esta_examinando()).is_false()


## Un cuerpo del mundo con un estado que se nota si no vuelve: movido, girado, suelto del padre,
## con capa y máscara propias y sin congelar.
func _del_mundo() -> RigidBody3D:
	var cuerpo := _cuerpo()
	cuerpo.position = Vector3(1.0, 0.5, -2.0)
	cuerpo.rotation = Vector3(0.0, 0.8, 0.0)
	cuerpo.collision_layer = 5
	cuerpo.collision_mask = 7
	cuerpo.freeze = false
	return cuerpo


func test_la_e_sobre_un_levantable_lo_examina_sin_agarrarlo() -> void:  # AC-INV-020
	var agarre := _agarre()
	var examen := _examen(agarre)
	var cuerpo := _del_mundo()
	var lata := _lata()
	var iniciados: Array[Node3D] = []
	examen.examen_iniciado.connect(func(nodo: Node3D) -> void: iniciados.append(nodo))
	var revelados: Array[Resource] = []
	examen.objeto_revelado.connect(
		func(datos: Resource, _es_nuevo: bool) -> void: revelados.append(datos)
	)
	assert_bool(examen.iniciar(lata, cuerpo)).is_true()
	assert_bool(examen.esta_examinando()).is_true()
	assert_object(cuerpo.get_parent()).is_same(examen.punto_de_examen)
	assert_array(iniciados).contains_exactly([cuerpo])
	assert_array(revelados).contains_exactly([lata])
	assert_object(agarre.manos().sostenido()).is_null()
	examen.terminar()
	assert_bool(agarre.pedir_agarrar(lata, cuerpo)).is_true()


func test_la_segunda_e_devuelve_lo_examinado_a_su_lugar() -> void:  # AC-INV-021
	var agarre := _agarre()
	var examen := _examen(agarre)
	var cuerpo := _del_mundo()
	var padre := cuerpo.get_parent()
	var lugar := cuerpo.transform
	var lata := _lata()
	var nuevos: Array[bool] = []
	examen.objeto_revelado.connect(
		func(_datos: Resource, es_nuevo: bool) -> void: nuevos.append(es_nuevo)
	)
	examen.alternar(lata, cuerpo)
	assert_bool(cuerpo.freeze).is_true()
	assert_int(cuerpo.collision_layer).is_zero()
	examen.girar(Vector2.RIGHT, 0.5)
	examen.alternar(lata, cuerpo)
	assert_bool(examen.esta_examinando()).is_false()
	assert_object(cuerpo.get_parent()).is_same(padre)
	assert_bool(cuerpo.transform.is_equal_approx(lugar)).is_true()
	assert_int(cuerpo.collision_layer).is_equal(5)
	assert_int(cuerpo.collision_mask).is_equal(7)
	assert_bool(cuerpo.freeze).is_false()
	assert_object(agarre.manos().sostenido()).is_null()
	examen.alternar(lata, cuerpo)
	assert_bool(examen.esta_examinando()).is_true()
	assert_array(nuevos).contains_exactly([true, false])
