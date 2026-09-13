## Yaw y pitch: convertir un delta de mouse en radianes y no dejar que la cámara se dé vuelta.
##
## No sabe a qué nodo van los dos ángulos —el yaw al cuerpo, el pitch a la cámara— y por eso se
## puede ejercer sin levantar una escena, que es lo que la vuelve la única parte del controlador
## de primera persona que tiene test de verdad.
class_name Mirada
extends RefCounted

var _sensibilidad: float
var _pitch_minimo: float
var _pitch_maximo: float
var _yaw: float = 0.0
var _pitch: float = 0.0


## Los tres valores se reciben y no se van a buscar a `ReglasDelJugador`: hace baratos los tests
## —una `Mirada` de prueba se arma con sensibilidad `0.01`, que da números redondos— y deja que
## el balance viva en un solo lugar sin que el dominio lo lea por su cuenta.
func _init(sensibilidad: float, pitch_minimo: float, pitch_maximo: float) -> void:
	_sensibilidad = sensibilidad
	_pitch_minimo = pitch_minimo
	_pitch_maximo = pitch_maximo


## Las dos cuentas son asimétricas a propósito.
func girar(delta_del_mouse: Vector2) -> void:
	# Los dos signos son negativos: mover el mouse a la derecha tiene que girar la vista a la
	# derecha, y en Godot eso es un yaw decreciente porque la rotación positiva alrededor de +Y
	# va al otro lado. Lo mismo para el pitch: bajar el mouse es mirar para abajo.
	#
	# El yaw da la vuelta —girar en redondo es legal, lo que no puede es que el número crezca
	# sin límite— y el pitch se clampea, porque acá el límite es el diseño: pasarse es darse
	# vuelta.
	_yaw = wrapf(_yaw - delta_del_mouse.x * _sensibilidad, -PI, PI)
	_pitch = clampf(_pitch - delta_del_mouse.y * _sensibilidad, _pitch_minimo, _pitch_maximo)


func yaw() -> float:
	return _yaw


func pitch() -> float:
	return _pitch
