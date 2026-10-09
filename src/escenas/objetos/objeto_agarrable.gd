## La cáscara de una cosa suelta del almacén: un cuerpo físico que contesta qué es.
##
## Va en `objetos/` y no en `puestos/`, que es el criterio de esa carpeta —cuántas instancias
## hay—: de esto hay N, se crean y se destruyen en juego, mientras que un puesto se instancia una
## vez y vive cableado.
##
## Es cáscara y no decide nada del juego: qué se puede levantar lo decide `Manos`, qué revela lo
## decide `ObjetoDelAlmacen`, y dónde queda al agarrarlo lo decide `Agarre`. Acá viven el cuerpo
## físico y el `Resource` que lo describe.
class_name ObjetoAgarrable
extends RigidBody3D

## Cada vez que toca algo. La rapidez es la de antes del contacto: la de después ya la frenó el
## choque. Cuál contacto suena lo decide el audio.
signal contacto_recibido(nodo: Node3D, rapidez: float)

## Los datos entran por el `.tres`, así que agregar un objeto nuevo al almacén es duplicar la
## escena y cambiarle este campo: no se toca código.
@export var datos: ObjetoDelAlmacen
@export var orientacion_en_mano := Basis.IDENTITY
## Sin él, el marco le pone el contorno común.
var material_de_foco: Material = null

## Dónde lo dejó la escena. Se guarda en `_ready()` y no en la declaración porque el `transform`
## que importa es el que le puso el `.tscn`, y ése recién existe cuando el nodo entró al árbol.
var _padre_de_origen: Node
var _capa_de_origen: int
var _mascara_de_origen: int
var _congelado_de_origen: bool
var _visible_de_origen: bool
var _lugar_de_origen: Transform3D
var _origen_en_el_mundo: Transform3D
var _rapidez := 0.0
var _rapidez_previa := 0.0


func _ready() -> void:
	_padre_de_origen = get_parent()
	_capa_de_origen = collision_layer
	_mascara_de_origen = collision_mask
	_congelado_de_origen = freeze
	_visible_de_origen = visible
	_lugar_de_origen = transform
	_origen_en_el_mundo = global_transform
	contact_monitor = true
	max_contacts_reported = maxi(max_contacts_reported, 1)
	body_entered.connect(
		func(_otro: Node) -> void: contacto_recibido.emit(self, maxf(_rapidez, _rapidez_previa))
	)


## El motor llama a esto con la velocidad ya frenada por el choque del paso, y recién después
## avisa el contacto. Por eso se guarda también la del paso anterior.
func _integrate_forces(estado: PhysicsDirectBodyState3D) -> void:
	_rapidez_previa = _rapidez
	_rapidez = estado.linear_velocity.length()


## Devuelve padre, pose y cuerpo físico de arranque, incluso después de un tiro al contenedor.
func volver_a_su_lugar() -> void:
	freeze = true
	if get_parent() != _padre_de_origen:
		reparent(_padre_de_origen)
	top_level = false
	transform = _lugar_de_origen
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	collision_layer = _capa_de_origen
	collision_mask = _mascara_de_origen
	visible = _visible_de_origen
	freeze = _congelado_de_origen
	reset_physics_interpolation()


## El contrato de «con esto se puede interactuar» es este método más el grupo del `.tscn`, y no un
## tipo, porque ninguna de las capas que lo necesitan puede nombrar el tipo: `sistemas/` no puede
## nombrar un `class_name` de `escenas/` —el gate de capas lo caza sin que haya un `preload`— y
## `dominio/` tampoco, porque esto es un `Node3D`. El nombre del método vive en
## `ReglasDeLosObjetos.METODO_INTERACTUAR` y lo afirma el test de esta escena.
func interactuar() -> ObjetoDelAlmacen:
	return datos


func lugar_de_origen() -> Transform3D:
	return _origen_en_el_mundo
