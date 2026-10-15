## Una máscara de las referencias permite desenfocar su imagen completa, incluida la silueta.
## La profundidad del mundo conserva por delante el estante y los productos interactuables.
class_name DesenfoqueDeReferencias
extends Node3D

const MASCARA := preload("res://src/ui/mascara_de_referencias.gdshader")
const DESENFOQUE := preload("res://src/ui/desenfoque_de_referencias.gdshader")
var _ventana := SubViewport.new()
var _camara := Camera3D.new()
var _pantalla := MeshInstance3D.new()
var _material_de_mascara := ShaderMaterial.new()


func _ready() -> void:
	process_priority = 50
	# También con el almacén detenido detrás de la carga: si no, la máscara se dibujaba recién en
	# el primer cuadro de juego, y ahí compilaba sus shaders.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Las transformaciones copiadas ya vienen interpoladas. Interpolarlas otra vez atrasa
	# la máscara respecto de la imagen y descubre el producto al mover la cámara.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_ventana.own_world_3d = true
	_ventana.transparent_bg = true
	_ventana.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_ventana.positional_shadow_atlas_size = 0
	_ventana.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_ventana)
	_ventana.add_child(_camara)
	_camara.environment = Environment.new()
	_camara.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_camara.current = true
	_material_de_mascara.shader = MASCARA
	var malla := QuadMesh.new()
	malla.size = Vector2(2.0, 2.0)
	_pantalla.mesh = malla
	_pantalla.extra_cull_margin = 100.0
	_pantalla.ignore_occlusion_culling = true
	_pantalla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pantalla.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_pantalla.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var material := ShaderMaterial.new()
	material.shader = DESENFOQUE
	material.render_priority = -100
	material.set_shader_parameter("mascara", _ventana.get_texture())
	_pantalla.material_override = material
	add_child(_pantalla)


func agregar(grupo: MultiMeshInstance3D, bloque: PackedFloat32Array, cantidad: int) -> void:
	var dibujo := MultiMeshInstance3D.new()
	var copias := MultiMesh.new()
	copias.transform_format = MultiMesh.TRANSFORM_3D
	copias.mesh = grupo.multimesh.mesh
	copias.instance_count = grupo.multimesh.instance_count
	copias.buffer = bloque
	copias.visible_instance_count = cantidad
	dibujo.multimesh = copias
	dibujo.material_override = _material_de_mascara
	dibujo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dibujo.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_ventana.add_child(dibujo)
	dibujo.transform = grupo.global_transform


func _process(_delta: float) -> void:
	var vista := get_viewport().get_camera_3d()
	if vista == null:
		return
	_ventana.size = Vector2i(get_viewport().get_visible_rect().size)
	_camara.projection = vista.projection
	_camara.keep_aspect = vista.keep_aspect
	_camara.fov = vista.fov
	_camara.size = vista.size
	_camara.near = vista.near
	_camara.far = vista.far
	_camara.frustum_offset = vista.frustum_offset
	# El giro no se interpola, pero la cámara hereda el dibujo de la traslación del jugador.
	# Copiar la pose física adelanta la máscara y su profundidad al retroceder.
	_camara.transform = _pose_dibujada(vista)
	_pantalla.global_transform = _camara.transform
	_pantalla.position -= _pantalla.basis.z


func _pose_dibujada(vista: Node3D) -> Transform3D:
	var nodo := vista
	while nodo != null:
		if nodo.is_physics_interpolated_and_enabled():
			return vista.get_global_transform_interpolated()
		if nodo.top_level:
			break
		nodo = nodo.get_parent_node_3d()
	# Sin traslación interpolada, el getter puede conservar una muestra anterior del giro.
	return vista.global_transform
