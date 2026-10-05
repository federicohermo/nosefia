## Las raíces quedan fijas; las puntas siguen un resorte amortiguado en espacio local.
## Es una aproximación visual por grupos de fibras, sin modificar las reglas de limpieza.
extends MeshInstance3D

const FIBRAS := preload("res://src/escenas/objetos/fibras_de_la_mopa.gdshader")
const CABEZA := preload("res://src/escenas/objetos/cabeza_de_la_mopa.gdshader")
const CONTORNO_FIBRAS := preload("res://src/escenas/objetos/contorno_de_fibras.gdshader")
const CONTORNO_CABEZA := preload("res://src/escenas/objetos/contorno_de_cabeza.gdshader")
const CONTORNO := preload("res://src/sistemas/marco/contorno.gdshader")
const Raices := preload("res://src/escenas/objetos/raices_de_fibras.gd")
const PASO := 1.0 / 120.0

var _pinturas: Array[ShaderMaterial] = []
var _desvio := Vector2.ZERO
var _rapidez := Vector2.ZERO
var _aceleracion := Vector2.ZERO
var _posicion_previa := Vector3.ZERO
var _velocidad_previa := Vector3.ZERO
var _padre_previo: Node
var _muestreada := false
var _caida := Vector3.ZERO
var _inmersion := 0.0
var _rigidas: Array[ShaderMaterial] = []
var _articulacion := Basis.IDENTITY
var _contornos_fibra: Array[ShaderMaterial] = []
var _contornos_rigidos: Array[ShaderMaterial] = []
var _segundos_pases: Dictionary[Material, ShaderMaterial] = {}


func _ready() -> void:
	set_physics_process(false)
	_preparar.call_deferred()


func _preparar() -> void:
	if mesh == null:
		return
	mesh = Raices.preparar(mesh)
	if mesh == null:
		return
	for superficie: int in mesh.get_surface_count():
		var original := mesh.surface_get_material(superficie) as StandardMaterial3D
		if original == null:
			continue
		var pintura := ShaderMaterial.new()
		var contorno := ShaderMaterial.new()
		if original.resource_name.begins_with("util_fibra"):
			pintura.shader = FIBRAS
			pintura.set_shader_parameter("color_de_fibra", original.albedo_color)
			_pinturas.append(pintura)
			contorno.shader = CONTORNO_FIBRAS
			_contornos_fibra.append(contorno)
		elif original.resource_name in ["util_plastico_azul", "util_asa_grafito"]:
			pintura.shader = CABEZA
			pintura.set_shader_parameter("color_plastico", original.albedo_color)
			pintura.set_shader_parameter("rugosidad", original.roughness)
			_rigidas.append(pintura)
			contorno.shader = CONTORNO_CABEZA
			_contornos_rigidos.append(contorno)
		else:
			var copia := original.duplicate() as StandardMaterial3D
			contorno.shader = CONTORNO
			_segundos_pases[copia] = contorno
			set_surface_override_material(superficie, copia)
			continue
		_segundos_pases[pintura] = contorno
		set_surface_override_material(superficie, pintura)
	set_physics_process(not _pinturas.is_empty())


func _physics_process(delta: float) -> void:
	if delta <= 0.0 or not is_visible_in_tree():
		_muestreada = false
		return
	var paso := minf(delta, 0.1)
	var gravedad_local := (
		_articulacion.inverse() * global_basis.orthonormalized().inverse() * Vector3.DOWN
	)
	_caida = _caida.lerp((gravedad_local - Vector3.DOWN) * 0.08, 1.0 - exp(-paso / 0.15))
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
		_pintar(paso)
		return
	var velocidad := distancia / paso
	var aceleracion := (
		_articulacion.inverse() * global_basis.inverse() * ((velocidad - _velocidad_previa) / paso)
	)
	_posicion_previa = punto
	_velocidad_previa = velocidad
	_aceleracion = _aceleracion.lerp(
		Vector2(aceleracion.x, aceleracion.z).limit_length(24.0), 1.0 - exp(-paso / 0.06)
	)
	var gravedad := gravedad_local
	var objetivo := Vector2(gravedad.x, gravedad.z) * 0.045 - _aceleracion * 0.008
	objetivo = objetivo.limit_length(0.065)
	var restante := paso
	while restante > 0.0:
		var subpaso := minf(PASO, restante)
		_rapidez += ((objetivo - _desvio) * 55.0 - _rapidez * 4.5) * subpaso
		_desvio = (_desvio + _rapidez * subpaso).limit_length(0.075)
		restante -= subpaso
	_pintar(paso)


