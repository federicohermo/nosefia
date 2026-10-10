## Cablea las cinco hojas existentes a una sola vista y al control del jugador.
extends Node

const JugadorDelLocal := preload("res://src/escenas/jugador.gd")
const NotaDelLocal := preload("res://src/escenas/objetos/nota_pegada.gd")

@export var jugador: JugadorDelLocal
@export var reloj: RelojDelTurno
@export var vista: NotaEncuadrada
@export var notas: Array[NotaDelLocal]

var _abierta := false


func _ready() -> void:
	for nota in notas:
		var dato := (
			NotaPegada.tareas_a_realizar(Apertura.obligatorias())
			if nota.id == NotaPegada.Id.TAREAS_A_REALIZAR
			else NotaPegada.de(nota.id)
		)
		nota.declarar(dato)
		nota.apertura_pedida.connect(_abrir.bind(nota))
	reloj.turno_cerrado.connect(_al_cerrar_el_turno)


func _abrir(nota: NotaDelLocal) -> void:
	_abierta = true
	vista.mostrar(nota.dato(), nota.imagen())
	jugador.suspender()


func cerrar() -> void:
	if not _abierta:
		return
	_abierta = false
	vista.ocultar()
	jugador.reanudar()


func _input(evento: InputEvent) -> void:
	if _abierta and evento.is_action_pressed(ReglasDelJugador.ACCION_USAR):
		get_viewport().set_input_as_handled()
		cerrar()


func _al_cerrar_el_turno(_cumplidas: int) -> void:
	cerrar()
