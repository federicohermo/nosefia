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
const CompradorEnRetirada := preload("res://src/escenas/objetos/comprador_en_retirada.gd")
const ANIMACIONES := {
	DialogosDeCompradores.Personaje.MARTIN: preload("res://assets/characters/martin/idle.tres"),
	DialogosDeCompradores.Personaje.TIAGO: preload("res://assets/characters/tiago/idle.tres"),
}

@export var jugador: JugadorDelLocal
@export var reloj: RelojDelTurno
@export var atenciones: Ventanilla
@export var panel: PanelDeLaVentanilla
@export var borde_superior: Marker3D
@export var antepecho: MeshInstance3D
@export var comprador_visible: AnimatedSprite3D

## Si el vidrio está abierto ahora mismo. Es estado de cáscara —qué ventana hay arriba— y no una
## regla del juego: a quién hay que atender lo sigue contestando el dominio.
var _abierta := false
var _recibidos: Dictionary[Comprador, Array] = {}
var _imagen_de: Atencion = null
var _retiradas: Array[CompradorEnRetirada] = []
var _entrada: Tween
var _posicion_de_espera: Vector3


func _ready() -> void:
	_posicion_de_espera = comprador_visible.position
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
	_detener_entrada()
	comprador_visible.position = _posicion_de_espera
	_limpiar_retiradas()
	_imagen_de = null
	for comprador: Comprador in _recibidos:
		_descartar_recibidos(comprador)
	_recibidos.clear()
	panel.preparar(atenciones.tarea().fisica())
	comprador_visible.hide()
	comprador_visible.stop()
	cerrar()


func _process(_delta: float) -> void:
	if _abierta and comprador_visible.visible:
		_ubicar_blanco()


func _ubicar_blanco() -> void:
	var camara := get_viewport().get_camera_3d()
	if camara == null:
		return
	var centro := comprador_visible.global_position
	var textura := comprador_visible.sprite_frames.get_frame_texture(&"idle", 0)
	var mitad := textura.get_size() * comprador_visible.pixel_size / 2.0
	var area := Rect2(camara.unproject_position(centro), Vector2.ZERO)
	for x: float in [-1.0, 1.0]:
		for y: float in [-1.0, 1.0]:
			var esquina := centro + comprador_visible.global_basis.x * mitad.x * x
			esquina += Vector3.UP * mitad.y * y
			area = area.expand(camara.unproject_position(esquina))
	panel.ubicar_comprador(area)


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
	_mostrar_personaje(atendida)
	if atendida != null and atendida.vendida() and atendida.despachada():
		_descartar_recibidos(atendida.comprador())
	if not _abierta:
		return
	if atenciones.tarea().en_ventanilla() == null:
		panel.mostrar_sin_nadie()
	else:
		panel.mostrar(atendida)
		_ubicar_blanco()


func _mostrar_personaje(atendida: Atencion) -> void:
	if atendida == null or not atendida.fisica() or atendida.despachada():
		if atendida != null and atendida == _imagen_de and comprador_visible.visible:
			_conservar_imagen()
		_imagen_de = null
		_detener_entrada()
		comprador_visible.position = _posicion_de_espera
		comprador_visible.hide()
		comprador_visible.stop()
		return
	var cuadros: SpriteFrames = ANIMACIONES[atendida.comprador().personaje]
	if comprador_visible.sprite_frames != cuadros:
		comprador_visible.sprite_frames = cuadros
		comprador_visible.set_frame_and_progress(0, 0.0)
	comprador_visible.show()
	comprador_visible.play(&"idle")
	if _imagen_de != atendida:
		_iniciar_entrada()
	_imagen_de = atendida


func _iniciar_entrada() -> void:
	_detener_entrada()
	var recorrido := _distancia_hasta_la_pared()
	comprador_visible.position = _posicion_de_espera - comprador_visible.basis.x * recorrido
	_entrada = create_tween()
	_entrada.tween_property(comprador_visible, "position", _posicion_de_espera, recorrido)


func _detener_entrada() -> void:
	if _entrada != null:
		_entrada.kill()
		_entrada = null


func _distancia_hasta_la_pared() -> float:
	var textura := comprador_visible.sprite_frames.get_frame_texture(&"idle", 0)
	return (
		antepecho.get_aabb().size.x / 2.0 + textura.get_width() * comprador_visible.pixel_size / 2.0
	)


func _conservar_imagen() -> void:
	_detener_entrada()
	var imagen := comprador_visible.duplicate(0) as AnimatedSprite3D
	imagen.set_script(CompradorEnRetirada)
	var retirada := imagen as CompradorEnRetirada
	var recorrido := (imagen.position - _posicion_de_espera).dot(imagen.basis.x)
	var limite := _distancia_hasta_la_pared() - recorrido
	retirada.preparar(limite)
	add_child(retirada)
	retirada.set_frame_and_progress(comprador_visible.frame, comprador_visible.frame_progress)
	retirada.play(&"idle")
	_retiradas.append(retirada)


func _limpiar_retiradas() -> void:
	for retirada in _retiradas:
		if is_instance_valid(retirada):
			retirada.hide()
			retirada.queue_free()
	_retiradas.clear()


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
	_detener_entrada()
	comprador_visible.position = _posicion_de_espera
	_limpiar_retiradas()
	_imagen_de = null
	comprador_visible.hide()
	comprador_visible.stop()
	cerrar()
