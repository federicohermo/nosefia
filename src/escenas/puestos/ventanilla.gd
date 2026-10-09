## La ventanilla que se ve: el vidrio por el que se atiende. Cablea y nada más.
##
## **No decide nada sobre el juego.** A quién hay que atender, cuánto marca la caja y cuándo la
## obligatoria queda cumplida son preguntas del dominio; qué señal va con qué método es lo único
## que se decide acá.
##
## El jugador encuadra sólo su cámara por una puerta propia, sin escribir el cuerpo desde acá.
## El control conserva sus ángulos; al salir la vista recupera su reposo y su orientación efectiva.
## Dintel y antepecho se leen a su profundidad real; la base enterrada no es visible.
##
## **El reloj está acá para cerrar el panel cuando la noche termina**, no para pausarlo: si la
## ventanilla se quedara abierta encima de la placa de cierre, el jugador vería las dos y no
## tendría cómo sacar la de arriba.
##
## Va en `puestos/` y no en `objetos/`, que es el criterio de esa carpeta —cuántas instancias
## hay—: hay una sola y llega cableada.
extends StaticBody3D

## El script del jugador se preloadea para poder tiparlo: los scripts de `escenas/` son cáscara y
## no declaran `class_name`, así que sin esto el tipo estático sería `CharacterBody3D` y llamarle
## `suspender()` no compilaría.
const JugadorDelLocal := preload("res://src/escenas/jugador.gd")

@export var jugador: JugadorDelLocal
@export var reloj: RelojDelTurno
@export var atenciones: Ventanilla
@export var panel: PanelDeLaVentanilla
@export var borde_superior: Marker3D
@export var antepecho: MeshInstance3D

## Si el vidrio está abierto ahora mismo. Es estado de cáscara —qué ventana hay arriba— y no una
## regla del juego: a quién hay que atender lo sigue contestando el dominio.
var _abierta := false
var _recibidos: Dictionary[Comprador, Array] = {}


func _ready() -> void:
	reloj.turno_cerrado.connect(_al_cerrar_el_turno)
	panel.cobro_pedido.connect(atenciones.pedir_cobrar)
	panel.despacho_pedido.connect(atenciones.pedir_despachar_sin_vender)
	atenciones.comprador_llegado.connect(_al_llegar_un_comprador)
	atenciones.cobro_rechazado.connect(_al_rechazarse_el_cobro)
	atenciones.atencion_despachada.connect(_al_despacharse)
	atenciones.ventanilla_vacia.connect(panel.mostrar_sin_nadie)
	atenciones.presentacion_cambiada.connect(_repintar)
	atenciones.comprador_vencido.connect(_al_vencer)
	atenciones.jornada_preparada.connect(_al_preparar)
	panel.comprador_pulsado.connect(_al_pulsar)


func _al_preparar() -> void:
	for comprador: Comprador in _recibidos:
		_descartar_recibidos(comprador)
	_recibidos.clear()
	panel.preparar(atenciones.tarea().fisica())
	cerrar()


func _al_pulsar() -> void:
	var comprador := atenciones.tarea().en_ventanilla()
	if comprador == null:
		return
	var resultado := atenciones.pedir_interaccion(jugador.agarre.manos().sostenido())
	if resultado in [RecepcionDeCompra.Resultado.ACEPTADA, RecepcionDeCompra.Resultado.COMPLETA]:
		var nodo := jugador.agarre.entregar()
		if nodo != null:
			nodo.reparent(self)
			nodo.hide()
			nodo.set_meta(&"recibido_por_comprador", true)
			if not _recibidos.has(comprador):
				_recibidos[comprador] = []
			_recibidos[comprador].append(nodo)
	_repintar()


func _repintar() -> void:
	var atendida := atenciones.atencion()
	if atendida != null and atendida.vendida() and atendida.despachada():
		_descartar_recibidos(atendida.comprador())
	if not _abierta:
		return
	if atenciones.tarea().en_ventanilla() == null:
		panel.mostrar_sin_nadie()
	else:
		panel.mostrar(atendida)


func _descartar_recibidos(comprador: Comprador) -> void:
	for nodo: Node3D in _recibidos.get(comprador, []):
		if is_instance_valid(nodo) and not nodo.is_queued_for_deletion():
			nodo.queue_free()
	_recibidos[comprador] = []


func _al_vencer(comprador: Comprador) -> void:
	_descartar_recibidos(comprador)
	_repintar()


## El clic derecho abre lo fijo.
func accionar() -> void:
	abrir()


## Clava al jugador delante del vidrio y pide a quien corresponda.
func abrir() -> void:
	_abierta = true
	var referencia := borde_superior.global_transform
	var soporte: AABB = (
		referencia.affine_inverse() * antepecho.global_transform * antepecho.get_aabb()
	)
	var tamano := Vector2(soporte.size.x, -soporte.end.y)
	var profundidad := -soporte.position.z
	var marco := referencia
	marco.origin = referencia * Vector3(soporte.get_center().x, -tamano.y / 2.0, -profundidad / 2.0)
	jugador.asomarse(marco, tamano, profundidad)
	jugador.suspender()
	atenciones.pedir_abrir()


## Cierra una vez y devuelve el control.
func cerrar() -> void:
	if not _abierta:
		return
	_abierta = false
	panel.ocultar()
	jugador.dejar_de_asomarse()
	jugador.reanudar()


## Atiende el cierre antes de que la interfaz reciba el gesto.
func _input(evento: InputEvent) -> void:
	if _abierta and evento.is_action_pressed(ReglasDelJugador.ACCION_USAR):
		get_viewport().set_input_as_handled()
		if atenciones.puede_abandonar():
			cerrar()


func _al_llegar_un_comprador(_comprador: Comprador) -> void:
	_repintar()


## Un cobro rechazado repinta la misma atención: el aviso de lo que falta lo arma el dominio, así
## que acá no hay que traducir la lista a un cartel.
func _al_rechazarse_el_cobro(_faltantes: Array[Producto]) -> void:
	panel.mostrar(atenciones.atencion())


## Despachado el comprador, el vidrio queda vacío hasta que el jugador vuelva a tocar.
func _al_despacharse(_despachados: int) -> void:
	if not atenciones.tarea().fisica():
		panel.mostrar_sin_nadie()


func _al_cerrar_el_turno(_cumplidas: int) -> void:
	cerrar()
