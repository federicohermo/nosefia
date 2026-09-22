## Lista y detalle sobre el cuaderno existente. El borrador sobrevive al cambiar de aplicación.
class_name AppNotas
extends Control

signal escritura_pedida(titulo: String, texto: String)

const TEXTO_DEL_TITULO := "/ MIS NOTAS:"
const TEXTO_DEL_BOTON := "ANOTAR +"
const PISTA_DEL_TITULO := "Título de la nota"
const PISTA_DEL_TEXTO := "¿Qué viste?"
const TEXTO_DE_LA_NOTA := "%02d  / %s"
const TEXTO_VACIO := "TODAVÍA NO HAY NOTAS"
const TEXTO_DE_AYUDA := "Escribí una observación abajo para guardarla en tu cuaderno."
const TEXTO_DEL_EDITOR := "/ NUEVA NOTA:"

@export var _titulo: Label
@export var _lista: VBoxContainer
@export var _campo_titulo: LineEdit
@export var _campo_texto: TextEdit
@export var _anotar: Button
@export var _detalle_titulo: Label
@export var _detalle_texto: Label
@export var _editor_titulo: Label

var _seleccion: int = 0
var _notas: Array[Nota] = []


func _ready() -> void:
	_titulo.text = TEXTO_DEL_TITULO
	_anotar.text = TEXTO_DEL_BOTON
	_editor_titulo.text = TEXTO_DEL_EDITOR
	_campo_titulo.placeholder_text = PISTA_DEL_TITULO
	_campo_texto.placeholder_text = PISTA_DEL_TEXTO
	_anotar.pressed.connect(_al_anotar)


func mostrar(notas: Array[Nota]) -> void:
	_notas = notas
	for viejo in _lista.get_children():
		_lista.remove_child(viejo)
		viejo.queue_free()
	for indice in notas.size():
		var boton := Button.new()
		boton.text = TEXTO_DE_LA_NOTA % [indice + 1, notas[indice].titulo().to_upper()]
		boton.tooltip_text = notas[indice].titulo()
		boton.custom_minimum_size = Vector2(0, 80)
		boton.alignment = HORIZONTAL_ALIGNMENT_LEFT
		boton.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		boton.clip_text = true
		boton.toggle_mode = true
		boton.theme_type_variation = &"NotaDeLista"
		boton.pressed.connect(_seleccionar.bind(indice))
		_lista.add_child(boton)
	if notas.is_empty():
		_detalle_titulo.text = TEXTO_VACIO
		_detalle_texto.text = TEXTO_DE_AYUDA
	else:
		_seleccionar(clampi(_seleccion, 0, notas.size() - 1))


## El cableado llama esto sólo después de que Cuaderno acepta la nota.
func limpiar_campos() -> void:
	_campo_titulo.text = ""
	_campo_texto.text = ""
	_seleccion = _notas.size()


func _seleccionar(indice: int) -> void:
	_seleccion = indice
	_detalle_titulo.text = _notas[indice].titulo()
	_detalle_texto.text = _notas[indice].texto()
	for posicion in _lista.get_child_count():
		var boton: Button = _lista.get_child(posicion)
		boton.set_pressed_no_signal(posicion == indice)


func _al_anotar() -> void:
	escritura_pedida.emit(_campo_titulo.text, _campo_texto.text)
