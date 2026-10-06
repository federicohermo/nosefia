## Gotas visuales con gravedad y cupo fijo; se extinguen al tocar un sólido.
extends Node3D

const CUPO := 24
const VIDA := 0.85

var _malla := MultiMeshInstance3D.new()
var _posiciones := PackedVector3Array()
var _velocidades := PackedVector3Array()
var _vidas := PackedFloat32Array()
var _siguiente := 0
var _rayo := PhysicsRayQueryParameters3D.new()


func preparar(pintura: Material) -> void:
	var esfera := SphereMesh.new()
	esfera.radius = 0.009
	esfera.height = 0.018
	esfera.radial_segments = 6
	esfera.rings = 3
	var lote := MultiMesh.new()
	lote.transform_format = MultiMesh.TRANSFORM_3D
	lote.mesh = esfera
	lote.instance_count = CUPO
	_malla.multimesh = lote
	_malla.material_override = pintura
	_malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_malla.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	add_child(_malla)
	_malla.top_level = true
	_malla.global_transform = Transform3D.IDENTITY
	_posiciones.resize(CUPO)
	_velocidades.resize(CUPO)
	_vidas.resize(CUPO)
	_rayo.collision_mask = 9
	limpiar()


func emitir(origen: Vector3, velocidad: Vector3, cantidad: int = 4) -> void:
	for indice: int in clampi(cantidad, 0, CUPO):
		var turno := _siguiente % CUPO
		_siguiente += 1
		_posiciones[turno] = origen
		var dispersion := Vector3(sin(_siguiente * 2.4), 0.2, cos(_siguiente * 2.4)) * 0.3
		_velocidades[turno] = velocidad + dispersion
		_vidas[turno] = VIDA
	_dibujar()
	set_physics_process(true)


func limpiar() -> void:
	_vidas.fill(0.0)
	_malla.visible = false
	# Una instancia oculta permite precalentar la variante de instancing antes de jugar.
	_malla.multimesh.visible_instance_count = 1
	_malla.multimesh.set_instance_transform(0, Transform3D(Basis.IDENTITY, global_position))
	_malla.custom_aabb = AABB(global_position - Vector3.ONE * 0.01, Vector3.ONE * 0.02)
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	var espacio := get_world_3d().direct_space_state
	for indice: int in CUPO:
		if _vidas[indice] <= 0.0:
			continue
		_vidas[indice] -= delta
		if _vidas[indice] <= 0.0:
			continue
		_velocidades[indice] += Vector3.DOWN * 9.81 * delta
		var destino := _posiciones[indice] + _velocidades[indice] * delta
		_rayo.from = _posiciones[indice]
		_rayo.to = destino
		if not espacio.intersect_ray(_rayo).is_empty():
			_vidas[indice] = 0.0
			continue
		_posiciones[indice] = destino
	_dibujar()
	set_physics_process(_malla.visible)


## Sólo se dibujan las instancias activas; las posiciones de la simulación siguen en el mundo.
func _dibujar() -> void:
	var activas := 0
	var caja := AABB()
	for indice: int in CUPO:
		if _vidas[indice] <= 0.0:
			continue
		var escala := minf(1.0, _vidas[indice] * 5.0)
		_malla.multimesh.set_instance_transform(
			activas, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * escala), _posiciones[indice])
		)
		var suya := AABB(_posiciones[indice] - Vector3.ONE * 0.01, Vector3.ONE * 0.02)
		caja = suya if activas == 0 else caja.merge(suya)
		activas += 1
	if activas == 0:
		limpiar()
		return
	_malla.custom_aabb = caja
	_malla.multimesh.visible_instance_count = activas
	_malla.visible = true
