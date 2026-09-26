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

## Dónde lo dejó la escena. Se guarda en `_ready()` y no en la declaración porque el `transform`
## que importa es el que le puso el `.tscn`, y ése recién existe cuando el nodo entró al árbol.
var _lugar_de_origen: Transform3D
## El mismo lugar en el mundo: en la mano, el padre es la mano y el local ya no dice nada.
var _origen_en_el_mundo: Transform3D
var _rapidez := 0.0
var _rapidez_previa := 0.0


## El monitoreo de contactos se prende acá y no en el `.tscn`, que comparten otros cambios.
func _ready() -> void:
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


## Lo devuelve a donde empezó la noche.
##
## **El dominio se resetea y los nodos no**: al abrir la jornada el recolector vuelve a
## `depositadas() == 0`, pero las bolsas siguen físicamente adentro del `Area3D` del fondo, así
## que desde la jornada 2 sacar la basura no cuesta un paso — está hecha antes de empezar.
##
## Las velocidades van a cero además del `transform` porque un `RigidBody3D` teletransportado
## conserva su impulso y se va solo del lugar al que lo acaban de mandar. El `freeze` alrededor
## es lo que evita que el servidor de física pise la escritura en el mismo cuadro, y se restaura
## al valor que tenía en vez de apagarse: el objeto puede estar congelado porque lo están
## llevando, y despertarlo acá lo dejaría caer.
##
## El reseteo de la interpolación cierra lo mismo del lado del dibujo. El motor dibuja entre el
## paso anterior y el actual. Sin el reseteo, el cuerpo se dibuja cruzando el almacén en un
## cuadro.
func volver_a_su_lugar() -> void:
	var estaba_congelado := freeze
	freeze = true
	transform = _lugar_de_origen
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = estaba_congelado
	reset_physics_interpolation()


## El contrato de «con esto se puede interactuar» es este método más el grupo del `.tscn`, y no un
## tipo, porque ninguna de las capas que lo necesitan puede nombrar el tipo: `sistemas/` no puede
## nombrar un `class_name` de `escenas/` —el gate de capas lo caza sin que haya un `preload`— y
## `dominio/` tampoco, porque esto es un `Node3D`. El nombre del método vive en
## `ReglasDeLosObjetos.METODO_INTERACTUAR` y lo afirma el test de esta escena.
func interactuar() -> ObjetoDelAlmacen:
	return datos


## Dónde lo dejó la escena, en el mundo. Una unidad que nace en juego contesta dónde nació.
func lugar_de_origen() -> Transform3D:
	return _origen_en_el_mundo
