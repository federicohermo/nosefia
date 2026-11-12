## La pantalla de controles dibuja y rotula los botones del joystick según su familia: PlayStation
## con sus símbolos, Xbox con letras de color y Nintendo con las letras en su posición. Cambiar la
## familia con la pantalla abierta cambia los glifos en el acto y no toca la asignación.
extends GdUnitTestSuite

const ESCENA := "res://src/ui/interrupciones/pantalla_de_controles.tscn"
const DEL_JOYSTICK := AsignacionDeControles.TipoDeEntrada.BOTON_DEL_JOYSTICK
const EN_EL_JOYSTICK := AsignacionDeControles.RANURA_DEL_JOYSTICK
const XBOX := FamiliaDeJoystick.Familia.XBOX
const PLAYSTATION := FamiliaDeJoystick.Familia.PLAYSTATION
const NINTENDO := FamiliaDeJoystick.Familia.NINTENDO
const BOTONES_DE_CARA: Array[int] = [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y]

var _avisos: Array[AsignacionDeControles] = []


func before_test() -> void:
	_avisos = []


func _pantalla(familia: FamiliaDeJoystick.Familia) -> PantallaDeControles:
	var pantalla: PantallaDeControles = auto_free(load(ESCENA).instantiate())
	add_child(pantalla)
	pantalla.preparar(AsignacionDeControles.new())
	pantalla.poner_joystick_conectado(true)
	pantalla.poner_familia(familia)
	pantalla.controles_cambiados.connect(func(a: AsignacionDeControles) -> void: _avisos.append(a))
	pantalla.abrir(true)
	return pantalla


func _boton(indice: int) -> InputEventJoypadButton:
	var evento := InputEventJoypadButton.new()
	evento.button_index = indice as JoyButton
	evento.pressed = true
	return evento


func _glifo_de_cara(boton: int, familia: FamiliaDeJoystick.Familia) -> GlifoDeEntrada:
	return auto_free(
		GlifoDeEntrada.de_la_entrada(
			Vector2i(DEL_JOYSTICK, boton), FamiliaDeJoystick.rotulo_de(familia, boton), familia
		)
	)


func _pildoras(pantalla: PantallaDeControles) -> Array[GlifoDeEntrada]:
	var pildoras: Array[GlifoDeEntrada] = []
	pildoras.assign(pantalla.get("_pildoras_de_las_pestanas"))
	pildoras.append(pantalla.get("_pildora_de_pausa"))
	return pildoras


func _rotulos_esperados(familia: FamiliaDeJoystick.Familia) -> Array[String]:
	return [
		FamiliaDeJoystick.rotulo_de(familia, JOY_BUTTON_LEFT_SHOULDER),
		FamiliaDeJoystick.rotulo_de(familia, JOY_BUTTON_RIGHT_SHOULDER),
		FamiliaDeJoystick.rotulo_de(familia, JOY_BUTTON_START),
	]


func test_en_xbox_los_botones_de_cara_son_letras_de_color_y_no_simbolos() -> void:  # AC-CFG-045
	var colores: Array[Color] = []
	for boton: int in BOTONES_DE_CARA:
		var glifo := _glifo_de_cara(boton, XBOX)
		assert_int(glifo.forma).is_equal(GlifoDeEntrada.Forma.PALANCA)
		assert_array(colores).not_contains([glifo.color_del_texto])
		colores.append(glifo.color_del_texto)
	var pantalla := _pantalla(XBOX)
	var de_cara: Dictionary[StringName, int] = {
		AsignacionDeControles.AGARRAR: JOY_BUTTON_A,
		AsignacionDeControles.CELULAR: JOY_BUTTON_B,
		AsignacionDeControles.EXAMINAR: JOY_BUTTON_X,
	}
	for accion: StringName in de_cara:
		var celda := pantalla.glifo_de(accion, EN_EL_JOYSTICK)
		assert_int(celda.forma).is_equal(GlifoDeEntrada.Forma.PALANCA)
		assert_str(celda.texto).is_equal(FamiliaDeJoystick.rotulo_de(XBOX, de_cara[accion]))


