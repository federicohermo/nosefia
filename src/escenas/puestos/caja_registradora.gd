## Cablea el programa y coloca los papeles en la ranura a escala física real.
extends StaticBody3D

const JugadorDelLocal := preload("res://src/escenas/jugador.gd")
const PAPEL := preload("res://src/escenas/objetos/ticket.tscn")
const EscrituraDelTicket := preload("res://src/escenas/objetos/escritura_del_ticket.gd")
const MODELO_DEL_PAPEL := preload("res://assets/models/ticket_impreso.res")
const ANCHO_DEL_MODELO := 0.074995

@export var jugador: JugadorDelLocal
@export var agarre: Agarre
@export var reloj: RelojDelTurno
@export var caja: CajaRegistradora
@export var programa: ProgramaDeTickets
@export var ranura: Marker3D
@export var destino_de_los_tickets: Node3D
@export var mallas: Array[MeshInstance3D]
@export var ancho_del_papel: float = ANCHO_DEL_MODELO

var _abierta := false
var _en_ranura: ObjetoAgarrable
var _papel: ObjetoAgarrable
var _tickets: Array[ObjetoAgarrable] = []
var _salida: Tween
var _fin_de_salida := Vector3.ZERO
var _restante := Reglas.DURACION_DEL_TURNO


func _ready() -> void:
	caja.renglones_cambiados.connect(_repintar)
	caja.ticket_impreso.connect(_al_imprimir)
	programa.borrado_pedido.connect(caja.pedir_borrar)
	programa.impresion_pedida.connect(_imprimir_desde_entrada)
	programa.eleccion_pedida.connect(caja.pedir_elegir)
	programa.cierre_pedido.connect(_cerrar_desde_entrada)
	reloj.turno_cerrado.connect(_al_cerrar_el_turno)
	reloj.tiempo_consumido.connect(func(restante: float) -> void: _restante = restante)
	caja.programa_arrancado.connect(
		func(_manual: bool) -> void: _restante = Reglas.DURACION_DEL_TURNO
	)
	jugador.examen.examen_iniciado.connect(_al_examinar)
	jugador.examen.examen_terminado.connect(_al_terminar_el_examen)
	agarre.objeto_agarrado.connect(_al_agarrar)
	agarre.objeto_soltado.connect(_al_soltar)
	jugador.uso_pedido.connect(_al_usar)
	jugador.consultar_interaccion_con(_contexto_del_descarte)
	_agregar_papel_para_calentar()


## El papel real entra recién al imprimir. Este, oculto y sin colisión, deja su material a la vista
## del calentamiento de shaders, que lo dibuja con el resto del local, detrás de la carga. En el
## grupo de lo interactuable para que el calentamiento le ponga también el contorno de foco.
func _agregar_papel_para_calentar() -> void:
	var cuerpo := RigidBody3D.new()
	cuerpo.add_to_group(ReglasDelJugador.GRUPO_INTERACTUABLE)
	cuerpo.freeze = true
	cuerpo.collision_layer = 0
	cuerpo.collision_mask = 0
	cuerpo.add_child(EscrituraDelTicket.papel_para_calentar(MODELO_DEL_PAPEL))
	add_child(cuerpo)


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
		_cerrar_desde_entrada()


func _cerrar_desde_entrada() -> void:
	cerrar()
	jugador.tomar_el_cursor_desde_entrada()


func _imprimir_desde_entrada() -> void:
	caja.pedir_imprimir(_restante)
	jugador.tomar_el_cursor_desde_entrada()


func _repintar() -> void:
	if _abierta:
		programa.mostrar(caja.generador())


func _al_cerrar_el_turno(_cumplidas: int) -> void:
	cerrar()


func _al_imprimir(dato: Ticket) -> void:
	cerrar()
	_detener_salida()
	if is_instance_valid(_en_ranura):
		_en_ranura.global_position = _fin_de_salida
		_en_ranura.freeze = false
		_en_ranura.sleeping = false
	var papel: ObjetoAgarrable = PAPEL.instantiate()
	var factor := ancho_del_papel / ANCHO_DEL_MODELO
	(papel.get_node("Malla") as MeshInstance3D).scale *= factor
	(papel.get_node("Forma") as CollisionShape3D).scale *= factor
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
	_fin_de_salida = papel.global_position
	papel.global_position -= ranura.global_basis.orthonormalized().y * 0.121548 * factor
	_salida = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_salida.tween_property(papel, "global_position", _fin_de_salida, 0.8)


func _detener_salida() -> void:
	if _salida != null and _salida.is_valid():
		_salida.kill()
	_salida = null


func _al_agarrar(objeto: Node3D) -> void:
	_papel = null
	var papel := objeto as ObjetoAgarrable
	if papel != null and _tickets.has(papel):
		_papel = papel
		_escalar(papel, ReglasDeLosObjetos.ESCALA_DEL_TICKET_EN_MANO)
	if objeto == _en_ranura:
		_detener_salida()
		_en_ranura = null


func limpiar() -> void:
	_detener_salida()
	_papel = null
	for papel in _tickets:
		if is_instance_valid(papel):
			papel.queue_free()
	_tickets.clear()
	_en_ranura = null


func _al_soltar(objeto: Node3D) -> void:
	_papel = null
	var papel := objeto as ObjetoAgarrable
	if papel != null and _tickets.has(papel):
		_escalar(papel, 1.0)


func _al_examinar(objeto: Node3D) -> void:
	var papel := objeto as ObjetoAgarrable
	if papel != null and _tickets.has(papel):
		_escalar(papel, ReglasDeLosObjetos.ESCALA_DEL_TICKET_AL_EXAMINAR)


func _al_terminar_el_examen() -> void:
	if is_instance_valid(_papel):
		_escalar(_papel, ReglasDeLosObjetos.ESCALA_DEL_TICKET_EN_MANO)


## El cuerpo del papel conserva su tamaño: se escalan su malla y su colisión, como en
## `_al_imprimir`. `1.0` es el tamaño que tiene en el mundo.
func _escalar(papel: ObjetoAgarrable, factor: float) -> void:
	var escala := Vector3.ONE * ancho_del_papel / ANCHO_DEL_MODELO * factor
	(papel.get_node("Malla") as MeshInstance3D).scale = escala
	(papel.get_node("Forma") as CollisionShape3D).scale = escala


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


## Si lo que se lleva se desecha en ese objetivo —el ticket en el inodoro—, sin desecharlo.
func _contexto_del_descarte(
	objetivo: Node3D, sostenido: ObjetoDelAlmacen
) -> ReferenciaDeControles.Contexto:
	if objetivo == null or not objetivo.has_method("destino_del_uso"):
		return null
	var destino: StringName = objetivo.call("destino_del_uso")
	return ReferenciaDeControles.contexto_del_descarte(sostenido, destino)


func tickets_en_el_mundo() -> Array[Node3D]:
	var activos: Array[Node3D] = []
	for papel: ObjetoAgarrable in _tickets:
		if is_instance_valid(papel) and not papel.is_queued_for_deletion():
			activos.append(papel)
	return activos


## Lo que dice la caja registradora al examinarla, sin abrirla.
func texto_al_examinar() -> String:
	return SubtitulosAlExaminar.de_lo_fijo(SubtitulosAlExaminar.CAJA_REGISTRADORA)
