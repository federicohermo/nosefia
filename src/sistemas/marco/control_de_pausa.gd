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
signal cierre_de_configuraciones_pedido
## Esc cerró la foto o el celular. Quien lo escucha devuelve el cursor al juego. Las demás
## interfaces devuelven el cursor ellas mismas, al cerrarse.
signal esc_atendido_por_el_celular

## La devolución del cierre, mirada sólo por si está en pantalla: con ella, perder el cursor no
## pausa. Esc sí: abre la pausa por encima.
@export var placa: CanvasLayer
## Configuraciones abierta desde la pausa, mirada sólo por si está en pantalla. La cierra quien
## la abrió, al recibir `cierre_de_configuraciones_pedido`.
@export var configuraciones: CanvasLayer
## El celular, mirado por si está libre y abierto: entonces Esc lo cierra y no pausa. Lo asigna
## quien arma el almacén.
var celular: CelularDelEmpleado

var _interfaces: Array[Interfaz] = []

var _cursor_antes := false
var _menu_pedido := false
var _ventana_activa := true
## Lo que falta de la gracia que deja un Esc atendido por el celular. Ver `Pausa`.
var _gracia_tras_esc := 0.0


## Una interfaz que Esc cierra: la computadora, la caja o una nota. Cada puesto dice si está
## abierta y cómo cierra con Esc, que no es siempre cerrar del todo.
class Interfaz:
	var abierta: Callable
	var cerrar_con_esc: Callable


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
	_hacer(
		Pausa.ante_esc(
			get_tree().paused,
			_configuraciones_en_pantalla(),
			_celular_libre_abierto(),
			_interfaz_abierta() != null
		)
	)


func _physics_process(delta: float) -> void:
	_gracia_tras_esc = maxf(_gracia_tras_esc - delta, 0.0)
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
		get_tree().paused,
		_placa_en_pantalla(),
		_cursor_antes,
		_cursor_tomado(),
		_ventana_activa,
		_gracia_tras_esc > 0.0
	)
	_hacer(accion)


func _hacer(accion: Pausa.Accion) -> void:
	var acciones: Dictionary[Pausa.Accion, Callable] = {
		Pausa.Accion.NADA: func() -> void: pass,
		Pausa.Accion.PAUSAR: pausar,
		Pausa.Accion.REANUDAR: reanudar,
		Pausa.Accion.CERRAR_CONFIGURACIONES: cierre_de_configuraciones_pedido.emit,
		Pausa.Accion.CERRAR_CELULAR: _cerrar_el_celular,
		Pausa.Accion.CERRAR_INTERFAZ: _cerrar_la_interfaz,
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


func registrar_interfaz(abierta: Callable, cerrar_con_esc: Callable) -> void:
	var interfaz := Interfaz.new()
	interfaz.abierta = abierta
	interfaz.cerrar_con_esc = cerrar_con_esc
	_interfaces.append(interfaz)


func _cerrar_la_interfaz() -> void:
	_gracia_tras_esc = Pausa.GRACIA_TRAS_ESC
	_interfaz_abierta().cerrar_con_esc.call()


func _interfaz_abierta() -> Interfaz:
	for interfaz in _interfaces:
		if interfaz.abierta.call():
			return interfaz
	return null


func _cerrar_el_celular() -> void:
	if celular.pedir_esc():
		_gracia_tras_esc = Pausa.GRACIA_TRAS_ESC
		esc_atendido_por_el_celular.emit()


func _celular_libre_abierto() -> bool:
	return celular != null and celular.celular().abierto() and not celular.celular().fijo()


func _placa_en_pantalla() -> bool:
	return placa != null and placa.visible


func _configuraciones_en_pantalla() -> bool:
	return configuraciones != null and configuraciones.visible


func _cursor_tomado() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
