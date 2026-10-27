## El panel presenta tres renglones y publica los dos botones de la ficha.
class_name ProgramaDeTickets
extends CanvasLayer

signal borrado_pedido
signal impresion_pedida
signal boton_pulsado
signal eleccion_pedida(renglon: int, producto: Producto)

@export var marco: Control
@export var selectores: Array[SelectorDeRenglon]
@export var filas: Array[Label]
@export var flechas: Array[Label]
@export var borrar: Button
@export var imprimir: Button
@export var salida: Label
@export var renglon_lleno: StyleBox
@export var renglon_vacio: StyleBox

var _catalogo: Array[Producto] = Catalogo.todos()


func _ready() -> void:
	for indice in selectores.size():
		var selector := selectores[indice]
		selector.armar(_catalogo)
		selector.hide()
		selector.producto_elegido.connect(_al_elegir.bind(indice))
		selector.lista_abierta.connect(_al_abrir_una_lista.bind(selector))
	borrar.pressed.connect(_al_borrar)
	imprimir.pressed.connect(_al_imprimir)
	salida.text = LienzoDeManada.TEXTO_DE_SALIDA
	get_viewport().size_changed.connect(_ajustar)
	_ajustar()
	ocultar()


func mostrar(generador: GeneradorDeTickets) -> void:
	var renglones := generador.renglones()
	for indice in filas.size():
		var manual := generador.es_manual()
		filas[indice].visible = not manual
		selectores[indice].visible = manual
		var producto: Producto = (
			generador.en_el_renglon(indice)
			if manual
			else (renglones[indice] if indice < renglones.size() else null)
		)
		var tiene_producto := producto != null
		filas[indice].text = Catalogo.de(producto.id).nombre if tiene_producto else ""
		flechas[indice].visible = not manual
		selectores[indice].mostrar_producto(producto)
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
	cerrar_las_listas()
	visible = false


func _ajustar() -> void:
	LienzoDeManada.ajustar(marco, get_viewport().get_visible_rect().size)


func _al_borrar() -> void:
	boton_pulsado.emit()
	borrado_pedido.emit()


func _al_imprimir() -> void:
	boton_pulsado.emit()
	impresion_pedida.emit()


func cerrar_las_listas() -> void:
	for selector in selectores:
		selector.cerrar()


func _al_elegir(producto: Producto, renglon: int) -> void:
	eleccion_pedida.emit(renglon, producto)


func _al_abrir_una_lista(abierto: SelectorDeRenglon) -> void:
	for selector in selectores:
		if selector != abierto:
			selector.cerrar()
