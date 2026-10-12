## Lo que el jugador ajusta y cruza sesiones, aparte de la partida: dos volúmenes, el brillo y la
## letra de la interfaz, y la sensibilidad del mouse.
##
## Cada preferencia se guarda como **cuántos pasos está por encima de su mínimo**, no como el
## número: así diez + seguidos de 0,1 caen exactamente en el tope, sin el error de sumar
## decimales, y arrastrar una barra cae en el mismo valor que los botones.
##
## Cada defecto es el juego de hoy: ningún volumen pasa de 0 dB, y la sensibilidad y la letra de
## fábrica se multiplican por uno.
class_name Preferencias
extends RefCounted

enum Campo { EFECTOS, MUSICA, BRILLO, SENSIBILIDAD, TEXTOS }

## El orden en que se muestran: el de la ficha.
const CAMPOS: Array[Campo] = [
	Campo.EFECTOS, Campo.MUSICA, Campo.BRILLO, Campo.SENSIBILIDAD, Campo.TEXTOS
]

## Rango, paso y defecto de cada una, decididos por el dueño en #378. Los volúmenes y el brillo
## van en por ciento; la sensibilidad y la letra, en veces.
const MINIMOS: Dictionary[Campo, float] = {
	Campo.EFECTOS: 0.0,
	Campo.MUSICA: 0.0,
	Campo.BRILLO: 50.0,
	Campo.SENSIBILIDAD: 0.25,
	Campo.TEXTOS: 0.8,
}
const PASOS: Dictionary[Campo, float] = {
	Campo.EFECTOS: 10.0,
	Campo.MUSICA: 10.0,
	Campo.BRILLO: 10.0,
	Campo.SENSIBILIDAD: 0.25,
	Campo.TEXTOS: 0.1,
}
## Cuántos pasos hay del mínimo al máximo.
const TRAMOS: Dictionary[Campo, int] = {
	Campo.EFECTOS: 10,
	Campo.MUSICA: 10,
	Campo.BRILLO: 10,
	Campo.SENSIBILIDAD: 7,
	Campo.TEXTOS: 7,
}
const DEFECTOS: Dictionary[Campo, float] = {
	Campo.EFECTOS: 100.0,
	Campo.MUSICA: 100.0,
	Campo.BRILLO: 100.0,
	Campo.SENSIBILIDAD: 1.0,
	Campo.TEXTOS: 1.0,
}

## Las claves del archivo. Son texto y no el número del `enum`: reordenarlo no puede cambiar qué
## valor se lee en cada campo.
const CLAVES: Dictionary[Campo, String] = {
	Campo.EFECTOS: "efectos",
	Campo.MUSICA: "musica",
	Campo.BRILLO: "brillo",
	Campo.SENSIBILIDAD: "sensibilidad",
	Campo.TEXTOS: "textos",
}

## Un volumen en 0 % se calla del todo; este es el número que acompaña al silencio.
const DECIBELIOS_DEL_SILENCIO := -80.0

## Cuánto puede pasarse un número leído de su tope y seguir contando como adentro: lo que deja
## escribir y leer un decimal.
const TOLERANCIA := 1e-4

var _pasos: Dictionary[Campo, int] = {}


func _init() -> void:
	for campo: Campo in CAMPOS:
		_pasos[campo] = _pasos_hasta(campo, DEFECTOS[campo])


static func minimo(campo: Campo) -> float:
	return MINIMOS[campo]


static func maximo(campo: Campo) -> float:
	return MINIMOS[campo] + TRAMOS[campo] * PASOS[campo]


static func paso(campo: Campo) -> float:
	return PASOS[campo]


func valor(campo: Campo) -> float:
	return MINIMOS[campo] + _pasos[campo] * PASOS[campo]


## Sube un paso. En el máximo no cambia nada, y contesta que no cambió.
func sumar(campo: Campo) -> bool:
	if _pasos[campo] >= TRAMOS[campo]:
		return false
	_pasos[campo] += 1
	return true


## Baja un paso. En el mínimo no cambia nada, y contesta que no cambió.
func restar(campo: Campo) -> bool:
	if _pasos[campo] <= 0:
		return false
	_pasos[campo] -= 1
	return true


## Deja la preferencia en el valor posible más cercano a `nuevo`, dentro de su rango, y lo
## devuelve. Es lo que hace arrastrar una barra.
func poner(campo: Campo, nuevo: float) -> float:
	_pasos[campo] = _pasos_hasta(campo, nuevo)
	return valor(campo)


## Proporcional a la amplitud: en v % el bus suena a v/100 de la amplitud de hoy.
func decibelios(campo: Campo) -> float:
	if en_silencio(campo):
		return DECIBELIOS_DEL_SILENCIO
	return 20.0 * log(valor(campo) / 100.0) / log(10.0)


func en_silencio(campo: Campo) -> bool:
	return _pasos[campo] == 0 and is_zero_approx(MINIMOS[campo])


## Los radianes por píxel del giro de la vista y del examen: la sensibilidad de fábrica por la
## elegida.
func sensibilidad_del_giro() -> float:
	return ReglasDelJugador.SENSIBILIDAD_DEL_MOUSE * valor(Campo.SENSIBILIDAD)


func copia() -> Preferencias:
	var otra := Preferencias.new()
	otra._pasos = _pasos.duplicate()
	return otra


## Los cinco valores, cada uno como número decimal y con su clave de texto.
func datos() -> Dictionary:
	var salida := {}
	for campo: Campo in CAMPOS:
		salida[CLAVES[campo]] = valor(campo)
	return salida


## Sanea igual que la partida: un campo que falta, de otro tipo o fuera de su rango vuelve con su
## defecto, sin descartar los demás. Un número adentro del rango pero entre dos pasos cae en el
## más cercano, igual que al arrastrar; la regla la deja abierta `OQ-CFG-004`.
static func desde(crudo: Dictionary) -> Preferencias:
	var preferencias := Preferencias.new()
	for campo: Campo in CAMPOS:
		var leido: Variant = crudo.get(CLAVES[campo])
		if _legible(campo, leido):
			preferencias.poner(campo, float(leido))
	return preferencias


static func _legible(campo: Campo, leido: Variant) -> bool:
	if typeof(leido) != TYPE_FLOAT and typeof(leido) != TYPE_INT:
		return false
	var numero := float(leido)
	if is_nan(numero):
		return false
	return numero >= minimo(campo) - TOLERANCIA and numero <= maximo(campo) + TOLERANCIA


static func _pasos_hasta(campo: Campo, nuevo: float) -> int:
	return clampi(roundi((nuevo - MINIMOS[campo]) / PASOS[campo]), 0, TRAMOS[campo])
