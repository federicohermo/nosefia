## Amplía una imagen original o presenta el mismo texto que la hoja del corcho.
class_name NotaEncuadrada
extends CanvasLayer

## El tono del tachado de las tareas cumplidas. Las dos notas lo toman de acá.
const COLOR_DEL_TACHADO := Color(0.8, 0.05, 0.03)
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

var _tachados: Array[ColorRect] = []
var _filas_tachadas: Array[int] = []


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
	_pintar_tachados(nota)
	visible = true


func ocultar() -> void:
	visible = false


## Los renglones de la lectura que van tachados.
func filas_tachadas() -> Array[int]:
	return _filas_tachadas.duplicate()


func tachados_visibles() -> Array[ColorRect]:
	return _tachados.duplicate()


## Una línea sobre toda la oración, por tarea cumplida. Cada nombre cabe en un renglón.
func _pintar_tachados(nota: NotaPegada) -> void:
	for tachado in _tachados:
		_renglones.remove_child(tachado)
		tachado.queue_free()
	_tachados.clear()
	_filas_tachadas.clear()
	var alto := _renglones.get_line_height()
	var oraciones := _renglones.text.split("\n")
	var fuente := _renglones.get_theme_font("font")
	var tamano := _renglones.get_theme_font_size("font_size")
	for fila in nota.renglones().size():
		if not nota.cumplida(fila):
			continue
		var tachado := ColorRect.new()
		tachado.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tachado.color = COLOR_DEL_TACHADO
		var largo := (
			fuente.get_string_size(oraciones[fila], HORIZONTAL_ALIGNMENT_LEFT, -1, tamano).x
		)
		tachado.size = Vector2(largo, GROSOR_DEL_TACHADO * alto)
		tachado.position = Vector2(0.0, (fila + ALTURA_DEL_TACHADO) * alto - tachado.size.y / 2.0)
		_renglones.add_child(tachado)
		_tachados.append(tachado)
		_filas_tachadas.append(fila)


func _ajustar() -> void:
	LienzoDeManada.ajustar(_marco, get_viewport().get_visible_rect().size)


static func texto_de_renglones(nota: NotaPegada) -> String:
	var filas: Array[String] = []
	for renglon in nota.renglones():
		var prefijo := "%d. " % (filas.size() + 1) if nota.numerada() else "• "
		filas.append(prefijo + renglon)
	return "\n".join(filas)
