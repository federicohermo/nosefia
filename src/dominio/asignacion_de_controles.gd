## Qué tecla, qué botón del mouse o qué botón del joystick hace cada acción reasignable.
##
## Cada acción tiene una o más **ranuras** estables: Movimiento tiene dos por dirección, la de WASD
## y la de flechas; las cinco acciones de botón tienen la de teclado o mouse y la del joystick; y
## Pausa una. Una entrada es un par de números, el tipo y el código físico de la tecla o el índice
## del botón: acá no se nombra `InputEvent`. Una ranura del joystick sólo acepta un botón del
## joystick, y las demás no lo aceptan.
##
## **Una entrada nunca está en dos ranuras.** Asignar una que ya tiene otra ranura las intercambia,
## y por eso ninguna acción queda sin entrada.
##
## El esquema de fábrica es el de `project.godot`: lo declaran los mismos números, y un test los
## cruza con el `InputMap` recién cargado.
class_name AsignacionDeControles
extends RefCounted

enum TipoDeEntrada { TECLA, BOTON_DEL_MOUSE, BOTON_DEL_JOYSTICK }

const ADELANTE := &"mover_adelante"
const ATRAS := &"mover_atras"
const IZQUIERDA := &"mover_izquierda"
const DERECHA := &"mover_derecha"
const CELULAR := &"celular"
const EXAMINAR := &"examinar"
const AGACHARSE := &"agacharse"
const AGARRAR := &"agarrar"
const INTERACTUAR := ReglasDelJugador.ACCION_USAR
## Pausa es la acción con la que el motor cierra: Configuraciones y las listas desplegables.
const PAUSA := &"ui_cancel"

## El orden en que se muestran.
const ACCIONES: Array[StringName] = [
	ADELANTE, ATRAS, IZQUIERDA, DERECHA, CELULAR, EXAMINAR, AGACHARSE, AGARRAR, INTERACTUAR, PAUSA
]
const DIRECCIONES: Array[StringName] = [ADELANTE, ATRAS, IZQUIERDA, DERECHA]

const RANURA_DE_WASD := 0
const RANURA_DE_FLECHAS := 1
## Las acciones de botón: las cinco que además tienen un botón de joystick, en esta ranura.
const ACCIONES_CON_BOTON: Array[StringName] = [CELULAR, EXAMINAR, AGACHARSE, AGARRAR, INTERACTUAR]
const RANURA_DEL_JOYSTICK := 1
## START es la pausa del joystick: no se reasigna, y apretarlo cancela la espera de un botón.
const BOTON_DE_PAUSA := JOY_BUTTON_START

## Los índices de botón del mouse son los de `MouseButton`: el dominio no nombra el motor.
const BOTON_IZQUIERDO := 1
const BOTON_DERECHO := 2
const BOTON_CENTRAL := 3
const BOTON_LATERAL_ATRAS := 8
const BOTON_LATERAL_ADELANTE := 9

## Mover el mouse y la rueda no son entradas: la rueda es un botón con índice, y queda afuera.
const BOTONES_ACEPTADOS: Array[int] = [
	BOTON_IZQUIERDO,
	BOTON_DERECHO,
	BOTON_CENTRAL,
	BOTON_LATERAL_ATRAS,
	BOTON_LATERAL_ADELANTE,
]

## Cómo se lee cada botón aceptado. Lo leen la pantalla de controles y la referencia del HUD.
const NOMBRES_DE_LOS_BOTONES: Dictionary[int, String] = {
	BOTON_IZQUIERDO: "Click Izq",
	BOTON_DERECHO: "Click Der",
	BOTON_CENTRAL: "Click Central",
	BOTON_LATERAL_ATRAS: "Click Atrás",
	BOTON_LATERAL_ADELANTE: "Click Adelante",
}

## Las cuatro direcciones se nombran por la dirección: juntas son un solo «Movimiento».
const NOMBRES: Dictionary = {
	ADELANTE: "ADELANTE",
	ATRAS: "ATRÁS",
	IZQUIERDA: "IZQUIERDA",
	DERECHA: "DERECHA",
	CELULAR: "ABRIR LA INTERFAZ DEL CELULAR",
	EXAMINAR: "EXAMINAR",
	AGACHARSE: "AGACHARSE",
	AGARRAR: "AGARRAR / SOLTAR",
	INTERACTUAR: "INTERACTUAR",
	PAUSA: "PAUSA",
}

## Los botones del joystick, con los nombres de PlayStation de la ficha.
const NOMBRES_DE_LOS_BOTONES_DEL_JOYSTICK: Dictionary[int, String] = {
	JOY_BUTTON_A: "X",
	JOY_BUTTON_B: "CÍRCULO",
	JOY_BUTTON_X: "CUADRADO",
	JOY_BUTTON_Y: "TRIÁNGULO",
	JOY_BUTTON_BACK: "SELECT",
	JOY_BUTTON_GUIDE: "GUÍA",
	JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "L1",
	JOY_BUTTON_RIGHT_SHOULDER: "R1",
	JOY_BUTTON_DPAD_UP: "CRUCETA ARRIBA",
	JOY_BUTTON_DPAD_DOWN: "CRUCETA ABAJO",
	JOY_BUTTON_DPAD_LEFT: "CRUCETA IZQUIERDA",
	JOY_BUTTON_DPAD_RIGHT: "CRUCETA DERECHA",
}

