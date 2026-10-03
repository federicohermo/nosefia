## Gotas visuales con gravedad y cupo fijo; se extinguen al tocar un sólido.
extends Node3D

const CUPO := 24
const VIDA := 0.85

var _gotas: Array[MeshInstance3D] = []
var _velocidades: Array[Vector3] = []
var _vidas: Array[float] = []
var _siguiente := 0


func preparar(pintura: Material) -> void:
	var esfera := SphereMesh.new()
	esfera.radius = 0.009
	esfera.height = 0.018
	esfera.radial_segments = 6
	esfera.rings = 3
	for indice: int in CUPO:
		var gota := MeshInstance3D.new()
		gota.mesh = esfera
		gota.material_override = pintura
		gota.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gota.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
		add_child(gota)
		gota.top_level = true
		gota.visible = false
		_gotas.append(gota)
		_velocidades.append(Vector3.ZERO)
		_vidas.append(0.0)
	set_physics_process(false)


func emitir(origen: Vector3, velocidad: Vector3) -> void:
	for indice: int in 4:
		var turno := _siguiente % CUPO
		_siguiente += 1
		var gota := _gotas[turno]
		gota.global_position = origen
		gota.scale = Vector3.ONE
		gota.visible = true
		var dispersion := Vector3(sin(_siguiente * 2.4), 0.2, cos(_siguiente * 2.4)) * 0.3
		_velocidades[turno] = velocidad + dispersion
		_vidas[turno] = VIDA
	set_physics_process(true)


func limpiar() -> void:
	for indice: int in _gotas.size():
		_gotas[indice].visible = false
		_vidas[indice] = 0.0
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	var activas := 0
	for indice: int in _gotas.size():
		if _vidas[indice] <= 0.0:
			continue
		var gota := _gotas[indice]
		_vidas[indice] -= delta
		_velocidades[indice] += Vector3.DOWN * 9.81 * delta
		var destino := gota.global_position + _velocidades[indice] * delta
		var rayo := PhysicsRayQueryParameters3D.create(gota.global_position, destino, 9)
		if (
			_vidas[indice] <= 0.0
			or not get_world_3d().direct_space_state.intersect_ray(rayo).is_empty()
		):
			gota.visible = false
			_vidas[indice] = 0.0
			continue
		gota.global_position = destino
		gota.scale = Vector3.ONE * minf(1.0, _vidas[indice] * 5.0)
		activas += 1
	set_physics_process(activas > 0)
