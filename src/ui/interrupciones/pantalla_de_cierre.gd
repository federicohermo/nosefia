## La placa del cierre: copia el parte y lo pone en pantalla.
##
## **No tiene una sola condición adentro, y eso es lo que este spec vino a comprar.** Qué texto
## va en cada renglón y qué botones se ofrecen son reglas del juego, y una regla escrita acá
## arriba nace sin test: está medido que ni `gate_de_tests.py` ni `gate_de_capas.py` la ven.
## Todo lo que se lee en la placa sale ya decidido de `ParteDeCierre`.
##
## **No pausa nada**, y no hace falta: cuando aparece, el reloj del turno ya cerró.
##
## Las líneas se crean en vez de venir escritas en la escena porque son tantas como obligatorias
## pida la jornada, y ese número no está escrito en ninguna parte — sale de recorrer la lista.
class_name PantallaDeCierre
extends CanvasLayer

signal cierre_despachado(opcion: ParteDeCierre.Opcion)

## Lo único propio de esta capa: la palabra de cada botón. Vive acá y **no** además en el
## `.tscn`, que es lo que pide `.claude/rules/presentacion.md` — un texto en los dos lados se
## cambia en uno solo el día que haya que cambiarlo.
const TEXTOS: Dictionary[ParteDeCierre.Opcion, String] = {
	ParteDeCierre.Opcion.SEGUIR: "SEGUIR",
	ParteDeCierre.Opcion.VOLVER_AL_MENU: "VOLVER AL MENÚ",
}

@export var _fondo: ColorRect
@export var _marco: Control
@export var _saludo: Label
@export var _renglones: VBoxContainer
@export var _comentario: Label
@export var _riesgo: Label
@export var _continuar: Button
@export var _volver_al_menu: Button

var _botones: Dictionary[ParteDeCierre.Opcion, Button] = {}


## Arranca invisible: la placa es del cierre y no del arranque. Visible desde el primer cuadro
## taparía la jornada entera, y el jugador no tendría cómo sacarla porque el turno recién empieza.
func _ready() -> void:
	visible = false
	_botones = {
		ParteDeCierre.Opcion.SEGUIR: _continuar,
		ParteDeCierre.Opcion.VOLVER_AL_MENU: _volver_al_menu,
	}
	for opcion: ParteDeCierre.Opcion in _botones:
		_botones[opcion].text = TEXTOS[opcion]
		_botones[opcion].pressed.connect(_al_elegir.bind(opcion))
	get_viewport().size_changed.connect(_ajustar_al_viewport)
	_ajustar_al_viewport()


## Pinta el parte y se muestra.
func mostrar(parte: ParteDeCierre) -> void:
	_saludo.text = parte.saludo()
	_comentario.text = parte.comentario()
	_riesgo.text = parte.aviso_de_riesgo()
	_riesgo.visible = parte.en_riesgo()
	_pintar(parte.lineas())
	var opciones := parte.opciones()
	for opcion: ParteDeCierre.Opcion in _botones:
		_botones[opcion].visible = opciones.has(opcion)
	visible = true
	# Con el foco puesto, `ui_accept` despacha el cierre aunque el mouse no llegue al botón.
	_botones[opciones[0]].grab_focus()


## Reemplaza los renglones de la jornada anterior.
##
## Se sacan del árbol **antes** de liberarlos: `queue_free()` no los desprende hasta el final
## del cuadro, así que sin el `remove_child` la placa de la noche 5 tendría los renglones de las
## cinco noches apilados.
func _pintar(lineas: Array[String]) -> void:
	for viejo in _renglones.get_children():
		_renglones.remove_child(viejo)
		viejo.queue_free()
	for linea in lineas:
		var etiqueta := Label.new()
		etiqueta.text = linea
		_renglones.add_child(etiqueta)


## La placa se cierra sola y avisa qué se eligió. Qué hace cada opción no es asunto de la
## pantalla: emite hacia arriba y el cableado de la escena lo resuelve.
func _al_elegir(opcion: ParteDeCierre.Opcion) -> void:
	visible = false
	cierre_despachado.emit(opcion)


func _ajustar_al_viewport() -> void:
	LienzoDeManada.ajustar(_marco, get_viewport().get_visible_rect().size)
