## Una de las puertas del local: si está abierta y cuánto le falta al giro de la hoja.
##
## Va en `almacen/` y no en `ambiente/` porque una puerta cerrada cambia **cuánto cuesta cumplir
## una obligatoria**: la zona de descarte de la basura está del otro lado de una de las dos, así
## que con la hoja trabada esa tarea no se puede cumplir. No es cómo se siente la noche.
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


## La deja cerrada y sin giro, sin pasar por `avanzar()`. Es la apertura de la jornada: una
## puerta que se cerrara girando arrastraría lo que tiene adelante antes de que el jugador haga
## nada.
func cerrar_de_golpe() -> void:
	_abierta = false
	_angulo = 0.0
	_quieta = true


## Acerca la hoja al tope que le toca y devuelve dónde quedó.
##
## Los segundos entran como parámetro y no se leen de ningún reloj: es lo que deja probar el
## giro entero, los dos topes incluidos, sin un solo cuadro.
func avanzar(segundos: float) -> float:
	var destino := ANGULO_ABIERTA if _abierta else 0.0
	var antes := _angulo
	_angulo = move_toward(_angulo, destino, VELOCIDAD_DEL_GIRO * segundos)
	_quieta = is_equal_approx(_angulo, antes)
	return _angulo


## Si la hoja no giró en el último `avanzar()`. No dice si llegó al tope: una hoja frenada no
## llegaría nunca, y la consulta tiene que seguir sirviendo entonces.
func quieta() -> bool:
	return _quieta
