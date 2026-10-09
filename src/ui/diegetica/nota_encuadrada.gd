## Amplía una imagen original o presenta el mismo texto que la hoja del corcho.
class_name NotaEncuadrada
extends CanvasLayer

@export var _marco: Control
@export var _titulo: Label
@export var _renglones: Label
@export var _imagen: TextureRect
@export var _papel: Control
@export var _salida: Label
@export var _grafica_de_tareas: Control
@export var _grafica_de_orden: Control


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
	visible = true


func ocultar() -> void:
	visible = false


func _ajustar() -> void:
	LienzoDeManada.ajustar(_marco, get_viewport().get_visible_rect().size)


func _input(evento: InputEvent) -> void:
	if visible and evento.is_action_pressed(ReglasDeLosObjetos.ACCION_AGARRAR):
		get_viewport().set_input_as_handled()


static func texto_de_renglones(nota: NotaPegada) -> String:
	var filas: Array[String] = []
	for renglon in nota.renglones():
		var prefijo := "%d. " % (filas.size() + 1) if nota.numerada() else "• "
		filas.append(prefijo + renglon)
	return "\n".join(filas)
