## Qué variante suena: nunca la anterior, y con un sorteo que entra por parámetro.
extends GdUnitTestSuite

const SEMILLA := 1234


func _secuencia(cantidad: int, largo: int) -> Array[int]:
	var azar := RandomNumberGenerator.new()
	azar.seed = SEMILLA
	var secuencia: Array[int] = []
	var anterior := -1
	for _vez in range(largo):
		anterior = EleccionDeVariante.siguiente(cantidad, anterior, azar)
		secuencia.append(anterior)
	return secuencia


func test_nunca_suena_la_misma_dos_veces_seguidas() -> void:  # AC-AMB-018
	var secuencia := _secuencia(4, 20)
	for indice in range(1, secuencia.size()):
		assert_int(secuencia[indice]).is_not_equal(secuencia[indice - 1])
		assert_int(secuencia[indice]).is_between(0, 3)


func test_la_misma_semilla_da_la_misma_secuencia() -> void:  # AC-AMB-018
	assert_array(_secuencia(4, 20)).is_equal(_secuencia(4, 20))


func test_una_sola_variante_se_repite() -> void:  # AC-AMB-018
	assert_array(_secuencia(1, 3)).is_equal([0, 0, 0])


func test_sin_variantes_contesta_que_no_hay() -> void:
	assert_int(EleccionDeVariante.siguiente(0, -1, RandomNumberGenerator.new())).is_equal(-1)
