## Cuánto espera el celular con la persiana ya baja, sin levantar una escena.
extends GdUnitTestSuite


func test_el_celular_espera_con_la_persiana_baja() -> void:  # AC-EMP-095
	var espera := DevolucionDelJefe.SEGUNDOS_DE_ESPERA_DEL_CELULAR
	assert_bool(DevolucionDelJefe.celular_a_la_vista(0.0)).is_false()
	assert_bool(DevolucionDelJefe.celular_a_la_vista(espera - 0.01)).is_false()
	assert_bool(DevolucionDelJefe.celular_a_la_vista(espera)).is_true()
	assert_bool(DevolucionDelJefe.celular_a_la_vista(espera + 10.0)).is_true()
