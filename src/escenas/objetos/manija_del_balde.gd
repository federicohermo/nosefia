## El arco y el agarre giran sobre sus bisagras; el borde y las pestañas quedan fijos.
extends MeshInstance3D

const Partes := preload("res://src/escenas/objetos/partes_de_manija.gd")
const PINTURA := preload("res://src/escenas/objetos/manija_del_balde.gdshader")
const CONTORNO_MANIJA := preload("res://src/escenas/objetos/contorno_de_manija.gdshader")
const CONTORNO := preload("res://src/sistemas/marco/contorno.gdshader")
const REPOSO := PI / 2.0
const DURACION := 0.25

@export var observador: Node3D

var _balde: RigidBody3D
var _suspendido := false
var _angulo := REPOSO
var _reposo := REPOSO
var _desde := REPOSO
var _hasta := REPOSO
var _tiempo := DURACION
var _pinturas: Array[ShaderMaterial] = []
var _contornos: Array[ShaderMaterial] = []
var _segundos_pases: Dictionary[Material, ShaderMaterial] = {}


func _ready() -> void:
	_balde = get_parent() as RigidBody3D
	set_process(false)
	_preparar.call_deferred()


func _preparar() -> void:
	if mesh == null or _balde == null:
		return
	mesh = Partes.preparar(mesh)
	if mesh == null:
		return
	# El asa recostada queda por fuera de los límites de la pose importada.
	extra_cull_margin = 0.07
	for superficie in mesh.get_surface_count():
		var original := mesh.surface_get_material(superficie) as StandardMaterial3D
		if original == null:
			continue
		var borde := ShaderMaterial.new()
		var pintura: Material
		if original.resource_name in ["util_asa_grafito", "util_borde_crema"]:
			var animada := ShaderMaterial.new()
			animada.shader = PINTURA
			animada.set_shader_parameter("color", original.albedo_color)
			animada.set_shader_parameter("rugosidad", original.roughness)
			animada.set_shader_parameter("metal", original.metallic)
			_pinturas.append(animada)
			pintura = animada
			borde.shader = CONTORNO_MANIJA
			_contornos.append(borde)
		else:
			pintura = original.duplicate() as StandardMaterial3D
			borde.shader = CONTORNO
		_segundos_pases[pintura] = borde
		set_surface_override_material(superficie, pintura)
	_pintar()
	set_process(true)


func _process(delta: float) -> void:
	# Agarre termina de escribir estos flags después de reparentar, también durante el examen.
	var suspendido := _balde.freeze and not _balde.top_level
	if suspendido != _suspendido:
		_suspendido = suspendido
		_desde = _angulo
		if not suspendido and is_instance_valid(observador):
			var lado := to_local(observador.global_position).z
			if absf(lado) > 0.001:
				_reposo = -signf(lado) * REPOSO
		_hasta = 0.0 if suspendido else _reposo
		_tiempo = 0.0
	# Conserva el ángulo al interrumpir el gesto; caminar no vuelve a elegir el lado de caída.
	_tiempo = minf(_tiempo + maxf(delta, 0.0), DURACION)
	_angulo = lerpf(_desde, _hasta, smoothstep(0.0, 1.0, _tiempo / DURACION))
	_pintar()


func _pintar() -> void:
	for pintura: ShaderMaterial in _pinturas + _contornos:
		pintura.set_shader_parameter("angulo", _angulo)


func mostrar_contorno(material: ShaderMaterial) -> void:
	for pintura: Material in _segundos_pases:
		var borde := _segundos_pases[pintura]
		pintura.next_pass = borde if material != null else null
		if material != null:
			borde.set_shader_parameter("color", material.get_shader_parameter("color"))
			borde.set_shader_parameter("grosor", material.get_shader_parameter("grosor"))
