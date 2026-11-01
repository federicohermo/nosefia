## El corte de luz de la sexta noche, aplicado al local: oscurece, devuelve la luz y avisa.
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

## La luz de afuera entra por los vidrios que dan a la calle en la noche sin luz. **Sólo existe en
## el horneado oscuro**: ahí cada vidrio emite este color hacia adentro, y las sondas lo guardan
## con su dirección. Así, lo que mira al ventanal recibe más luz que lo que mira adentro del local.
## No es el cielo del horneado: el cielo alumbra también abajo del piso y arriba del techo, y se
## filtra por cada junta de las paredes. Tampoco una luz puntual afuera: la sonda guarda sólo su
## rebote, que llega desde adentro del local.
const COLOR_DE_AFUERA := Color(0.8, 1.0, 0.92)
const ENERGIA_DE_AFUERA := 0.35
## Los vidrios que dan a la calle, por el principio de su nombre en el modelo. Los de las heladeras
## no: dan adentro.
const VIDRIOS_A_LA_CALLE := [
	"local_vidrio_ventanal",
	"local_vidrio_frente",
	"local_vidrio_sobre_entrada",
	"local_vidrio_puerta_entrada",
	"local_vidrio_ventanilla",
]

## La luz de emergencia de la noche sin luz: alcanza para orientarse alrededor del tablero. Vale
## para el horneado oscuro y, mientras dura el corte, para el juego: lo que no está horneado la
## recibe igual que los muebles. Su sombra la frena en la pared del depósito. Con luz, y en el
## horneado normal, conserva lo de su escena.
const ENERGIA_DE_LA_EMERGENCIA_SIN_LUZ := 4.0
const ALCANCE_DE_LA_EMERGENCIA_SIN_LUZ := 4.0
const ANGULO_DE_LA_EMERGENCIA_SIN_LUZ := 80.0

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
var _emergencia: Dictionary[SpotLight3D, Array] = {}


## Las luces del local que el corte apaga: todas las que no son la de emergencia.
static func luces_del_local(raiz: Node) -> Array[Light3D]:
	var luces: Array[Light3D] = []
	for nodo: Node in raiz.find_children("*", "Light3D", true, false):
		if not nodo.is_in_group(GRUPO_DE_LA_EMERGENCIA):
			luces.append(nodo as Light3D)
	return luces


## Hace que los vidrios a la calle emitan la luz de afuera, y le saca el cielo al horneado. Sólo
## lo usa el horneador, que no guarda la escena: en el juego los vidrios quedan como estaban.
static func abrir_a_la_calle(raiz: Node, horno: LightmapGI) -> void:
	horno.environment_mode = LightmapGI.ENVIRONMENT_MODE_DISABLED
	var afuera := StandardMaterial3D.new()
	afuera.albedo_color = Color.BLACK
	afuera.emission_enabled = true
	afuera.emission = COLOR_DE_AFUERA
	afuera.emission_energy_multiplier = ENERGIA_DE_AFUERA
	afuera.cull_mode = BaseMaterial3D.CULL_DISABLED
	for vidrio in vidrios_a_la_calle(raiz):
		vidrio.gi_mode = GeometryInstance3D.GI_MODE_STATIC
		vidrio.material_override = afuera


static func vidrios_a_la_calle(raiz: Node) -> Array[MeshInstance3D]:
	var vidrios: Array[MeshInstance3D] = []
	for nodo: Node in raiz.find_children("local_vidrio_*", "MeshInstance3D", true, false):
		for prefijo: String in VIDRIOS_A_LA_CALLE:
			if String(nodo.name).begins_with(prefijo):
				vidrios.append(nodo as MeshInstance3D)
	return vidrios


## Le da a la luz de emergencia lo que hace falta para alumbrar el depósito sin luz.
static func reforzar_la_emergencia(raiz: Node) -> void:
	for luz: SpotLight3D in raiz.get_tree().get_nodes_in_group(GRUPO_DE_LA_EMERGENCIA):
		_reforzar(luz)


static func _reforzar(luz: SpotLight3D) -> void:
	luz.light_energy = ENERGIA_DE_LA_EMERGENCIA_SIN_LUZ
	luz.spot_range = ALCANCE_DE_LA_EMERGENCIA_SIN_LUZ
	luz.spot_angle = ANGULO_DE_LA_EMERGENCIA_SIN_LUZ
	luz.shadow_enabled = true


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
	for nodo: Node in raiz.find_children("*", "SpotLight3D", true, false):
		var luz := nodo as SpotLight3D
		if luz.is_in_group(GRUPO_DE_LA_EMERGENCIA):
			_emergencia[luz] = [
				luz.light_energy, luz.spot_range, luz.spot_angle, luz.shadow_enabled
			]


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
	for luz: SpotLight3D in _emergencia:
		if not hay:
			_reforzar(luz)
			continue
		var de_siempre: Array = _emergencia[luz]
		luz.light_energy = de_siempre[0]
		luz.spot_range = de_siempre[1]
		luz.spot_angle = de_siempre[2]
		luz.shadow_enabled = de_siempre[3]
	luz_cambiada.emit(hay)
