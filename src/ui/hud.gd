## La pantalla del turno: cuántas obligatorias van y lo que dice la caja examinada.
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
## **El subtítulo llega escrito.** Lo que dice una caja examinada lo arma `dominio/`, que es donde
## tiene test; acá se pinta y se vacía. Va con el tema de Manada y sin fuente ni color propios: el
## contorno que lo deja leer sobre el blanco del estante es de su variación en el tema.
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

@onready var _mira: ColorRect = $Mira


func _ready() -> void:
	var mitad := IndicacionDelFoco.TAMANO_DE_MIRA / 2.0
	_mira.offset_left = -mitad
	_mira.offset_top = -mitad
	_mira.offset_right = mitad
	_mira.offset_bottom = mitad
	ocultar_foco()


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


## Pinta la línea de subtítulo tal como llega. Un texto vacío es no decir nada.
func mostrar_subtitulo(texto: String) -> void:
	_subtitulo.text = texto


## Borra la línea de subtítulo. La llama el fin del examen: el subtítulo dura lo que dura él.
func vaciar_subtitulo() -> void:
	_subtitulo.text = ""