func test_en_nintendo_las_letras_van_en_su_posicion_y_sin_color() -> void:  # AC-CFG-045
	for boton: int in BOTONES_DE_CARA:
		var glifo := _glifo_de_cara(boton, NINTENDO)
		assert_int(glifo.forma).is_equal(GlifoDeEntrada.Forma.PALANCA)
		assert_that(glifo.color_del_texto).is_equal(GlifoDeEntrada.COLOR_DEL_BORDE)
	var pantalla := _pantalla(NINTENDO)
	assert_str(pantalla.texto_de(AsignacionDeControles.AGARRAR, EN_EL_JOYSTICK)).is_equal(
		FamiliaDeJoystick.rotulo_de(NINTENDO, JOY_BUTTON_A)
	)
	assert_str(pantalla.texto_de(AsignacionDeControles.CELULAR, EN_EL_JOYSTICK)).is_equal(
		FamiliaDeJoystick.rotulo_de(NINTENDO, JOY_BUTTON_B)
	)
	assert_str(pantalla.texto_de(AsignacionDeControles.EXAMINAR, EN_EL_JOYSTICK)).is_equal(
		FamiliaDeJoystick.rotulo_de(NINTENDO, JOY_BUTTON_X)
	)


func test_en_playstation_siguen_los_simbolos() -> void:  # AC-CFG-045
	var pantalla := _pantalla(PLAYSTATION)
	var esperadas: Dictionary[StringName, GlifoDeEntrada.Forma] = {
		AsignacionDeControles.AGARRAR: GlifoDeEntrada.Forma.CRUZ,
		AsignacionDeControles.CELULAR: GlifoDeEntrada.Forma.CIRCULO,
		AsignacionDeControles.EXAMINAR: GlifoDeEntrada.Forma.CUADRADO,
	}
	for accion: StringName in esperadas:
		assert_int(pantalla.glifo_de(accion, EN_EL_JOYSTICK).forma).is_equal(esperadas[accion])
	assert_int(_glifo_de_cara(JOY_BUTTON_Y, PLAYSTATION).forma).is_equal(
		GlifoDeEntrada.Forma.TRIANGULO
	)


func test_hombros_y_pausa_llevan_el_rotulo_de_la_familia() -> void:  # AC-CFG-045
	for familia: FamiliaDeJoystick.Familia in FamiliaDeJoystick.Familia.values():
		var pantalla := _pantalla(familia)
		var rotulos: Array[String] = []
		for pildora: GlifoDeEntrada in _pildoras(pantalla):
			rotulos.append(pildora.texto)
		assert_array(rotulos).is_equal(_rotulos_esperados(familia))


func test_cambiar_la_familia_abierta_cambia_los_glifos_y_no_la_asignacion() -> void:  # AC-CFG-045
	var pantalla := _pantalla(PLAYSTATION)
	var accion := AsignacionDeControles.AGARRAR
	var antes := pantalla.glifo_de(accion, EN_EL_JOYSTICK).texto
	pantalla.poner_familia(XBOX)
	assert_str(pantalla.glifo_de(accion, EN_EL_JOYSTICK).texto).is_not_equal(antes)
	assert_int(pantalla.glifo_de(accion, EN_EL_JOYSTICK).forma).is_equal(
		GlifoDeEntrada.Forma.PALANCA
	)
	var rotulos: Array[String] = []
	for pildora: GlifoDeEntrada in _pildoras(pantalla):
		rotulos.append(pildora.texto)
	assert_array(rotulos).is_equal(_rotulos_esperados(XBOX))
	assert_array(_avisos).is_empty()
	pantalla.poner_familia(PLAYSTATION)
	assert_str(pantalla.glifo_de(accion, EN_EL_JOYSTICK).texto).is_equal(antes)


func test_l3_y_r3_reasignados_son_pildoras_en_toda_familia() -> void:  # AC-CFG-036
	for familia: FamiliaDeJoystick.Familia in FamiliaDeJoystick.Familia.values():
		for boton: int in [JOY_BUTTON_LEFT_STICK, JOY_BUTTON_RIGHT_STICK]:
			var pantalla := _pantalla(familia)
			pantalla.elegir(AsignacionDeControles.EXAMINAR, EN_EL_JOYSTICK)
			pantalla.atender(_boton(boton))
			var glifo := pantalla.glifo_de(AsignacionDeControles.EXAMINAR, EN_EL_JOYSTICK)
			assert_int(glifo.forma).is_equal(GlifoDeEntrada.Forma.PILDORA)
			assert_str(glifo.texto).is_equal(FamiliaDeJoystick.rotulo_de(familia, boton))


func test_la_espera_de_un_boton_no_nombra_ninguna_marca() -> void:  # AC-CFG-045
	var pantalla := _pantalla(XBOX)
	pantalla.elegir(AsignacionDeControles.EXAMINAR, EN_EL_JOYSTICK)
	var dicho := pantalla.texto_de(AsignacionDeControles.EXAMINAR, EN_EL_JOYSTICK).to_lower()
	assert_str(dicho).is_not_empty()
	for marca: String in ["playstation", "xbox", "nintendo"]:
		assert_bool(marca in dicho).is_false()