func _pintar(paso: float) -> void:
	var cabeza := to_global(Vector3(0.0, -0.83, 0.0))
	var consulta := PhysicsRayQueryParameters3D.create(
		cabeza + Vector3.UP * 0.25, cabeza + Vector3.DOWN * 0.8, 9
	)
	consulta.exclude = [(get_parent() as CollisionObject3D).get_rid()]
	var apoyo := get_world_3d().direct_space_state.intersect_ray(consulta)
	var suelo := -1000.0 if apoyo.is_empty() else (apoyo.position as Vector3).y
	var pivot := Vector3(0.0, -0.752, 0.0)
	var altura := to_global(pivot).y - suelo
	var cuerpo := get_parent() as RigidBody3D
	if cuerpo.freeze:
		_articulacion = Basis.IDENTITY
	else:
		var vertical := (global_basis.inverse() * Vector3.UP).normalized()
		var giro := Basis(Quaternion(Vector3.UP, vertical))
		var contacto := 1.0 - smoothstep(0.18, 0.35, altura)
		var destino := Basis.IDENTITY.slerp(giro, contacto)
		_articulacion = _articulacion.slerp(destino, 1.0 - exp(-paso / 0.1))
	var pose := Transform3D(_articulacion, pivot - _articulacion * pivot)
	for pintura: ShaderMaterial in _rigidas + _contornos_rigidos:
		pintura.set_shader_parameter("articulacion", pose)
	for pintura: ShaderMaterial in _pinturas + _contornos_fibra:
		pintura.set_shader_parameter("articulacion", pose)
		pintura.set_shader_parameter("flexion", _desvio)
		pintura.set_shader_parameter("caida", _caida)
		pintura.set_shader_parameter("suelo_y", suelo)


func limitar_en(balde: Node3D, progreso: float) -> void:
	_inmersion = smoothstep(0.55, 0.85, progreso)
	var centro := to_local(balde.to_global(Vector3(0.0, 0.07, 0.0)))
	var vertical := (global_basis.inverse() * balde.global_basis.y).normalized()
	for pintura: ShaderMaterial in _pinturas + _contornos_fibra:
		pintura.set_shader_parameter("centro_balde", centro)
		pintura.set_shader_parameter("vertical_balde", vertical)
		pintura.set_shader_parameter("inmersion", _inmersion)


func liberar() -> void:
	_inmersion = 0.0
	for pintura: ShaderMaterial in _pinturas + _contornos_fibra:
		pintura.set_shader_parameter("inmersion", 0.0)


func mostrar_contorno(material: ShaderMaterial) -> void:
	for pintura: Material in _segundos_pases:
		var contorno := _segundos_pases[pintura]
		pintura.next_pass = contorno if material != null else null
		if material != null:
			contorno.set_shader_parameter("color", material.get_shader_parameter("color"))
			contorno.set_shader_parameter("grosor", material.get_shader_parameter("grosor"))


## El agua tiñe las mismas fibras que se flexionan, sin envolverlas en una superficie rígida.
func mostrar_la_carga(cargada: bool, color: Color, cantidad: float = 1.0) -> void:
	for pintura: ShaderMaterial in _pinturas:
		pintura.set_shader_parameter("humedad", 0.65 * cantidad if cargada else 0.0)
		pintura.set_shader_parameter("color_del_agua", color)
