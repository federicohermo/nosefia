## La fila de arriba del teléfono, a la derecha: la hora y, a su derecha, el ícono de wifi.
##
## **Muestra lo que le dan y no decide**: qué hora es lo dice `Marcador` y si hay wifi, el router.
## Sin wifi, el ícono de sin conexión ocupa el lugar del conectado. Antes de que llegue el primer
## tiempo lee la hora de cierre, que es la de entre jornadas.
class_name BarraDeEstadoDelCelular
extends HBoxContainer

const ICONO_CON_WIFI := preload("res://assets/ui/manada/celular/wifi_conectado.svg")
const ICONO_SIN_WIFI := preload("res://assets/ui/manada/celular/wifi_sin_conexion.svg")
## El lugar de cada ícono: lo que mide el dibujo de la ficha de diseño.
const TAMANO_DEL_ICONO := Vector2(28.0, 24.0)
const TINTA_DE_LA_HORA := Color("1f2b2e")
const TAMANO_DE_LA_HORA := 20
const SEPARACION := 12

var _hora: Label
var _con_wifi: TextureRect
var _sin_wifi: TextureRect


func _init(fuente: Font) -> void:
	name = "BarraDeEstado"
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override("separation", SEPARACION)
	custom_minimum_size = Vector2(0.0, TAMANO_DEL_ICONO.y)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hora = Label.new()
	_hora.name = "Hora"
	_hora.text = Marcador.hora(0.0)
	_hora.add_theme_font_override("font", fuente)
	_hora.add_theme_color_override("font_color", TINTA_DE_LA_HORA)
	_hora.add_theme_font_size_override("font_size", TAMANO_DE_LA_HORA)
	_hora.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hora.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hora)
	_con_wifi = _icono("Wifi", ICONO_CON_WIFI)
	_sin_wifi = _icono("SinWifi", ICONO_SIN_WIFI)
	_sin_wifi.visible = false


## La hora, según cuánto queda del turno. Con el turno cerrado queda el último valor que llegó,
## el de la hora de cierre: `RelojDelTurno` emite en cero al cerrar.
func mostrar_tiempo(restante: float) -> void:
	_hora.text = Marcador.hora(restante)


func mostrar_el_wifi(hay_wifi: bool) -> void:
	_con_wifi.visible = hay_wifi
	_sin_wifi.visible = not hay_wifi


func _icono(nombre: String, textura: Texture2D) -> TextureRect:
	var icono := TextureRect.new()
	icono.name = nombre
	icono.texture = textura
	icono.custom_minimum_size = TAMANO_DEL_ICONO
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icono)
	return icono
