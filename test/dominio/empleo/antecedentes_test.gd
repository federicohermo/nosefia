## Las cuentas que la devolución lee entre noches, sin levantar una escena.
extends GdUnitTestSuite

const T := Tarea.Tipo
const L := Partida.Llamado


func test_una_partida_nueva_arranca_sin_cuentas() -> void:  # AC-EMP-059
	var antecedentes := Antecedentes.new()
	for tipo: T in Antecedentes.FIJAS:
		assert_int(antecedentes.fallas(tipo)).is_zero()
	for motivo: L in L.values():
		assert_int(antecedentes.llamados(motivo)).is_zero()
	assert_bool(antecedentes.hubo_llamados()).is_false()
	assert_int(antecedentes.noches_sin_sumar()).is_zero()


func test_cada_noche_suma_fallas_llamados_y_lleva_r() -> void:  # AC-EMP-059
	var antecedentes := Antecedentes.new()
	antecedentes.anotar_noche(
		[T.REPONER, T.LIMPIAR, T.ORDENAR_LAS_CAJAS],
		[L.PAPEL_EN_EL_INODORO, L.PAPEL_EN_EL_INODORO],
		5
	)
	assert_int(antecedentes.fallas(T.REPONER)).is_equal(1)
	assert_int(antecedentes.fallas(T.LIMPIAR)).is_equal(1)
	assert_int(antecedentes.fallas(T.CAJA)).is_zero()
	assert_int(antecedentes.fallas(T.REGISTRAR)).is_zero()
	assert_int(antecedentes.fallas(T.ORDENAR_LAS_CAJAS)).is_zero()
	assert_int(antecedentes.llamados(L.PAPEL_EN_EL_INODORO)).is_equal(1)
	assert_bool(antecedentes.hubo_llamados()).is_true()
	assert_int(antecedentes.noches_sin_sumar()).is_zero()
	antecedentes.anotar_noche([], [], 0)
	assert_int(antecedentes.noches_sin_sumar()).is_equal(1)
	assert_int(antecedentes.fallas(T.REPONER)).is_equal(1)
	antecedentes.anotar_noche([], [], 0)
	assert_int(antecedentes.noches_sin_sumar()).is_equal(2)
	antecedentes.anotar_noche([], [L.OBJETO_AFUERA], 1)
	assert_int(antecedentes.noches_sin_sumar()).is_zero()


func test_los_datos_vuelven_iguales() -> void:  # AC-SAV-024
	var antecedentes := Antecedentes.new()
	antecedentes.anotar_noche([T.REPONER], [L.PAPEL_EN_EL_INODORO], 2)
	antecedentes.anotar_noche([T.REPONER], [], 0)
	var leidos := Antecedentes.desde(antecedentes.a_datos())
	assert_int(leidos.fallas(T.REPONER)).is_equal(2)
	assert_int(leidos.llamados(L.PAPEL_EN_EL_INODORO)).is_equal(1)
	assert_bool(leidos.hubo_llamados()).is_true()
	assert_int(leidos.noches_sin_sumar()).is_equal(1)


func test_lo_desconocido_o_de_otro_tipo_se_ignora() -> void:  # AC-SAV-025
	var sin_nada := Antecedentes.desde({})
	assert_bool(sin_nada.hubo_llamados()).is_false()
	assert_int(sin_nada.noches_sin_sumar()).is_zero()
	var otro_tipo := (
		Antecedentes
		. desde(
			{
				Antecedentes.CLAVE_DE_FALLAS: 3,
				Antecedentes.CLAVE_DE_LLAMADOS: "muchos",
				Antecedentes.CLAVE_DE_NOCHES_SIN_SUMAR: "dos",
			}
		)
	)
	assert_int(otro_tipo.fallas(T.REPONER)).is_zero()
	assert_bool(otro_tipo.hubo_llamados()).is_false()
	assert_int(otro_tipo.noches_sin_sumar()).is_zero()
	var mezclado := (
		Antecedentes
		. desde(
			{
				Antecedentes.CLAVE_DE_FALLAS: {"VOLAR": 4, "REPONER": 1, "LIMPIAR": "dos"},
				Antecedentes.CLAVE_DE_LLAMADOS: {"PAPEL_EN_EL_INODORO": 2, "OTRO": 1},
			}
		)
	)
	assert_int(mezclado.fallas(T.REPONER)).is_equal(1)
	assert_int(mezclado.fallas(T.LIMPIAR)).is_zero()
	assert_int(mezclado.llamados(L.PAPEL_EN_EL_INODORO)).is_equal(2)
