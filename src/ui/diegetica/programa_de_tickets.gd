## El panel presenta tres renglones y publica los dos botones de la ficha.
class_name ProgramaDeTickets
extends CanvasLayer

signal borrado_pedido
signal impresion_pedida
signal boton_pulsado

@export var marco: Control
@export var filas: Array[Label]
@export var flechas: Array[Label]
@export var borrar: Button
@export var imprimir: Button
@export var salida: Label
@export var renglon_lleno: StyleBox
@export var renglon_vacio: StyleBox


func _ready() -> void:
	borrar.pressed.connect(_al_borrar)
	imprimir.pressed.connect(_al_imprimir)
	salida.text = LienzoDeManada.TEXTO_DE_SALIDA
	get_viewport().size_changed.connect(_ajustar)
	_ajustar()
	ocultar()


func mostrar(renglones: Array[Producto]) -> void:
	for indice in filas.size():
		var tiene_producto := indice < renglones.size()
		filas[indice].text = renglones[indice].nombre if tiene_producto else ""
		filas[indice].add_theme_stylebox_override(
			"normal", renglon_lleno if tiene_producto else renglon_vacio
		)
		flechas[indice].add_theme_color_override(
			"font_color", Color.BLACK if tiene_producto else Color("f0f4d1")
		)
		filas[indice].add_theme_color_override(
			"font_color", Color.BLACK if tiene_producto else Color("f0f4d1")
		)
	visible = true


func ocultar() -> void:
	visible = false


func _ajustar() -> void:
	LienzoDeManada.ajustar(marco, get_viewport().get_visible_rect().size)


func _al_borrar() -> void:
	boton_pulsado.emit()
	borrado_pedido.emit()


func _al_imprimir() -> void:
	boton_pulsado.emit()
	impresion_pedida.emit()
