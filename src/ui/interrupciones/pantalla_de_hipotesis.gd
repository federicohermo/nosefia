## El recuadro de la reflexión de cierre, a la derecha del celular: el encabezado de la noche y
## un texto para seguir leyendo, o una hipótesis para elegir.
##
## Qué se muestra y qué acepta cada pedido lo decide `ReflexionDeCierre`; acá se pinta lo que
## ella dice y se piden los gestos, sin tocarla. Con la pausa en pantalla los botones no
## responden: el árbol está detenido.
##
## La composición es la de Figma, «J2 - PISTAS + HIPÓTESIS», sobre el lienzo de 1920 × 1080.
class_name PantallaDeHipotesis
extends CanvasLayer

signal continuacion_pedida(identidad: String)
signal anterior_pedido
signal siguiente_pedido
signal eleccion_pedida(identidad: String)

const TEXTO_DE_CONTINUAR := "Continuar"
const TEXTO_DE_ANTERIOR := "Anterior"
const TEXTO_DE_SIGUIENTE := "Siguiente"
const TEXTO_DE_ELEGIR := "Elegir"
const TEMA := preload("res://assets/ui/manada/tema.tres")
const TINTA := Color("f0f4d1")
const FONDO := Color(0.0, 0.0, 0.0, 0.47)
const BOTON := Color("e7eeae")
const BOTON_SECUNDARIO := Color("cbd0a0")
const ENCABEZADO := Rect2(751.0, 130.0, 1063.0, 200.0)
const RECUADRO := Rect2(751.0, 346.0, 1063.0, 427.0)
const MARCO := Rect2(838.0, 385.0, 808.0, 326.0)
const FLECHA := Vector2(861.0, 441.0)
const TITULO := Rect2(903.0, 437.0, 720.0, 44.0)
const TEXTO := Rect2(903.0, 499.0, 720.0, 200.0)
const PUNTOS := Vector2(1672.0, 694.0)
const ANTERIOR := Rect2(1389.0, 748.0, 188.0, 45.0)
const SIGUIENTE := Rect2(1596.0, 748.0, 188.0, 45.0)
const ACCION := Rect2(1389.0, 811.0, 257.0, 62.0)

var _lienzo: Control
var _encabezado: Label
var _flecha: Line2D
var _titulo: Label
var _texto: Label
var _puntos: HBoxContainer
var _anterior: Button
var _siguiente: Button
var _accion: Button
var _identidad: String = ""
var _elige: bool = false


func _ready() -> void:
	visible = false
	_lienzo = Control.new()
	_lienzo.name = "Lienzo"
	_lienzo.theme = TEMA
	_lienzo.size = LienzoDeManada.TAMANO_DEL_DISENO
	_lienzo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lienzo)
	_ubicar(_panel("Recuadro", FONDO, null), RECUADRO)
	var marco := StyleBoxFlat.new()
	marco.draw_center = false
	marco.border_color = TINTA
	marco.set_border_width_all(2)
	_ubicar(_panel("Marco", Color.TRANSPARENT, marco), MARCO)
	_encabezado = _etiqueta("Encabezado", 40, TINTA, ENCABEZADO)
	_encabezado.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_flecha = Line2D.new()
	_flecha.name = "Flecha"
	_flecha.points = PackedVector2Array([Vector2(0, 0), Vector2(14, 13.5), Vector2(0, 27)])
	_flecha.width = 2.5
	_flecha.default_color = TINTA
	_flecha.position = FLECHA
	_lienzo.add_child(_flecha)
	_titulo = _etiqueta("Titulo", 36, TINTA, TITULO)
	_texto = _etiqueta("Texto", 30, Color.WHITE, TEXTO)
	_puntos = HBoxContainer.new()
	_puntos.name = "Puntos"
	_puntos.position = PUNTOS
	_puntos.add_theme_constant_override("separation", 14)
	_puntos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lienzo.add_child(_puntos)
	_anterior = _boton("Anterior", TEXTO_DE_ANTERIOR, 30, BOTON_SECUNDARIO, ANTERIOR)
	_anterior.pressed.connect(anterior_pedido.emit)
	_siguiente = _boton("Siguiente", TEXTO_DE_SIGUIENTE, 30, BOTON, SIGUIENTE)
	_siguiente.pressed.connect(siguiente_pedido.emit)
	_accion = _boton("Accion", TEXTO_DE_CONTINUAR, 41, BOTON, ACCION)
	_accion.pressed.connect(_al_pulsar_la_accion)
	get_viewport().size_changed.connect(_ajustar)
	_ajustar()


