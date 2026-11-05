## La lista de productos del pedido al proveedor, dentro del chat de Hernán: un renglón por
## producto con su casilla, el texto que la abre y el aviso de que hace falta marcar uno.
##
## **No decide qué está marcado:** eso es del pedido (BR-INV-124). La lista le dice cada casilla que
## cambió y avisa para que quien la muestra actualice «Enviar».
class_name ListaDelPedido
extends PanelContainer

signal seleccion_cambiada

const TITULO := "Seleccioná los productos que faltan."
const AVISO := "* Seleccioná uno o varios productos para enviar."
const FONDO_DEL_RENGLON := Color("e3e6e2")
const TAMANO_DEL_TEXTO := 28
const TAMANO_DEL_AVISO := 20

var _pedido: PedidoAlProveedor
var _fuente: Font


## Arma la lista con los productos del pedido, todos desmarcados.
func armar(pedido: PedidoAlProveedor, fondo: Color, tinta: Color, fuente: Font) -> void:
	_pedido = pedido
	_fuente = fuente
	name = "ListaDelPedido"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override("panel", _estilo(fondo, 16, 16))
	var contenido := VBoxContainer.new()
	contenido.add_theme_constant_override("separation", 8)
	add_child(contenido)
	contenido.add_child(_texto(PedidoAlProveedor.SALUDO, tinta, TAMANO_DEL_TEXTO))
	contenido.add_child(_texto(TITULO, tinta, TAMANO_DEL_AVISO))
	for producto in pedido.productos_de_la_lista():
		contenido.add_child(_renglon(producto, tinta))
	contenido.add_child(_texto(AVISO, tinta, TAMANO_DEL_AVISO))


func _renglon(producto: Producto, tinta: Color) -> PanelContainer:
	var renglon := PanelContainer.new()
	renglon.name = "Renglon" + str(producto.id)
	renglon.add_theme_stylebox_override("panel", _estilo(FONDO_DEL_RENGLON, 4, 10))
	var fila := HBoxContainer.new()
	renglon.add_child(fila)
	var nombre := _texto(producto.nombre, tinta, TAMANO_DEL_TEXTO)
	nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(nombre)
	var casilla := CheckBox.new()
	casilla.name = "Casilla"
	casilla.button_pressed = _pedido.esta_marcado(producto.id)
	casilla.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	casilla.toggled.connect(
		func(marcada: bool) -> void:
			if marcada:
				_pedido.marcar(producto.id)
			else:
				_pedido.desmarcar(producto.id)
			seleccion_cambiada.emit()
	)
	fila.add_child(casilla)
	return renglon


func _texto(texto: String, color: Color, tamano: int) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.add_theme_font_override("font", _fuente)
	etiqueta.add_theme_color_override("font_color", color)
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return etiqueta


func _estilo(color: Color, radio: int, margen: int) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color
	estilo.set_corner_radius_all(radio)
	estilo.set_content_margin_all(margen)
	return estilo
