## Las raíces quedan fijas; las puntas siguen un resorte amortiguado en espacio local.
## Es una aproximación visual por grupos de fibras, sin modificar las reglas de limpieza.
extends MeshInstance3D

const FIBRAS := preload("res://src/escenas/objetos/fibras_de_la_mopa.gdshader")
const PASO := 1.0 / 120.0

var _pinturas: Array[ShaderMaterial] = []
var _desvio := Vector2.ZERO
var _rapidez := Vector2.ZERO
var _aceleracion := Vector2.ZERO
var _posicion_previa := Vector3.ZERO
var _velocidad_previa := Vector3.ZERO
var _padre_previo: Node
var _muestreada := false


func _ready() -> void:
	set_physics_process(false)
	_preparar.call_deferred()


func _preparar() -> void:
	if mesh == null:
		return
	for superficie: int in mesh.get_surface_count():
		var original := mesh.surface_get_material(superficie) as StandardMaterial3D
		if original == null or not original.resource_name.begins_with("util_fibra"):
			continue
		var pintura := ShaderMaterial.new()
		pintura.shader = FIBRAS
		pintura.set_shader_parameter("color_de_fibra", original.albedo_color)
		set_surface_override_material(superficie, pintura)
		_pinturas.append(pintura)
	set_physics_process(not _pinturas.is_empty())


func _physics_process(delta: float) -> void:
	if delta <= 0.0 or not is_visible_in_tree():
		_muestreada = false
		return
	var paso := minf(delta, 0.1)
	var punto := to_global(Vector3(0.0, -0.78, 0.0))
	var padre := get_parent().get_parent()
	var distancia := punto - _posicion_previa
	if not _muestreada or distancia.length() > 0.75 or padre != _padre_previo:
		_muestreada = true
		_padre_previo = padre
		_posicion_previa = punto
		_velocidad_previa = Vector3.ZERO
		_desvio = Vector2.ZERO
		_rapidez = Vector2.ZERO
		_aceleracion = Vector2.ZERO
		_pintar()
		return
	var velocidad := distancia / paso
	var aceleracion := global_basis.inverse() * ((velocidad - _velocidad_previa) / paso)
	_posicion_previa = punto
	_velocidad_previa = velocidad
	_aceleracion = _aceleracion.lerp(
		Vector2(aceleracion.x, aceleracion.z).limit_length(24.0), 1.0 - exp(-paso / 0.06)
	)
	var gravedad := global_basis.inverse() * Vector3.DOWN
	var objetivo := Vector2(gravedad.x, gravedad.z) * 0.045 - _aceleracion * 0.008
	objetivo = objetivo.limit_length(0.065)
	var restante := paso
	while restante > 0.0:
		var subpaso := minf(PASO, restante)
		_rapidez += ((objetivo - _desvio) * 55.0 - _rapidez * 4.5) * subpaso
		_desvio = (_desvio + _rapidez * subpaso).limit_length(0.075)
		restante -= subpaso
	_pintar()


func _pintar() -> void:
	for pintura: ShaderMaterial in _pinturas:
		pintura.set_shader_parameter("flexion", _desvio)


## El agua tiñe las mismas fibras que se flexionan, sin envolverlas en una superficie rígida.
func mostrar_la_carga(cargada: bool, color: Color) -> void:
	for pintura: ShaderMaterial in _pinturas:
		pintura.set_shader_parameter("humedad", 0.65 if cargada else 0.0)
		pintura.set_shader_parameter("color_del_agua", color)
