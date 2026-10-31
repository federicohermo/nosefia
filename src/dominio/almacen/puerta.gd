## Una de las puertas del local: si está abierta y cuánto le falta al giro de la hoja.
##
## **El ángulo vive acá y no en la escena**, aunque parezca cosa de la hoja: pasarse del tope y
## saltar a él en un cuadro son bugs de aritmética, y acá se prueban sin levantar una escena.
class_name Puerta
extends RefCounted

## Radianes. Un cuarto de vuelta saca la hoja del vano: mide 1,72 m de ancho por 0,23 de
## espesor, el vano 1,70, y abierta de costado su canto deja 1,47 m de paso — de sobra para los
## 0,8 m de la cápsula del jugador.
const ANGULO_ABIERTA := PI / 2.0

## Radianes por segundo. Es tacto, no balance: a esta velocidad la hoja tarda poco más de medio
## segundo en abrirse, que es lo que hace que el gesto se vea y no cueste tiempo del turno.
const VELOCIDAD_DEL_GIRO := 3.0

## Sin límite en el giro: el `tope` que usa `avanzar()` cuando nada detiene la hoja.
const SIN_TOPE := NAN

var _abierta := false
var _angulo := 0.0
var _quieta := true
var _trabada := false


## Trabada es de nacimiento: ninguna puerta se traba ni se destraba en juego.
func _init(trabada: bool = false) -> void:
	_trabada = trabada


## Si quedó pedida abierta. Es la intención, no la hoja: apenas alternada, la puerta ya está
## `abierta()` con el ángulo todavía en cero.
func abierta() -> bool:
	return _abierta


## Cuánto giró la hoja, entre `0.0` y `ANGULO_ABIERTA`.
func angulo() -> float:
	return _angulo


func trabada() -> bool:
	return _trabada


## Un gesto de interacción: la abre si estaba cerrada y la cierra si estaba abierta. Devuelve si
## alternó: una trabada contesta `false` y queda como estaba.
func alternar() -> bool:
	if _trabada:
		return false
	_abierta = not _abierta
	return true


func abrir_para_salida() -> bool:
	if _abierta:
		return false
	_abierta = true
	return true


func cerrar_de_golpe() -> void:
	_abierta = false
	_angulo = 0.0
	_quieta = true


## Dónde quedaría la hoja tras `segundos` de giro sin freno ni tope.
func angulo_siguiente(segundos: float) -> float:
	return move_toward(_angulo, _destino(), VELOCIDAD_DEL_GIRO * segundos)


## Acerca la hoja al tope que le toca y devuelve dónde quedó.
##
## Los segundos entran como parámetro y no se leen de ningún reloj: es lo que deja probar el
## giro entero, los dos topes incluidos, sin un solo cuadro.
##
## `factor` es la fracción de la velocidad que el giro conserva; fuera de (0, 1] vale 1. `tope`
## es el ángulo que la hoja no cruza en el sentido en que gira: sirve igual al abrir y al cerrar,
## y nunca la hace retroceder.
func avanzar(segundos: float, factor: float = 1.0, tope: float = SIN_TOPE) -> float:
	var antes := _angulo
	var paso := VELOCIDAD_DEL_GIRO * segundos
	if factor > 0.0 and factor <= 1.0:
		paso *= factor
	_angulo = move_toward(_angulo, _destino(), paso)
	if not is_nan(tope):
		_angulo = clampf(tope, minf(antes, _angulo), maxf(antes, _angulo))
	_quieta = is_equal_approx(_angulo, antes)
	return _angulo


func _destino() -> float:
	return ANGULO_ABIERTA if _abierta else 0.0


## Si la hoja no giró en el último `avanzar()`.
func quieta() -> bool:
	return _quieta