func test_el_gatillo_de_correr_es_una_pildora_con_el_rotulo_de_la_familia() -> void:  # AC-CFG-045
	for familia: FamiliaDeJoystick.Familia in FamiliaDeJoystick.Familia.values():
		var glifo := _pantalla(familia).glifo_de(AsignacionDeControles.CORRER, EN_EL_JOYSTICK)
		assert_int(glifo.forma).is_equal(GlifoDeEntrada.Forma.PILDORA)
		assert_str(glifo.texto).is_equal(FamiliaDeJoystick.rotulo_del_gatillo(familia))


func test_esperando_el_boton_de_correr_el_gatillo_derecho_se_asigna() -> void:  # AC-CFG-047
	var pantalla := _pantalla(XBOX)
	var correr := AsignacionDeControles.CORRER
	pantalla.elegir(correr, EN_EL_JOYSTICK)
	assert_bool(pantalla.atender(_boton(JOY_BUTTON_Y))).is_true()
	assert_array(_avisos).has_size(1)
	pantalla.elegir(correr, EN_EL_JOYSTICK)
	assert_bool(pantalla.atender(_gatillo(JOY_AXIS_TRIGGER_RIGHT, 0.6))).is_true()
	assert_array(_avisos).has_size(2)
	var entrada := _avisos[1].entrada(correr, EN_EL_JOYSTICK)
	assert_int(entrada["tipo"]).is_equal(AsignacionDeControles.TipoDeEntrada.GATILLO_DEL_JOYSTICK)
	assert_int(entrada["codigo"]).is_equal(JOY_AXIS_TRIGGER_RIGHT)


func test_el_gatillo_no_cambia_nada_esperando_otra_ranura_ni_otro_gatillo() -> void:  # AC-CFG-047
	var pantalla := _pantalla(XBOX)
	pantalla.elegir(AsignacionDeControles.EXAMINAR, EN_EL_JOYSTICK)
	assert_bool(pantalla.atender(_gatillo(JOY_AXIS_TRIGGER_RIGHT, 0.9))).is_true()
	assert_bool(pantalla.capturando()).is_true()
	pantalla.elegir(AsignacionDeControles.CORRER, EN_EL_JOYSTICK)
	assert_bool(pantalla.atender(_gatillo(JOY_AXIS_TRIGGER_LEFT, 0.9))).is_false()
	assert_bool(pantalla.atender(_gatillo(JOY_AXIS_TRIGGER_RIGHT, 0.4))).is_false()
	assert_array(_avisos).is_empty()


func _gatillo(eje: int, valor: float) -> InputEventJoypadMotion:
	var evento := InputEventJoypadMotion.new()
	evento.axis = eje as JoyAxis
	evento.axis_value = valor
	return evento


func _pantalla_sin_joystick() -> PantallaDeControles:
	var pantalla: PantallaDeControles = auto_free(load(ESCENA).instantiate())
	add_child(pantalla)
	pantalla.preparar(AsignacionDeControles.new())
	pantalla.poner_joystick_conectado(false)
	return pantalla


func test_la_prueba_con_joystick_habilita_la_pestana_sin_cambiar_la_familia() -> void:
	var pantalla := _pantalla_sin_joystick()
	var antes := pantalla.glifo_de(AsignacionDeControles.AGARRAR, EN_EL_JOYSTICK).texto
	pantalla.aplicar_la_prueba(PartidaDePrueba.desde_busqueda("?joystick=1"))
	pantalla.abrir(true)
	assert_bool(pantalla.pestana_del_joystick()).is_true()
	assert_str(pantalla.aviso_del_joystick()).is_not_empty()
	assert_str(pantalla.glifo_de(AsignacionDeControles.AGARRAR, EN_EL_JOYSTICK).texto).is_equal(
		antes
	)


func test_la_prueba_con_una_familia_la_fija_en_los_glifos() -> void:
	var pantalla := _pantalla_sin_joystick()
	pantalla.aplicar_la_prueba(PartidaDePrueba.desde_busqueda("?joystick=nintendo"))
	pantalla.abrir(true)
	var rotulos: Array[String] = []
	for pildora: GlifoDeEntrada in _pildoras(pantalla):
		rotulos.append(pildora.texto)
	assert_array(rotulos).is_equal(_rotulos_esperados(NINTENDO))


func test_sin_prueba_o_sin_joystick_la_pantalla_queda_como_estaba() -> void:
	for prueba: PartidaDePrueba in [null, PartidaDePrueba.desde_busqueda("?logros=1")]:
		var pantalla := _pantalla_sin_joystick()
		pantalla.aplicar_la_prueba(prueba)
		pantalla.abrir(true)
		assert_bool(pantalla.pestana_del_joystick()).is_false()
		assert_str(pantalla.aviso_del_joystick()).is_empty()
