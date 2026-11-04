## Cablea las seis hojas existentes a una sola vista y al control del jugador.
extends Node

const JugadorDelLocal := preload("res://src/escenas/jugador.gd")
const NotaDelLocal := preload("res://src/escenas/objetos/nota_pegada.gd")

@export var jugador: JugadorDelLocal
@export var reloj: RelojDelTurno
@export var vista: NotaEncuadrada
@export var notas: Array[NotaDelLocal]

var _abierta := false
var _nota_abierta: NotaDelLocal
var _obligatorias: Array[Tarea] = []


func _ready() -> void:
	for nota in notas:
		nota.declarar(NotaPegada.de(nota.id))
		nota.apertura_pedida.connect(_abrir.bind(nota))
	reloj.turno_cerrado.connect(_al_cerrar_el_turno)
	reloj.tarea_completada.connect(_al_cambiar_una_tarea)
	reloj.tarea_descumplida.connect(_al_cambiar_una_tarea)


func _abrir(nota: NotaDelLocal) -> void:
	_abierta = true
	_nota_abierta = nota
	vista.mostrar(nota.dato(), nota.imagen())
	jugador.suspender()


func cerrar() -> void:
	if not _abierta:
		return
	_abierta = false
	vista.ocultar()
	jugador.reanudar()


func esta_abierta() -> bool:
	return _abierta


## Lo pide el nodo de la pausa. Como el clic derecho: devuelve el cursor al juego.
func cerrar_con_esc() -> void:
	cerrar()
	jugador.tomar_el_cursor_desde_entrada()


func _input(evento: InputEvent) -> void:
	if not _abierta:
		return
	if evento.is_action_pressed(ReglasDelJugador.ACCION_USAR):
		get_viewport().set_input_as_handled()
		cerrar()
		jugador.tomar_el_cursor_desde_entrada()


func _al_cerrar_el_turno(_cumplidas: int) -> void:
	cerrar()


func _al_cambiar_una_tarea(_cumplidas: int) -> void:
	declarar_tareas(_obligatorias)
	if _abierta and _nota_abierta.id == NotaPegada.Id.TAREAS_A_REALIZAR:
		vista.mostrar(_nota_abierta.dato(), null)


func declarar_tareas(obligatorias: Array[Tarea]) -> void:
	_obligatorias = obligatorias
	for nota in notas:
		if nota.id == NotaPegada.Id.TAREAS_A_REALIZAR:
			nota.declarar(NotaPegada.tareas_a_realizar(obligatorias))
