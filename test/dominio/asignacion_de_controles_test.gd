## La asignación de controles como regla: qué acciones se reasignan, qué entrada acepta cada una,
## el intercambio y el saneamiento del esquema, sin levantar una escena.
extends GdUnitTestSuite

const A := AsignacionDeControles
const TECLA := AsignacionDeControles.TipoDeEntrada.TECLA
const BOTON := AsignacionDeControles.TipoDeEntrada.BOTON_DEL_MOUSE

## Las catorce ranuras del esquema de fábrica: la acción, la ranura y su entrada.
const DE_FABRICA: Array = [
	[A.ADELANTE, 0, TECLA, KEY_W],
	[A.ADELANTE, 1, TECLA, KEY_UP],
	[A.ATRAS, 0, TECLA, KEY_S],
	[A.ATRAS, 1, TECLA, KEY_DOWN],
	[A.IZQUIERDA, 0, TECLA, KEY_A],
	[A.IZQUIERDA, 1, TECLA, KEY_LEFT],
	[A.DERECHA, 0, TECLA, KEY_D],
	[A.DERECHA, 1, TECLA, KEY_RIGHT],
	[A.CELULAR, 0, TECLA, KEY_Q],
	[A.EXAMINAR, 0, TECLA, KEY_E],
	[A.AGACHARSE, 0, TECLA, KEY_SPACE],
	[A.AGARRAR, 0, BOTON, MOUSE_BUTTON_LEFT],
	[A.INTERACTUAR, 0, BOTON, MOUSE_BUTTON_RIGHT],
	[A.PAUSA, 0, TECLA, KEY_ESCAPE],
]


func _entrada(asignacion: AsignacionDeControles, accion: StringName, ranura: int) -> Vector2i:
	var entrada := asignacion.entrada(accion, ranura)
	return Vector2i(entrada["tipo"], entrada["codigo"])


func _tecla(codigo: int) -> Vector2i:
	return Vector2i(TECLA, codigo)


func _no_repite_ninguna(asignacion: AsignacionDeControles) -> bool:
	var vistas: Dictionary = {}
	for entrada: Dictionary in asignacion.entradas():
		var par := Vector2i(entrada["tipo"], entrada["codigo"])
		if vistas.has(par):
			return false
		vistas[par] = true
	return true


func _de_fabrica(asignacion: AsignacionDeControles) -> bool:
	return asignacion.datos() == AsignacionDeControles.new().datos()


func test_son_siete_acciones_y_catorce_ranuras() -> void:  # AC-CFG-016
	var nombres: Dictionary = {}
	for accion: StringName in A.ACCIONES:
		var nombre := A.nombre_de_la_accion(accion)
		assert_str(nombre).is_not_empty()
		nombres[nombre] = true
	assert_int(nombres.size()).is_equal(7)
	assert_int(AsignacionDeControles.new().entradas().size()).is_equal(DE_FABRICA.size())
	for direccion: StringName in A.DIRECCIONES:
		assert_int(A.ranuras_de(direccion)).is_equal(2)
	assert_int(A.ranuras_de(&"accion_que_no_existe")).is_equal(0)


func test_el_esquema_de_fabrica_es_el_de_la_ficha() -> void:  # AC-CFG-016
	var asignacion := AsignacionDeControles.new()
	for ranura: Array in DE_FABRICA:
		assert_vector(_entrada(asignacion, ranura[0], ranura[1])).is_equal(
			Vector2i(ranura[2], ranura[3])
		)


func test_cada_renglon_tiene_un_nombre_distinto() -> void:  # AC-CFG-016
	var nombres: Dictionary = {}
	for entrada: Dictionary in AsignacionDeControles.new().entradas():
		var nombre := A.nombre_en_pantalla(entrada["accion"], entrada["ranura"])
		assert_str(nombre).is_not_empty()
		assert_bool(nombres.has(nombre)).is_false()
		nombres[nombre] = true


func test_una_accion_acepta_una_tecla_y_una_tecla_acepta_un_clic() -> void:  # AC-CFG-017
	var asignacion := AsignacionDeControles.new()
	assert_bool(asignacion.asignar(A.AGARRAR, 0, TECLA, KEY_F)).is_true()
	assert_vector(_entrada(asignacion, A.AGARRAR, 0)).is_equal(_tecla(KEY_F))
	assert_bool(asignacion.asignar(A.EXAMINAR, 0, BOTON, MOUSE_BUTTON_MIDDLE)).is_true()
	assert_vector(_entrada(asignacion, A.EXAMINAR, 0)).is_equal(
		Vector2i(BOTON, MOUSE_BUTTON_MIDDLE)
	)


