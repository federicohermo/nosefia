class_name CapaDeDialogo
extends CanvasLayer

@export var locutor: Locutor
@export var _entrada: RichTextLabel


func _ready() -> void:
	ocultar()
	if locutor != null:
		locutor.entrada_mostrada.connect(mostrar)
		locutor.dialogo_cerrado.connect(ocultar)


func mostrar(entrada: String) -> void:
	_entrada.text = entrada
	show()


func ocultar() -> void:
	_entrada.clear()
	hide()
