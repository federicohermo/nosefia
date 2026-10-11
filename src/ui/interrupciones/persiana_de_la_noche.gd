class_name PersianaDeLaNoche
extends CanvasLayer

signal persiana_subida(jornada: int)

@export var _persiana: TextureRect
@export var _marco: Control
@export var _placa: Label

var _entrada: EntradaALaNoche
var _jornada: int


func _ready() -> void:
	visible = false
	set_process(false)
	get_viewport().size_changed.connect(_pintar)


func _process(delta: float) -> void:
	_entrada.avanzar(delta)
	_pintar()
	if _entrada.terminada():
		_al_terminar()


func anunciar(jornada: int) -> void:
	_jornada = jornada
	_entrada = EntradaALaNoche.new(jornada)
	visible = true
	set_process(true)
	_pintar()


func terminar() -> void:
	if not en_pantalla():
		return
	_entrada.avanzar(EntradaALaNoche.DURACION)
	_pintar()
	_al_terminar()


func en_pantalla() -> bool:
	return visible


func _pintar() -> void:
	if _entrada == null:
		return
	var pantalla := get_viewport().get_visible_rect().size
	LienzoDeManada.ajustar(_marco, pantalla)
	_persiana.size = pantalla
	_persiana.position = Vector2(0.0, -pantalla.y * _entrada.apertura_de_la_persiana())
	_placa.text = _entrada.texto()
	_placa.modulate.a = _entrada.opacidad_de_la_placa()


func _al_terminar() -> void:
	visible = false
	set_process(false)
	persiana_subida.emit(_jornada)
