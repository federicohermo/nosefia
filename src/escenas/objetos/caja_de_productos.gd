## La caja del depósito: se lleva, se apoya, y declara qué producto guarda.
##
## No decide nada. Qué sale de ella y desde dónde lo resuelve `reposicion_manual.gd`.
##
## **Su cuerpo es rígido pero congelado.** Apoyada se porta como algo estático —no rebota, no
## rueda, no tiembla— y el puesto le escribe el lugar derecho, que es lo que deja apoyar una caja
## entrando justa en un estante. Se descongela sólo cuando pierde lo que la sostenía, y ahí cae:
## es lo que desarma una pila cuando le sacan una de abajo. **Cuándo despertarla no se decide
## acá**, lo pide el puesto; volver a dormirse lo resuelve el motor.
extends RigidBody3D

## La caja se va a correr. Para el motor es un cuerpo estático, y lo apoyado encima no se
## entera: lo despierta el puesto.
signal empujada(caja: Node3D)

@export var producto: Producto.Id = Producto.Id.ACTRONCITO
@export var datos: ObjetoDelAlmacen
@export var mallas: Array[MeshInstance3D] = []

## Cómo queda en la mano: de frente y mostrando su cara rotulada. La lee `Agarre` al colgarla.
@export var orientacion_en_mano := Basis.IDENTITY

var _lugar_de_origen: Transform3D
var _padre_de_origen: Node = null

## Dónde se apoyó por última vez. Lo pregunta el puesto al levantarla: para cuando avisa que la
## agarró, la caja ya cuelga de la mano y el volumen que dejó libre no lo sabe nadie más.
var _apoyo_que_dejo := Vector3.ZERO


func _ready() -> void:
	_lugar_de_origen = transform
	_padre_de_origen = get_parent()
	_apoyo_que_dejo = global_position
	sleeping_state_changed.connect(_al_cambiar_el_reposo)


func interactuar() -> ObjetoDelAlmacen:
	return datos


## Dónde arranca la noche, en el mundo.
func lugar_de_origen() -> Transform3D:
	var padre := _padre_de_origen as Node3D
	return _lugar_de_origen if padre == null else padre.global_transform * _lugar_de_origen


## El volumen que ocupaba cuando estaba apoyada. Lo usa el puesto para saber a quién despertar.
func apoyo_que_dejo() -> Vector3:
	return _apoyo_que_dejo


## Queda quieta donde la dejaron: sin velocidad, congelada y dormida.
##
## La llama el puesto **después** de ubicarla. Soltar la deja como un cuerpo vivo —es lo que
## `Agarre` hace con todo lo que se suelta—, y un cuerpo vivo se acomoda solo: una caja que entró
## justa en un estante se saldría sola al cuadro siguiente de haberla dejado bien.
func quedarse_quieta() -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true
	sleeping = true
	# El apoyo se anota acá y no sólo en la señal: `sleeping_state_changed` avisa los CAMBIOS, y
	# una caja que ya venía dormida —que es el caso normal, porque el puesto la ubica congelada—
	# no cambia nada. Medido: sin esta línea el apoyo se queda en el que le puso el `.tscn`.
	_apoyo_que_dejo = global_position


## La despierta, y entonces cae hasta encontrar dónde apoyarse.
##
## La llama el puesto cuando le sacan de abajo lo que la sostenía. Quedarse quieta otra vez no
## hace falta pedirlo: el motor la duerme al frenar y de ahí se agarra `_al_cambiar_el_reposo()`.
func soltarse() -> void:
	freeze = false
	sleeping = false


## Congelada mientras duerme, viva mientras no. Es lo que la deja lista para que le vuelvan a
## escribir el lugar: a un cuerpo rígido despierto no se le mueve el `transform` a mano.
##
## No decide nada, y por eso son dos asignaciones: la señal avisa los dos cambios —se durmió y se
## despertó—, y en los dos `freeze` vale lo mismo que `sleeping`. El apoyo se anota en los dos
## por el mismo motivo: al despertarse todavía está donde descansaba, y al dormirse ya está donde
## aterrizó.
func _al_cambiar_el_reposo() -> void:
	freeze = sleeping
	_apoyo_que_dejo = global_position


## El dominio se resetea y los nodos no: sin esto la jornada siguiente arranca con la caja donde
## la dejó la anterior.
##
## Vuelve también de padre, y no sólo de lugar: la noche puede terminar con la caja en la mano,
## y ahí `transform` es relativo al cuerpo del jugador. Escribirlo sin despegarla la deja
## flotando pegada a él toda la noche siguiente.
func volver_a_su_lugar() -> void:
	top_level = false
	reparent(_padre_de_origen, false)
	transform = _lugar_de_origen
	quedarse_quieta()


## Se arrastra por el piso cuando el jugador la empuja al pasar. Cuánto recibe lo dice el
## dominio; acá sólo se mueve, en horizontal y sin dar vuelta nada.
##
## Avisa **antes** de correrse: lo que hay que despertar está sobre el apoyo que todavía ocupa.
func empujar(desplazamiento: Vector3) -> void:
	var arrastre := desplazamiento * ReglasDeLosObjetos.ARRASTRE_DE_LA_CAJA
	arrastre.y = 0.0
	empujada.emit(self)
	move_and_collide(arrastre)
	_apoyo_que_dejo = global_position
