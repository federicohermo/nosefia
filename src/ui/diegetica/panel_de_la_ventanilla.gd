## El panel de la ventanilla: copia lo que la atención dice y lo pone en pantalla.
##
## **No tiene una sola condición sobre el juego, y eso es lo que este spec vino a comprar.** Qué
## va en cada renglón, cuánto marca la caja y qué no se puede vender son reglas, y una regla
## escrita acá arriba nace sin test: está medido que ni `gate_de_tests.py` ni `gate_de_capas.py`
## la ven.
## Todo lo que se lee sale ya decidido de `Atencion`.
##
## **No pausa nada, y es deliberado**: mientras el panel está arriba el turno sigue corriendo.
## Atender cuesta minutos, y ésa es la mitad de la tensión que este spec pone del lado de la
## tarea.
##
## Va en `diegetica/` y no en `interrupciones/`, que es el criterio de esa carpeta —si el reloj
## sigue corriendo—: éste corre.
class_name PanelDeLaVentanilla
extends CanvasLayer

signal cobro_pedido
signal despacho_pedido

## Lo único propio de esta capa son las palabras de los botones y el cartel de la ventanilla
## vacía. Viven acá y **no** además en el `.tscn`: un texto en los dos lados se cambia en uno solo
## el día que haya que cambiarlo.
const TEXTO_DE_COBRAR := "COBRAR"
const TEXTO_DE_DESPACHAR := "DESPACHAR SIN COBRAR"
const TEXTO_SIN_NADIE := "No hay nadie en la ventanilla."

@export var _fondo: ColorRect
@export var _marco: Control
@export var _titulo: Label
@export var _cliente: Label
@export var _pedido: Label
@export var _cobro: Label
@export var _salida: Label
@export var _nombre: Label
@export var _renglones: VBoxContainer
@export var _aviso: Label
@export var _cobrar: Button
@export var _despachar: Button


## Arranca invisible: la ventanilla se abre cuando el jugador va, no cuando empieza la noche.
func _ready() -> void:
	visible = false
	_titulo.text = "/ ATENDER:"
	_cliente.text = "/ CLIENTE:"
	_pedido.text = "/ PEDIDO:"
	_cobro.text = "/ COBRO:"
	_salida.text = LienzoDeManada.TEXTO_DE_SALIDA
	get_viewport().size_changed.connect(_ajustar_al_viewport)
	_ajustar_al_viewport()
	_cobrar.text = TEXTO_DE_COBRAR
	_despachar.text = TEXTO_DE_DESPACHAR
	_cobrar.pressed.connect(cobro_pedido.emit)
	_despachar.pressed.connect(despacho_pedido.emit)


## Pinta la atención y se muestra.
func mostrar(atencion: Atencion) -> void:
	_nombre.text = atencion.comprador().nombre()
	_pintar(atencion.renglones())
	_aviso.text = atencion.aviso()
	_botones(true)
	visible = true


## El cartel de que no queda nadie por atender.
##
## Es un método aparte y no un `mostrar(null)` para que acá no haya que decidir nada: dos
## situaciones distintas, dos llamadas, cero condiciones en esta capa.
func mostrar_sin_nadie() -> void:
	_nombre.text = TEXTO_SIN_NADIE
	_pintar([])
	_aviso.text = ""
	_botones(false)
	visible = true


func ocultar() -> void:
	visible = false


## Reemplaza los renglones de la atención anterior.
##
## Se sacan del árbol **antes** de liberarlos: `queue_free()` no los desprende hasta el final del
## cuadro, así que sin el `remove_child` el segundo comprador tendría el ticket del primero
## apilado encima.
func _pintar(lineas: Array[String]) -> void:
	for viejo in _renglones.get_children():
		_renglones.remove_child(viejo)
		viejo.queue_free()
	for linea in lineas:
		var etiqueta := Label.new()
		etiqueta.text = linea
		etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_renglones.add_child(etiqueta)


## Los botones sólo tienen sentido con alguien del otro lado del vidrio.
func _botones(hay_alguien: bool) -> void:
	_cobrar.visible = hay_alguien
	_despachar.visible = hay_alguien


func _ajustar_al_viewport() -> void:
	LienzoDeManada.ajustar(_marco, get_viewport().get_visible_rect().size)
