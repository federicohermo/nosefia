## El menú de inicio: dibuja las opciones que contesta el dominio y entra al almacén.
extends Control

const ESCENA_DEL_ALMACEN := "res://src/escenas/almacen.tscn"

const TEXTOS: Dictionary[MenuDeInicio.Opcion, String] = {
	MenuDeInicio.Opcion.NUEVO_JUEGO: "NUEVO JUEGO",
	MenuDeInicio.Opcion.CONTINUAR: "CONTINUAR",
	MenuDeInicio.Opcion.CONFIGURACIONES: "CONFIGURACIONES",
	MenuDeInicio.Opcion.LOGROS: "LOGROS",
	MenuDeInicio.Opcion.SALIR: "SALIR",
}

@export var _opciones: VBoxContainer
@export var _pedidos: PedidosDelMenu
@export var _guardado: Guardado
@export var _confirmacion: ConfirmationDialog


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


## Nuevo juego y continuar entran por acá. El almacén decide solo si retoma: lee el guardado.
func entrar_al_almacen() -> void:
	get_tree().change_scene_to_file(ESCENA_DEL_ALMACEN)
