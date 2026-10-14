## La tapa usa sondas de luz y una colisión animable; no arrastra una sombra horneada al girar.
extends AnimatableBody3D

## A un grado, el borde avanza unos 13 mm, menos que los 25 mm de espesor de su colisión.
const PASO_DE_COMPROBACION := deg_to_rad(1.0)
const HOLGURA_DEL_GIRO := 0.005

@export var bisagra: Node3D
@export var mallas: Array[MeshInstance3D] = []
@export var recolector: RecolectorDeBasura
@export var forma: CollisionShape3D
@export var soporte: StaticBody3D
@export var angulo_en_modelo := TapaDelContenedor.ANGULO_ABIERTA
@export var bisagras_adicionales: Array[Node3D] = []
@export var formas_adicionales: Array[CollisionShape3D] = []

var _tapa := TapaDelContenedor.new()
var _cerrada: Transform3D
var _desde_la_bisagra: Transform3D
var _cerradas_adicionales: Array[Transform3D] = []


func _ready() -> void:
	_cerrada = (
		bisagra.transform * Transform3D(Basis(Vector3.RIGHT, angulo_en_modelo), Vector3.ZERO)
	)
	for adicional: Node3D in bisagras_adicionales:
		_cerradas_adicionales.append(adicional.transform)
	_desde_la_bisagra = bisagra.global_transform.affine_inverse() * global_transform
	top_level = true


func usar() -> void:
	_tapa.alternar()


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
	for adicional: Node3D in bisagras_adicionales:
		adicional.reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	var siguiente := _tapa.angulo_siguiente(delta)
	_tapa.avanzar(delta, _paso_libre(siguiente))
	_dibujar()


func _dibujar() -> void:
	bisagra.transform = _pose(_tapa.angulo())
	for indice: int in bisagras_adicionales.size():
		bisagras_adicionales[indice].transform = (
			_cerradas_adicionales[indice]
			* Transform3D(Basis(Vector3.RIGHT, -_tapa.angulo()), Vector3.ZERO)
		)
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
	consulta.margin = HOLGURA_DEL_GIRO
	consulta.collision_mask = collision_mask
	consulta.exclude = [get_rid(), soporte.get_rid()]
	var padre := bisagra.get_parent_node_3d().global_transform
	var espacio := get_world_3d().direct_space_state
	var formas: Array[CollisionShape3D] = [forma]
	formas.append_array(formas_adicionales)
	for paso in range(1, pasos + 1):
		var angulo := lerpf(desde, siguiente, float(paso) / pasos)
		for volumen: CollisionShape3D in formas:
			consulta.shape = volumen.shape
			consulta.transform = padre * _pose(angulo) * _desde_la_bisagra * volumen.transform
			if not espacio.intersect_shape(consulta, 1).is_empty():
				return false
	return true


func recibe_objetos() -> bool:
	return _tapa.recibe_objetos()


func interactuar() -> ObjetoDelAlmacen:
	recolector.pedir_tirar(recibe_objetos())
	return null


## El cuerpo y la tapa dicen lo mismo: son el mismo contenedor.
func texto_al_examinar() -> String:
	return SubtitulosAlExaminar.de_lo_fijo(SubtitulosAlExaminar.CONTENEDOR)
