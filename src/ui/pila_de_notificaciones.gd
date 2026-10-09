class_name PilaDeNotificaciones
extends CanvasLayer

const TEXTOS := {
	Notificaciones.Tipo.CLIENTE: "¡HAY UN\nCLIENTE!",
	Notificaciones.Tipo.LECTURA_FALLIDA: "NO SE PUDO\nLEER",
}
const SIMBOLOS := {
	Notificaciones.Tipo.CLIENTE: preload("res://assets/ui/manada/notificacion_cliente.svg"),
	Notificaciones.Tipo.LECTURA_FALLIDA: preload("res://assets/ui/manada/notificacion_lectura.svg"),
}
const ESCALA_DEL_CARTEL := 0.4

@export var _marco: Control
@export var _pila: VBoxContainer
@export var _estilo: StyleBoxFlat

var _estado := Notificaciones.new()
var _dibujadas: Array[Notificaciones.Tipo] = []


func _ready() -> void:
	get_viewport().size_changed.connect(_ajustar_al_viewport)
	_ajustar_al_viewport()


func _process(delta: float) -> void:
	_estado.avanzar(delta)
	_pintar()


func avisar_llegada(comprador: Comprador) -> void:
	_estado.llego(comprador)
	_pintar()


func avisar_lectura_rechazada(motivo: GeneradorDeTickets.Resultado) -> void:
	_estado.lectura_rechazada(motivo)
	_pintar()


func vaciar() -> void:
	_estado.vaciar()
	_pintar()


func _pintar() -> void:
	var actuales := _estado.visibles()
	if actuales == _dibujadas:
		return
	for hijo in _pila.get_children():
		_pila.remove_child(hijo)
		hijo.free()
	for tipo in actuales:
		_pila.add_child(_cartel(tipo))
	_dibujadas = actuales


func _cartel(tipo: Notificaciones.Tipo) -> PanelContainer:
	var cartel := PanelContainer.new()
	cartel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cartel.custom_minimum_size = Vector2(572.4, 96)
	cartel.add_theme_stylebox_override("panel", _estilo)
	var fila := HBoxContainer.new()
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_theme_constant_override("separation", 22)
	cartel.add_child(fila)
	var simbolo := TextureRect.new()
	simbolo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	simbolo.texture = SIMBOLOS[tipo]
	simbolo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	simbolo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	simbolo.custom_minimum_size = simbolo.texture.get_size() * ESCALA_DEL_CARTEL
	fila.add_child(simbolo)
	var texto := Label.new()
	texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texto.text = TEXTOS[tipo]
	texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	texto.add_theme_color_override("font_color", Color("04060c"))
	texto.add_theme_font_size_override("font_size", 27)
	fila.add_child(texto)
	return cartel


func _ajustar_al_viewport() -> void:
	var disponible := get_viewport().get_visible_rect().size
	var referencia := LienzoDeManada.TAMANO_DEL_DISENO
	var factor := minf(disponible.x / referencia.x, disponible.y / referencia.y)
	_marco.scale = Vector2.ONE * factor
