## El registro mantiene su acción de un clic. El detalle se muestra al enfocar cada tarjeta.
class_name AppCaja
extends Control

signal registro_pedido(producto: Producto)

const TEXTO_DEL_TITULO := "/ PRODUCTOS:"
const TEXTO_DEL_FALTANTE := "FALTA EN GÓNDOLA\n\n%s"
const TEXTO_SIN_FALTANTES := "LA GÓNDOLA ESTÁ AL DÍA."
const TEXTO_DEL_BOTON := "REGISTRAR"
const TEXTO_YA_REGISTRADO := "REGISTRADO"
const TEXTO_DEL_RESUMEN := "DEL DÍA     %02d\n\nREGISTRADOS  %02d"
const TEXTO_DE_AYUDA := "CLIC / REGISTRAR\n\nPasá el cursor por un producto para ver su detalle."
const TEXTO_SIN_PRODUCTOS := "No hay productos para registrar."
const TEXTO_DEL_PRECIO := "PRECIO / $%d"
const TEXTO_PENDIENTE := "PRODUCTO SIN REGISTRAR."
const TEXTO_REGISTRADO := "PRODUCTO REGISTRADO."
const IMAGENES := {
	Producto.Id.ACTRONCITO: preload("res://assets/ui/manada/actroncito.png"),
	Producto.Id.DUREXTRA: preload("res://assets/ui/manada/durextra.png"),
	Producto.Id.BURBALOO: preload("res://assets/ui/manada/burbaloo.png"),
}

@export var _titulo: Label
@export var _botones: GridContainer
@export var _faltantes: Label
@export var _resumen: Label
@export var _ayuda: Label
@export var _imagen: TextureRect
@export var _nombre: Label
@export var _precio: Label
@export var _estado: Label

var _producto: Producto
var _caja: CajaRegistradora


func _ready() -> void:
	_titulo.text = TEXTO_DEL_TITULO
	_ayuda.text = TEXTO_DE_AYUDA


func mostrar(caja: CajaRegistradora) -> void:
	_caja = caja
	for viejo in _botones.get_children():
		_botones.remove_child(viejo)
		viejo.queue_free()
	var productos := caja.del_dia()
	for producto in productos:
		_botones.add_child(_boton_de(producto, caja.esta_registrado(producto)))
	_resumen.text = TEXTO_DEL_RESUMEN % [productos.size(), caja.registrados()]
	_faltantes.text = _aviso_de(caja.faltantes())
	if productos.is_empty():
		_producto = null
		_imagen.texture = null
		_nombre.text = TEXTO_SIN_PRODUCTOS
		_precio.text = ""
		_estado.text = ""
		return
	var seleccionado := productos[0]
	for producto in productos:
		if _producto != null and producto.id == _producto.id:
			seleccionado = producto
	_mostrar_detalle(seleccionado)


func _boton_de(producto: Producto, registrado: bool) -> Button:
	var boton := Button.new()
	boton.custom_minimum_size = Vector2(246, 280)
	boton.disabled = registrado
	boton.tooltip_text = (
		producto.nombre + " / " + (TEXTO_YA_REGISTRADO if registrado else TEXTO_DEL_BOTON)
	)
	boton.pressed.connect(func() -> void: registro_pedido.emit(producto))
	boton.mouse_entered.connect(func() -> void: _mostrar_detalle(producto))
	boton.focus_entered.connect(func() -> void: _mostrar_detalle(producto))
	var contenido := VBoxContainer.new()
	contenido.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	contenido.offset_left = 12
	contenido.offset_top = 12
	contenido.offset_right = -12
	contenido.offset_bottom = -12
	contenido.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boton.add_child(contenido)
	var imagen := TextureRect.new()
	imagen.texture = IMAGENES.get(producto.id)
	imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	imagen.custom_minimum_size = Vector2(0, 184)
	imagen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contenido.add_child(imagen)
	var nombre := Label.new()
	nombre.text = producto.nombre.to_upper()
	nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nombre.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nombre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contenido.add_child(nombre)
	var estado := Label.new()
	estado.text = TEXTO_YA_REGISTRADO if registrado else TEXTO_DEL_BOTON
	estado.theme_type_variation = &"TextoSecundario"
	estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	estado.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contenido.add_child(estado)
	return boton


func _mostrar_detalle(producto: Producto) -> void:
	_producto = producto
	_imagen.texture = IMAGENES.get(producto.id)
	_nombre.text = producto.nombre.to_upper()
	_precio.text = TEXTO_DEL_PRECIO % producto.precio
	_estado.text = (TEXTO_REGISTRADO if _caja.esta_registrado(producto) else TEXTO_PENDIENTE)


func _aviso_de(faltantes: Array[Producto]) -> String:
	if faltantes.is_empty():
		return TEXTO_SIN_FALTANTES
	var nombres: Array[String] = []
	for producto in faltantes:
		nombres.append(producto.nombre)
	return TEXTO_DEL_FALTANTE % "\n".join(nombres)
