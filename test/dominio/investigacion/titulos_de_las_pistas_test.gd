## El título que lleva una pista en la pantalla de logros: el de la hipótesis que esa pista abre.
extends GdUnitTestSuite


func _hipotesis(identidad: String, titulo: String, exigencias: PackedStringArray) -> Hipotesis:
	var hipotesis := Hipotesis.new()
	hipotesis.identidad = identidad
	hipotesis.titulo = titulo
	hipotesis.exigencias = exigencias
	return hipotesis


func _caso(hipotesis: Array[Hipotesis]) -> CasoDeInvestigacion:
	var jornada := HipotesisDeLaJornada.new()
	jornada.opciones = hipotesis
	var caso := CasoDeInvestigacion.new()
	caso.hipotesis = [jornada]
	return caso


func test_la_pista_lleva_el_titulo_de_la_hipotesis_que_la_exige_sola() -> void:  # AC-ACH-013
	var caso := _caso(
		[
			_hipotesis("A", "Una cosa", PackedStringArray(["1A"])),
			_hipotesis("B", "Otra cosa", PackedStringArray(["1B"])),
			_hipotesis("C", "Las dos", PackedStringArray(["1A", "1B"])),
		]
	)
	assert_str(caso.titulo_de_la_pista("1A")).is_equal("Una cosa")
	assert_str(caso.titulo_de_la_pista("1B")).is_equal("Otra cosa")


func test_una_pista_sin_hipotesis_no_inventa_titulo() -> void:  # AC-ACH-013
	var caso := _caso([_hipotesis("A", "Una cosa", PackedStringArray(["1A"]))])
	assert_str(caso.titulo_de_la_pista("7B")).is_empty()
	assert_str(caso.titulo_de_la_pista("")).is_empty()


func test_la_pista_del_cigarrillo_lleva_el_titulo_de_su_hipotesis() -> void:  # AC-ACH-013
	var caso := CasoDeInvestigacion.de_la_partida()
	var pista := caso.pista_de("2B")
	var hipotesis := caso.opcion(pista.jornada, "2B")
	assert_str(hipotesis.titulo).is_not_empty()
	assert_str(caso.titulo_de_la_pista("2B")).is_equal(hipotesis.titulo)


func test_toda_pista_con_nota_del_caso_real_tiene_titulo() -> void:  # AC-ACH-013
	var caso := CasoDeInvestigacion.de_la_partida()
	for pista: Pista in caso.pistas:
		if pista.deja_nota():
			assert_str(caso.titulo_de_la_pista(pista.identidad)).is_not_empty()
