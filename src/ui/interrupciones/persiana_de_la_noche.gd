class_name PersianaDeLaNoche
extends CanvasLayer

signal persiana_subida(jornada: int)
signal sonido_pedido
signal silencio_pedido

const FADE_DE_LA_PERSIANA_BAJA := 0.3

@export var _persiana: TextureRect
@export var _marco: Control
@export var _placa: Label
@export var _movimiento: AudioStreamPlayer

var _entrada: EntradaALaNoche
var _jornada: int
var _ahora: Callable = Time.get_ticks_usec
var _ultimo: int = 0
var _avance_del_fade: float = 0.0
var _negro: ColorRect
var _bajando := false
var _avance_de_la_bajada := 0.0
var _subida_sonando := false


func _ready() -> void:
	visible = false
	set_process(false)
	_negro = ColorRect.new()
	_negro.color = Color.BLACK
	_negro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_negro)
	_negro.hide()
	get_viewport().size_changed.connect(_pintar)


func _notification(que: int) -> void:
	if que == NOTIFICATION_UNPAUSED:
		_ultimo = _ahora.call()


func _process(_delta: float) -> void:
	var ahora: int = _ahora.call()
	var segundos := maxf(0.0, (ahora - _ultimo) / 1000000.0)
	_ultimo = ahora
	if _bajando:
		_avance_de_la_bajada = minf(
			1.0, _avance_de_la_bajada + segundos / EntradaALaNoche.SUBIDA_DE_LA_PERSIANA
		)
		_pintar()
		if _avance_de_la_bajada == 1.0:
			_bajando = false
			_callar()
			set_process(false)
	elif _entrada == null:
		_avance_del_fade = minf(1.0, _avance_del_fade + segundos / FADE_DE_LA_PERSIANA_BAJA)
		_negro.modulate.a = 1.0 - _avance_del_fade
		if _avance_del_fade == 1.0:
			_negro.hide()
			set_process(false)
	else:
		_entrada.avanzar(segundos)
		_pintar()
		if _entrada.apertura_de_la_persiana() > 0.0 and not _subida_sonando:
			_subida_sonando = true
			_sonar()
		if _entrada.terminada():
			_al_terminar()


func mostrar_baja() -> void:
	_callar()
	_bajando = false
	layer = 4
	_entrada = null
	_avance_del_fade = 0.0
	_ultimo = _ahora.call()
	_negro.modulate.a = 1.0
	_negro.show()
	visible = true
	set_process(true)
	_pintar()


func anunciar(jornada: int) -> void:
	_callar()
	_bajando = false
	_subida_sonando = false
	layer = 4
	_jornada = jornada
	_entrada = EntradaALaNoche.new(jornada)
	_ultimo = _ahora.call()
	_negro.hide()
	visible = true
	set_process(true)
	_pintar()


func terminar() -> void:
	if not en_pantalla():
		return
	if _entrada == null:
		_bajando = false
		visible = false
		set_process(false)
		_callar()
		return
	_entrada.avanzar(EntradaALaNoche.DURACION)
	_pintar()
	_al_terminar()


func en_pantalla() -> bool:
	return visible


func bajar() -> void:
	_entrada = null
	_bajando = true
	_avance_de_la_bajada = 0.0
	_ultimo = _ahora.call()
	_negro.hide()
	# El parte actual permanece accesible por encima de la persiana del cierre.
	layer = 1
	visible = true
	set_process(true)
	_pintar()
	_sonar()


func _sonar() -> void:
	_movimiento.pitch_scale = (
		_movimiento.stream.get_length() / EntradaALaNoche.SUBIDA_DE_LA_PERSIANA
	)
	_movimiento.play()
	sonido_pedido.emit()


func _callar() -> void:
	_movimiento.stop()
	silencio_pedido.emit()


func _pintar() -> void:
	var pantalla := get_viewport().get_visible_rect().size
	LienzoDeManada.ajustar(_marco, pantalla)
	_persiana.size = pantalla
	if _bajando:
		_persiana.position = Vector2(0.0, -pantalla.y * (1.0 - _avance_de_la_bajada))
		_placa.hide()
	elif _entrada == null:
		_persiana.position = Vector2.ZERO
		_placa.hide()
	else:
		_persiana.position = Vector2(0.0, -pantalla.y * _entrada.apertura_de_la_persiana())
		_placa.show()
		_placa.text = _entrada.texto()
		_placa.modulate.a = _entrada.opacidad_de_la_placa()


func _al_terminar() -> void:
	_callar()
	visible = false
	set_process(false)
	persiana_subida.emit(_jornada)
