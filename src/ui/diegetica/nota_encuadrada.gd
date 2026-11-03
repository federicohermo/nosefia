## Amplía una imagen original o presenta el mismo texto que la hoja del corcho.
class_name NotaEncuadrada
extends CanvasLayer

## El tono del tick de las tareas cumplidas. Las dos notas lo toman de acá.
const COLOR_DEL_TICK := Color(0.8, 0.05, 0.03)
## La fuente de la nota no trae el glifo «✓»: el tick es una textura con el alto del renglón.
const TICK := preload("res://assets/ui/manada/notas/tick.svg")
## Cuánto se separa el tick del número, en renglones.
const SEPARACION_DEL_TICK := 0.1

@export var _marco: Control
@export var _titulo: Label
@export var _renglones: Label
@export var _imagen: TextureRect
@export var _papel: Control
@export var _salida: Label
@export var _grafica_de_tareas: Control
@export var _grafica_de_orden: Control

var _ticks: Array[TextureRect] = []
var _filas_con_tick: Array[int] = []


func _ready() -> void:
	_salida.text = LienzoDeManada.TEXTO_DE_SALIDA
	get_viewport().size_changed.connect(_ajustar)
	_ajustar()
	ocultar()


func mostrar(nota: NotaPegada, imagen: Texture2D) -> void:
	_titulo.text = nota.titulo()
	_renglones.text = texto_de_renglones(nota)
	_imagen.texture = imagen
	_imagen.visible = imagen != null
	_papel.visible = imagen == null
	if _grafica_de_tareas != null and _grafica_de_orden != null:
		var es_tareas := nota.numerada()
		_titulo.visible = false
		_grafica_de_tareas.visible = es_tareas
		_grafica_de_orden.visible = not es_tareas
		_renglones.position.y = 200.0 if es_tareas else 260.0
	_pintar_ticks(nota)
	visible = true


func ocultar() -> void:
	visible = false


## Los renglones de la lectura que llevan tick.
func filas_con_tick() -> Array[int]:
	return _filas_con_tick.duplicate()


func ticks_visibles() -> Array[TextureRect]:
	return _ticks.duplicate()


## Un tick por tarea cumplida, a la izquierda del número. Cada nombre cabe en un renglón.
func _pintar_ticks(nota: NotaPegada) -> void:
	for tick in _ticks:
		_renglones.remove_child(tick)
		tick.queue_free()
	_ticks.clear()
	_filas_con_tick.clear()
	var alto := _renglones.get_line_height()
	var ancho := alto * TICK.get_width() / TICK.get_height()
	for fila in nota.renglones().size():
		if not nota.cumplida(fila):
			continue
		var tick := TextureRect.new()
		tick.texture = TICK
		tick.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tick.stretch_mode = TextureRect.STRETCH_SCALE
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tick.modulate = COLOR_DEL_TICK
		tick.size = Vector2(ancho, alto)
		tick.position = Vector2(-ancho - SEPARACION_DEL_TICK * alto, fila * alto)
		_renglones.add_child(tick)
		_ticks.append(tick)
		_filas_con_tick.append(fila)


func _ajustar() -> void:
	LienzoDeManada.ajustar(_marco, get_viewport().get_visible_rect().size)


static func texto_de_renglones(nota: NotaPegada) -> String:
	var filas: Array[String] = []
	for renglon in nota.renglones():
		var prefijo := "%d. " % (filas.size() + 1) if nota.numerada() else "• "
		filas.append(prefijo + renglon)
	return "\n".join(filas)
