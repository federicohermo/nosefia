extends GdUnitTestSuite

const Sondas := preload("res://addons/hornear/sondas.gd")


func test_una_sonda_de_afuera_toma_los_coeficientes_de_su_vecina_de_adentro() -> void:
	var puntos := PackedVector3Array([Vector3.ZERO, Vector3.RIGHT])
	var sh := _coeficientes([Color(0.3, 0.3, 0.3), Color(0.006, 0.005, 0.004)])
	var resultado: Dictionary = Sondas.rellenar_coeficientes(puntos, sh, [false, true])
	assert_int(resultado.rellenadas).is_equal(1)
	assert_array(Array(resultado.sh).slice(0, 9)).is_equal(Array(sh).slice(9, 18))


func test_una_sonda_de_adentro_sin_luz_no_toma_la_de_una_vecina() -> void:
	var puntos := PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.LEFT])
	var sh := _coeficientes([Color(0, 0, 0), Color(0.1, 0.2, 0.15), Color(0.3, 0.3, 0.3)])
	var resultado: Dictionary = Sondas.rellenar_coeficientes(puntos, sh, [true, true, false])
	assert_array(Array(resultado.sh).slice(0, 18)).is_equal(Array(sh).slice(0, 18))


func test_una_sonda_de_afuera_sin_vecinas_de_adentro_se_conserva() -> void:
	var puntos := PackedVector3Array([Vector3.ZERO])
	var sh := _coeficientes([Color(0.3, 0.3, 0.3)])
	var resultado: Dictionary = Sondas.rellenar_coeficientes(puntos, sh, [false])
	assert_array(Array(resultado.sh)).is_equal(Array(sh))


func test_la_cascara_encierra_lo_que_esta_adentro_de_un_ambiente() -> void:
	var cascara := Sondas.Cascara.new(_ambiente(true), Transform3D.IDENTITY)
	assert_bool(cascara.encierra(Vector3.ZERO)).is_true()
	assert_bool(cascara.encierra(Vector3(0, -3, 0))).is_false()


func test_lo_que_esta_adentro_de_una_pared_no_esta_encerrado() -> void:
	var cascara := Sondas.Cascara.new(_ambiente(false), Transform3D.IDENTITY)
	assert_bool(cascara.encierra(Vector3.ZERO)).is_false()


## Un vidrio o una hoja que abre no entran al horneado: cierran el ambiente de los dos lados.
func test_lo_que_no_se_hornea_cierra_de_los_dos_lados() -> void:
	var ambiente := _ambiente(false)
	(ambiente.get_child(0) as MeshInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	var cascara := Sondas.Cascara.new(ambiente, Transform3D.IDENTITY)
	assert_bool(cascara.encierra(Vector3.ZERO)).is_true()


## Una caja de dos metros de lado. Con las caras hacia adentro es un ambiente; hacia afuera, un
## sólido.
func _ambiente(caras_hacia_adentro: bool) -> Node3D:
	var caja := BoxMesh.new()
	caja.size = Vector3(2, 2, 2)
	caja.flip_faces = caras_hacia_adentro
	var malla := MeshInstance3D.new()
	malla.mesh = caja
	malla.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	var ambiente: Node3D = auto_free(Node3D.new())
	ambiente.add_child(malla)
	return ambiente


func _coeficientes(colores: Array[Color]) -> PackedColorArray:
	var sh := PackedColorArray()
	for color: Color in colores:
		sh.append(color)
		for indice: int in 8:
			sh.append(Color(0, 0, 0, 0))
	return sh
