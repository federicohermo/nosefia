## Un útil de limpieza —la mopa, el balde o un jabón—: se levanta como cualquier objeto del
## almacén, y se dibuja con la malla del modelo que lo trae.
##
## **La malla no se copia**: se toma, por su nombre, del nodo del `.glb` que la dibujaba fija en el
## baño. Una copia en `assets/` quedaría vieja el día que el artista toque el balde, sin que nada
## lo dijera. El `transform` de la malla sí está escrito en la escena, y un caso afirma que
## coincide con el del modelo.
##
## Es cáscara: qué tiene el balde y de qué está mojada la mopa lo sabe `PisoDelLocal`. Acá vive la
## carga que se ve —el agua del balde, la punta mojada de la mopa—, y quien la pinta es el puesto
## de limpieza, con el color que contesta el dominio.
extends ObjetoAgarrable

const MODELO := preload("res://assets/models/SEPT_JUEGOS_PROTOTIPO.glb")

## El nodo del modelo que lo dibujaba fijo: su malla es la de este útil.
@export var nodo_del_modelo: StringName

@export var malla: MeshInstance3D

## Lo que muestra de qué está cargado: el agua del balde, la punta mojada de la mopa. Los jabones
## no llevan.
@export var carga: MeshInstance3D

## Lo que se marca al enfocarlo: la malla, y no la carga, que queda adentro del balde.
@export var mallas: Array[MeshInstance3D] = []


func _ready() -> void:
	super()
	malla.mesh = malla_del_modelo(nodo_del_modelo)


## Muestra la carga del color que se le pasa, o la esconde. Cuál y de qué color lo decide el
## dominio: acá sólo se pinta.
func mostrar_la_carga(cargada: bool, color: Color) -> void:
	carga.visible = cargada
	(carga.material_override as StandardMaterial3D).albedo_color = color


## La malla del nodo del modelo que se llama así, o `null`.
##
## Se lee del `SceneState` y no instanciando el modelo: son doscientos nodos para quedarse con uno.
static func malla_del_modelo(nombre: StringName) -> Mesh:
	var estado := MODELO.get_state()
	for nodo: int in estado.get_node_count():
		if estado.get_node_name(nodo) != nombre:
			continue
		for propiedad: int in estado.get_node_property_count(nodo):
			if estado.get_node_property_name(nodo, propiedad) == &"mesh":
				return estado.get_node_property_value(nodo, propiedad)
	return null
