## La pantalla de logros: tres columnas —pistas, finales y logros— que dibuja lo que contesta
## `Logros`. Una entrada alcanzada muestra su imagen y su nombre —el de una pista es el título de
## su hipótesis—; una que no, el signo de pregunta y «?????». No decide nada ni escribe nada.
##
## Corre también con el árbol en pausa: se abre desde el menú de pausa. Esc la cierra; en la pausa
## lo atiende primero el control de la pausa, que la cierra sin reanudar.
class_name PantallaDeLogros
extends CanvasLayer

signal cerrada

const TEXTO_DEL_TITULO := "/ LOGROS:"
const TEXTO_DE_VOLVER := "VOLVER"
const TEXTO_DE_LAS_PISTAS := "PISTAS"
const TEXTO_DE_LOS_FINALES := "FINALES"
const TEXTO_DE_LOS_LOGROS := "LOGROS"
const TEXTO_BLOQUEADO := "?????"

const IMAGEN_BLOQUEADA := preload("res://assets/ui/manada/logros/bloqueado.png")

## Obelisco de cartón y Elemental no están: se ven bloqueados y no tienen imagen propia todavía.
const _IMAGEN_DE_LOS_LOGROS: Dictionary[Logros.Logro, Texture2D] = {
	Logros.Logro.REBELDE: preload("res://assets/ui/manada/logros/rebelde.png"),
	Logros.Logro.Y_SE_MARCHO: preload("res://assets/ui/manada/logros/y_se_marcho.png"),
	Logros.Logro.A_LA_BASURA: preload("res://assets/ui/manada/logros/a_la_basura.png"),
	Logros.Logro.ESTAMOS_AL_PEDO: preload("res://assets/ui/manada/logros/estamos_al_pedo.png"),
	Logros.Logro.EMPLEADO_EJEMPLAR: preload("res://assets/ui/manada/logros/empleado_ejemplar.png"),
	Logros.Logro.PESIMA_PRIMERA_IMPRESION:
	preload("res://assets/ui/manada/logros/pesima_primera_impresion.png"),
	Logros.Logro.MI_TALON_DE_AQUILES:
	preload("res://assets/ui/manada/logros/mi_talon_de_aquiles.png"),
}
const _IMAGEN_DE_LOS_FINALES: Dictionary[Partida.Final, Texture2D] = {
	Partida.Final.DESPEDIDO: preload("res://assets/ui/manada/logros/final_despedido.png"),
	Partida.Final.CONTRATO_CUMPLIDO:
	preload("res://assets/ui/manada/logros/final_contrato_cumplido.png"),
}

## Medidas del lienzo de 1920 × 1080.
const LADO_DE_LA_IMAGEN := 72.0
const ANCHO_DE_LA_COLUMNA := 480.0

@export var _marco: Control
@export var _titulo: Label
@export var _columnas: HBoxContainer
@export var _volver: Button

var _logros := Logros.new()
var _caso: CasoDeInvestigacion = null
var _listas: Dictionary[StringName, VBoxContainer] = {}


func _ready() -> void:
	visible = false
	_titulo.text = TEXTO_DEL_TITULO
	_volver.text = TEXTO_DE_VOLVER
	_volver.pressed.connect(cerrar)
	for titulo: String in [TEXTO_DE_LAS_PISTAS, TEXTO_DE_LOS_FINALES, TEXTO_DE_LOS_LOGROS]:
		_columnas.add_child(_columna(titulo))
	get_viewport().size_changed.connect(_ajustar_al_viewport)
	_ajustar_al_viewport()


## Lo que muestra al abrirse: los logros que leyó quien la abre, y las pistas del caso. Se pasa
## la misma instancia que el juego va actualizando: la pantalla la vuelve a leer al abrir.
func preparar(logros: Logros, caso: CasoDeInvestigacion) -> void:
	_logros = logros
	_caso = caso


func abrir() -> void:
	_pintar()
	visible = true
	_volver.grab_focus(true)


func cerrar() -> void:
	if not visible:
		return
	visible = false
	cerrada.emit()


## Las entradas de una columna, en el orden en que se ven.
func entradas(columna: StringName) -> Array[HBoxContainer]:
	var todas: Array[HBoxContainer] = []
	for entrada: HBoxContainer in _listas[columna].get_children():
		todas.append(entrada)
	return todas


func columnas() -> Array[StringName]:
	var nombres: Array[StringName] = []
	for columna: Control in _columnas.get_children():
		nombres.append(columna.name)
	return nombres


func marco() -> Control:
	return _marco


func _unhandled_input(evento: InputEvent) -> void:
	if visible and evento.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cerrar()


func _columna(titulo: String) -> VBoxContainer:
	var columna := VBoxContainer.new()
	columna.name = titulo
	columna.custom_minimum_size.x = ANCHO_DE_LA_COLUMNA
	var encabezado := Label.new()
	encabezado.text = titulo
	encabezado.theme_type_variation = &"TextoDelMenu"
	columna.add_child(encabezado)
	var desplazable := ScrollContainer.new()
	desplazable.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desplazable.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desplazable.add_child(lista)
	columna.add_child(desplazable)
	_listas[StringName(titulo)] = lista
	return columna


func _pintar() -> void:
	for lista: VBoxContainer in _listas.values():
		for entrada: Node in lista.get_children():
			lista.remove_child(entrada)
			entrada.free()
	if _caso != null:
		for pista: Pista in _caso.pistas.filter(func(p: Pista) -> bool: return p.deja_nota()):
			var descubierta := _logros.pista_descubierta(pista.identidad)
			_agregar(
				TEXTO_DE_LAS_PISTAS,
				descubierta,
				pista.foto,
				_caso.titulo_de_la_pista(pista.identidad)
			)
	for final: Partida.Final in Logros.finales():
		_agregar(
			TEXTO_DE_LOS_FINALES,
			_logros.final_alcanzado(final),
			_IMAGEN_DE_LOS_FINALES.get(final),
			Logros.nombre_del_final(final)
		)
	for logro: Logros.Logro in Logros.Logro.values():
		_agregar(
			TEXTO_DE_LOS_LOGROS,
			_logros.desbloqueado(logro),
			_IMAGEN_DE_LOS_LOGROS.get(logro),
			Logros.nombre(logro)
		)


func _agregar(columna: StringName, alcanzada: bool, imagen: Texture2D, nombre: String) -> void:
	var entrada := HBoxContainer.new()
	var figura := TextureRect.new()
	figura.texture = imagen if alcanzada else IMAGEN_BLOQUEADA
	figura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	figura.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	figura.custom_minimum_size = Vector2.ONE * LADO_DE_LA_IMAGEN
	entrada.add_child(figura)
	var texto := Label.new()
	texto.text = nombre if alcanzada else TEXTO_BLOQUEADO
	texto.theme_type_variation = &"TextoDelMenu"
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	entrada.add_child(texto)
	_listas[columna].add_child(entrada)
	if not alcanzada:
		figura.self_modulate = texto.get_theme_color(&"font_color")


func _ajustar_al_viewport() -> void:
	LienzoDeManada.ajustar(_marco, get_viewport().get_visible_rect().size)
