## El dibujo conserva el scroll al ampliar: la foto se superpone al chat, no lo reconstruye.
class_name PantallaDelCelular
extends CanvasLayer

signal chat_pedido(quien: Conversacion.Interlocutor)
signal volver_pedido
signal foto_pedida(indice: int)
signal cierre_de_foto_pedido

const RECORRIDO_COMPLETO := 0.25
const TAMANO := Vector2(522.0, 928.0)
const CENTRO := Vector2(960.0, 540.0)
const TEXTO_DEL_MENU := "CHATS"
const TEXTO_DEL_RECORDATORIO := "Q"
const TINTA := Color("1a1a1a")
const PAPEL := Color("ffffff")
const BURBUJA := Color("0b343d")
const GRIS := Color("787878")
const MASCARA_DEL_AVATAR := preload("res://assets/ui/manada/celular/avatar.tres")
const AVATAR_ENRIQUE := preload("res://assets/ui/manada/celular/enrique.png")
const AVATAR_ENRIQUE_MENU := preload("res://assets/ui/manada/celular/enrique_menu.png")
const RETRATO_ENRIQUE := "res://assets/ui/manada/enrique.png"
const BUSCAR := "Buscar contacto..."
const TEXTO_DEL_ROL := "Jefe"
const FOTO := "Foto"
const MENSAJE := "Mensaje..."
const AYUDA := "RUEDA DEL MOUSE / DESPLAZAR HISTORIAL"

@export var _velo: Control
@export var _lienzo: Control
@export var _telefono: PanelContainer
@export var _titulo: Label
@export var _volver: Button
@export var _scroll: ScrollContainer
@export var _mensajes: VBoxContainer
@export var _foto_ampliada: PanelContainer
@export var _imagen: TextureRect
@export var _adjunto: RichTextLabel
@export var _recordatorio: HBoxContainer
@export var _cabecera: PanelContainer
@export var _avatar_del_chat: TextureRect
@export var _subtitulo: Label
@export var _opciones: Label
@export var _busqueda: LineEdit
@export var _pie: VBoxContainer
@export var _entrada: LineEdit
@export var _ayuda: Label

var _avance: float = 0.0
var _destino: float = 0.0
var _ultimo: int = 0
var _ahora: Callable = Time.get_ticks_usec
var _bandeja: Bandeja


func _ready() -> void:
	_volver.text = ""
	_volver.tooltip_text = "Volver al menú"
	var flecha := Line2D.new()
	flecha.name = "Flecha"
	flecha.points = PackedVector2Array([Vector2(6, -12), Vector2(-6, 0), Vector2(6, 12)])
	flecha.width = 3.0
	flecha.default_color = TINTA
	flecha.antialiased = true
	flecha.position = _volver.size / 2.0
	_volver.add_child(flecha)
	_volver.resized.connect(func() -> void: flecha.position = _volver.size / 2.0)
	_volver.pressed.connect(func() -> void: volver_pedido.emit())
	_busqueda.placeholder_text = BUSCAR
	_busqueda.text_changed.connect(_filtrar)
	_subtitulo.text = TEXTO_DEL_ROL
	_opciones.text = "..."
	_entrada.placeholder_text = MENSAJE
	_ayuda.text = AYUDA
	(_recordatorio.get_node("Tecla") as Label).text = TEXTO_DEL_RECORDATORIO
	_foto_ampliada.hide()
	_recordatorio.hide()
	_telefono.hide()
	_velo.hide()
	set_process(false)
	get_viewport().size_changed.connect(_ajustar)
	_ajustar()


func _notification(que: int) -> void:
	if que == NOTIFICATION_UNPAUSED:
		_ultimo = _ahora.call()


func _process(_delta: float) -> void:
	var ahora: int = _ahora.call()
	var segundos := maxf(0.0, (ahora - _ultimo) / 1000000.0)
	_ultimo = ahora
	_avance = move_toward(_avance, _destino, segundos / RECORRIDO_COMPLETO)
	_pintar_posicion()
	if is_equal_approx(_avance, _destino):
		set_process(false)
		if _destino == 0.0:
			_telefono.hide()
			_velo.hide()


func subir() -> void:
	_mover_hacia(1.0)


func bajar() -> void:
	_mover_hacia(0.0)


func mostrar_menu(bandeja: Bandeja) -> void:
	_bandeja = bandeja
	_foto_ampliada.hide()
	_volver.hide()
	_titulo.text = TEXTO_DEL_MENU
	_titulo.add_theme_font_size_override("font_size", 38)
	_avatar_del_chat.hide()
	_subtitulo.hide()
	_opciones.show()
	_busqueda.show()
	_busqueda.text = ""
	_pie.hide()
	_componer(true)
	_filtrar("")


