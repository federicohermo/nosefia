## La placa del cierre: copia el parte y lo pone en pantalla.
##
## **No tiene una sola condición adentro, y eso es lo que este spec vino a comprar.** Qué texto
## va en cada renglón es una regla del juego, y una regla escrita acá arriba nace sin test: está
## medido que ni `gate_de_tests.py` ni `gate_de_capas.py` la ven. Todo lo que se lee en la placa
## sale ya decidido de `ParteDeCierre`.
##
## **No pausa nada**, y no hace falta: cuando aparece, el reloj del turno ya cerró.
##
## Las líneas se crean en vez de venir escritas en la escena porque son tantas como obligatorias
## pida la jornada, y ese número no está escrito en ninguna parte — sale de recorrer la lista.
class_name PantallaDeCierre
extends CanvasLayer

signal cierre_despachado

## Lo único propio de esta capa: la palabra del botón. Vive acá y **no** además en el `.tscn`,
## que es lo que pide `.claude/rules/presentacion.md` — un texto en los dos lados se cambia en
## uno solo el día que haya que cambiarlo.
const TEXTO_DE_CONTINUAR := "Seguir"

@export var _fondo: ColorRect
@export var _saludo: Label
@export var _renglones: VBoxContainer
@export var _comentario: Label
@export var _riesgo: Label
@export var _continuar: Button


## Arranca invisible: la placa es del cierre y no del arranque. Visible desde el primer cuadro
## taparía la jornada entera, y el jugador no tendría cómo sacarla porque el turno recién empieza.
func _ready() -> void:
	visible = false
	_continuar.text = TEXTO_DE_CONTINUAR
	_continuar.pressed.connect(_al_continuar)


## Pinta el parte y se muestra.
func mostrar(parte: ParteDeCierre) -> void:
	_saludo.text = parte.saludo()
	_comentario.text = parte.comentario()
	_riesgo.text = parte.aviso_de_riesgo()
	_riesgo.visible = parte.en_riesgo()
	_pintar(parte.lineas())
	visible = true


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


## La placa se cierra sola y avisa. Quién abre la jornada siguiente no es asunto de la pantalla:
## emite hacia arriba y el cableado de la escena decide qué hacer.
func _al_continuar() -> void:
	visible = false
	cierre_despachado.emit()
