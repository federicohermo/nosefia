## Cuánto frena un obstáculo a la hoja de una puerta, y dónde la detiene.
##
## **La escena sólo mide el contacto y la movilidad**; qué pesa y cuándo se frena lo decide
## esto, donde se prueba sin levantar una escena.
class_name FrenoDeLaPuerta
extends RefCounted

## Lo que la hoja encuentra en su próximo paso. Pesado es lo que el jugador empuja; liviano, lo
## demás que se agarra.
enum Obstaculo { NADA, LIVIANO, PESADO }

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
## Contra algo pesado e inmóvil la hoja se queda donde está, a cualquier ángulo.
static func decidir(obstaculo: Obstaculo, puede_correrse: bool, angulo: float) -> FrenoDeLaPuerta:
	if obstaculo != Obstaculo.PESADO:
		return FrenoDeLaPuerta.new()
	if puede_correrse:
		return FrenoDeLaPuerta.new(FACTOR_DE_LO_PESADO)
	return FrenoDeLaPuerta.new(1.0, angulo)
