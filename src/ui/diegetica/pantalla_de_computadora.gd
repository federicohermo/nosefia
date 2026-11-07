## La terminal de ventas. No pausa el turno: registrar cuesta minutos, igual que reponer.
class_name PantallaDeComputadora
extends CanvasLayer

signal boton_pulsado
## El botón de arriba a la derecha pide pasar de la pantalla normal a la conjunta, o volver.
signal conjunta_pedida

const TEXTO_DEL_TITULO := "TERMINAL DE VENTAS  /  REGISTRO DE PRODUCTOS"
const TEXTO_DE_MOSTRAR_EL_CELULAR := "MOSTRAR CELULAR"
const TEXTO_DE_OCULTAR_EL_CELULAR := "OCULTAR CELULAR"
## El margen, en el lienzo, entre el registro y el borde de la ventana y entre el registro y el
## celular cuando están lado a lado.
const MARGEN_CON_EL_CELULAR := 24.0
const POSICION_DEL_BOTON := Vector2(1556.0, 54.0)
const TAMANO_DEL_BOTON := Vector2(320.0, 56.0)

@export var _marco: Control
@export var _titulo: Label
@export var _caja: AppCaja

var _boton_del_celular: Button
var _conjunta: bool = false


## Arranca apagada: la computadora se enciende cuando el jugador va al escritorio, no cuando
## empieza la noche.
func _ready() -> void:
	visible = false
	_titulo.text = TEXTO_DEL_TITULO
	_armar_el_boton_del_celular()
	get_viewport().size_changed.connect(_ajustar_al_viewport)
	_ajustar_al_viewport()
	for boton in find_children("*", "BaseButton", true, false):
		_escuchar(boton)
	# El registro arma sus botones después de `_ready()`.
	get_tree().node_added.connect(_al_agregar_nodo)


func caja() -> AppCaja:
	return _caja


func boton_del_celular() -> Button:
	return _boton_del_celular


## Sólo la jornada que lo declara ofrece el botón.
func ofrecer_el_celular(se_ofrece: bool) -> void:
	_boton_del_celular.visible = se_ofrece
	mostrar_conjunta(false)


func conjunta() -> bool:
	return _conjunta


## En la pantalla conjunta el registro se achica para dejarle lugar al celular.
func mostrar_conjunta(activa: bool) -> void:
	_conjunta = activa
	_boton_del_celular.text = (
		TEXTO_DE_OCULTAR_EL_CELULAR if activa else TEXTO_DE_MOSTRAR_EL_CELULAR
	)
	_ajustar_al_viewport()


func mostrar() -> void:
	visible = true


func ocultar() -> void:
	visible = false


func _armar_el_boton_del_celular() -> void:
	_boton_del_celular = Button.new()
	_boton_del_celular.name = "BotonDelCelular"
	_boton_del_celular.text = TEXTO_DE_MOSTRAR_EL_CELULAR
	_boton_del_celular.position = POSICION_DEL_BOTON
	_boton_del_celular.size = TAMANO_DEL_BOTON
	_boton_del_celular.focus_mode = Control.FOCUS_NONE
	_boton_del_celular.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_boton_del_celular.visible = false
	_boton_del_celular.pressed.connect(func() -> void: conjunta_pedida.emit())
	_marco.add_child(_boton_del_celular)


func _al_agregar_nodo(nodo: Node) -> void:
	if nodo is BaseButton and is_ancestor_of(nodo):
		_escuchar(nodo)


func _escuchar(boton: BaseButton) -> void:
	var avisar := _al_pulsar.bind(boton)
	if not boton.pressed.is_connected(avisar):
		boton.pressed.connect(avisar)


func _al_pulsar(boton: BaseButton) -> void:
	if not boton.disabled:
		boton_pulsado.emit()


## En la conjunta el registro llena el área libre a la izquierda del celular, que se ubica en el
## mismo lienzo que el resto de las pantallas.
func _ajustar_al_viewport() -> void:
	var ventana := get_viewport().get_visible_rect().size
	LienzoDeManada.ajustar(_marco, ventana)
	if not _conjunta:
		return
	var lienzo := _marco.scale.x
	var margen := MARGEN_CON_EL_CELULAR * lienzo
	var celular := _marco.position.x + PantallaDelCelular.borde_izquierdo_en_la_conjunta() * lienzo
	var libre := Rect2(margen, margen, celular - 2.0 * margen, ventana.y - 2.0 * margen)
	LienzoDeManada.ajustar(_marco, libre.size)
	_marco.position += libre.position
