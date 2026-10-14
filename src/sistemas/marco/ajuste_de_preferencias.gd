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
const TAMANOS_PROPIOS := &"tamanos_antes_de_las_preferencias"

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
var _escalando := false


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


## La letra queda pendiente mientras se mueve su barra: la pantalla no cambia bajo el cursor.
## Se guarda el valor elegido junto con las otras preferencias, y se aplica al confirmar.
func previsualizar(preferencias: Preferencias) -> bool:
	var inmediatas := preferencias.copia()
	inmediatas.poner(Preferencias.Campo.TEXTOS, _actuales.valor(Preferencias.Campo.TEXTOS))
	aplicar(inmediatas)
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
	if control == null:
		return
	var al_cambiar := _escalar_la_letra_propia.bind(control)
	if not control.theme_changed.is_connected(al_cambiar):
		control.theme_changed.connect(al_cambiar)
	_escalar_la_letra_propia(control)
	if control.theme != TEMA:
		return
	var brillo := _actuales.valor(Preferencias.Campo.BRILLO) / 100.0
	control.modulate = Color(brillo, brillo, brillo, control.modulate.a)


## Los tamaños propios ganan al tema: el celular y la computadora los necesitan también.
## Se conserva cada tamaño original y se detectan los cambios que hace la pantalla después.
func _escalar_la_letra_propia(control: Control) -> void:
	if _escalando or not _usa_el_tema(control):
		return
	_escalando = true
	var tamanos: Dictionary = control.get_meta(TAMANOS_PROPIOS, {})
	var escala := _actuales.valor(Preferencias.Campo.TEXTOS)
	for propiedad: Dictionary in control.get_property_list():
		var ruta: String = propiedad.name
		if not ruta.begins_with("theme_override_font_sizes/"):
			continue
		var nombre := ruta.get_slice("/", 1)
		if not control.has_theme_font_size_override(nombre):
			tamanos.erase(nombre)
			continue
		var actual := control.get_theme_font_size(nombre)
		var guardado: Array = tamanos.get(nombre, [actual, actual])
		if actual != guardado[1]:
			guardado[0] = actual
		var escalado := roundi(guardado[0] * escala)
		tamanos[nombre] = [guardado[0], escalado]
		if actual != escalado:
			control.add_theme_font_size_override(nombre, escalado)
	control.set_meta(TAMANOS_PROPIOS, tamanos)
	_escalando = false


func _usa_el_tema(control: Control) -> bool:
	var actual := control
	while actual != null:
		if actual.theme != null:
			return actual.theme == TEMA
		actual = actual.get_parent_control()
	return false


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
