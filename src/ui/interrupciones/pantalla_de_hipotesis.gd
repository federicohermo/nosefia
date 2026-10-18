## El recuadro de la reflexión de cierre, a la derecha del celular: el encabezado de la noche y
## un texto para seguir leyendo, o una hipótesis para elegir.
##
## Qué se muestra y qué acepta cada pedido lo decide `ReflexionDeCierre`; acá se pinta lo que
## ella dice y se piden los gestos, sin tocarla. Con la pausa en pantalla los botones no
## responden: el árbol está detenido.
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
const RECUADRO_A_LA_DERECHA := Rect2(1010.0, 250.0, 760.0, 580.0)
const TINTA := Color("f0f4d1")
const RESALTE := Color("e4f850")
const TEMA := preload("res://assets/ui/manada/tema.tres")

var _lienzo: Control
var _encabezado: Label
var _titulo: Label
var _texto: Label
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
	var recuadro := PanelContainer.new()
	recuadro.name = "Recuadro"
	recuadro.position = RECUADRO_A_LA_DERECHA.position
	recuadro.size = RECUADRO_A_LA_DERECHA.size
	recuadro.add_theme_stylebox_override("panel", _marco())
	_lienzo.add_child(recuadro)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 28)
	recuadro.add_child(columna)
	_encabezado = _etiqueta("Encabezado", 30, TINTA)
	_titulo = _etiqueta("Titulo", 38, RESALTE)
	_texto = _etiqueta("Texto", 30, TINTA)
	_texto.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for etiqueta: Label in [_encabezado, _titulo, _texto]:
		columna.add_child(etiqueta)
	var botones := HBoxContainer.new()
	botones.name = "Botones"
	botones.alignment = BoxContainer.ALIGNMENT_CENTER
	botones.add_theme_constant_override("separation", 24)
	columna.add_child(botones)
	_anterior = _boton("Anterior", TEXTO_DE_ANTERIOR, anterior_pedido.emit)
	_siguiente = _boton("Siguiente", TEXTO_DE_SIGUIENTE, siguiente_pedido.emit)
	_accion = _boton("Accion", TEXTO_DE_CONTINUAR, _al_pulsar_la_accion)
	for boton: Button in [_anterior, _siguiente, _accion]:
		botones.add_child(boton)
	get_viewport().size_changed.connect(_ajustar)
	_ajustar()


## Pinta la etapa de la reflexión. Durante la espera deja la elección a la vista sin responder.
func mostrar(reflexion: ReflexionDeCierre) -> void:
	visible = true
	_encabezado.text = reflexion.encabezado()
	var etapa := reflexion.etapa()
	_elige = etapa in [ReflexionDeCierre.Etapa.ELEGIR, ReflexionDeCierre.Etapa.ESPERA]
	var opcion := reflexion.mostrada()
	_titulo.visible = _elige and opcion != null
	_titulo.text = opcion.titulo if _titulo.visible else ""
	_texto.text = opcion.texto if _titulo.visible else reflexion.texto_actual()
	_identidad = opcion.identidad if _titulo.visible else reflexion.identidad_del_texto()
	var navegable := etapa == ReflexionDeCierre.Etapa.ELEGIR and reflexion.opciones().size() > 1
	_anterior.visible = navegable
	_siguiente.visible = navegable
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


func _ajustar() -> void:
	LienzoDeManada.ajustar(_lienzo, get_viewport().get_visible_rect().size)


func _etiqueta(nombre: String, tamano: int, color: Color) -> Label:
	var etiqueta := Label.new()
	etiqueta.name = nombre
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", color)
	return etiqueta


func _boton(nombre: String, texto_del_boton: String, al_pulsar: Callable) -> Button:
	var boton := Button.new()
	boton.name = nombre
	boton.text = texto_del_boton
	boton.theme_type_variation = &"BotonContinuar"
	boton.pressed.connect(al_pulsar)
	return boton


func _marco() -> StyleBoxFlat:
	var marco := StyleBoxFlat.new()
	marco.bg_color = Color("1f1e1e")
	marco.border_color = Color("c8c8c8")
	marco.set_border_width_all(12)
	marco.set_corner_radius_all(32)
	marco.set_content_margin_all(56)
	return marco
