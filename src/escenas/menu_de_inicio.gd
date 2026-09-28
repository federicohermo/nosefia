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

## El frame de Figma pone estas dos en una fila debajo de la columna.
const EN_LA_FILA: Array[MenuDeInicio.Opcion] = [
	MenuDeInicio.Opcion.CONFIGURACIONES,
	MenuDeInicio.Opcion.SALIR,
]

@export var _opciones: VBoxContainer
@export var _pedidos: PedidosDelMenu
@export var _marco: Control
@export var _fila: HBoxContainer


func _notification(que: int) -> void:
	if que == NOTIFICATION_RESIZED:
		LienzoDeManada.ajustar(_marco, size)


func _ready() -> void:
	var menu := MenuDeInicio.new(OS.has_feature("web"))
	for opcion: MenuDeInicio.Opcion in menu.opciones():
		var boton := Button.new()
		boton.text = TEXTOS[opcion]
		boton.disabled = not menu.habilitada(opcion)
		boton.pressed.connect(_pedidos.elegir.bind(opcion))
		boton.theme_type_variation = &"BotonDelMenu"
		if opcion in EN_LA_FILA:
			boton.custom_minimum_size.x = _opciones.size.x
			_fila.add_child(boton)
		else:
			_opciones.add_child(boton)
	_pedidos.nuevo_juego_pedido.connect(entrar_al_almacen)


func entrar_al_almacen() -> void:
	get_tree().change_scene_to_file(ESCENA_DEL_ALMACEN)
