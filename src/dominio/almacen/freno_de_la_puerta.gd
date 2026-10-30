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
## La hoja gira sobre un canto del vano: a `angulo`, su proyección sobre el vano mide
## `largo * cos + espesor * sin`, y lo que sobra del vano es el hueco. Con un vano al que la
## hoja cerrada apenas entra, el hueco crece con el ángulo.
static func angulo_de_paso(largo: float, espesor: float, vano: float) -> float:
	var libre := vano - ANCHO_DEL_JUGADOR - MARGEN_DEL_PASO
	if libre >= largo:
		return 0.0
	var radio := Vector2(largo, espesor).length()
	var angulo := atan2(espesor, largo) + acos(clampf(libre / radio, -1.0, 1.0))
	return minf(deg_to_rad(ceilf(rad_to_deg(angulo))), Puerta.ANGULO_ABIERTA)
