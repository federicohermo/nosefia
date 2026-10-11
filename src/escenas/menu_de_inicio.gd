## El menú de inicio: dibuja las opciones que contesta el dominio y entra al almacén.
extends Control

const ESCENA_DEL_ALMACEN := "res://src/escenas/almacen.tscn"
const PANTALLA_DE_CARGA := preload("res://src/ui/interrupciones/pantalla_de_carga.tscn")
## Por encima de todas las capas del almacén: se lo arma detrás de la pantalla de carga.
const CAPA_DE_LA_CARGA := 10
## La barra se reparte entre leer el almacén y calentar sus shaders.
const PARTE_DE_LA_LECTURA := 0.5

const TEXTOS: Dictionary[MenuDeInicio.Opcion, String] = {
	MenuDeInicio.Opcion.NUEVO_JUEGO: "NUEVO JUEGO",
	MenuDeInicio.Opcion.CONTINUAR: "CONTINUAR",
	MenuDeInicio.Opcion.CONFIGURACIONES: MenuDePausa.TEXTO_DE_CONFIGURACIONES,
	MenuDeInicio.Opcion.LOGROS: MenuDePausa.TEXTO_DE_LOGROS,
	MenuDeInicio.Opcion.SALIR: "SALIR",
}

## El frame de Figma pone estas dos en una fila debajo de la columna.
const EN_LA_FILA: Array[MenuDeInicio.Opcion] = [
	MenuDeInicio.Opcion.CONFIGURACIONES,
	MenuDeInicio.Opcion.SALIR,
]

@export var _opciones: VBoxContainer
@export var _pedidos: PedidosDelMenu
@export var _confirmacion: ConfirmationDialog
@export var _marco: Control
@export var _fila: HBoxContainer

var _guardado := Guardado.new()

var _carga: CargaEnSegundoPlano
var _pantalla: PantallaDeCarga
var _almacen: PackedScene
var _espera: EsperaDeLaCarga
var _calentamiento: CalentamientoDeShaders


func _notification(que: int) -> void:
	if que == NOTIFICATION_RESIZED:
		LienzoDeManada.ajustar(_marco, size)


func _ready() -> void:
	var menu := MenuDeInicio.new(OS.has_feature("web"), _guardado.hay_guardado())
	_pedidos.preparar(menu, _guardado)
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
	_pedidos.continuar_pedido.connect(entrar_al_almacen)
	_pedidos.confirmacion_pedida.connect(_confirmacion.popup_centered)
	_confirmacion.confirmed.connect(_pedidos.confirmar_nuevo_juego)
	# Se crean acá y no al declararlos: una instancia que nunca entra al árbol los dejaría
	# colgados.
	_carga = CargaEnSegundoPlano.new()
	_pantalla = PANTALLA_DE_CARGA.instantiate()
	_calentamiento = CalentamientoDeShaders.new()
	var capa := CanvasLayer.new()
	capa.layer = CAPA_DE_LA_CARGA
	capa.add_child(_pantalla)
	add_child(_carga)
	add_child(capa)
	add_child(_calentamiento)
	_calentamiento.avanzo.connect(_pintar_el_calentamiento)
	_carga.lista.connect(_al_cargar_el_almacen)
	_carga.fallo.connect(_al_fallar_la_carga)
	_carga.pedir(ESCENA_DEL_ALMACEN)
	print("[carga] menú visible")


func _process(delta: float) -> void:
	_pantalla.pintar(_carga.progreso() * PARTE_DE_LA_LECTURA)
	if _espera == null:
		return
	_espera.avanzar(delta)
	if _espera.puede_entrar():
		_espera = null
		_calentar_el_almacen()


## Nuevo juego y continuar entran por acá. El almacén decide solo si retoma: lee el guardado.
func entrar_al_almacen() -> void:
	_espera = EsperaDeLaCarga.new()
	if _almacen != null:
		_espera.terminar_carga()
	else:
		_carga.pedir(ESCENA_DEL_ALMACEN)
	_pantalla.mostrar()


## El almacén entra al árbol detenido, detrás de la pantalla de carga, y recién pasa a ser la
## escena cuando dibujó cada objeto una vez: en la web, cada shader se compila la primera vez que
## se dibuja, y cada uno frena el navegador alrededor de un segundo. Detenido, el reloj del turno
## no corre, el jugador no se mueve y no suena nada. Se lo detiene después de entrar: sólo así el
## motor pausa el sonido que ya arrancó su `_ready`.
func _calentar_el_almacen() -> void:
	set_process(false)
	var almacen := _almacen.instantiate()
	get_tree().root.add_child(almacen)
	almacen.process_mode = Node.PROCESS_MODE_DISABLED
	_calentamiento.terminado.connect(_entrar.bind(almacen))
	_calentamiento.calentar(almacen)


func _pintar_el_calentamiento(progreso: float) -> void:
	_pantalla.pintar(PARTE_DE_LA_LECTURA + progreso * (1.0 - PARTE_DE_LA_LECTURA))


func _entrar(almacen: Node) -> void:
	almacen.call("anunciar_la_noche")
	almacen.process_mode = Node.PROCESS_MODE_INHERIT
	get_tree().current_scene = almacen
	queue_free()
	print("[carga] almacén en pantalla")


func _al_cargar_el_almacen(escena: PackedScene) -> void:
	_almacen = escena
	if _espera != null:
		_espera.terminar_carga()


## Una carga fallida no deja al jugador colgado en la pantalla de carga: vuelve al menú, y el
## próximo «Nuevo juego» pide el almacén otra vez.
func _al_fallar_la_carga() -> void:
	_espera = null
	_pantalla.ocultar()
	_pedidos.rearmar()