## Cada entrada es un `Vector2i(tipo, código)`. Las de una acción van por ranura.
const DE_FABRICA: Dictionary = {
	ADELANTE: [Vector2i(TipoDeEntrada.TECLA, KEY_W), Vector2i(TipoDeEntrada.TECLA, KEY_UP)],
	ATRAS: [Vector2i(TipoDeEntrada.TECLA, KEY_S), Vector2i(TipoDeEntrada.TECLA, KEY_DOWN)],
	IZQUIERDA: [Vector2i(TipoDeEntrada.TECLA, KEY_A), Vector2i(TipoDeEntrada.TECLA, KEY_LEFT)],
	DERECHA: [Vector2i(TipoDeEntrada.TECLA, KEY_D), Vector2i(TipoDeEntrada.TECLA, KEY_RIGHT)],
	CELULAR:
	[
		Vector2i(TipoDeEntrada.TECLA, KEY_Q),
		Vector2i(TipoDeEntrada.BOTON_DEL_JOYSTICK, JOY_BUTTON_B)
	],
	EXAMINAR:
	[
		Vector2i(TipoDeEntrada.TECLA, KEY_E),
		Vector2i(TipoDeEntrada.BOTON_DEL_JOYSTICK, JOY_BUTTON_X)
	],
	AGACHARSE:
	[
		Vector2i(TipoDeEntrada.TECLA, KEY_SPACE),
		Vector2i(TipoDeEntrada.BOTON_DEL_JOYSTICK, JOY_BUTTON_LEFT_SHOULDER)
	],
	AGARRAR:
	[
		Vector2i(TipoDeEntrada.BOTON_DEL_MOUSE, BOTON_IZQUIERDO),
		Vector2i(TipoDeEntrada.BOTON_DEL_JOYSTICK, JOY_BUTTON_A)
	],
	INTERACTUAR:
	[
		Vector2i(TipoDeEntrada.BOTON_DEL_MOUSE, BOTON_DERECHO),
		Vector2i(TipoDeEntrada.BOTON_DEL_JOYSTICK, JOY_BUTTON_RIGHT_SHOULDER)
	],
	PAUSA: [Vector2i(TipoDeEntrada.TECLA, KEY_ESCAPE)],
}

## Lo que no se puede leer.
const ILEGIBLE := Vector2i(-1, -1)

## Acción → `Array` de `Vector2i`, una por ranura.
var _entradas: Dictionary = DE_FABRICA.duplicate(true)


## Cuántas ranuras tiene la acción. Una acción que no se reasigna tiene cero.
static func ranuras_de(accion: StringName) -> int:
	if accion in DIRECCIONES or accion in ACCIONES_CON_BOTON:
		return 2
	return 1 if accion in ACCIONES else 0


## Si esa ranura es la del botón del joystick de una de las cinco acciones de botón.
static func es_del_joystick(accion: StringName, ranura: int) -> bool:
	return accion in ACCIONES_CON_BOTON and ranura == RANURA_DEL_JOYSTICK


## El nombre del grupo en pantalla: las cuatro direcciones son un solo «Movimiento».
static func nombre_de_la_accion(accion: StringName) -> String:
	if accion in DIRECCIONES:
		return "MOVIMIENTO"
	var nombre: String = NOMBRES.get(accion, "")
	return nombre


## Si la ranura de esa acción acepta la entrada. En la web, Esc sólo lo acepta Pausa: con el
## cursor tomado el navegador se come Esc, y cualquier otra acción no se podría hacer. La ranura
## del joystick sólo acepta un botón, y START no: es la pausa. Un eje o un gatillo analógico no es
## un botón.
static func acepta(
	accion: StringName, tipo: int, codigo: int, en_la_web: bool = false, ranura: int = 0
) -> bool:
	if accion not in ACCIONES:
		return false
	if es_del_joystick(accion, ranura) or tipo == TipoDeEntrada.BOTON_DEL_JOYSTICK:
		return (
			es_del_joystick(accion, ranura)
			and tipo == TipoDeEntrada.BOTON_DEL_JOYSTICK
			and codigo >= JOY_BUTTON_A
			and codigo < JOY_BUTTON_SDL_MAX
			and codigo != BOTON_DE_PAUSA
		)
	if tipo == TipoDeEntrada.BOTON_DEL_MOUSE:
		return codigo in BOTONES_ACEPTADOS
	if tipo != TipoDeEntrada.TECLA or codigo <= KEY_NONE or codigo > KEY_CODE_MASK:
		return false
	return not (en_la_web and codigo == KEY_ESCAPE and accion != PAUSA)


