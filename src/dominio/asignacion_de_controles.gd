## Qué tecla o qué botón del mouse hace cada acción reasignable.
##
## Cada acción tiene una o más **ranuras** estables: Movimiento tiene dos por dirección, la de WASD
## y la de flechas, y las demás una. Una entrada es un par de números, el tipo y el código físico
## de la tecla o el índice del botón: acá no se nombra `InputEvent`.
##
## **Una entrada nunca está en dos ranuras.** Asignar una que ya tiene otra ranura las intercambia,
## y por eso ninguna acción queda sin entrada.
##
## El esquema de fábrica es el de `project.godot`: lo declaran los mismos números, y un test los
## cruza con el `InputMap` recién cargado.
class_name AsignacionDeControles
extends RefCounted

enum TipoDeEntrada { TECLA, BOTON_DEL_MOUSE }

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

const NOMBRES: Dictionary = {
	ADELANTE: "MOVIMIENTO ADELANTE",
	ATRAS: "MOVIMIENTO ATRÁS",
	IZQUIERDA: "MOVIMIENTO IZQUIERDA",
	DERECHA: "MOVIMIENTO DERECHA",
	CELULAR: "ABRIR LA INTERFAZ DEL CELULAR",
	EXAMINAR: "EXAMINAR",
	AGACHARSE: "AGACHARSE",
	AGARRAR: "AGARRAR / SOLTAR",
	INTERACTUAR: "INTERACTUAR",
	PAUSA: "PAUSA",
}
const NOMBRES_DE_LAS_RANURAS: Array[String] = ["WASD", "FLECHAS"]

## Cada entrada es un `Vector2i(tipo, código)`. Las de una acción van por ranura.
const DE_FABRICA: Dictionary = {
	ADELANTE: [Vector2i(TipoDeEntrada.TECLA, KEY_W), Vector2i(TipoDeEntrada.TECLA, KEY_UP)],
	ATRAS: [Vector2i(TipoDeEntrada.TECLA, KEY_S), Vector2i(TipoDeEntrada.TECLA, KEY_DOWN)],
	IZQUIERDA: [Vector2i(TipoDeEntrada.TECLA, KEY_A), Vector2i(TipoDeEntrada.TECLA, KEY_LEFT)],
	DERECHA: [Vector2i(TipoDeEntrada.TECLA, KEY_D), Vector2i(TipoDeEntrada.TECLA, KEY_RIGHT)],
	CELULAR: [Vector2i(TipoDeEntrada.TECLA, KEY_Q)],
	EXAMINAR: [Vector2i(TipoDeEntrada.TECLA, KEY_E)],
	AGACHARSE: [Vector2i(TipoDeEntrada.TECLA, KEY_SPACE)],
	AGARRAR: [Vector2i(TipoDeEntrada.BOTON_DEL_MOUSE, BOTON_IZQUIERDO)],
	INTERACTUAR: [Vector2i(TipoDeEntrada.BOTON_DEL_MOUSE, BOTON_DERECHO)],
	PAUSA: [Vector2i(TipoDeEntrada.TECLA, KEY_ESCAPE)],
}

## Lo que no se puede leer.
const ILEGIBLE := Vector2i(-1, -1)

## Acción → `Array` de `Vector2i`, una por ranura.
var _entradas: Dictionary = DE_FABRICA.duplicate(true)


## Cuántas ranuras tiene la acción. Una acción que no se reasigna tiene cero.
static func ranuras_de(accion: StringName) -> int:
	if accion in DIRECCIONES:
		return 2
	return 1 if accion in ACCIONES else 0


## El nombre del grupo en pantalla: las cuatro direcciones son un solo «Movimiento».
static func nombre_de_la_accion(accion: StringName) -> String:
	if accion in DIRECCIONES:
		return "MOVIMIENTO"
	var nombre: String = NOMBRES.get(accion, "")
	return nombre


## El nombre del renglón: el de la acción, y en Movimiento también la ranura.
static func nombre_en_pantalla(accion: StringName, ranura: int) -> String:
	var nombre: String = NOMBRES.get(accion, "")
	if accion in DIRECCIONES:
		return "%s (%s)" % [nombre, NOMBRES_DE_LAS_RANURAS[ranura]]
	return nombre


## Si la ranura de esa acción acepta la entrada. En la web, Esc sólo lo acepta Pausa: con el
## cursor tomado el navegador se come Esc, y cualquier otra acción no se podría hacer.
static func acepta(accion: StringName, tipo: int, codigo: int, en_la_web: bool = false) -> bool:
	if accion not in ACCIONES:
		return false
	if tipo == TipoDeEntrada.BOTON_DEL_MOUSE:
		return codigo in BOTONES_ACEPTADOS
	if tipo != TipoDeEntrada.TECLA or codigo <= KEY_NONE or codigo > KEY_CODE_MASK:
		return false
	return not (en_la_web and codigo == KEY_ESCAPE and accion != PAUSA)


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
	if ranura < 0 or ranura >= ranuras_de(accion) or not acepta(accion, tipo, codigo, en_la_web):
		return false
	var nueva := Vector2i(tipo, codigo)
	var propias: Array = _entradas[accion]
	var anterior: Vector2i = propias[ranura]
	if anterior == nueva:
		return false
	var otra := _ranura_con(nueva)
	if not otra.is_empty():
		var de_la_otra: StringName = otra["accion"]
		if not acepta(de_la_otra, anterior.x, anterior.y, en_la_web):
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
			var candidata := _leer(accion, guardadas[ranura])
			if candidata != ILEGIBLE:
				leida._entradas[accion][ranura] = candidata
	if leida._hay_repetidas():
		return AsignacionDeControles.new()
	return leida


static func _leer(accion: StringName, crudo: Variant) -> Vector2i:
	if crudo is not Dictionary:
		return ILEGIBLE
	var campos: Dictionary = crudo
	var tipo: Variant = campos.get("tipo")
	var codigo: Variant = campos.get("codigo")
	if typeof(tipo) != TYPE_INT or typeof(codigo) != TYPE_INT:
		return ILEGIBLE
	if not acepta(accion, int(tipo), int(codigo)):
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
