## La pantalla del turno: cuántas obligatorias van, los controles que sirven ahora y lo que dice
## la caja examinada.
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

## Cómo se lee cada botón del mouse, por su máscara. Los demás botones no tienen nombre: la línea
## de un gesto que sólo tiene uno de ésos no se pinta.
const NOMBRES_DE_LOS_BOTONES := {
	MOUSE_BUTTON_MASK_LEFT: "Click Izq",
	MOUSE_BUTTON_MASK_RIGHT: "Click Der",
}

@export var _tareas: Label
@export var _subtitulo: Label

## La referencia de controles, una línea por renglón, debajo del contador de tareas.
@export var _controles: Label

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


## Pinta las líneas de la referencia con el control que cada gesto tiene asignado ahora. Qué
## líneas valen llega decidido; la que no tiene un control con nombre no se pinta.
func pintar_referencia(lineas: Array[ReferenciaDeControles.Linea]) -> void:
	var textos := PackedStringArray()
	for linea in lineas:
		var texto := ReferenciaDeControles.texto(
			linea, nombre_del_control(ReferenciaDeControles.accion(linea))
		)
		if not texto.is_empty():
			textos.append(texto)
	mostrar_referencia(textos)


## Pinta las líneas tal como llegan, una por renglón. Una lista vacía no dice nada.
func mostrar_referencia(lineas: PackedStringArray) -> void:
	_controles.text = "\n".join(lineas)


## El nombre del control asignado al gesto: el primero de teclado o de mouse que tenga nombre. Un
## joystick no se lee. Sin ninguno, vacío.
static func nombre_del_control(accion: StringName) -> String:
	if not InputMap.has_action(accion):
		return ""
	for evento in InputMap.action_get_events(accion):
		var nombre := _nombre_del_evento(evento)
		if not nombre.is_empty():
			return nombre
	return ""


static func _nombre_del_evento(evento: InputEvent) -> String:
	var boton := evento as InputEventMouseButton
	if boton != null:
		if boton.button_index <= 0:
			return ""
		var nombre: String = NOMBRES_DE_LOS_BOTONES.get(1 << (boton.button_index - 1), "")
		return nombre
	var tecla := evento as InputEventKey
	if tecla == null:
		return ""
	# La asignación de fábrica guarda la tecla física. Traducirla con la distribución del teclado
	# es del servidor de pantalla, que en headless no la soporta: se lee la tecla como está.
	var codigo := tecla.keycode
	if codigo == KEY_NONE:
		codigo = tecla.key_label
	if codigo == KEY_NONE:
		codigo = tecla.physical_keycode
	return OS.get_keycode_string(codigo)


## Borra la línea en el acto. La llaman el fin del examen y la jornada que se abre.
func vaciar_subtitulo() -> void:
	_linea.soltar()
	_pintar_el_subtitulo()


func _pintar_el_subtitulo() -> void:
	_subtitulo.text = _linea.texto()
	_subtitulo.modulate.a = _linea.opacidad()
