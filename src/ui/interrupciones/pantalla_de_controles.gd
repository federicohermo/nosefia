## Controles: un renglón por entrada, con el nombre de su acción y la tecla o el botón que tiene.
## Elegir un renglón y apretar una tecla o un botón del mouse se lo asigna. Dibuja lo que contesta
## `AsignacionDeControles` y avisa cada asignación que cambió algo. No escribe ni aplica nada: eso
## lo cablea quien la abre.
##
## Corre también con el árbol en pausa: se abre desde Configuraciones, que se abre desde la pausa.
## Mientras espera una entrada se come las teclas y los clics antes que nadie, y la tecla de Pausa
## cancela la espera. Esc no se puede asignar a otra acción hasta que Pausa deje de ser Esc.
class_name PantallaDeControles
extends CanvasLayer

## Una vez por asignación que cambia una ranura, con una copia: quien la recibe puede guardarla.
signal controles_cambiados(asignacion: AsignacionDeControles)
signal cerrada

const TEXTO_DEL_TITULO := "/ CONTROLES:"
const TEXTO_DE_VOLVER := "VOLVER"
const TEXTO_DE_ESPERA := "PRESIONÁ UNA TECLA"
const ANCHO_DEL_NOMBRE := 760.0
const NOMBRES_DE_LOS_BOTONES: Dictionary = {
	MOUSE_BUTTON_LEFT: "CLIC IZQUIERDO",
	MOUSE_BUTTON_RIGHT: "CLIC DERECHO",
	MOUSE_BUTTON_MIDDLE: "CLIC CENTRAL",
}
const NOMBRES_DE_LAS_TECLAS: Dictionary = {
	KEY_ESCAPE: "ESC",
	KEY_SPACE: "ESPACIO",
	KEY_UP: "FLECHA ARRIBA",
	KEY_DOWN: "FLECHA ABAJO",
	KEY_LEFT: "FLECHA IZQUIERDA",
	KEY_RIGHT: "FLECHA DERECHA",
}

@export var _marco: Control
@export var _titulo: Label
@export var _filas: VBoxContainer
@export var _volver: Button

## En la web, Esc no se asigna a otra acción que Pausa.
var en_la_web: bool = OS.has_feature("web")

var _asignacion := AsignacionDeControles.new()
var _botones: Dictionary = {}
var _primer_boton: Button
var _esperando_accion: StringName = &""
var _esperando_ranura: int = -1


func _ready() -> void:
	visible = false
	_titulo.text = TEXTO_DEL_TITULO
	_volver.text = TEXTO_DE_VOLVER
	_volver.pressed.connect(cerrar)
	for accion: StringName in AsignacionDeControles.ACCIONES:
		for ranura: int in AsignacionDeControles.ranuras_de(accion):
			_filas.add_child(_fila_de(accion, ranura))
	get_viewport().size_changed.connect(_ajustar_al_viewport)
	_ajustar_al_viewport()


## Cómo se lee una entrada. El nombre de una tecla lo da el motor, y sin traducir a la
## distribución del teclado: se lee el código físico como está.
static func nombre_de_la_entrada(tipo: int, codigo: int) -> String:
	if tipo == AsignacionDeControles.TipoDeEntrada.BOTON_DEL_MOUSE:
		return String(NOMBRES_DE_LOS_BOTONES.get(codigo, "BOTÓN %d" % codigo))
	return String(
		NOMBRES_DE_LAS_TECLAS.get(codigo, OS.get_keycode_string(codigo as Key).to_upper())
	)


## Los valores que muestra al abrirse. Quien la abre los leyó del disco.
func preparar(asignacion: AsignacionDeControles) -> void:
	_asignacion = asignacion.copia()
	_pintar()


func abrir() -> void:
	_cancelar_la_espera()
	_pintar()
	visible = true
	_primer_boton.grab_focus(true)


func cerrar() -> void:
	if not visible:
		return
	_cancelar_la_espera()
	visible = false
	cerrada.emit()


## Atrás: cancela la espera de una entrada, y si no esperaba nada, cierra la pantalla.
func retroceder() -> void:
	if capturando():
		_cancelar_la_espera()
		_pintar()
		return
	cerrar()


func capturando() -> bool:
	return _esperando_ranura >= 0


## Pide la próxima entrada para esa ranura. Es lo que hace apretar el renglón.
func elegir(accion: StringName, ranura: int) -> void:
	_esperando_accion = accion
	_esperando_ranura = ranura
	_pintar()


func filas() -> Array[HBoxContainer]:
	var todas: Array[HBoxContainer] = []
	for fila: HBoxContainer in _filas.get_children():
		todas.append(fila)
	return todas


func marco() -> Control:
	return _marco


## El texto del botón de una ranura: su entrada, o la espera.
func texto_de(accion: StringName, ranura: int) -> String:
	return (_botones[_clave(accion, ranura)] as Button).text


## Atiende un evento si espera una entrada, y contesta si se lo comió.
func atender(evento: InputEvent) -> bool:
	if not visible or not capturando():
		return false
	if evento.is_action_pressed(AsignacionDeControles.PAUSA):
		_cancelar_la_espera()
		_pintar()
		return true
	if not evento.is_pressed() or evento.is_echo():
		return false
	var entrada := AjusteDePreferencias.entrada_de(evento)
	if entrada == AjusteDePreferencias.SIN_ENTRADA:
		return false
	if not AsignacionDeControles.acepta(_esperando_accion, entrada.x, entrada.y, en_la_web):
		return true
	var cambio := _asignacion.asignar(
		_esperando_accion,
		_esperando_ranura,
		entrada.x as AsignacionDeControles.TipoDeEntrada,
		entrada.y,
		en_la_web
	)
	_cancelar_la_espera()
	_pintar()
	if cambio:
		controles_cambiados.emit(_asignacion.copia())
	return true


func _input(evento: InputEvent) -> void:
	if atender(evento):
		get_viewport().set_input_as_handled()


func _fila_de(accion: StringName, ranura: int) -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.theme_type_variation = &"FilaDeConfiguraciones"
	var nombre := Label.new()
	nombre.text = AsignacionDeControles.nombre_en_pantalla(accion, ranura)
	nombre.theme_type_variation = &"TextoDelMenu"
	nombre.custom_minimum_size.x = ANCHO_DEL_NOMBRE
	nombre.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var boton := Button.new()
	boton.theme_type_variation = &"BotonDelMenu"
	boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boton.pressed.connect(elegir.bind(accion, ranura))
	fila.add_child(nombre)
	fila.add_child(boton)
	_botones[_clave(accion, ranura)] = boton
	if _primer_boton == null:
		_primer_boton = boton
	return fila


func _clave(accion: StringName, ranura: int) -> String:
	return "%s/%d" % [accion, ranura]


func _cancelar_la_espera() -> void:
	_esperando_accion = &""
	_esperando_ranura = -1


func _pintar() -> void:
	for guardada: Dictionary in _asignacion.entradas():
		var accion: StringName = guardada["accion"]
		var ranura: int = guardada["ranura"]
		var boton: Button = _botones[_clave(accion, ranura)]
		if capturando() and accion == _esperando_accion and ranura == _esperando_ranura:
			boton.text = TEXTO_DE_ESPERA
		else:
			boton.text = nombre_de_la_entrada(guardada["tipo"], guardada["codigo"])


func _ajustar_al_viewport() -> void:
	LienzoDeManada.ajustar(_marco, get_viewport().get_visible_rect().size)
