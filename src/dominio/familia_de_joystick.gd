## De qué marca es el joystick conectado, y cómo rotula cada botón esa marca.
##
## La familia sale del nombre que el joystick dice de sí mismo. El navegador lo informa con el
## fabricante adentro, y por eso también se reconoce por él. Lo que no se reconoce es Xbox. Los
## botones se identifican por su posición, como hace el motor: el de abajo es siempre
## `JOY_BUTTON_A`, y Nintendo lo rotula B.
class_name FamiliaDeJoystick
extends RefCounted

enum Familia { XBOX, PLAYSTATION, NINTENDO }

const MARCAS_DE_PLAYSTATION: Array[String] = [
	"playstation", "ps3", "ps4", "ps5", "dualshock", "dualsense", "sony", "054c"
]
const MARCAS_DE_NINTENDO: Array[String] = [
	"nintendo", "switch", "joy-con", "joycon", "pro controller", "057e"
]

## Lo que se lee igual en toda familia.
const ROTULOS_COMUNES: Dictionary[int, String] = {
	JOY_BUTTON_GUIDE: "GUÍA",
	JOY_BUTTON_DPAD_UP: "CRUCETA ARRIBA",
	JOY_BUTTON_DPAD_DOWN: "CRUCETA ABAJO",
	JOY_BUTTON_DPAD_LEFT: "CRUCETA IZQUIERDA",
	JOY_BUTTON_DPAD_RIGHT: "CRUCETA DERECHA",
}

const ROTULOS: Dictionary[Familia, Dictionary] = {
	Familia.PLAYSTATION:
	{
		JOY_BUTTON_A: "X",
		JOY_BUTTON_B: "CÍRCULO",
		JOY_BUTTON_X: "CUADRADO",
		JOY_BUTTON_Y: "TRIÁNGULO",
		JOY_BUTTON_BACK: "SELECT",
		JOY_BUTTON_START: "START",
		JOY_BUTTON_LEFT_STICK: "L3",
		JOY_BUTTON_RIGHT_STICK: "R3",
		JOY_BUTTON_LEFT_SHOULDER: "L1",
		JOY_BUTTON_RIGHT_SHOULDER: "R1",
	},
	Familia.XBOX:
	{
		JOY_BUTTON_A: "A",
		JOY_BUTTON_B: "B",
		JOY_BUTTON_X: "X",
		JOY_BUTTON_Y: "Y",
		JOY_BUTTON_BACK: "VIEW",
		JOY_BUTTON_START: "MENU",
		JOY_BUTTON_LEFT_STICK: "LS",
		JOY_BUTTON_RIGHT_STICK: "RS",
		JOY_BUTTON_LEFT_SHOULDER: "LB",
		JOY_BUTTON_RIGHT_SHOULDER: "RB",
	},
	Familia.NINTENDO:
	{
		JOY_BUTTON_A: "B",
		JOY_BUTTON_B: "A",
		JOY_BUTTON_X: "Y",
		JOY_BUTTON_Y: "X",
		JOY_BUTTON_BACK: "-",
		JOY_BUTTON_START: "+",
		JOY_BUTTON_LEFT_STICK: "LS",
		JOY_BUTTON_RIGHT_STICK: "RS",
		JOY_BUTTON_LEFT_SHOULDER: "L",
		JOY_BUTTON_RIGHT_SHOULDER: "R",
	},
}

## Cómo se rotula el gatillo derecho: el de arriba del hombro derecho.
const ROTULOS_DEL_GATILLO_DERECHO: Dictionary[Familia, String] = {
	Familia.PLAYSTATION: "R2",
	Familia.XBOX: "RT",
	Familia.NINTENDO: "ZR",
}


## La familia que dice un nombre de joystick.
static func de_el_nombre(nombre: String) -> Familia:
	var minuscula := nombre.to_lower()
	for marca: String in MARCAS_DE_PLAYSTATION:
		if marca in minuscula:
			return Familia.PLAYSTATION
	for marca: String in MARCAS_DE_NINTENDO:
		if marca in minuscula:
			return Familia.NINTENDO
	return Familia.XBOX


## La familia de los joysticks conectados, con sus nombres en el orden de conexión: manda el
## primero. Sin ninguno es Xbox.
static func de_los_nombres(nombres: Array[String]) -> Familia:
	if nombres.is_empty():
		return Familia.XBOX
	return de_el_nombre(nombres[0])


## Cómo se lee un botón en esa familia, o vacío si no tiene rótulo.
static func rotulo_de(familia: Familia, boton: int) -> String:
	var propios: Dictionary = ROTULOS[familia]
	var rotulo: String = propios.get(boton, ROTULOS_COMUNES.get(boton, ""))
	return rotulo


## Cómo se lee el gatillo derecho en esa familia.
static func rotulo_del_gatillo(familia: Familia) -> String:
	return ROTULOS_DEL_GATILLO_DERECHO[familia]
