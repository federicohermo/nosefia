## El saneamiento del esquema de controles al leerlo: lo ilegible vuelve a su entrada de fábrica y
## una entrada repetida descarta el bloque entero, sin dejar nunca un esquema parcial.
extends GdUnitTestSuite

const A := AsignacionDeControles
const TECLA := AsignacionDeControles.TipoDeEntrada.TECLA
const BOTON := AsignacionDeControles.TipoDeEntrada.BOTON_DEL_MOUSE


func _entrada(asignacion: AsignacionDeControles, accion: StringName, ranura: int) -> Vector2i:
	var entrada := asignacion.entrada(accion, ranura)
	return Vector2i(entrada["tipo"], entrada["codigo"])


func _tecla(codigo: int) -> Vector2i:
	return Vector2i(TECLA, codigo)


func _de_fabrica(asignacion: AsignacionDeControles) -> bool:
	return asignacion.datos() == AsignacionDeControles.new().datos()


## Los datos del esquema de fábrica con dos ranuras cambiadas a mano, para probar el saneamiento.
func _datos_con(cambios: Dictionary) -> Dictionary:
	var datos := AsignacionDeControles.new().datos()
	for clave: String in cambios:
		datos[clave] = cambios[clave]
	return datos


func _cruda(tipo: Variant, codigo: Variant) -> Dictionary:
	return {"tipo": tipo, "codigo": codigo}


func test_una_accion_que_no_existe_se_ignora() -> void:  # AC-CFG-023
	var datos := _datos_con({"accion_que_no_existe": [_cruda(TECLA, KEY_F)]})
	assert_bool(_de_fabrica(AsignacionDeControles.desde(datos))).is_true()


func test_una_entrada_ilegible_vuelve_a_la_de_fabrica_y_conserva_las_demas() -> void:  # AC-CFG-023
	var datos := _datos_con(
		{
			String(A.EXAMINAR): [_cruda("tecla", "e")],
			String(A.AGACHARSE): [_cruda(TECLA, KEY_F)],
		}
	)
	var leida := AsignacionDeControles.desde(datos)
	assert_vector(_entrada(leida, A.EXAMINAR, 0)).is_equal(_tecla(KEY_E))
	assert_vector(_entrada(leida, A.AGACHARSE, 0)).is_equal(_tecla(KEY_F))


func test_una_entrada_que_la_accion_no_acepta_se_trata_como_ilegible() -> void:  # AC-CFG-023
	var datos := _datos_con({String(A.EXAMINAR): [_cruda(BOTON, MOUSE_BUTTON_WHEEL_UP)]})
	assert_bool(_de_fabrica(AsignacionDeControles.desde(datos))).is_true()


func test_dos_acciones_guardadas_en_la_misma_tecla_descartan_el_bloque() -> void:  # AC-CFG-023
	var datos := _datos_con(
		{
			String(A.EXAMINAR): [_cruda(TECLA, KEY_F)],
			String(A.AGACHARSE): [_cruda(TECLA, KEY_F)],
			String(A.CELULAR): [_cruda(TECLA, KEY_G)],
		}
	)
	assert_bool(_de_fabrica(AsignacionDeControles.desde(datos))).is_true()


func test_restaurar_una_entrada_ilegible_que_choca_descarta_el_bloque() -> void:  # AC-CFG-023
	var datos := _datos_con(
		{
			String(A.EXAMINAR): [_cruda("tecla", "e")],
			String(A.AGACHARSE): [_cruda(TECLA, KEY_E)],
			String(A.CELULAR): [_cruda(TECLA, KEY_G)],
		}
	)
	assert_bool(_de_fabrica(AsignacionDeControles.desde(datos))).is_true()


func test_las_dos_ranuras_de_una_direccion_en_una_tecla_descartan_el_bloque() -> void:  # AC-CFG-023
	var datos := _datos_con({String(A.ADELANTE): [_cruda(TECLA, KEY_H), _cruda(TECLA, KEY_H)]})
	assert_bool(_de_fabrica(AsignacionDeControles.desde(datos))).is_true()


func test_un_bloque_que_no_es_una_lista_vuelve_a_la_de_fabrica() -> void:  # AC-CFG-023
	var datos := _datos_con({String(A.EXAMINAR): "no es una lista"})
	assert_bool(_de_fabrica(AsignacionDeControles.desde(datos))).is_true()
