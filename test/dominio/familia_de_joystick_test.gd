## La familia de un joystick sale del nombre que dice de sí mismo, y cada familia rotula los botones
## por su posición.
extends GdUnitTestSuite

const XBOX := FamiliaDeJoystick.Familia.XBOX
const PLAYSTATION := FamiliaDeJoystick.Familia.PLAYSTATION
const NINTENDO := FamiliaDeJoystick.Familia.NINTENDO
const BOTONES_CON_ROTULO: Array[int] = [
	JOY_BUTTON_A,
	JOY_BUTTON_B,
	JOY_BUTTON_X,
	JOY_BUTTON_Y,
	JOY_BUTTON_BACK,
	JOY_BUTTON_START,
	JOY_BUTTON_LEFT_STICK,
	JOY_BUTTON_RIGHT_STICK,
	JOY_BUTTON_LEFT_SHOULDER,
	JOY_BUTTON_RIGHT_SHOULDER,
]


func _nombres(lista: Array[String]) -> Array[String]:
	return lista


func test_un_nombre_de_playstation_es_playstation() -> void:  # AC-CFG-043
	for nombre: String in [
		"PS4 Controller",
		"DualSense Wireless Controller",
		"Sony Interactive Entertainment Wireless Controller",
		"Wireless Controller (STANDARD GAMEPAD Vendor: 054c Product: 09cc)",
	]:
		assert_int(FamiliaDeJoystick.de_el_nombre(nombre)).is_equal(PLAYSTATION)


func test_un_nombre_de_nintendo_es_nintendo() -> void:  # AC-CFG-043
	for nombre: String in [
		"Nintendo Switch Pro Controller",
		"Joy-Con (L)",
		"Pro Controller (STANDARD GAMEPAD Vendor: 057e Product: 2009)",
	]:
		assert_int(FamiliaDeJoystick.de_el_nombre(nombre)).is_equal(NINTENDO)


func test_un_nombre_de_xbox_o_desconocido_o_vacio_es_xbox() -> void:  # AC-CFG-043
	for nombre: String in ["Xbox 360 Controller", "Controller (XInput)", "Gamepad genérico", ""]:
		assert_int(FamiliaDeJoystick.de_el_nombre(nombre)).is_equal(XBOX)


func test_sin_joystick_es_xbox() -> void:  # AC-CFG-043
	assert_int(FamiliaDeJoystick.de_los_nombres([])).is_equal(XBOX)


func test_con_varios_joysticks_manda_el_primero_de_la_lista() -> void:  # AC-CFG-043
	(
		assert_int(
			FamiliaDeJoystick.de_los_nombres(_nombres(["PS4 Controller", "Xbox Controller"]))
		)
		. is_equal(PLAYSTATION)
	)
	(
		assert_int(
			FamiliaDeJoystick.de_los_nombres(_nombres(["Xbox Controller", "PS4 Controller"]))
		)
		. is_equal(XBOX)
	)


func test_xbox_rotula_los_botones_de_cara_con_sus_letras() -> void:  # AC-CFG-044
	assert_str(FamiliaDeJoystick.rotulo_de(XBOX, JOY_BUTTON_A)).is_equal("A")
	assert_str(FamiliaDeJoystick.rotulo_de(XBOX, JOY_BUTTON_B)).is_equal("B")
	assert_str(FamiliaDeJoystick.rotulo_de(XBOX, JOY_BUTTON_X)).is_equal("X")
	assert_str(FamiliaDeJoystick.rotulo_de(XBOX, JOY_BUTTON_Y)).is_equal("Y")


func test_nintendo_rotula_las_letras_en_su_posicion() -> void:  # AC-CFG-044
	assert_str(FamiliaDeJoystick.rotulo_de(NINTENDO, JOY_BUTTON_A)).is_equal(
		FamiliaDeJoystick.rotulo_de(XBOX, JOY_BUTTON_B)
	)
	assert_str(FamiliaDeJoystick.rotulo_de(NINTENDO, JOY_BUTTON_B)).is_equal(
		FamiliaDeJoystick.rotulo_de(XBOX, JOY_BUTTON_A)
	)
	assert_str(FamiliaDeJoystick.rotulo_de(NINTENDO, JOY_BUTTON_X)).is_equal(
		FamiliaDeJoystick.rotulo_de(XBOX, JOY_BUTTON_Y)
	)
	assert_str(FamiliaDeJoystick.rotulo_de(NINTENDO, JOY_BUTTON_Y)).is_equal(
		FamiliaDeJoystick.rotulo_de(XBOX, JOY_BUTTON_X)
	)


func test_playstation_rotula_sus_nombres_de_siempre() -> void:  # AC-CFG-044
	for par: Array in [
		[JOY_BUTTON_A, "X"],
		[JOY_BUTTON_B, "CÍRCULO"],
		[JOY_BUTTON_X, "CUADRADO"],
		[JOY_BUTTON_Y, "TRIÁNGULO"],
		[JOY_BUTTON_LEFT_SHOULDER, "L1"],
		[JOY_BUTTON_RIGHT_SHOULDER, "R1"],
		[JOY_BUTTON_LEFT_STICK, "L3"],
		[JOY_BUTTON_RIGHT_STICK, "R3"],
		[JOY_BUTTON_START, "START"],
	]:
		assert_str(FamiliaDeJoystick.rotulo_de(PLAYSTATION, par[0])).is_equal(par[1])


func test_xbox_rotula_hombros_palancas_y_start() -> void:  # AC-CFG-044
	for par: Array in [
		[JOY_BUTTON_LEFT_SHOULDER, "LB"],
		[JOY_BUTTON_RIGHT_SHOULDER, "RB"],
		[JOY_BUTTON_LEFT_STICK, "LS"],
		[JOY_BUTTON_RIGHT_STICK, "RS"],
		[JOY_BUTTON_START, "MENU"],
	]:
		assert_str(FamiliaDeJoystick.rotulo_de(XBOX, par[0])).is_equal(par[1])


func test_nintendo_rotula_hombros_palancas_y_start() -> void:  # AC-CFG-044
	for par: Array in [
		[JOY_BUTTON_LEFT_SHOULDER, "L"],
		[JOY_BUTTON_RIGHT_SHOULDER, "R"],
		[JOY_BUTTON_LEFT_STICK, "LS"],
		[JOY_BUTTON_RIGHT_STICK, "RS"],
		[JOY_BUTTON_START, "+"],
	]:
		assert_str(FamiliaDeJoystick.rotulo_de(NINTENDO, par[0])).is_equal(par[1])


func test_cada_familia_rotula_distinto_cada_boton() -> void:  # AC-CFG-044
	for familia: FamiliaDeJoystick.Familia in [XBOX, PLAYSTATION, NINTENDO]:
		var vistos: Array[String] = []
		for boton: int in BOTONES_CON_ROTULO:
			var rotulo := FamiliaDeJoystick.rotulo_de(familia, boton)
			assert_str(rotulo).is_not_empty()
			assert_array(vistos).not_contains([rotulo])
			vistos.append(rotulo)


func test_un_boton_sin_rotulo_contesta_vacio() -> void:  # AC-CFG-044
	assert_str(FamiliaDeJoystick.rotulo_de(XBOX, JOY_BUTTON_TOUCHPAD)).is_empty()
