## El router junto a la computadora. Cascarón: traduce el clic a una señal y el estado del wifi a
## la textura de sus luces.
##
## **No decide nada del wifi.** Qué luces corresponden a cada estado y qué hace el clic es de
## `WifiDelLocal`. El estado cambia la textura y no la malla: las luces están dibujadas en el
## atlas del artista, así que cada estado es la misma imagen con otras luces.
extends StaticBody3D

## Un clic izquierdo sobre el router, sea cual sea su estado.
signal accionado

## Los materiales del modelo que llevan el atlas con las luces. Los demás conservan su color.
const MATERIALES_CON_LUCES: Array[StringName] = [
	&"router_cuerpo", &"router_antenas", &"router_luces"
]

@export var mallas: Array[MeshInstance3D] = []
@export var textura_verde: Texture2D
@export var textura_apagada: Texture2D
@export var textura_roja: Texture2D

var _con_luces: Array[StandardMaterial3D] = []


func _ready() -> void:
	var malla := mallas[0]
	for superficie in malla.mesh.get_surface_count():
		var material := malla.mesh.surface_get_material(superficie) as StandardMaterial3D
		if material == null or not MATERIALES_CON_LUCES.has(StringName(material.resource_name)):
			continue
		# El material del recurso se comparte con todo el que use la malla: se cambia una copia.
		var propio := material.duplicate() as StandardMaterial3D
		propio.albedo_color = Color.WHITE
		malla.set_surface_override_material(superficie, propio)
		_con_luces.append(propio)
	mostrar(WifiDelLocal.Luces.VERDES)


func accionar() -> void:
	accionado.emit()


func mostrar(luces: WifiDelLocal.Luces) -> void:
	var textura := textura_verde
	match luces:
		WifiDelLocal.Luces.APAGADAS:
			textura = textura_apagada
		WifiDelLocal.Luces.ROJAS:
			textura = textura_roja
	for material in _con_luces:
		material.albedo_texture = textura


## Lo que dice el router al examinarlo, sin tocarlo.
func texto_al_examinar() -> String:
	return SubtitulosAlExaminar.de_lo_fijo(SubtitulosAlExaminar.ROUTER)


## Qué hace el clic depende del estado y todavía no tiene una línea en la referencia de controles.
func contexto_de_interaccion(_sostenido: ObjetoDelAlmacen) -> ReferenciaDeControles.Contexto:
	return ReferenciaDeControles.Contexto.new()
