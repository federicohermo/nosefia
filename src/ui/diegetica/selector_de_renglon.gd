## El renglón del modo manual: la fila de «Manada — UI» y su lista desplegable de productos.
##
## Presenta lo que le dan y publica lo que se elige: no sabe de generadores ni de tickets.
class_name SelectorDeRenglon
extends Control

## `null` es vaciar el renglón.
signal producto_elegido(producto: Producto)
signal lista_abierta
signal animacion_terminada

const COLOR_CLARO := Color("f0f4d1")
const COLOR_OSCURO := Color("1a1a1a")
const COLOR_DEL_PANEL := Color("3f434a")
const TAMANO_DEL_TEXTO := 34
const ANCHO := 380.0
const ALTO_DE_LA_LISTA := 429.0
const ALTO_DEL_RENGLON := 95.0
const ALTO_DE_LA_CABECERA := 72.0
const ALTO_DEL_ITEM := 60.0
const MARGEN_INFERIOR := 28.0
const MARGEN_DEL_NOMBRE := 57.0
const MARGEN_DEL_VACIO := 27.0
const ANCHO_DEL_BORDE := 1
const DURACION_DE_LA_ANIMACION := 0.15

const FLECHA := preload("res://assets/ui/manada/ticket_flecha.svg")
const EQUIS := preload("res://assets/ui/manada/ticket_x.svg")

var _producto: Producto
var _abierta := false
var _lleno := _estilo(COLOR_CLARO)
var _vacio := _estilo(COLOR_DEL_PANEL)
var _cabecera: Button
var _borde: BordeDePixel
var _flecha: TextureRect
var _nombre: Label
var _equis: TextureRect
var _lista: Panel
var _limite_inferior := INF
var _alto_final := ALTO_DE_LA_LISTA
var _progreso := 0.0
var _animando := false
var _tween: Tween


func armar(catalogo: Array[Producto]) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lista = _armar_la_lista(catalogo)
	add_child(_lista)
	_cabecera = _boton(_vacio, _vacio)
	_cabecera.name = "Cabecera"
	_cabecera.pressed.connect(_alternar)
	_borde = _borde_de_pixel()
	_cabecera.add_child(_borde)
	add_child(_cabecera)
	_flecha = _textura(FLECHA, "Flecha", Vector2(16.72, 29.28))
	_flecha.pivot_offset = _flecha.size / 2.0
	add_child(_flecha)
	_nombre = Label.new()
	_nombre.name = "Nombre"
	_nombre.position = Vector2(MARGEN_DEL_NOMBRE, 29.0)
	_nombre.size = Vector2(268.0, 37.0)
	_nombre.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_nombre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nombre.add_theme_font_size_override("font_size", TAMANO_DEL_TEXTO)
	add_child(_nombre)
	_equis = _textura(EQUIS, "Equis", Vector2(17.04, 23.43))
	_equis.position = Vector2(335.0, 36.0)
	add_child(_equis)
	_desplegar(0.0)
	mostrar_producto(null)


func mostrar_producto(producto: Producto) -> void:
	_producto = producto
	_nombre.text = Catalogo.de(producto.id).nombre.to_upper() if producto != null else ""
	_pintar()


## El borde, en las coordenadas del padre, que la lista abierta no pasa.
func limitar_hasta(limite: float) -> void:
	_limite_inferior = limite


func elegido() -> Producto:
	return _producto


func esta_abierta() -> bool:
	return _abierta


func cerrar() -> void:
	if not _abierta:
		return
	_abierta = false
	_pintar()
	_animar(0.0)


func _input(evento: InputEvent) -> void:
	var clic := evento as InputEventMouseButton
	if not (_abierta or _animando) or clic == null or not clic.pressed:
		return
	if clic.button_index != MOUSE_BUTTON_LEFT:
		return
	var local := _lista.get_global_transform_with_canvas().affine_inverse() * clic.position
	if Rect2(Vector2.ZERO, Vector2(ANCHO, _alto_final)).has_point(local):
		# Una línea a medio desplegar no se elige: el clic se traga hasta que termina.
		if _animando:
			get_viewport().set_input_as_handled()
		return
	if _abierta:
		cerrar()
		get_viewport().set_input_as_handled()


func _alternar() -> void:
	if _abierta:
		cerrar()
		return
	_abierta = true
	_ajustar_el_alto_de_la_lista()
	_lista.visible = true
	z_index = 1
	# El z_index sólo ordena el dibujo: el clic lo gana el último nodo del árbol.
	get_parent().move_child(self, -1)
	_pintar()
	_animar(1.0)
	lista_abierta.emit()


func _ajustar_el_alto_de_la_lista() -> void:
	_alto_final = minf(ALTO_DE_LA_LISTA, _limite_inferior - MARGEN_INFERIOR - position.y)
	var desplazamiento := _lista.get_node("Desplazamiento") as Control
	desplazamiento.size.y = _alto_final - ALTO_DE_LA_CABECERA - 1.0


## Despliega la lista y gira la flecha: 0 es el renglón cerrado y 1 la lista abierta.
func _desplegar(progreso: float) -> void:
	_progreso = progreso
	_lista.size.y = _alto_final * progreso
	_flecha.rotation_degrees = 90.0 * progreso
	var centro := Vector2(34.07, 47.6).lerp(Vector2(25.66, 45.6), progreso)
	_flecha.position = centro - _flecha.size / 2.0