func mostrar_chat(conversacion: Conversacion, mensajes: Array[Mensaje], fijo: bool) -> void:
	_foto_ampliada.hide()
	_volver.visible = not fijo
	_titulo.text = conversacion.nombre.to_upper()
	_titulo.add_theme_font_size_override("font_size", 36)
	_avatar_del_chat.texture = _imagen_del_contacto(conversacion, false)
	_avatar_del_chat.show()
	_subtitulo.visible = (
		conversacion.imagen != null and conversacion.imagen.resource_path == RETRATO_ENRIQUE
	)
	_opciones.hide()
	_busqueda.hide()
	_busqueda.release_focus()
	_pie.show()
	_componer(false)
	_limpiar()
	for indice in mensajes.size():
		_mensajes.add_child(_burbuja_de(mensajes[indice], indice))
	_ir_al_ultimo.call_deferred()


func ampliar(foto: Mensaje, adjunto: Mensaje) -> void:
	_imagen.texture = foto.foto
	_adjunto.text = adjunto.texto if adjunto != null else ""
	_adjunto.visible = adjunto != null
	_foto_ampliada.show()


func cerrar_foto() -> void:
	_foto_ampliada.hide()


func mostrar_recordatorio(se_ve: bool) -> void:
	_recordatorio.visible = se_ve


func _input(evento: InputEvent) -> void:
	if not _foto_ampliada.visible or not _telefono.visible:
		return
	if (
		evento is InputEventMouseButton
		and evento.button_index == MOUSE_BUTTON_LEFT
		and evento.pressed
	):
		get_viewport().set_input_as_handled()
		cierre_de_foto_pedido.emit()


func _mover_hacia(destino: float) -> void:
	_destino = destino
	_ultimo = _ahora.call()
	if destino == 1.0:
		_telefono.show()
		_velo.show()
	set_process(true)
	_pintar_posicion()


func _ajustar() -> void:
	var encuadre := get_viewport().get_visible_rect().size
	LienzoDeManada.ajustar(_lienzo, encuadre)
	# El recordatorio pertenece al borde de la ventana, no al lienzo centrado del teléfono.
	_recordatorio.scale = _lienzo.scale
	_recordatorio.position = Vector2(36.0, -130.0) * _lienzo.scale + Vector2(0, encuadre.y)
	_pintar_posicion()


func _pintar_posicion() -> void:
	_telefono.size = TAMANO
	var arriba := CENTRO.y - TAMANO.y / 2.0
	_telefono.position = Vector2(CENTRO.x - TAMANO.x / 2.0, lerpf(1080.0, arriba, _avance))


func _componer(menu: bool) -> void:
	var marco := _estilo(PAPEL if menu else Color("c8c8c8"), 35 if menu else 26, 12)
	if menu:
		marco.set_border_width_all(8)
		marco.border_color = Color("c8c8c8")
	_telefono.add_theme_stylebox_override("panel", marco)
	_cabecera.add_theme_stylebox_override("panel", _estilo(PAPEL, 16, 16))
	var historial := _estilo(PAPEL, 12, 12 if menu else 22)
	if menu:
		historial.content_margin_top = 4
		historial.content_margin_bottom = 4
	_scroll.add_theme_stylebox_override("panel", historial)
	_mensajes.add_theme_constant_override("separation", 0 if menu else 16)
	var buscar := _estilo(Color("ebebeb"), 8, 18)
	buscar.content_margin_top = 0
	buscar.content_margin_bottom = 0
	_busqueda.add_theme_stylebox_override("normal", buscar)
	_entrada.add_theme_stylebox_override("read_only", _estilo(Color("f3f3ef"), 12, 16))
	var barra := _scroll.get_v_scroll_bar()
	barra.add_theme_stylebox_override("scroll", _estilo(PAPEL, 0, 5))
	for estado: String in ["grabber", "grabber_highlight", "grabber_pressed"]:
		barra.add_theme_stylebox_override(estado, _estilo(Color("7d8280"), 9, 5))


func _filtrar(busqueda: String) -> void:
	if _bandeja == null:
		return
	_limpiar()
	for conversacion in _bandeja.conversaciones():
		if (
			not busqueda.is_empty()
			and not conversacion.nombre.to_lower().contains(busqueda.to_lower())
		):
			continue
		var mensajes := _bandeja.mensajes_de(conversacion.interlocutor)
		var ultimo := mensajes[-1]
		var resumen := ultimo.texto if not ultimo.texto.is_empty() else FOTO
		_mensajes.add_child(
			_boton_de(conversacion, _bandeja.no_leidos(conversacion.interlocutor), resumen)
		)
	_scroll.scroll_vertical = 0


