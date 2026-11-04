## El movimiento vertical del celular: sube y baja con un resorte suave tipo «Gentle».
##
## La curva pasa levemente de su destino y se asienta. Bajar usa la misma curva, así que su
## rebote queda fuera del encuadre. Un recorrido interrumpido parte de la posición actual.
class_name RecorridoDelCelular
extends RefCounted

## Segundos reales de un recorrido completo, rebote incluido.
const DURACION := 0.25
## Cuánto se pasa la curva de su destino: es el parámetro de sobrepaso de una curva de resorte,
## sin unidad. Con 1.0 se pasa menos de un 4 % del recorrido.
const SOBREPASO := 1.0

var _desde: float = 0.0
var _hacia: float = 0.0
var _duracion: float = 0.0
var _transcurrido: float = 0.0


## Una posición de 0 es fuera del margen inferior, y 1, el centro del encuadre.
func ir_a(destino: float) -> void:
	_desde = posicion()
	_hacia = destino
	_duracion = DURACION * minf(1.0, absf(destino - _desde))
	_transcurrido = 0.0


func avanzar(segundos: float) -> void:
	_transcurrido = minf(_transcurrido + segundos, _duracion)


func posicion() -> float:
	if llego():
		return _hacia
	return lerpf(_desde, _hacia, _curva(_transcurrido / _duracion))


func destino() -> float:
	return _hacia


## Con tolerancia: los pasos sumados de a cuadros no siempre dan la duración exacta.
func llego() -> bool:
	return _transcurrido >= _duracion or is_equal_approx(_transcurrido, _duracion)


static func _curva(progreso: float) -> float:
	var resto := progreso - 1.0
	return 1.0 + (SOBREPASO + 1.0) * pow(resto, 3.0) + SOBREPASO * pow(resto, 2.0)
