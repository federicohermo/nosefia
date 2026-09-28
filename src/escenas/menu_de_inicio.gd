## El menú de inicio: dibuja las opciones que contesta el dominio y entra al almacén.
extends Control

const ESCENA_DEL_ALMACEN := "res://src/escenas/almacen.tscn"
const PANTALLA_DE_CARGA := preload("res://src/ui/interrupciones/pantalla_de_carga.tscn")

const TEXTOS: Dictionary[MenuDeInicio.Opcion, String] = {
	MenuDeInicio.Opcion.NUEVO_JUEGO: "NUEVO JUEGO",
	MenuDeInicio.Opcion.CONTINUAR: "CONTINUAR",
	MenuDeInicio.Opcion.CONFIGURACIONES: "CONFIGURACIONES",
	MenuDeInicio.Opcion.LOGROS: "LOGROS",
	MenuDeInicio.Opcion.SALIR: "SALIR",
}

@export var _opciones: VBoxContainer
@export var _pedidos: PedidosDelMenu
@export var _confirmacion: ConfirmationDialog

var _guardado := Guardado.new()

var _carga: CargaEnSegundoPlano
var _pantalla: PantallaDeCarga
var _almacen: PackedScene
var _esperando := false


func _ready() -> void:
	var menu := MenuDeInicio.new(OS.has_feature("web"), _guardado.hay_guardado())
	_pedidos.preparar(menu, _guardado)
	for opcion: MenuDeInicio.Opcion in menu.opciones():
		var boton := Button.new()
		boton.text = TEXTOS[opcion]
		boton.disabled = not menu.habilitada(opcion)
		boton.pressed.connect(_pedidos.elegir.bind(opcion))
		_opciones.add_child(boton)
	_pedidos.nuevo_juego_pedido.connect(entrar_al_almacen)
	_pedidos.continuar_pedido.connect(entrar_al_almacen)
	_pedidos.confirmacion_pedida.connect(_confirmacion.popup_centered)
	_confirmacion.confirmed.connect(_pedidos.confirmar_nuevo_juego)
	# Se crean acá y no al declararlos: una instancia que nunca entra al árbol los dejaría
	# colgados.
	_carga = CargaEnSegundoPlano.new()
	_pantalla = PANTALLA_DE_CARGA.instantiate()
	add_child(_carga)
	add_child(_pantalla)
	_carga.lista.connect(_al_cargar_el_almacen)
	_carga.fallo.connect(_al_fallar_la_carga)
	_carga.pedir(ESCENA_DEL_ALMACEN)
	print("[carga] menú visible")


func _process(_delta: float) -> void:
	_pantalla.pintar(_carga.progreso())


## Nuevo juego y continuar entran por acá. El almacén decide solo si retoma: lee el guardado.
func entrar_al_almacen() -> void:
	if _almacen != null:
		get_tree().change_scene_to_packed(_almacen)
		return
	_esperando = true
	_carga.pedir(ESCENA_DEL_ALMACEN)
	_pantalla.mostrar()


func _al_cargar_el_almacen(escena: PackedScene) -> void:
	_almacen = escena
	if _esperando:
		get_tree().change_scene_to_packed(_almacen)


## Una carga fallida no deja al jugador colgado en la pantalla de carga: vuelve al menú, y el
## próximo «Nuevo juego» pide el almacén otra vez.
func _al_fallar_la_carga() -> void:
	_esperando = false
	_pantalla.ocultar()
	_pedidos.rearmar()
