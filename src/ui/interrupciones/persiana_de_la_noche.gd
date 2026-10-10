class_name PersianaDeLaNoche
extends CanvasLayer

signal persiana_subida(jornada: int)

const FADE_DE_LA_PERSIANA_BAJA := 0.3

@export var _persiana: TextureRect
@export var _marco: Control
@export var _placa: Label

var _entrada: EntradaALaNoche
var _jornada: int
var _ahora: Callable = Time.get_ticks_usec
var _ultimo: int = 0
var _avance_del_fade: float = 0.0
var _negro: ColorRect


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
	if _entrada == null:
		_avance_del_fade = minf(1.0, _avance_del_fade + segundos / FADE_DE_LA_PERSIANA_BAJA)
		_negro.modulate.a = 1.0 - _avance_del_fade
		if _avance_del_fade == 1.0:
			_negro.hide()
			set_process(false)
	else:
		_entrada.avanzar(segundos)
		_pintar()
		if _entrada.terminada():
			_al_terminar()


func mostrar_baja() -> void:
	_entrada = null
	_avance_del_fade = 0.0
	_ultimo = _ahora.call()
	_negro.modulate.a = 1.0
	_negro.show()
	visible = true
	set_process(true)
	_pintar()


func anunciar(jornada: int) -> void:
	_jornada = jornada
	_entrada = EntradaALaNoche.new(jornada)
	_ultimo = _ahora.call()
	_negro.hide()
	visible = true
	set_process(true)
	_pintar()


func terminar() -> void:
	if not en_pantalla() or _entrada == null:
		return
	_entrada.avanzar(EntradaALaNoche.DURACION)
	_pintar()
	_al_terminar()


func en_pantalla() -> bool:
	return visible


func _pintar() -> void:
	var pantalla := get_viewport().get_visible_rect().size
	LienzoDeManada.ajustar(_marco, pantalla)
	_persiana.size = pantalla
	if _entrada == null:
		_persiana.position = Vector2.ZERO
		_placa.hide()
	else:
		_persiana.position = Vector2(0.0, -pantalla.y * _entrada.apertura_de_la_persiana())
		_placa.show()
		_placa.text = _entrada.texto()
		_placa.modulate.a = _entrada.opacidad_de_la_placa()


func _al_terminar() -> void:
	visible = false
	set_process(false)
	persiana_subida.emit(_jornada)
