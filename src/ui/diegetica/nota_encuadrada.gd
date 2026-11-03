## Amplía una imagen original o presenta el mismo texto que la hoja del corcho.
class_name NotaEncuadrada
extends CanvasLayer

## El tono del tick de las tareas cumplidas. Las dos notas lo toman de acá.
const COLOR_DEL_TICK := Color(0.8, 0.05, 0.03)
## La fuente de la nota no trae el glifo «✓»: el tick es una textura con el alto del renglón.
const TICK := preload("res://assets/ui/manada/notas/tick.svg")
## Cuánto se separa el tick del número, en renglones.
const SEPARACION_DEL_TICK := 0.1
## Cuánto se corre la lista de tareas hacia el centro del papel, en renglones. Los ticks y
## los tachados van con ella.
const CORRIMIENTO_DE_LA_LISTA := 0.3
## El grosor del tachado y la altura de su línea dentro del renglón, en renglones.
const GROSOR_DEL_TACHADO := 0.06
const ALTURA_DEL_TACHADO := 0.55

@export var _marco: Control
@export var _titulo: Label
@export var _renglones: Label
@export var _imagen: TextureRect
@export var _papel: Control
@export var _salida: Label
@export var _grafica_de_tareas: Control
@export var _grafica_de_orden: Control

var _ticks: Array[TextureRect] = []
var _tachados: Array[ColorRect] = []
var _filas_con_tick: Array[int] = []
var _x_de_los_renglones: float


func _ready() -> void:
	_x_de_los_renglones = _renglones.position.x
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
		_renglones.position.x = _x_de_los_renglones
		if es_tareas:
			_renglones.position.x += CORRIMIENTO_DE_LA_LISTA * _renglones.get_line_height()
	_pintar_ticks(nota)
	visible = true


func ocultar() -> void:
	visible = false


## Los renglones de la lectura que llevan tick.
func filas_con_tick() -> Array[int]:
	return _filas_con_tick.duplicate()


func ticks_visibles() -> Array[TextureRect]:
	return _ticks.duplicate()


## Los renglones de la lectura que van tachados: los mismos que llevan tick.
func filas_tachadas() -> Array[int]:
	return _filas_con_tick.duplicate()


func tachados_visibles() -> Array[ColorRect]:
	return _tachados.duplicate()


## Un tick a la izquierda del número y una línea sobre toda la oración, por tarea cumplida.
## Cada nombre cabe en un renglón.
func _pintar_ticks(nota: NotaPegada) -> void:
	for tick in _ticks:
		_renglones.remove_child(tick)
		tick.queue_free()
	for tachado in _tachados:
		_renglones.remove_child(tachado)
		tachado.queue_free()
	_ticks.clear()
	_tachados.clear()
	_filas_con_tick.clear()
	var alto := _renglones.get_line_height()
	var ancho := alto * TICK.get_width() / TICK.get_height()
	var oraciones := _renglones.text.split("\n")
	var fuente := _renglones.get_theme_font("font")
	var tamano := _renglones.get_theme_font_size("font_size")
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
		var tachado := ColorRect.new()
		tachado.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tachado.color = COLOR_DEL_TICK
		var largo := (
			fuente.get_string_size(oraciones[fila], HORIZONTAL_ALIGNMENT_LEFT, -1, tamano).x
		)
		tachado.size = Vector2(largo, GROSOR_DEL_TACHADO * alto)
		tachado.position = Vector2(0.0, (fila + ALTURA_DEL_TACHADO) * alto - tachado.size.y / 2.0)
		_renglones.add_child(tachado)
		_tachados.append(tachado)


func _ajustar() -> void:
	LienzoDeManada.ajustar(_marco, get_viewport().get_visible_rect().size)


static func texto_de_renglones(nota: NotaPegada) -> String:
	var filas: Array[String] = []
	for renglon in nota.renglones():
		var prefijo := "%d. " % (filas.size() + 1) if nota.numerada() else "• "
		filas.append(prefijo + renglon)
	return "\n".join(filas)
