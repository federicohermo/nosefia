## La pantalla de logros: tres columnas en orden, una entrada alcanzada con su imagen y su nombre,
## una que no con el signo de pregunta, y Esc que la cierra.
extends GdUnitTestSuite

const ESCENA := "res://src/ui/interrupciones/pantalla_de_logros.tscn"
const L := Logros.Logro
const F := Partida.Final
const PISTAS := &"PISTAS"
const FINALES := &"FINALES"
const LOGROS := &"LOGROS"

var _cierres := 0


func before_test() -> void:
	_cierres = 0


func _pantalla(logros: Logros = Logros.new()) -> PantallaDeLogros:
	var pantalla: PantallaDeLogros = auto_free(load(ESCENA).instantiate())
	add_child(pantalla)
	pantalla.preparar(logros, CasoDeInvestigacion.de_la_partida())
	pantalla.cerrada.connect(func() -> void: _cierres += 1)
	pantalla.abrir()
	return pantalla


func _texto(entrada: HBoxContainer) -> String:
	return (entrada.get_child(1) as Label).text


func _imagen(entrada: HBoxContainer) -> Texture2D:
	return (entrada.get_child(0) as TextureRect).texture


func test_tiene_tres_columnas_en_orden_con_una_entrada_por_cosa() -> void:  # AC-ACH-012
	var pantalla := _pantalla()
	assert_array(pantalla.columnas()).is_equal([PISTAS, FINALES, LOGROS])
	var pistas := CasoDeInvestigacion.de_la_partida().pistas.size()
	assert_int(pantalla.entradas(PISTAS).size()).is_equal(pistas)
	assert_int(pantalla.entradas(FINALES).size()).is_equal(Logros.finales().size())
	assert_int(pantalla.entradas(LOGROS).size()).is_equal(L.values().size())


func test_lo_bloqueado_pregunta_en_las_tres_columnas() -> void:  # AC-ACH-013
	var pantalla := _pantalla()
	for columna: StringName in [PISTAS, FINALES, LOGROS]:
		for entrada: HBoxContainer in pantalla.entradas(columna):
			assert_str(_texto(entrada)).is_equal(PantallaDeLogros.TEXTO_BLOQUEADO)
			assert_object(_imagen(entrada)).is_same(PantallaDeLogros.IMAGEN_BLOQUEADA)


func test_un_logro_desbloqueado_muestra_su_nombre_y_los_demas_no() -> void:  # AC-ACH-013
	var logros := Logros.new()
	logros.desbloquear(L.Y_SE_MARCHO)
	var entradas := _pantalla(logros).entradas(LOGROS)
	assert_str(_texto(entradas[L.Y_SE_MARCHO])).is_equal(Logros.nombre(L.Y_SE_MARCHO))
	assert_object(_imagen(entradas[L.Y_SE_MARCHO])).is_not_same(PantallaDeLogros.IMAGEN_BLOQUEADA)
	assert_str(_texto(entradas[L.REBELDE])).is_equal(PantallaDeLogros.TEXTO_BLOQUEADO)


func test_cada_entrada_alcanzada_muestra_una_imagen_propia() -> void:  # AC-ACH-013
	var logros := Logros.new()
	var desbloqueables: Array[L] = []
	for logro: L in L.values():
		if logro != L.OBELISCO_DE_CARTON and logro != L.ELEMENTAL:
			logros.desbloquear(logro)
			desbloqueables.append(logro)
	for final: F in Logros.finales():
		logros.alcanzar_final(final)
	var pantalla := _pantalla(logros)
	var imagenes: Array[Texture2D] = []
	for logro: L in desbloqueables:
		imagenes.append(_imagen(pantalla.entradas(LOGROS)[logro]))
	for entrada: HBoxContainer in pantalla.entradas(FINALES):
		imagenes.append(_imagen(entrada))
	assert_int(imagenes.size()).is_equal(desbloqueables.size() + Logros.finales().size())
	var vistas: Array[Texture2D] = [PantallaDeLogros.IMAGEN_BLOQUEADA]
	for imagen: Texture2D in imagenes:
		assert_object(imagen).is_not_null()
		assert_bool(vistas.has(imagen)).is_false()
		vistas.append(imagen)


