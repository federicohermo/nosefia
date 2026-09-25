## Cuánto del mouse falta dibujar todavía.
##
## Un mouse de 125 Hz no llega en todos los cuadros de una pantalla de 144: medido, uno de cada
## cinco o seis cuadros viene sin movimiento. La cámara no giraba en ése y giraba el doble en el
## siguiente, y eso se ve como escalones. Acá cada reporte se muestra parejo a lo largo de una
## ventana.
##
## **Suaviza el dibujo, no la mirada.** La mirada del control gira entera en cuanto llega el
## mouse: hacia adónde se camina y qué se enfoca no esperan. La cámara se dibuja atrás de ella lo
## que devuelve `pendiente()`.
class_name SuavizadoDelGiro
extends RefCounted

## Segundos en que se muestra cada reporte: cuatro cuadros a 144 Hz. El giro dibujado queda entre
## 0,86 y 1,15 veces el parejo, y atrasa en promedio la mitad de la ventana.
const VENTANA := 0.028

var _ventana: float

## Cada reporte con el tiempo que lleva mostrándose: `[relativo: Vector2, transcurrido: float]`.
var _reportes: Array[Array] = []


## La ventana entra por parámetro, igual que en `Mirada`: un test la arma redonda.
func _init(ventana: float) -> void:
	_ventana = ventana


func agregar(relativo: Vector2) -> void:
	if relativo != Vector2.ZERO:
		_reportes.append([relativo, 0.0])


## `delta` entra por parámetro y no se lee del motor: así se prueba sin levantar una escena.
func avanzar(delta: float) -> void:
	for reporte in _reportes:
		reporte[1] += delta
	_reportes = _reportes.filter(func(reporte: Array) -> bool: return reporte[1] < _ventana)


func pendiente() -> Vector2:
	var falta := Vector2.ZERO
	for reporte in _reportes:
		falta += reporte[0] * (1.0 - reporte[1] / _ventana)
	return falta
