## Configuraciones: una barra por preferencia, con su − y su +, y el idioma. Dibuja lo que
## contesta `Preferencias` y avisa cada gesto que cambió un valor. No escribe ni aplica nada: eso
## lo cablea quien la abre.
##
## Corre también con el árbol en pausa: se abre desde el menú de pausa. Esc la cierra; en la
## pausa lo atiende primero el control de la pausa, que la cierra sin reanudar.
class_name PantallaDeConfiguraciones
extends CanvasLayer

## Una vez por gesto que cambia un valor, con una copia: quien la recibe puede guardarla.
signal preferencias_cambiadas(preferencias: Preferencias)
signal preferencias_confirmadas(preferencias: Preferencias)
signal cerrada

const TEXTO_DEL_TITULO := "/ CONFIGURACIONES:"
const TEXTO_DE_MENOS := "−"
const TEXTO_DE_MAS := "+"
const TEXTO_DE_LENGUAJE := "LENGUAJE"
const TEXTO_DE_VOLVER := "VOLVER"
const IDIOMAS: Array[String] = ["ESPAÑOL"]
const TEXTOS: Dictionary[Preferencias.Campo, String] = {
	Preferencias.Campo.EFECTOS: "EFECTOS",
	Preferencias.Campo.MUSICA: "MÚSICA",
	Preferencias.Campo.BRILLO: "BRILLO",
	Preferencias.Campo.SENSIBILIDAD: "SENSIBILIDAD",
	Preferencias.Campo.TEXTOS: "TEXTOS",
}

## Medidas del lienzo de 1920 × 1080: el nombre de cada fila y el lado de cada botón.
const ANCHO_DEL_NOMBRE := 420.0
const LADO_DEL_BOTON := 72.0

@export var _marco: Control
@export var _titulo: Label
@export var _filas: VBoxContainer
@export var _volver: Button

var _preferencias := Preferencias.new()
var _barras: Dictionary[Preferencias.Campo, HSlider] = {}
var _primer_boton: Button


func _ready() -> void:
	visible = false
	_titulo.text = TEXTO_DEL_TITULO
	_volver.text = TEXTO_DE_VOLVER
	_volver.pressed.connect(cerrar)
	for campo: Preferencias.Campo in Preferencias.CAMPOS:
		_filas.add_child(_fila_de(campo))
	_filas.add_child(_fila_del_lenguaje())
	get_viewport().size_changed.connect(_ajustar_al_viewport)
	_ajustar_al_viewport()


## Los valores que muestra al abrirse. Quien la abre los leyó del disco.
func preparar(preferencias: Preferencias) -> void:
	_preferencias = preferencias.copia()
	_pintar()


func abrir() -> void:
	_pintar()
	visible = true
	_primer_boton.grab_focus()


func cerrar() -> void:
	if not visible:
		return
	visible = false
	preferencias_confirmadas.emit(_preferencias.copia())
	cerrada.emit()


func filas() -> Array[HBoxContainer]:
	var todas: Array[HBoxContainer] = []
	for fila: HBoxContainer in _filas.get_children():
		todas.append(fila)
	return todas


func marco() -> Control:
	return _marco


func _unhandled_input(evento: InputEvent) -> void:
	if visible and evento.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cerrar()


func _fila_de(campo: Preferencias.Campo) -> HBoxContainer:
	var fila := _fila_con_nombre(TEXTOS[campo])
	var menos := _boton(TEXTO_DE_MENOS)
	var barra := HSlider.new()
	var mas := _boton(TEXTO_DE_MAS)
	barra.min_value = Preferencias.minimo(campo)
	barra.max_value = Preferencias.maximo(campo)
	barra.step = Preferencias.paso(campo)
	barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	menos.pressed.connect(_restar.bind(campo))
	mas.pressed.connect(_sumar.bind(campo))
	barra.value_changed.connect(_arrastrar.bind(campo))
	_barras[campo] = barra
	fila.add_child(menos)
	fila.add_child(barra)
	fila.add_child(mas)
	if _primer_boton == null:
		_primer_boton = menos
	return fila


func _fila_del_lenguaje() -> HBoxContainer:
	var fila := _fila_con_nombre(TEXTO_DE_LENGUAJE)
	var desplegable := OptionButton.new()
	for idioma: String in IDIOMAS:
		desplegable.add_item(idioma)
	desplegable.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(desplegable)
	return fila


func _fila_con_nombre(texto: String) -> HBoxContainer:
	var fila := HBoxContainer.new()
	var nombre := Label.new()
	nombre.text = texto
	nombre.custom_minimum_size.x = ANCHO_DEL_NOMBRE
	nombre.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fila.add_child(nombre)
	return fila


func _boton(texto: String) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.custom_minimum_size = Vector2.ONE * LADO_DEL_BOTON
	boton.theme_type_variation = &"BotonContinuar"
	return boton


func _sumar(campo: Preferencias.Campo) -> void:
	_avisar_si(_preferencias.sumar(campo))


func _restar(campo: Preferencias.Campo) -> void:
	_avisar_si(_preferencias.restar(campo))


## La barra cae en el paso más cercano: el que contesta el dominio, no el que dejó el mouse.
func _arrastrar(arrastrado: float, campo: Preferencias.Campo) -> void:
	var antes := _preferencias.valor(campo)
	var ahora := _preferencias.poner(campo, arrastrado)
	_barras[campo].set_value_no_signal(ahora)
	_avisar_si(not is_equal_approx(antes, ahora))


func _avisar_si(cambio: bool) -> void:
	_pintar()
	if cambio:
		preferencias_cambiadas.emit(_preferencias.copia())


func _pintar() -> void:
	for campo: Preferencias.Campo in _barras:
		_barras[campo].set_value_no_signal(_preferencias.valor(campo))


func _ajustar_al_viewport() -> void:
	LienzoDeManada.ajustar(_marco, get_viewport().get_visible_rect().size)
