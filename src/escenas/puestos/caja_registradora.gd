## Cablea el programa y coloca los papeles en la ranura a escala física real.
extends StaticBody3D

const JugadorDelLocal := preload("res://src/escenas/jugador.gd")
const PAPEL := preload("res://src/escenas/objetos/ticket.tscn")

@export var jugador: JugadorDelLocal
@export var reloj: RelojDelTurno
@export var caja: CajaRegistradora
@export var programa: ProgramaDeTickets
@export var ranura: Marker3D
@export var destino_de_los_tickets: Node3D
@export var mallas: Array[MeshInstance3D]

var _abierta := false
var _en_ranura: ObjetoAgarrable
var _tickets: Array[ObjetoAgarrable] = []


func _ready() -> void:
	caja.renglones_cambiados.connect(_repintar)
	caja.ticket_impreso.connect(_al_imprimir)
	programa.borrado_pedido.connect(caja.pedir_borrar)
	programa.impresion_pedida.connect(caja.pedir_imprimir)
	reloj.turno_cerrado.connect(_al_cerrar_el_turno)
	jugador.agarre.objeto_agarrado.connect(_al_agarrar)


func accionar() -> void:
	abrir()


func abrir() -> void:
	_abierta = true
	programa.mostrar(caja.generador().renglones())
	jugador.suspender()


func cerrar() -> void:
	if not _abierta:
		return
	_abierta = false
	programa.ocultar()
	jugador.reanudar()


func _input(evento: InputEvent) -> void:
	if _abierta and evento.is_action_pressed(ReglasDelJugador.ACCION_USAR):
		get_viewport().set_input_as_handled()
		cerrar()


func _repintar() -> void:
	if _abierta:
		programa.mostrar(caja.generador().renglones())


func _al_cerrar_el_turno(_cumplidas: int) -> void:
	cerrar()


func _al_imprimir(dato: Ticket) -> void:
	if is_instance_valid(_en_ranura):
		_en_ranura.freeze = false
		_en_ranura.sleeping = false
	var papel: ObjetoAgarrable = PAPEL.instantiate()
	papel.datos = dato
	papel.freeze = true
	# El modelo tiene escala: no se hereda al papel ni a su colisión. El origen se fija
	# antes de entrar al árbol, porque lo leen _ready y la red de seguridad.
	papel.transform = (
		destino_de_los_tickets.global_transform.affine_inverse()
		* ranura.global_transform.orthonormalized()
	)
	destino_de_los_tickets.add_child(papel)
	_tickets.append(papel)
	_en_ranura = papel


func _al_agarrar(objeto: Node3D) -> void:
	if objeto == _en_ranura:
		_en_ranura = null


func limpiar() -> void:
	for papel in _tickets:
		if is_instance_valid(papel):
			papel.queue_free()
	_tickets.clear()
	_en_ranura = null