func test_mover_el_mouse_y_la_rueda_no_son_entradas() -> void:  # AC-CFG-017
	var asignacion := AsignacionDeControles.new()
	for rueda: int in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_NONE]:
		assert_bool(A.acepta(A.EXAMINAR, BOTON, rueda)).is_false()
		assert_bool(asignacion.asignar(A.EXAMINAR, 0, BOTON, rueda)).is_false()
	assert_bool(A.acepta(A.EXAMINAR, TECLA, KEY_NONE)).is_false()
	assert_bool(_de_fabrica(asignacion)).is_true()


func test_en_la_web_solo_pausa_acepta_esc() -> void:  # AC-CFG-017
	assert_bool(A.acepta(A.EXAMINAR, TECLA, KEY_ESCAPE, true)).is_false()
	assert_bool(A.acepta(A.PAUSA, TECLA, KEY_ESCAPE, true)).is_true()
	var asignacion := AsignacionDeControles.new()
	assert_bool(asignacion.asignar(A.EXAMINAR, 0, TECLA, KEY_ESCAPE, true)).is_false()
	assert_bool(_de_fabrica(asignacion)).is_true()


func test_en_el_escritorio_esc_va_a_otra_accion_y_pausa_recibe_su_tecla() -> void:  # AC-CFG-017
	var asignacion := AsignacionDeControles.new()
	assert_bool(asignacion.asignar(A.EXAMINAR, 0, TECLA, KEY_ESCAPE)).is_true()
	assert_vector(_entrada(asignacion, A.EXAMINAR, 0)).is_equal(_tecla(KEY_ESCAPE))
	assert_vector(_entrada(asignacion, A.PAUSA, 0)).is_equal(_tecla(KEY_E))


func test_en_la_web_un_intercambio_no_le_da_esc_a_otra_accion() -> void:  # AC-CFG-017
	var asignacion := AsignacionDeControles.new()
	assert_bool(asignacion.asignar(A.EXAMINAR, 0, TECLA, KEY_P)).is_true()
	assert_bool(asignacion.asignar(A.PAUSA, 0, TECLA, KEY_P, true)).is_false()
	assert_vector(_entrada(asignacion, A.PAUSA, 0)).is_equal(_tecla(KEY_ESCAPE))
	assert_vector(_entrada(asignacion, A.EXAMINAR, 0)).is_equal(_tecla(KEY_P))


func test_la_tecla_de_otra_accion_se_intercambia() -> void:  # AC-CFG-018
	var asignacion := AsignacionDeControles.new()
	assert_bool(asignacion.asignar(A.EXAMINAR, 0, TECLA, KEY_SPACE)).is_true()
	assert_vector(_entrada(asignacion, A.EXAMINAR, 0)).is_equal(_tecla(KEY_SPACE))
	assert_vector(_entrada(asignacion, A.AGACHARSE, 0)).is_equal(_tecla(KEY_E))
	assert_bool(_no_repite_ninguna(asignacion)).is_true()


func test_un_clic_pasa_a_otra_accion_y_la_otra_recibe_el_suyo() -> void:  # AC-CFG-018
	var asignacion := AsignacionDeControles.new()
	assert_bool(asignacion.asignar(A.INTERACTUAR, 0, BOTON, MOUSE_BUTTON_LEFT)).is_true()
	assert_vector(_entrada(asignacion, A.INTERACTUAR, 0)).is_equal(
		Vector2i(BOTON, MOUSE_BUTTON_LEFT)
	)
	assert_vector(_entrada(asignacion, A.AGARRAR, 0)).is_equal(Vector2i(BOTON, MOUSE_BUTTON_RIGHT))
	assert_bool(_no_repite_ninguna(asignacion)).is_true()


func test_el_intercambio_vale_entre_las_dos_ranuras_de_una_misma_accion() -> void:  # AC-CFG-018
	var asignacion := AsignacionDeControles.new()
	assert_bool(asignacion.asignar(A.ADELANTE, A.RANURA_DE_FLECHAS, TECLA, KEY_W)).is_true()
	assert_vector(_entrada(asignacion, A.ADELANTE, A.RANURA_DE_FLECHAS)).is_equal(_tecla(KEY_W))
	assert_vector(_entrada(asignacion, A.ADELANTE, A.RANURA_DE_WASD)).is_equal(_tecla(KEY_UP))
	assert_bool(_no_repite_ninguna(asignacion)).is_true()


