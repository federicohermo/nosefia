## El panel presenta tres renglones y publica los dos botones de la ficha.
class_name ProgramaDeTickets
extends CanvasLayer

signal borrado_pedido
signal impresion_pedida
signal boton_pulsado
signal eleccion_pedida(renglon: int, producto: Producto)
signal cierre_pedido
signal pausa_pedida

@export var marco: Control
@export var selectores: Array[OptionButton]
@export var filas: Array[Label]
@export var flechas: Array[Label]
@export var borrar: Button
@export var imprimir: Button
@export var salida: Label
@export var renglon_lleno: StyleBox
@export var renglon_vacio: StyleBox
@export var menu: StyleBox

var _catalogo: Array[Producto] = Catalogo.todos()


func _ready() -> void:
	for indice in selectores.size():
		var selector := selectores[indice]
		selector.add_item("")
		for producto in _catalogo:
			selector.add_item(producto.nombre)
		for opcion in selector.item_count:
			selector.get_popup().set_item_as_radio_checkable(opcion, false)
		selector.get_popup().add_theme_stylebox_override("panel", menu)
		selector.get_popup().add_theme_color_override("font_color", Color("f0f4d1"))
		selector.get_popup().add_theme_color_override("font_hover_color", Color.BLACK)
		selector.hide()
		selector.item_selected.connect(_al_elegir.bind(indice))
		selector.get_popup().window_input.connect(_en_el_popup.bind(selector.get_popup()))
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
		filas[indice].text = producto.nombre if tiene_producto else ""
		selectores[indice].select(_opcion_de(producto))
		for estado: StringName in [&"normal", &"hover", &"pressed"]:
			selectores[indice].add_theme_stylebox_override(
				estado, renglon_lleno if tiene_producto else renglon_vacio
			)
		for estado: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color"]:
			selectores[indice].add_theme_color_override(
				estado, Color.BLACK if tiene_producto else Color("f0f4d1")
			)
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
	for selector in selectores:
		var popup := selector.get_popup()
		popup.max_size = Vector2i(roundi(380.0 * marco.scale.x), roundi(429.0 * marco.scale.y))
		popup.add_theme_font_size_override("font_size", 34)


func _al_borrar() -> void:
	boton_pulsado.emit()
	borrado_pedido.emit()


func _al_imprimir() -> void:
	boton_pulsado.emit()
	impresion_pedida.emit()


func cerrar_las_listas() -> void:
	for selector in selectores:
		selector.get_popup().hide()


func _al_elegir(opcion: int, renglon: int) -> void:
	if opcion < 0 or opcion > _catalogo.size():
		return
	eleccion_pedida.emit(renglon, _catalogo[opcion - 1] if opcion > 0 else null)


func _en_el_popup(evento: InputEvent, popup: PopupMenu) -> void:
	if evento.is_action_pressed("ui_cancel"):
		popup.set_input_as_handled()
		get_viewport().set_input_as_handled()
		cerrar_las_listas()
		pausa_pedida.emit()
	elif evento.is_action_pressed(ReglasDelJugador.ACCION_USAR):
		popup.set_input_as_handled()
		get_viewport().set_input_as_handled()
		cierre_pedido.emit()


func _opcion_de(producto: Producto) -> int:
	if producto == null:
		return 0
	for indice in _catalogo.size():
		if _catalogo[indice].id == producto.id:
			return indice + 1
	return 0
