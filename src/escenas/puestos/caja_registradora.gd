## Cablea el programa y coloca los papeles en la ranura a escala física real.
extends StaticBody3D

const JugadorDelLocal := preload("res://src/escenas/jugador.gd")
const PAPEL := preload("res://src/escenas/objetos/ticket.tscn")

@export var jugador: JugadorDelLocal
@export var agarre: Agarre
@export var reloj: RelojDelTurno
@export var caja: CajaRegistradora
@export var programa: ProgramaDeTickets
@export var ranura: Marker3D
@export var destino_de_los_tickets: Node3D
@export var mallas: Array[MeshInstance3D]

var _abierta := false
var _en_ranura: ObjetoAgarrable
var _papel: ObjetoAgarrable
var _tickets: Array[ObjetoAgarrable] = []


func _ready() -> void:
	caja.renglones_cambiados.connect(_repintar)
	caja.ticket_impreso.connect(_al_imprimir)
	programa.borrado_pedido.connect(caja.pedir_borrar)
	programa.impresion_pedida.connect(caja.pedir_imprimir)
	programa.eleccion_pedida.connect(caja.pedir_elegir)
	programa.cierre_pedido.connect(cerrar)
	reloj.turno_cerrado.connect(_al_cerrar_el_turno)
	agarre.objeto_agarrado.connect(_al_agarrar)
	agarre.objeto_soltado.connect(_al_soltar)
	jugador.uso_pedido.connect(_al_usar)


func accionar() -> void:
	abrir()


func abrir() -> void:
	_abierta = true
	programa.mostrar(caja.generador())
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
		programa.mostrar(caja.generador())


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
	_papel = null
	var papel := objeto as ObjetoAgarrable
	if papel != null and _tickets.has(papel):
		_papel = papel
	if objeto == _en_ranura:
		_en_ranura = null


func limpiar() -> void:
	_papel = null
	for papel in _tickets:
		if is_instance_valid(papel):
			papel.queue_free()
	_tickets.clear()
	_en_ranura = null


func _al_soltar(_objeto: Node3D) -> void:
	_papel = null


func _al_usar(objetivo: Node3D) -> void:
	if objetivo == null or not objetivo.has_method("destino_del_uso"):
		return
	if not is_instance_valid(_papel) or not _tickets.has(_papel):
		return
	if _papel.is_queued_for_deletion() or agarre.manos().sostenido() != _papel.datos:
		return
	var destino: StringName = objetivo.call("destino_del_uso")
	var papel := _papel
	if not caja.pedir_desechar(papel.datos, destino):
		return
	var entregado := agarre.entregar()
	if entregado != papel:
		push_error("Descarte sin cuerpo propio sostenido: revisar caja registradora")
		return
	_papel = null
	_tickets.erase(papel)
	if _en_ranura == papel:
		_en_ranura = null
	papel.queue_free()


func tickets_en_el_mundo() -> Array[Node3D]:
	var activos: Array[Node3D] = []
	for papel: ObjetoAgarrable in _tickets:
		if is_instance_valid(papel) and not papel.is_queued_for_deletion():
			activos.append(papel)
	return activos