func test_obelisco_y_elemental_se_ven_bloqueados() -> void:  # AC-ACH-013
	var logros := Logros.new()
	for logro: L in L.values():
		if logro != L.OBELISCO_DE_CARTON and logro != L.ELEMENTAL:
			logros.desbloquear(logro)
	var entradas := _pantalla(logros).entradas(LOGROS)
	for logro: L in [L.OBELISCO_DE_CARTON, L.ELEMENTAL]:
		assert_str(_texto(entradas[logro])).is_equal(PantallaDeLogros.TEXTO_BLOQUEADO)
		assert_object(_imagen(entradas[logro])).is_same(PantallaDeLogros.IMAGEN_BLOQUEADA)


func test_un_final_alcanzado_muestra_su_nombre_y_el_otro_pregunta() -> void:  # AC-ACH-013
	var logros := Logros.new()
	logros.alcanzar_final(F.DESPEDIDO)
	var entradas := _pantalla(logros).entradas(FINALES)
	var finales := Logros.finales()
	assert_str(_texto(entradas[finales.find(F.DESPEDIDO)])).is_equal(
		Logros.nombre_del_final(F.DESPEDIDO)
	)
	assert_str(_texto(entradas[finales.find(F.CONTRATO_CUMPLIDO)])).is_equal(
		PantallaDeLogros.TEXTO_BLOQUEADO
	)


func test_una_pista_descubierta_muestra_su_foto_y_su_texto() -> void:  # AC-ACH-013
	var pistas := CasoDeInvestigacion.de_la_partida().pistas
	var logros := Logros.new()
	logros.descubrir_pista(pistas[0].identidad)
	var entradas := _pantalla(logros).entradas(PISTAS)
	assert_str(_texto(entradas[0])).is_equal(pistas[0].texto)
	assert_object(_imagen(entradas[0])).is_same(pistas[0].foto)
	assert_str(_texto(entradas[1])).is_equal(PantallaDeLogros.TEXTO_BLOQUEADO)


func test_la_fuente_del_tema_dibuja_los_signos_de_los_nombres() -> void:  # AC-ACH-013
	var logros := Logros.new()
	for logro: L in L.values():
		logros.desbloquear(logro)
	var pantalla := _pantalla(logros)
	var fuente := pantalla.marco().get_theme_font("font")
	for entrada: HBoxContainer in pantalla.entradas(LOGROS):
		for letra: String in _texto(entrada):
			assert_bool(fuente.has_char(letra.unicode_at(0))).is_true()


func test_esc_la_cierra_y_avisa_una_sola_vez() -> void:  # AC-SAV-037
	var pantalla := _pantalla()
	assert_bool(pantalla.visible).is_true()
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	pantalla._unhandled_input(esc)
	assert_bool(pantalla.visible).is_false()
	pantalla._unhandled_input(esc)
	assert_int(_cierres).is_equal(1)


func test_abrirla_otra_vez_lee_lo_ganado_desde_entonces() -> void:  # AC-ACH-013
	var logros := Logros.new()
	var pantalla := _pantalla(logros)
	assert_str(_texto(pantalla.entradas(LOGROS)[L.REBELDE])).is_equal(
		PantallaDeLogros.TEXTO_BLOQUEADO
	)
	pantalla.cerrar()
	logros.desbloquear(L.REBELDE)
	pantalla.abrir()
	assert_str(_texto(pantalla.entradas(LOGROS)[L.REBELDE])).is_equal(Logros.nombre(L.REBELDE))


func test_una_pista_que_el_caso_no_conoce_no_agrega_una_entrada() -> void:  # AC-ACH-011
	var logros := Logros.new()
	logros.descubrir_pista("NO_ES_DEL_CASO")
	var pantalla := _pantalla(logros)
	var pistas := CasoDeInvestigacion.de_la_partida().pistas.size()
	assert_int(pantalla.entradas(PISTAS).size()).is_equal(pistas)
