## La tapa usa sondas de luz y una colisión animable; no arrastra una sombra horneada al girar.
extends AnimatableBody3D

## A un grado, el borde avanza unos 13 mm, menos que los 25 mm de espesor de su colisión.
const PASO_DE_COMPROBACION := deg_to_rad(1.0)
const HOLGURA_DEL_GIRO := 0.005

@export var bisagra: Node3D
@export var mallas: Array[MeshInstance3D] = []
@export var zona: Area3D
@export var forma: CollisionShape3D
@export var soporte: StaticBody3D

var _tapa := TapaDelContenedor.new()
var _cerrada: Transform3D
var _desde_la_bisagra: Transform3D


func _ready() -> void:
	_cerrada = (
		bisagra.transform
		* Transform3D(Basis(Vector3.RIGHT, TapaDelContenedor.ANGULO_ABIERTA), Vector3.ZERO)
	)
	_desde_la_bisagra = bisagra.global_transform.affine_inverse() * global_transform
	top_level = true


func usar() -> void:
	_tapa.alternar()
	_actualizar_la_zona()


func reiniciar() -> void:
	_tapa.reiniciar()
	_dibujar()
	# Un salto de jornada no debe darle velocidad a un objeto apoyado en la tapa.
	PhysicsServer3D.body_set_mode(get_rid(), PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_set_state(
		get_rid(),
		PhysicsServer3D.BODY_STATE_TRANSFORM,
		bisagra.global_transform * _desde_la_bisagra
	)
	PhysicsServer3D.body_set_mode(get_rid(), PhysicsServer3D.BODY_MODE_KINEMATIC)
	bisagra.reset_physics_interpolation()
	_actualizar_la_zona()


func _physics_process(delta: float) -> void:
	var siguiente := _tapa.angulo_siguiente(delta)
	_tapa.avanzar(delta, _paso_libre(siguiente))
	_dibujar()
	_actualizar_la_zona()


func _dibujar() -> void:
	bisagra.transform = _pose(_tapa.angulo())
	global_transform = bisagra.global_transform * _desde_la_bisagra


func _pose(angulo: float) -> Transform3D:
	return _cerrada * Transform3D(Basis(Vector3.RIGHT, -angulo), Vector3.ZERO)


## Se mide antes de mover la hoja: un giro cinemático no debe comprimir una pila de envases.
func _paso_libre(siguiente: float) -> bool:
	var desde := _tapa.angulo()
	if is_equal_approx(desde, siguiente):
		return true
	# Al abrir libera la cavidad y levanta lo apoyado sobre ella; el motor resuelve ese apoyo.
	if siguiente > desde:
		return true
	var pasos := ceili(absf(siguiente - desde) / PASO_DE_COMPROBACION)
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma.shape
	consulta.margin = HOLGURA_DEL_GIRO
	consulta.collision_mask = collision_mask
	consulta.exclude = [get_rid(), soporte.get_rid()]
	var padre := bisagra.get_parent_node_3d().global_transform
	var espacio := get_world_3d().direct_space_state
	for paso in range(1, pasos + 1):
		var angulo := lerpf(desde, siguiente, float(paso) / pasos)
		consulta.transform = padre * _pose(angulo) * _desde_la_bisagra * forma.transform
		if not espacio.intersect_shape(consulta, 1).is_empty():
			return false
	return true


func _actualizar_la_zona() -> void:
	# El dominio decide cuándo recibe bolsas. La escena traduce ese permiso al sensor físico.
	var recibe := _tapa.recibe_bolsas()
	if zona.monitoring != recibe:
		zona.set_deferred("monitoring", recibe)
