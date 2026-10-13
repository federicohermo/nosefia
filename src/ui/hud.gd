## La pantalla del turno: cuántas obligatorias van y el subtítulo de lo que se mira o examina.
##
## **Recibe todo ya decidido y lo pinta.** No conoce al nodo que le manda los números: se
## conecta por señal desde la escena.
##
## **La hora no está acá, y ésa es la decisión.** El GDD la pone en el reloj de mesa del local,
## no en la pantalla: un número siempre visible afloja la tensión, porque saber cuánto queda
## sale gratis. Con la hora afuera, enterarse cuesta caminar. Lo que quedó de eso vive en el
## dominio y en el nodo que lo pinta.
##
## Lo único propio de esta capa son las palabras. El veredicto del cierre **no** se dibuja acá:
## es de la pantalla de fin de jornada, y tenerlo en los dos lados sería la misma banda traducida
## a palabras en dos archivos que no llevan test obligatorio.
##
## **El subtítulo llega escrito.** Qué dice cada cosa lo arma `dominio/`, y cuánto se ve lo
## decide `Subtitulo`, que es donde tienen test; acá se le pasa el tiempo y se pinta. Va con el
## tema de Manada y sin fuente ni color propios: el contorno que lo deja leer sobre el blanco del
## estante es de su variación en el tema.
class_name Hud
extends CanvasLayer

## El texto de tareas vive acá y **no** además en `hud.tscn`, que es lo que pide
## `.claude/rules/presentacion.md`: los `Label` de la escena nacen vacíos y el cableado los pinta
## en su `_ready()`. Un texto en los dos lados se cambia en uno solo el día que haya que
## cambiarlo.
const TEXTO_DE_LAS_TAREAS := "Tareas %s"

@export var _tareas: Label
@export var _subtitulo: Label

var foco_presente: bool = false

var _obligatorias: int = 0

var _linea := Subtitulo.new()

@onready var _mira: ColorRect = $Mira


func _ready() -> void:
	var mitad := IndicacionDelFoco.TAMANO_DE_MIRA / 2.0
	_mira.offset_left = -mitad
	_mira.offset_top = -mitad
	_mira.offset_right = mitad
	_mira.offset_bottom = mitad
	ocultar_foco()
	_pintar_el_subtitulo()


## El pensamiento corre con el cuadro. Con la pausa abierta el árbol no procesa, y el tiempo
## del pensamiento queda donde estaba.
func _process(delta: float) -> void:
	_linea.avanzar(delta)
	_pintar_el_subtitulo()


func mostrar_foco(_objetivo: Node3D, _distancia: float) -> void:
	foco_presente = true
	_mira.color = IndicacionDelFoco.COLOR


func ocultar_foco() -> void:
	foco_presente = false
	_mira.color = IndicacionDelFoco.COLOR_SIN_FOCO


## Cuántas obligatorias pide la jornada. Se declara una vez al abrir el turno y el HUD la guarda
## para no tener que recibirla en cada actualización.
func declarar_obligatorias(cuantas: int) -> void:
	_obligatorias = cuantas
	mostrar_tareas(0)


func mostrar_tareas(cumplidas: int) -> void:
	_tareas.text = TEXTO_DE_LAS_TAREAS % Marcador.tareas(cumplidas, _obligatorias)


## Un pensamiento: se ve un rato y se desvanece. Un texto vacío no cambia la línea.
func pensar(texto: String) -> void:
	_linea.pensar(texto)
	_pintar_el_subtitulo()


## El texto del examen: queda fijo hasta `vaciar_subtitulo()`.
func mostrar_subtitulo(texto: String) -> void:
	_linea.fijar(texto)
	_pintar_el_subtitulo()


## Borra la línea en el acto. La llaman el fin del examen y la jornada que se abre.
func vaciar_subtitulo() -> void:
	_linea.soltar()
	_pintar_el_subtitulo()


func _pintar_el_subtitulo() -> void:
	_subtitulo.text = _linea.texto()
	_subtitulo.modulate.a = _linea.opacidad()
