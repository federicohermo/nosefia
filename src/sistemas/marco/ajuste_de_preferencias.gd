## Aplica unas `Preferencias` al motor: el volumen de los cuatro buses, el brillo y la letra de la
## interfaz. Escribe cada cambio al disco en el momento.
##
## **El volumen y la letra son de todo el proceso**: los buses del `AudioServer` y el tema de
## Manada, que el motor carga una sola vez. El brillo, en cambio, es de cada pantalla: se
## multiplica el color de cada raíz que usa el tema, y las que entran al árbol después lo toman
## al entrar. El local en 3D no usa el tema, y por eso no cambia.
##
## La letra se escala sobre los tamaños de hoy y no sobre los de la escala anterior: los de hoy
## se anotan la primera vez que se toca el tema, y cada escala sale de ellos.
class_name AjusteDePreferencias
extends Node

const TEMA := preload("res://assets/ui/manada/tema.tres")

## Los buses que regula cada barra de volumen.
const BUSES: Dictionary[Preferencias.Campo, Array] = {
	Preferencias.Campo.EFECTOS:
	[EntradaSonora.BUS_DE_AMBIENTE, EntradaSonora.BUS_DE_EFECTOS, EntradaSonora.BUS_DE_INTERFAZ],
	Preferencias.Campo.MUSICA: [EntradaSonora.BUS_DE_MUSICA],
}

## Los tamaños de letra de hoy, por `tipo/nombre`. Son del tema, que es uno solo en el proceso.
static var _tamanos_de_hoy: Dictionary[String, int] = {}
static var _letra_de_hoy: int = -1

var archivo := ArchivoDePreferencias.new()

var _actuales := Preferencias.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## El brillo de lo que entra después: una pantalla que se instancia a mitad de la noche.
func _enter_tree() -> void:
	get_tree().node_added.connect(_al_entrar_un_nodo)


func _exit_tree() -> void:
	get_tree().node_added.disconnect(_al_entrar_un_nodo)


## Lee lo guardado y lo aplica. Es lo primero que hace cada escena que abre el juego.
func cargar_y_aplicar() -> Preferencias:
	aplicar(archivo.cargar())
	return actuales()


## Aplica y escribe: cada cambio llega al disco en el momento, sin esperar a cerrar la pantalla.
func cambiar(preferencias: Preferencias) -> bool:
	aplicar(preferencias)
	return archivo.escribir(preferencias)


func aplicar(preferencias: Preferencias) -> void:
	_actuales = preferencias.copia()
	for campo: Preferencias.Campo in BUSES:
		for bus: String in BUSES[campo]:
			var indice := AudioServer.get_bus_index(bus)
			AudioServer.set_bus_volume_db(indice, preferencias.decibelios(campo))
			AudioServer.set_bus_mute(indice, preferencias.en_silencio(campo))
	_escalar_la_letra(preferencias.valor(Preferencias.Campo.TEXTOS))
	if is_inside_tree():
		_iluminar(get_tree().root)


func actuales() -> Preferencias:
	return _actuales.copia()


func _al_entrar_un_nodo(nodo: Node) -> void:
	_iluminar_uno(nodo)


func _iluminar(raiz: Node) -> void:
	_iluminar_uno(raiz)
	for hijo: Node in raiz.find_children("*", "Control", true, false):
		_iluminar_uno(hijo)


func _iluminar_uno(nodo: Node) -> void:
	var control := nodo as Control
	if control == null or control.theme != TEMA:
		return
	var brillo := _actuales.valor(Preferencias.Campo.BRILLO) / 100.0
	control.modulate = Color(brillo, brillo, brillo, control.modulate.a)


## El redondeo al entero más cercano es provisorio: lo deja abierto `OQ-CFG-002`.
##
## La letra por defecto se lee con su método y no como propiedad: sobre una constante, el
## compilador pliega `TEMA.default_font_size` al valor del archivo, y nunca ve la escala.
func _escalar_la_letra(escala: float) -> void:
	_anotar_los_tamanos_de_hoy()
	var letra := roundi(_letra_de_hoy * escala)
	if TEMA.get_default_font_size() != letra:
		TEMA.set_default_font_size(letra)
	for clave: String in _tamanos_de_hoy:
		var partes := clave.split("/")
		var tamano := roundi(_tamanos_de_hoy[clave] * escala)
		if TEMA.get_font_size(partes[1], partes[0]) != tamano:
			TEMA.set_font_size(partes[1], partes[0], tamano)


static func _anotar_los_tamanos_de_hoy() -> void:
	if _letra_de_hoy >= 0:
		return
	_letra_de_hoy = TEMA.get_default_font_size()
	for tipo: StringName in TEMA.get_font_size_type_list():
		for nombre: StringName in TEMA.get_font_size_list(tipo):
			_tamanos_de_hoy["%s/%s" % [tipo, nombre]] = TEMA.get_font_size(nombre, tipo)
