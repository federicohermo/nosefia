## El corte de luz de la séptima noche, aplicado al local: oscurece, devuelve la luz y avisa.
##
## **No decide cuándo se corta ni cuándo vuelve.** Eso es de `AnomaliasDeLaJornada`, que recibe lo
## que queda del turno y contesta el estado. Acá queda la cáscara: qué se enciende y qué se apaga.
##
## **La oscuridad no es apagar el `LightmapGI`.** El local tiene un segundo horneado, el de la
## noche sin luz, con la luz de emergencia del panel y la de afuera que entra por los ventanales. El
## corte le cambia los datos al mismo nodo y la restauración le devuelve los de siempre: los muebles
## y las sondas de los productos pasan de uno a otro. Las luces en tiempo real, las emisivas de las
## lámparas y la niebla no salen del horneado, así que se apagan aparte. Cómo se hornea, en
## `docs/guides/iluminacion.md`.
##
## **Las mismas reglas de «qué se apaga» las usa el horneador** (`addons/hornear`): lo que se
## apaga acá es exactamente lo que el segundo horneado dejó apagado.
extends Node

## La luz de la oscuridad se avisa con este cambio, también al abrir una jornada que venía
## cortada. Quien escucha cierra las interfaces o las deja abrir.
signal luz_cambiada(hay_luz: bool)

const HORNEADO_SIN_LUZ := "res://src/escenas/almacen_sin_luz.lmbake"

## La única luz que sigue encendida mientras no hay luz. Va en un grupo y no por nombre para que
## mudarla de lugar o de escena no la apague.
const GRUPO_DE_LA_EMERGENCIA := &"luz_de_emergencia"

## Los materiales emisivos del local que se apagan con las luces. Son los que el modelo declara
## con emisión; el del tubo del tablero queda afuera porque es la emergencia.
const MATERIALES_EMISIVOS := [
	&"local_cielorraso", &"bano_difusor", &"cuartito_tubo_difusor", &"deposito_lampara_panel"
]

## Las luces de afuera que entran por los ventanales en la noche sin luz: las dos lámparas de la
## marquesina de la estación, los dos faroles y, frente a la entrada, la calle y su cartel. Están
## donde la foto del exterior las dibuja. **Sólo existen en el horneado oscuro**: el horneador las
## suma en su copia del editor (`addons/hornear`), y el juego no las crea. El horneado normal no
## las ve. **Son tenues**: más fuertes, la góndola de al lado del ventanal y sus productos quedan
## tan claros como con las luces del local.
const POSICIONES_DE_AFUERA: Array[Vector3] = [
	Vector3(-8.9, 3.6, -1.5),
	Vector3(-10.7, 3.5, 1.2),
	Vector3(-5.5, 3.2, -6.6),
	Vector3(-6.5, 5.3, 6.2),
	Vector3(4.9, 3.0, 8.0),
]
const COLOR_DE_AFUERA := Color(0.8, 1.0, 0.92)
const ENERGIA_DE_AFUERA := 1.0
const ALCANCE_DE_AFUERA := 16.0

## La luz de emergencia del horneado oscuro: alcanza para orientarse alrededor del tablero. En el
## horneado normal conserva la energía y el alcance de su escena.
const ENERGIA_DE_LA_EMERGENCIA_AL_HORNEAR := 4.0
const ALCANCE_DE_LA_EMERGENCIA_AL_HORNEAR := 4.0
const ANGULO_DE_LA_EMERGENCIA_AL_HORNEAR := 80.0

var _jornada: int = 0
var _estado: AnomaliasDeLaJornada.Corte = AnomaliasDeLaJornada.corte_al_abrir()
var _hay_luz := true
var _horno: LightmapGI
var _con_luz: LightmapGIData
var _sin_luz: LightmapGIData
var _entorno: Environment
var _niebla := false
var _luces: Array[Light3D] = []
var _reflejos: Dictionary[ReflectionProbe, float] = {}
var _emision: Dictionary[BaseMaterial3D, float] = {}


## Las luces del local que el corte apaga: todas las que no son la de emergencia.
static func luces_del_local(raiz: Node) -> Array[Light3D]:
	var luces: Array[Light3D] = []
	for nodo: Node in raiz.find_children("*", "Light3D", true, false):
		if not nodo.is_in_group(GRUPO_DE_LA_EMERGENCIA):
			luces.append(nodo as Light3D)
	return luces


