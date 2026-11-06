## Los papeles se examinan más grandes que en el mundo y vuelven a su tamaño al terminar.
extends GdUnitTestSuite

const ESCALA := 2.0


func _agarre() -> Agarre:
	var agarre: Agarre = auto_free(Agarre.new())
	agarre.punto_de_carga = auto_free(Node3D.new())
	agarre.punto_de_soltado = auto_free(Node3D.new())
	agarre.punto_de_respaldo = auto_free(Node3D.new())
	return agarre


func _examen(agarre: Agarre) -> Examen:
	var examen: Examen = auto_free(Examen.new())
	examen.agarre = agarre
	examen.punto_de_examen = auto_free(Node3D.new())
	return examen


func _datos(escala: float) -> ObjetoDelAlmacen:
	var datos := ObjetoDelAlmacen.new()
	datos.id = &"papel_de_prueba"
	datos.escala_de_examen = escala
	return datos


## Un papel chico, con la malla y el cuerpo de las pistas.
func _papel(escala_del_mundo: float = 1.0) -> RigidBody3D:
	var padre: Node3D = auto_free(Node3D.new())
	var cuerpo := RigidBody3D.new()
	var malla := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(0.18, 0.2438)
	malla.mesh = plano
	cuerpo.add_child(malla)
	cuerpo.scale = Vector3.ONE * escala_del_mundo
	padre.add_child(cuerpo)
	return cuerpo


func test_un_papel_se_examina_mas_grande_y_vuelve_a_su_tamano() -> void:
	var agarre := _agarre()
	var examen := _examen(agarre)
	var papel := _papel(1.5)
	agarre.pedir_agarrar(_datos(ESCALA), papel)
	examen.iniciar()
	assert_vector(papel.scale).is_equal_approx(Vector3.ONE * 1.5 * ESCALA, Vector3.ONE * 0.001)
	examen.terminar()
	assert_vector(papel.scale).is_equal_approx(Vector3.ONE * 1.5, Vector3.ONE * 0.001)


func test_examinar_un_papel_dos_veces_no_acumula_la_escala() -> void:
	var agarre := _agarre()
	var examen := _examen(agarre)
	var papel := _papel()
	agarre.pedir_agarrar(_datos(ESCALA), papel)
	examen.iniciar()
	var primera := papel.scale
	examen.terminar()
	examen.iniciar()
	assert_vector(papel.scale).is_equal_approx(primera, Vector3.ONE * 0.001)


func test_lo_que_no_es_papel_se_examina_a_su_tamano() -> void:
	var agarre := _agarre()
	var examen := _examen(agarre)
	var objeto := _papel()
	agarre.pedir_agarrar(_datos(1.0), objeto)
	examen.iniciar()
	assert_vector(objeto.scale).is_equal_approx(Vector3.ONE, Vector3.ONE * 0.001)


func test_la_escala_no_cambia_la_distancia_de_examen() -> void:
	var distancias: Array[float] = []
	for escala: float in [1.0, ESCALA]:
		var agarre := _agarre()
		var examen := _examen(agarre)
		agarre.pedir_agarrar(_datos(escala), _papel())
		examen.iniciar()
		distancias.append(-examen.punto_de_examen.position.z)
	assert_float(distancias[1]).is_equal_approx(distancias[0], 0.001)
