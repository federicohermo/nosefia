## El nodo de la pausa: traduce Esc y la pérdida del cursor a la pregunta de `Pausa`, y pausa el
## árbol.
##
## **El reloj del turno no sabe que existe la pausa.** Se detiene porque el árbol está en pausa y
## el motor deja de llamarlo. Este nodo corre siempre, también en pausa, para poder reanudar.
##
## El cursor se mide a los dos lados de la escritura del jugador: lo de antes, después de su paso
## de física; lo de ahora, antes del paso siguiente. Lo que cambia en el medio no lo cambió el
## juego: en la web, es el navegador que se comió Esc para soltar el cursor.
class_name ControlDePausa
extends Node

signal pausado
signal reanudado
signal volver_al_menu_pedido

## La placa del cierre, mirada sólo por si está en pantalla.
@export var placa: CanvasLayer

var _cursor_antes := false
var _menu_pedido := false
var _ventana_activa := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Después del jugador, que escribe el modo del cursor en su paso de física.
	process_physics_priority = 1000


## El cuadro de física es del árbol, no del nodo: al salir de la escena el nodo queda fuera del
## árbol unos cuadros antes de liberarse, y la señal lo seguiría llamando.
func _enter_tree() -> void:
	get_tree().physics_frame.connect(_mirar_el_cursor)


func _exit_tree() -> void:
	get_tree().physics_frame.disconnect(_mirar_el_cursor)


func _input(evento: InputEvent) -> void:
	if not evento.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	_hacer(Pausa.ante_esc(get_tree().paused, _placa_en_pantalla()))


func _physics_process(_delta: float) -> void:
	_cursor_antes = _cursor_tomado()


## Cambiar de pestaña también suelta el cursor; no equivale a pedir la pausa con Esc.
func _notification(aviso: int) -> void:
	if aviso == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_ventana_activa = false
		_cursor_antes = false
	elif aviso == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_ventana_activa = true
		_cursor_antes = false


func _mirar_el_cursor() -> void:
	var accion := Pausa.ante_el_cursor(
		get_tree().paused, _placa_en_pantalla(), _cursor_antes, _cursor_tomado(), _ventana_activa
	)
	_hacer(accion)


func _hacer(accion: Pausa.Accion) -> void:
	var acciones: Dictionary[Pausa.Accion, Callable] = {
		Pausa.Accion.NADA: func() -> void: pass,
		Pausa.Accion.PAUSAR: pausar,
		Pausa.Accion.REANUDAR: reanudar,
	}
	acciones[accion].call()


## Detiene el árbol y suelta el cursor. No guarda qué modo tenía: al reanudar, el jugador vuelve
## a pedir el que le da el dominio.
func pausar() -> void:
	if get_tree().paused:
		return
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_cursor_antes = false
	pausado.emit()


func reanudar() -> void:
	if not get_tree().paused:
		return
	get_tree().paused = false
	reanudado.emit()


## Sale de la pausa **antes** de pedir el menú: con el árbol en pausa, el menú de inicio
## arrancaría congelado.
func pedir_volver_al_menu() -> void:
	if _menu_pedido:
		return
	_menu_pedido = true
	get_tree().paused = false
	volver_al_menu_pedido.emit()


func _placa_en_pantalla() -> bool:
	return placa != null and placa.visible


func _cursor_tomado() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