func _boton_de(conversacion: Conversacion, sin_leer: int, resumen: String) -> Button:
	var boton := Button.new()
	boton.custom_minimum_size = Vector2(0, 132)
	boton.tooltip_text = conversacion.nombre
	boton.add_theme_stylebox_override("normal", _estilo(PAPEL, 8))
	boton.add_theme_stylebox_override("hover", _estilo(Color("ebebeb"), 8))
	boton.add_theme_stylebox_override("pressed", _estilo(Color("c8c8c8"), 8))
	var fila := HBoxContainer.new()
	fila.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fila.offset_left = 12
	fila.offset_right = -12
	fila.add_theme_constant_override("separation", 18)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boton.add_child(fila)
	fila.add_child(_avatar(_imagen_del_contacto(conversacion, true)))
	var contacto := VBoxContainer.new()
	contacto.name = "Contacto"
	contacto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contacto.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	contacto.add_theme_constant_override("separation", 10)
	contacto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(contacto)
	var nombre := _etiqueta(conversacion.nombre.to_upper(), TINTA, 26)
	nombre.name = "Nombre"
	contacto.add_child(nombre)
	var vista_previa := _etiqueta(resumen, GRIS, 21)
	vista_previa.name = "VistaPrevia"
	vista_previa.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vista_previa.max_lines_visible = 2
	vista_previa.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	contacto.add_child(vista_previa)
	if sin_leer > 0:
		var badge := PanelContainer.new()
		badge.name = "NoLeidos"
		badge.custom_minimum_size = Vector2(28, 28)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		badge.add_theme_stylebox_override("panel", _estilo(Color("093338"), 14, 4))
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cuenta := _etiqueta(str(sin_leer), PAPEL, 20)
		cuenta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_child(cuenta)
		fila.add_child(badge)
	var quien := conversacion.interlocutor
	boton.pressed.connect(func() -> void: chat_pedido.emit(quien))
	return boton


func _imagen_del_contacto(conversacion: Conversacion, menu: bool) -> Texture2D:
	# El retrato de introducción conserva su composición propia; el celular usa sus exports Figma.
	if conversacion.imagen != null and conversacion.imagen.resource_path == RETRATO_ENRIQUE:
		return AVATAR_ENRIQUE_MENU if menu else AVATAR_ENRIQUE
	return conversacion.imagen


func _avatar(imagen: Texture2D) -> PanelContainer:
	var avatar := PanelContainer.new()
	avatar.custom_minimum_size = Vector2(66, 66)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar.add_theme_stylebox_override("panel", _estilo(BURBUJA, 33))
	if imagen != null:
		var textura := TextureRect.new()
		textura.texture = imagen
		textura.material = MASCARA_DEL_AVATAR
		textura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		textura.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		textura.mouse_filter = Control.MOUSE_FILTER_IGNORE
		avatar.add_child(textura)
	return avatar


func _burbuja_de(mensaje: Mensaje, indice: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(368, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.add_theme_stylebox_override("panel", _estilo(Color("0b363d"), 16, 16))
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var contenido := VBoxContainer.new()
	contenido.add_theme_constant_override("separation", 12)
	contenido.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(contenido)
	if mensaje.foto != null:
		var foto := TextureButton.new()
		foto.texture_normal = mensaje.foto
		foto.ignore_texture_size = true
		foto.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		foto.custom_minimum_size = Vector2(0, 240)
		foto.pressed.connect(func() -> void: foto_pedida.emit(indice))
		contenido.add_child(foto)
	if not mensaje.texto.is_empty():
		var texto := _texto(mensaje.texto, PAPEL, 28)
		texto.custom_minimum_size.x = 336
		texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		contenido.add_child(texto)
	return panel


func _ir_al_ultimo() -> void:
	# El contenedor debe terminar de medir los mensajes antes de pedir el extremo del scroll.
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func _limpiar() -> void:
	for viejo in _mensajes.get_children():
		_mensajes.remove_child(viejo)
		viejo.queue_free()


func _etiqueta(texto: String, color: Color, tamano: int) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.add_theme_color_override("font_color", color)
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return etiqueta


func _estilo(color: Color, radio: int, margen: int = 0) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color
	estilo.set_corner_radius_all(radio)
	estilo.content_margin_left = margen
	estilo.content_margin_right = margen
	estilo.content_margin_top = margen
	estilo.content_margin_bottom = margen
	return estilo


func _texto(texto: String, color: Color, tamano: int) -> RichTextLabel:
	var etiqueta := RichTextLabel.new()
	etiqueta.bbcode_enabled = true
	etiqueta.fit_content = true
	etiqueta.scroll_active = false
	etiqueta.text = texto
	etiqueta.add_theme_color_override("default_color", color)
	etiqueta.add_theme_font_size_override("normal_font_size", tamano)
	etiqueta.add_theme_font_size_override("bold_font_size", tamano)
	etiqueta.add_theme_font_override("bold_font", _adjunto.get_theme_font("bold_font"))
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return etiqueta
