## Cuánto del mouse falta dibujar todavía.
##
## Un mouse de 125 Hz no llega en todos los cuadros de una pantalla de 144: medido, uno de cada
## cinco o seis cuadros viene sin movimiento. La cámara no giraba en ése y giraba el doble en el
## siguiente, y eso se ve como escalones. Con un mouse así, cada reporte se muestra parejo a lo
## largo de una ventana.
##
## **Sólo se suaviza un mouse más lento que la pantalla.** Suavizar atrasa la cámara media ventana,
## y la puntería empeora con la demora aun por debajo de 20 ms (Spjut, Boudaoud y Kim, 2021,
## arXiv 2105.10498). Un mouse que llega en cada cuadro no tiene escalones: se dibuja sin demora.
##
## **Suaviza el dibujo, no la mirada.** La mirada del control gira entera en cuanto llega el
## mouse: hacia adónde se camina no espera. La cámara se dibuja atrás de ella lo que devuelve
## `pendiente()`.
class_name SuavizadoDelGiro
extends RefCounted

## Segundos en que se muestra cada reporte de un mouse lento: cuatro cuadros a 144 Hz. El giro
## dibujado queda entre 0,86 y 1,15 veces el parejo.
const VENTANA := 0.028

## Qué parte de los cuadros de un giro puede llegar sin mouse antes de suavizar. Un mouse de
## 125 Hz deja vacío el 13 % a 144 cuadros; uno de 1000 Hz, ninguno.
const HUECOS_ADMITIDOS := 0.05

## Cuánto pesa cada cuadro nuevo en la cuenta de huecos: se ajusta en unos veinte cuadros.
const PESO_DE_UN_CUADRO := 0.05

## Segundos sin mouse que ya no son un hueco del giro sino una pausa. Un mouse de 125 Hz deja
## hasta dos cuadros vacíos seguidos a 144.
const PAUSA := 0.025

var _ventana: float
var _suavizando := false
var _huecos := 0.0
var _llego := false
var _vacios := 0
var _desde_el_ultimo := INF

## Cada reporte con el tiempo que lleva mostrándose: `[relativo: Vector2, transcurrido: float]`.
var _reportes: Array[Array] = []


## La ventana entra por parámetro, igual que en `Mirada`: un test la arma redonda.
func _init(ventana: float) -> void:
	_ventana = ventana


func agregar(relativo: Vector2) -> void:
	if relativo == Vector2.ZERO:
		return
	_llego = true
	if _suavizando:
		_reportes.append([relativo, 0.0])


func avanzar(delta: float) -> void:
	_contar_el_cuadro(delta)
	for reporte in _reportes:
		reporte[1] += delta
	_reportes = _reportes.filter(func(reporte: Array) -> bool: return reporte[1] < _ventana)
	# Se cambia de modo sólo sin nada pendiente: si no, lo que faltaba dibujar saltaría de golpe.
	if _reportes.is_empty():
		_suavizando = _huecos > HUECOS_ADMITIDOS


func pendiente() -> Vector2:
	var falta := Vector2.ZERO
	for reporte in _reportes:
		falta += reporte[0] * (1.0 - reporte[1] / _ventana)
	return falta


## Un cuadro vacío es un hueco sólo si el mouse vuelve enseguida. Si no, era una pausa, y frenar
## no hace pasar a un mouse rápido por lento.
func _contar_el_cuadro(delta: float) -> void:
	if not _llego:
		_vacios += 1
		_desde_el_ultimo += delta
		return
	if _desde_el_ultimo < PAUSA:
		for vacio in _vacios:
			_huecos = lerpf(_huecos, 1.0, PESO_DE_UN_CUADRO)
	_huecos = lerpf(_huecos, 0.0, PESO_DE_UN_CUADRO)
	_llego = false
	_vacios = 0
	_desde_el_ultimo = delta