## Las luces de afuera del horneado oscuro, sin colgar de ningún lado.
static func luces_de_afuera() -> Array[OmniLight3D]:
	var luces: Array[OmniLight3D] = []
	for posicion: Vector3 in POSICIONES_DE_AFUERA:
		var luz := OmniLight3D.new()
		luz.position = posicion
		luz.light_color = COLOR_DE_AFUERA
		luz.light_energy = ENERGIA_DE_AFUERA
		luz.omni_range = ALCANCE_DE_AFUERA
		luz.light_bake_mode = Light3D.BAKE_STATIC
		luces.append(luz)
	return luces


## Le da a la luz de emergencia, sólo para hornear, lo que hace falta para alumbrar el depósito.
static func reforzar_la_emergencia(raiz: Node) -> void:
	for luz: SpotLight3D in raiz.get_tree().get_nodes_in_group(GRUPO_DE_LA_EMERGENCIA):
		luz.light_energy = ENERGIA_DE_LA_EMERGENCIA_AL_HORNEAR
		luz.spot_range = ALCANCE_DE_LA_EMERGENCIA_AL_HORNEAR
		luz.spot_angle = ANGULO_DE_LA_EMERGENCIA_AL_HORNEAR


## Los materiales emisivos del local con su emisión de hoy, para devolvérsela al restaurar.
static func emision_del_local(raiz: Node) -> Dictionary[BaseMaterial3D, float]:
	var emision: Dictionary[BaseMaterial3D, float] = {}
	for nodo: Node in raiz.find_children("*", "MeshInstance3D", true, false):
		var malla := nodo as MeshInstance3D
		for superficie in malla.get_surface_override_material_count():
			var material := malla.get_active_material(superficie) as BaseMaterial3D
			if material != null and MATERIALES_EMISIVOS.has(StringName(material.resource_name)):
				emision[material] = material.emission_energy_multiplier
	return emision


## Cuelga el corte del local. El horno es el `LightmapGI` que lo ilumina; el entorno, el que
## tiene la niebla.
func preparar(raiz: Node, horno: LightmapGI, entorno: Environment) -> void:
	_horno = horno
	_con_luz = horno.light_data
	_entorno = entorno
	_niebla = entorno.fog_enabled
	_luces = luces_del_local(raiz)
	_emision = emision_del_local(raiz)
	for sonda: Node in raiz.find_children("*", "ReflectionProbe", true, false):
		_reflejos[sonda as ReflectionProbe] = (sonda as ReflectionProbe).intensity


## Toda jornada abre con luz. La de la noche del corte deja listo el horneado oscuro, así que su
## carga no cae sobre el corte mismo.
func abrir_jornada(jornada: int) -> void:
	_jornada = jornada
	_estado = AnomaliasDeLaJornada.corte_al_abrir()
	if jornada == AnomaliasDeLaJornada.JORNADA_DEL_CORTE and _sin_luz == null:
		_sin_luz = load(HORNEADO_SIN_LUZ)
	_aplicar()


## Lo que queda del turno, cada cuadro: es lo que le hace llegar la hora al corte.
func avanzar(restante: float) -> void:
	_cambiar(AnomaliasDeLaJornada.corte_tras(_estado, _jornada, restante))


## El clic sobre el tablero.
func restablecer() -> void:
	_cambiar(AnomaliasDeLaJornada.restablecer(_estado))


func hay_luz() -> bool:
	return _hay_luz


func _cambiar(nuevo: AnomaliasDeLaJornada.Corte) -> void:
	_estado = nuevo
	_aplicar()


func _aplicar() -> void:
	var hay := AnomaliasDeLaJornada.hay_luz(_estado)
	if hay == _hay_luz:
		return
	_hay_luz = hay
	_horno.light_data = _con_luz if hay else _sin_luz
	_entorno.fog_enabled = _niebla and hay
	for luz in _luces:
		luz.visible = hay
	for sonda: ReflectionProbe in _reflejos:
		sonda.intensity = _reflejos[sonda] if hay else 0.0
	for material: BaseMaterial3D in _emision:
		material.emission_energy_multiplier = _emision[material] if hay else 0.0
	luz_cambiada.emit(hay)