## Si apretar esa entrada cancela la espera de una entrada nueva: es la que tiene Pausa, o START.
## Cancelar no cambia nada, y se distingue de una entrada que no se acepta, que deja seguir
## esperando.
func cancela_la_espera(tipo: int, codigo: int) -> bool:
	var pausa: Vector2i = _entradas[PAUSA][0]
	var apretada := Vector2i(tipo, codigo)
	return (
		apretada == pausa or apretada == Vector2i(TipoDeEntrada.BOTON_DEL_JOYSTICK, BOTON_DE_PAUSA)
	)


## Cada entrada con su acción y su ranura, en el orden en que se muestran.
func entradas() -> Array[Dictionary]:
	var todas: Array[Dictionary] = []
	for accion: StringName in ACCIONES:
		for ranura: int in ranuras_de(accion):
			todas.append(entrada(accion, ranura))
	return todas


func entrada(accion: StringName, ranura: int) -> Dictionary:
	var guardada: Vector2i = _entradas[accion][ranura]
	return {"accion": accion, "ranura": ranura, "tipo": guardada.x, "codigo": guardada.y}


## Deja la entrada en esa ranura. Contesta si algo cambió: una acción o ranura que no existe, una
## entrada que no acepta, o la que la ranura ya tiene no cambian nada. Si otra ranura tenía la
## entrada, recibe la que tenía ésta.
func asignar(
	accion: StringName, ranura: int, tipo: TipoDeEntrada, codigo: int, en_la_web: bool = false
) -> bool:
	if (
		ranura < 0
		or ranura >= ranuras_de(accion)
		or not acepta(accion, tipo, codigo, en_la_web, ranura)
	):
		return false
	var nueva := Vector2i(tipo, codigo)
	var propias: Array = _entradas[accion]
	var anterior: Vector2i = propias[ranura]
	if anterior == nueva:
		return false
	var otra := _ranura_con(nueva)
	if not otra.is_empty():
		var de_la_otra: StringName = otra["accion"]
		if not acepta(de_la_otra, anterior.x, anterior.y, en_la_web, otra["ranura"]):
			return false
		_entradas[de_la_otra][otra["ranura"]] = anterior
	propias[ranura] = nueva
	return true


func copia() -> AsignacionDeControles:
	var otra := AsignacionDeControles.new()
	otra._entradas = _entradas.duplicate(true)
	return otra


## Cada acción con sus entradas por ranura, como números.
func datos() -> Dictionary:
	var salida := {}
	for accion: StringName in ACCIONES:
		var lista: Array = []
		for guardada: Vector2i in _entradas[accion]:
			lista.append({"tipo": guardada.x, "codigo": guardada.y})
		salida[String(accion)] = lista
	return salida


## Se carga sobre las ranuras de fábrica y se valida el conjunto. Una entrada ilegible, o de una
## acción que no existe, deja la ranura en su entrada de fábrica. Si el resultado deja una entrada
## en dos ranuras, se descarta el bloque entero: nunca queda un esquema parcial.
static func desde(crudo: Dictionary) -> AsignacionDeControles:
	var leida := AsignacionDeControles.new()
	for accion: StringName in ACCIONES:
		var lista: Variant = crudo.get(String(accion))
		if lista is not Array:
			continue
		var guardadas: Array = lista
		for ranura: int in mini(guardadas.size(), ranuras_de(accion)):
			var candidata := _leer(accion, ranura, guardadas[ranura])
			if candidata != ILEGIBLE:
				leida._entradas[accion][ranura] = candidata
	if leida._hay_repetidas():
		return AsignacionDeControles.new()
	return leida


static func _leer(accion: StringName, ranura: int, crudo: Variant) -> Vector2i:
	if crudo is not Dictionary:
		return ILEGIBLE
	var campos: Dictionary = crudo
	var tipo: Variant = campos.get("tipo")
	var codigo: Variant = campos.get("codigo")
	if typeof(tipo) != TYPE_INT or typeof(codigo) != TYPE_INT:
		return ILEGIBLE
	if not acepta(accion, int(tipo), int(codigo), false, ranura):
		return ILEGIBLE
	return Vector2i(int(tipo), int(codigo))


## La acción y la ranura que tienen esa entrada, o vacío si ninguna.
func _ranura_con(buscada: Vector2i) -> Dictionary:
	for accion: StringName in ACCIONES:
		var guardadas: Array = _entradas[accion]
		for ranura: int in guardadas.size():
			if guardadas[ranura] == buscada:
				return {"accion": accion, "ranura": ranura}
	return {}


func _hay_repetidas() -> bool:
	var vistas: Dictionary = {}
	for accion: StringName in ACCIONES:
		for guardada: Vector2i in _entradas[accion]:
			if vistas.has(guardada):
				return true
			vistas[guardada] = true
	return false