## Pinta la etapa de la reflexión. Durante la espera deja la elección a la vista sin responder.
func mostrar(reflexion: ReflexionDeCierre) -> void:
	visible = true
	_encabezado.text = reflexion.encabezado()
	var etapa := reflexion.etapa()
	_elige = etapa in [ReflexionDeCierre.Etapa.ELEGIR, ReflexionDeCierre.Etapa.ESPERA]
	var opcion := reflexion.mostrada()
	var con_opcion := _elige and opcion != null
	_titulo.visible = con_opcion
	_flecha.visible = con_opcion
	_titulo.text = "“%s”" % opcion.titulo if con_opcion else ""
	_texto.position.y = TEXTO.position.y if con_opcion else TITULO.position.y
	_texto.text = "“%s”" % opcion.texto if con_opcion else reflexion.texto_actual()
	_identidad = opcion.identidad if con_opcion else reflexion.identidad_del_texto()
	var opciones := reflexion.opciones()
	var navegable := etapa == ReflexionDeCierre.Etapa.ELEGIR and opciones.size() > 1
	_anterior.visible = navegable
	_siguiente.visible = navegable
	_pintar_puntos(opciones.find(opcion) if navegable else -1, opciones.size())
	_accion.text = TEXTO_DE_ELEGIR if _elige else TEXTO_DE_CONTINUAR
	_accion.disabled = not (
		etapa in [ReflexionDeCierre.Etapa.TEXTOS, ReflexionDeCierre.Etapa.ELEGIR]
	)
	if not _accion.disabled:
		_accion.grab_focus()


func ocultar() -> void:
	visible = false
	_identidad = ""


## Los botones a la vista, para los casos de escena: Anterior, Siguiente y la acción.
func botones() -> Array[Button]:
	var visibles: Array[Button] = []
	for boton: Button in [_anterior, _siguiente, _accion]:
		if visible and boton.visible:
			visibles.append(boton)
	return visibles


func texto() -> String:
	return _texto.text


func _al_pulsar_la_accion() -> void:
	if _elige:
		eleccion_pedida.emit(_identidad)
	else:
		continuacion_pedida.emit(_identidad)


func _pintar_puntos(mostrada: int, cuantas: int) -> void:
	for punto: Node in _puntos.get_children():
		punto.queue_free()
	if mostrada < 0:
		return
	for indice: int in cuantas:
		var punto := StyleBoxFlat.new()
		punto.set_corner_radius_all(9)
		punto.border_color = TINTA
		punto.set_border_width_all(2)
		punto.bg_color = TINTA if indice == mostrada else Color.TRANSPARENT
		var circulo := _panel("Punto", Color.TRANSPARENT, punto)
		circulo.custom_minimum_size = Vector2(17, 17)
		circulo.reparent(_puntos, false)


func _ajustar() -> void:
	LienzoDeManada.ajustar(_lienzo, get_viewport().get_visible_rect().size)


func _ubicar(control: Control, lugar: Rect2) -> void:
	control.position = lugar.position
	control.size = lugar.size


func _panel(nombre: String, color: Color, estilo: StyleBoxFlat) -> Panel:
	var panel := Panel.new()
	panel.name = nombre
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if estilo == null:
		estilo = StyleBoxFlat.new()
		estilo.bg_color = color
	panel.add_theme_stylebox_override("panel", estilo)
	_lienzo.add_child(panel)
	return panel


func _etiqueta(nombre: String, tamano: int, color: Color, lugar: Rect2) -> Label:
	var etiqueta := Label.new()
	etiqueta.name = nombre
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", color)
	_lienzo.add_child(etiqueta)
	_ubicar(etiqueta, lugar)
	return etiqueta


func _boton(
	nombre: String, texto_del_boton: String, tamano: int, color: Color, lugar: Rect2
) -> Button:
	var boton := Button.new()
	boton.name = nombre
	boton.text = texto_del_boton
	boton.add_theme_font_size_override("font_size", tamano)
	for estado: String in [
		"font_color", "font_hover_color", "font_pressed_color", "font_focus_color"
	]:
		boton.add_theme_color_override(estado, Color("1a1a1a"))
	for estado: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var fondo := StyleBoxFlat.new()
		fondo.bg_color = color.lightened(0.15) if estado in ["hover", "focus"] else color
		fondo.set_corner_radius_all(roundi(lugar.size.y / 4.0))
		fondo.shadow_color = Color(0, 0, 0, 0.25)
		fondo.shadow_size = 8
		fondo.shadow_offset = Vector2(0, lugar.size.y / 2.0)
		boton.add_theme_stylebox_override(estado, fondo)
	_lienzo.add_child(boton)
	_ubicar(boton, lugar)
	return boton
