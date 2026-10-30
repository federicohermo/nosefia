## Cuánto frena un obstáculo a la hoja de una puerta, y dónde la detiene.
##
## **La escena sólo mide el contacto y la movilidad**; qué pesa y cuándo se frena lo decide
## esto, donde se prueba sin levantar una escena.
class_name FrenoDeLaPuerta
extends RefCounted

## Lo que la hoja encuentra en su próximo paso. Pesado es lo que el jugador empuja; liviano, lo
## demás que se agarra.
enum Obstaculo { NADA, LIVIANO, PESADO }

## Metros. El diámetro de la cápsula del jugador.
const ANCHO_DEL_JUGADOR := 0.8

## Metros de aire que se le piden al paso además del ancho del jugador.
const MARGEN_DEL_PASO := 0.05

## Fracción de la velocidad del giro que conserva la hoja contra algo pesado que se corre. Es
## tacto provisional, sin valor de balance aprobado.
const FACTOR_DE_LO_PESADO := 0.4

## Con qué velocidad gira la hoja, como fracción de la vigente.
var factor := 1.0

## El ángulo donde se detiene la hoja, o `Puerta.SIN_TOPE`.
var tope := Puerta.SIN_TOPE


func _init(factor_del_giro: float = 1.0, tope_del_giro: float = Puerta.SIN_TOPE) -> void:
	factor = factor_del_giro
	tope = tope_del_giro


## Lo que la hoja hace con el obstáculo que tiene en su próximo paso.
##
## Contra algo pesado e inmóvil la hoja se queda donde está, pero sólo si ahí todavía deja pasar:
## por debajo de `angulo_de_paso` atraviesa lo que toca y la red de seguridad lo rescata.
static func decidir(
	obstaculo: Obstaculo, puede_correrse: bool, angulo: float, angulo_de_paso: float
) -> FrenoDeLaPuerta:
	if obstaculo != Obstaculo.PESADO:
		return FrenoDeLaPuerta.new()
	if puede_correrse:
		return FrenoDeLaPuerta.new(FACTOR_DE_LO_PESADO)
	if angulo >= angulo_de_paso or is_equal_approx(angulo, angulo_de_paso):
		return FrenoDeLaPuerta.new(1.0, angulo)
	return FrenoDeLaPuerta.new()


## El menor ángulo, en grados enteros, al que la hoja deja al jugador pasar por el vano.
##
## `contorno` son los vértices de la hoja cerrada: `x` a lo largo del vano desde la bisagra, `y`
## a lo ancho de la hoja desde su eje. La hoja gira `sentido` (1 o -1) y lo que avanza a lo largo
## del vano es lo que le quita al hueco. Con un vano al que la hoja cerrada apenas entra, el hueco
## crece con el ángulo.
static func angulo_de_paso(contorno: PackedVector2Array, vano: float, sentido: float) -> float:
	var libre := vano - ANCHO_DEL_JUGADOR - MARGEN_DEL_PASO
	for grados in roundi(rad_to_deg(Puerta.ANGULO_ABIERTA)):
		var angulo := deg_to_rad(grados)
		var avance := -INF
		for punto in contorno:
			avance = maxf(avance, punto.x * cos(angulo) - punto.y * sin(angulo) * sentido)
		if avance <= libre:
			return angulo
	return Puerta.ANGULO_ABIERTA
