## La línea de `cabecera.svg`, con la solapa del tamaño de lo que lleva adentro. La imagen trae la
## solapa fija para un título corto, y uno largo se le salía por el costado.
##
## Dada vuelta es el pie: la solapa cuelga abajo a la derecha y se ensancha hacia la izquierda.
## No se hace más honda: lo que lleva adentro puede sobresalir por abajo.
##
## Al aparecer, la solapa crece o se achica desde la última que se ocultó en ese mismo lugar:
## pasar de una pantalla a la otra, de ida y de vuelta, no la hace saltar. Las pantallas que se
## turnan ponen sus líneas en el mismo lugar del lienzo, y por eso alcanza con recordar el cierre.
class_name CabeceraConSolapa
extends Control

const COLOR := Color("f0f4d1")
const GROSOR := 2.0
## Lo que la solapa pasa de lo que lleva adentro, en píxeles.
const AIRE := 32.0
## Lo que mide `cabecera.svg`: los puntos de abajo están en sus unidades.
const ANCHO := 1713.59
const ALTO := 70.3058
## Cuánto tarda la solapa en crecer, en segundos.
const DURACION := 0.25
## El paso más largo que se le cuenta a un cuadro. El cuadro que abre una pantalla tarda, y con
## el tiempo entero se comía la animación de un salto.
const PASO_MAXIMO := 1.0 / 30.0

## El cierre de la última solapa que se ocultó, arriba y abajo. Es de todo el proceso: la que se
## oculta es de otra pantalla.
static var _ultimos_cierres: Dictionary[bool, float] = {}

@export var contenido: Control
@export var volteada := false

## De 0, el cierre de la solapa anterior, a 1, el que pide el ancho de lo que lleva adentro.
var avance := 1.0:
	set(valor):
		avance = valor
		queue_redraw()

var _transcurrido := DURACION
## Si se veía en el último aviso. Una pantalla oculta recibe avisos igual —su capa, su marco—, y
## sin esto una solapa que ya estaba oculta pisaba el cierre que acababa de anotar otra.
var _a_la_vista := false
var _desde := NAN
var _cierre_dibujado := NAN


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if contenido != null:
		contenido.minimum_size_changed.connect(queue_redraw)
		contenido.resized.connect(queue_redraw)
	set_process(false)
	_a_la_vista = is_visible_in_tree()
	visibility_changed.connect(_al_cambiar_la_visibilidad)
	var capa := get_canvas_layer_node()
	if capa != null:
		capa.visibility_changed.connect(_al_cambiar_la_visibilidad)


func _al_cambiar_la_visibilidad() -> void:
	if is_visible_in_tree() == _a_la_vista:
		return
	_a_la_vista = is_visible_in_tree()
	if not _a_la_vista:
		if not is_nan(_cierre_dibujado):
			_ultimos_cierres[volteada] = _cierre_dibujado
		return
	_desde = _ultimos_cierres.get(volteada, NAN)
	_transcurrido = 0.0
	avance = 0.0
	set_process(true)


## Frena al llegar: la curva es la de un cúbico que sale rápido.
func _process(delta: float) -> void:
	_transcurrido = minf(_transcurrido + minf(delta, PASO_MAXIMO), DURACION)
	avance = 1.0 - pow(1.0 - _transcurrido / DURACION, 3.0)
	if _transcurrido >= DURACION:
		set_process(false)


## Los mismos puntos que el SVG. El cierre de la solapa sale de lo que lleva adentro: la de la
## imagen, si no lleva nada, o lo que haga falta para que entre. Se dibuja
## derecha y, si va dada vuelta, se espeja entera.
##
## Lo que sobresale tapa el borde de la solapa: ese tramo no se dibuja, porque el relleno del botón
## es translúcido y la línea se vería cruzándolo.
func _draw() -> void:
	var escala := Vector2(size.x / ANCHO, size.y / ALTO)
	var cierre := 282.61 * escala.x
	var desde := cierre if is_nan(_desde) else _desde
	var borde := 1.0 * escala.y
	var tapado := Vector2(INF, INF)
	if contenido != null:
		var caja := Rect2(contenido.position - position, contenido.size * contenido.scale)
		if volteada:
			caja = Rect2(size - caja.end, caja.size)
		else:
			caja.size.x = contenido.get_minimum_size().x * contenido.scale.x
		cierre = maxf(cierre, caja.end.x + AIRE)
		if caja.position.y < borde and caja.end.y > borde:
			tapado = Vector2(caja.position.x, caja.end.x)
	cierre = lerpf(desde, cierre, avance)
	_cierre_dibujado = cierre
	if volteada:
		draw_set_transform(size, 0.0, -Vector2.ONE)
	var antes := PackedVector2Array(
		[Vector2(1, 70) * escala, Vector2(1, 48.5) * escala, Vector2(35.292, 1) * escala]
	)
	var despues := PackedVector2Array(
		[
			Vector2(cierre, borde),
			Vector2(cierre, 48.5 * escala.y),
			Vector2(1684.42, 48.5) * escala,
			Vector2(1713, 69.5) * escala,
		]
	)
	if tapado.x < cierre:
		antes.append(Vector2(tapado.x, borde))
		despues.insert(0, Vector2(minf(tapado.y, cierre), borde))
		draw_polyline(antes, COLOR, GROSOR)
		draw_polyline(despues, COLOR, GROSOR)
		return
	antes.append_array(despues)
	draw_polyline(antes, COLOR, GROSOR)