func _animar(hacia: float) -> void:
	if _tween != null:
		_tween.kill()
	_animando = true
	_tween = create_tween()
	_tween.tween_method(
		_desplegar, _progreso, hacia, DURACION_DE_LA_ANIMACION * absf(hacia - _progreso)
	)
	_tween.tween_callback(_terminar_la_animacion)


func _terminar_la_animacion() -> void:
	_animando = false
	if not _abierta:
		_lista.visible = false
		z_index = 0
	animacion_terminada.emit()


func _elegir(producto: Producto) -> void:
	cerrar()
	producto_elegido.emit(producto)


func _pintar() -> void:
	var relleno := _producto != null and not _abierta
	var estilo: StyleBox = StyleBoxEmpty.new() if _abierta else (_lleno if relleno else _vacio)
	var color := COLOR_OSCURO if relleno else COLOR_CLARO
	for estado: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed"]:
		_cabecera.add_theme_stylebox_override(estado, estilo)
	_nombre.add_theme_color_override("font_color", color)
	_flecha.self_modulate = color
	_equis.self_modulate = color
	_equis.visible = _producto != null
	_borde.visible = not _abierta
	var alto := ALTO_DE_LA_CABECERA if _abierta else ALTO_DEL_RENGLON
	_cabecera.size = Vector2(ANCHO, alto)


func _armar_la_lista(catalogo: Array[Producto]) -> Panel:
	var lista := Panel.new()
	lista.name = "Lista"
	lista.size = Vector2(ANCHO, ALTO_DE_LA_LISTA)
	lista.visible = false
	lista.clip_contents = true
	lista.add_theme_stylebox_override("panel", _estilo(COLOR_DEL_PANEL))
	var separador := SeparadorDePixel.new()
	separador.name = "Separador"
	separador.position = Vector2(18.5, ALTO_DE_LA_CABECERA - 0.5)
	lista.add_child(separador)
	var desplazamiento := ScrollContainer.new()
	desplazamiento.name = "Desplazamiento"
	desplazamiento.position = Vector2(ANCHO_DEL_BORDE, ALTO_DE_LA_CABECERA)
	desplazamiento.size = Vector2(ANCHO - 2.0, ALTO_DE_LA_LISTA - ALTO_DE_LA_CABECERA - 1.0)
	desplazamiento.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lista.add_child(desplazamiento)
	var items := VBoxContainer.new()
	items.name = "Items"
	items.add_theme_constant_override("separation", 0)
	items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desplazamiento.add_child(items)
	var margen := Control.new()
	margen.custom_minimum_size.y = 4.0
	margen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	items.add_child(margen)
	items.add_child(_item(null))
	for producto in catalogo:
		items.add_child(_item(producto))
	lista.add_child(_borde_de_pixel())
	return lista


## Sin producto es la opción vacía de Figma: «>» y ningún nombre.
func _item(producto: Producto) -> Button:
	var margen := 56.0 if producto != null else MARGEN_DEL_VACIO
	var item := _boton(_estilo(COLOR_DEL_PANEL, margen), _estilo(COLOR_CLARO, margen))
	item.text = Catalogo.de(producto.id).nombre.to_upper() if producto != null else ">"
	item.alignment = HORIZONTAL_ALIGNMENT_LEFT
	item.custom_minimum_size.y = ALTO_DEL_ITEM
	item.add_theme_color_override("font_color", COLOR_CLARO)
	for estado: StringName in [
		&"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color"
	]:
		item.add_theme_color_override(estado, COLOR_OSCURO)
	item.pressed.connect(_elegir.bind(producto))
	var linea := SeparadorDePixel.new()
	linea.name = "Linea"
	linea.position = Vector2(17.5, ALTO_DEL_ITEM - 1.0)
	item.add_child(linea)
	if producto == null:
		item.name = "OpcionVacia"
		return item
	var equis := _textura(EQUIS, "EquisDelItem", Vector2(17.04, 23.43))
	equis.position = Vector2(334.0, 19.0)
	equis.self_modulate = COLOR_CLARO
	item.add_child(equis)
	item.mouse_entered.connect(func() -> void: equis.self_modulate = COLOR_OSCURO)
	item.mouse_exited.connect(func() -> void: equis.self_modulate = COLOR_CLARO)
	return item


func _boton(normal: StyleBox, resaltado: StyleBox) -> Button:
	var boton := Button.new()
	boton.focus_mode = Control.FOCUS_NONE
	boton.add_theme_font_size_override("font_size", TAMANO_DEL_TEXTO)
	boton.add_theme_stylebox_override("normal", normal)
	for estado: StringName in [&"hover", &"pressed", &"hover_pressed"]:
		boton.add_theme_stylebox_override(estado, resaltado)
	return boton


func _borde_de_pixel() -> BordeDePixel:
	var borde := BordeDePixel.new()
	borde.name = "Borde"
	borde.color = COLOR_CLARO
	return borde


func _textura(textura: Texture2D, nombre: String, tamano: Vector2) -> TextureRect:
	var rectangulo := TextureRect.new()
	rectangulo.name = nombre
	rectangulo.texture = textura
	rectangulo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rectangulo.stretch_mode = TextureRect.STRETCH_SCALE
	rectangulo.size = tamano
	rectangulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rectangulo


static func _estilo(relleno: Color, margen: float = 0.0) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = relleno
	estilo.content_margin_left = margen
	return estilo
