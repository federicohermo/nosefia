## El estado del control del jugador: compone la mirada, la caminata y el foco, y los suspende
## JUNTOS.
##
## Suspender es una sola llamada porque quien la hace no conoce las partes: la ventanilla —y
## también la computadora— tiene que poder decir «el jugador no controla» sin enterarse de que
## adentro hay un yaw, un vector de entrada y un rayo. Con tres interruptores sueltos, cada spec
## que suspenda al jugador tiene que acordarse de los tres, y el día que aparezca un cuarto hay
## que volver a tocarlos a todos.
class_name ControlDelJugador
extends RefCounted

var _mirada: Mirada
var _foco := Foco.new()
var _velocidad_maxima: float
var _suspendido: bool = false


## Recibe la `Mirada` ya armada en vez de armarla: es lo que deja que un test la construya con
## una sensibilidad de números redondos sin tocar `ReglasDelJugador`.
func _init(mirada: Mirada, velocidad_maxima: float) -> void:
	_mirada = mirada
	_velocidad_maxima = velocidad_maxima


## Apaga a la vez la caminata, la mirada, el foco de la mira y el pedido de tener el cursor
## tomado. Y suelta el objetivo enfocado: así `jugador.gd` emite `objetivo_perdido` una sola vez
## y la mira deja de hablar durante toda la atención.
func suspender() -> void:
	_suspendido = true
	_foco.observar(Foco.SIN_OBJETIVO, 0.0, false)


func reanudar() -> void:
	_suspendido = false


func esta_suspendido() -> bool:
	return _suspendido


func girar(delta_del_mouse: Vector2) -> void:
	if _suspendido:
		return
	_mirada.girar(delta_del_mouse)


func velocidad(entrada: Vector2) -> Vector3:
	if _suspendido:
		return Vector3.ZERO
	return Caminata.velocidad(entrada, _mirada.yaw(), _velocidad_maxima)


func observar(id: int, distancia: float, interactuable: bool) -> bool:
	if _suspendido:
		return false
	return _foco.observar(id, distancia, interactuable)


func yaw() -> float:
	return _mirada.yaw()


func pitch() -> float:
	return _mirada.pitch()


func objetivo() -> int:
	return _foco.objetivo()


func hay_interactuable() -> bool:
	return _foco.hay_interactuable()


## Un `bool` y no un `Input.MOUSE_MODE_*`: `dominio/` no nombra `Input`. Es la línea exacta
## donde se parte la traducción — acá se decide SI, en `src/escenas/jugador.gd` se traduce a QUÉ.
func quiere_el_cursor_tomado() -> bool:
	return not _suspendido