func test_el_intercambio_vale_entre_direcciones() -> void:  # AC-CFG-018
	var asignacion := AsignacionDeControles.new()
	assert_bool(asignacion.asignar(A.IZQUIERDA, A.RANURA_DE_WASD, TECLA, KEY_D)).is_true()
	assert_vector(_entrada(asignacion, A.IZQUIERDA, A.RANURA_DE_WASD)).is_equal(_tecla(KEY_D))
	assert_vector(_entrada(asignacion, A.DERECHA, A.RANURA_DE_WASD)).is_equal(_tecla(KEY_A))
	assert_bool(_no_repite_ninguna(asignacion)).is_true()


func test_asignar_la_entrada_que_ya_tiene_no_cambia_nada() -> void:  # AC-CFG-018
	var asignacion := AsignacionDeControles.new()
	assert_bool(asignacion.asignar(A.EXAMINAR, 0, TECLA, KEY_E)).is_false()
	assert_bool(asignacion.asignar(A.AGARRAR, 0, BOTON, MOUSE_BUTTON_LEFT)).is_false()
	assert_bool(_de_fabrica(asignacion)).is_true()


func test_cambiar_las_flechas_conserva_la_ranura_de_wasd() -> void:  # AC-CFG-019
	var asignacion := AsignacionDeControles.new()
	assert_bool(asignacion.asignar(A.ADELANTE, A.RANURA_DE_FLECHAS, TECLA, KEY_H)).is_true()
	assert_vector(_entrada(asignacion, A.ADELANTE, A.RANURA_DE_FLECHAS)).is_equal(_tecla(KEY_H))
	assert_vector(_entrada(asignacion, A.ADELANTE, A.RANURA_DE_WASD)).is_equal(_tecla(KEY_W))
	for direccion: StringName in [A.ATRAS, A.IZQUIERDA, A.DERECHA]:
		assert_vector(_entrada(asignacion, direccion, A.RANURA_DE_FLECHAS)).is_equal(
			_entrada(AsignacionDeControles.new(), direccion, A.RANURA_DE_FLECHAS)
		)


func test_una_accion_o_una_ranura_que_no_existe_no_cambia_nada() -> void:  # AC-CFG-019
	var asignacion := AsignacionDeControles.new()
	assert_bool(asignacion.asignar(&"accion_que_no_existe", 0, TECLA, KEY_H)).is_false()
	assert_bool(asignacion.asignar(A.EXAMINAR, 1, TECLA, KEY_H)).is_false()
	assert_bool(asignacion.asignar(A.EXAMINAR, -1, TECLA, KEY_H)).is_false()
	assert_bool(asignacion.asignar(A.ADELANTE, 2, TECLA, KEY_H)).is_false()
	assert_bool(_de_fabrica(asignacion)).is_true()


func test_los_datos_vuelven_con_cada_accion_y_ranura() -> void:  # AC-CFG-022
	var asignacion := AsignacionDeControles.new()
	asignacion.asignar(A.EXAMINAR, 0, TECLA, KEY_F)
	asignacion.asignar(A.ADELANTE, A.RANURA_DE_FLECHAS, BOTON, MOUSE_BUTTON_MIDDLE)
	var leida := AsignacionDeControles.desde(asignacion.datos())
	assert_array(leida.entradas()).is_equal(asignacion.entradas())
	assert_vector(_entrada(leida, A.EXAMINAR, 0)).is_equal(_tecla(KEY_F))
	assert_vector(_entrada(leida, A.ADELANTE, A.RANURA_DE_FLECHAS)).is_equal(
		Vector2i(BOTON, MOUSE_BUTTON_MIDDLE)
	)


func test_sin_datos_cada_ranura_tiene_su_entrada_de_fabrica() -> void:  # AC-CFG-022
	assert_bool(_de_fabrica(AsignacionDeControles.desde({}))).is_true()


func test_una_copia_no_comparte_las_entradas_con_el_original() -> void:  # AC-CFG-018
	var original := AsignacionDeControles.new()
	var copia := original.copia()
	copia.asignar(A.EXAMINAR, 0, TECLA, KEY_F)
	assert_vector(_entrada(original, A.EXAMINAR, 0)).is_equal(_tecla(KEY_E))
	assert_vector(_entrada(copia, A.EXAMINAR, 0)).is_equal(_tecla(KEY_F))
