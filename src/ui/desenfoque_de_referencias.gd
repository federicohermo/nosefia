## Una máscara de las referencias permite desenfocar su imagen completa, incluida la silueta.
## La profundidad del mundo conserva por delante el estante y los productos interactuables.
class_name DesenfoqueDeReferencias
extends Node3D

const MASCARA := preload("res://src/ui/mascara_de_referencias.gdshader")
const DESENFOQUE := preload("res://src/ui/desenfoque_de_referencias.gdshader")
## Cuántas mallas del mundo se vuelven a clasificar por material en cada cuadro. Casi ninguna
## puede tapar, y revisarlas todas en cada cuadro costaba más que el resto del efecto.
const REVISION_POR_CUADRO := 64

var _ventana := SubViewport.new()
var _camara := Camera3D.new()
var _pantalla := MeshInstance3D.new()
var _material_de_mascara := ShaderMaterial.new()
var _material_de_oclusor := ShaderMaterial.new()
var _oclusores: Dictionary[MeshInstance3D, MeshInstance3D] = {}
var _fuentes: Array[MeshInstance3D] = []
## Las mallas con materiales opacos: sólo esas pueden tapar una referencia.
var _posibles: Dictionary[MeshInstance3D, bool] = {}
var _revision := 0
var _mundo: Node


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
	_material_de_oclusor.shader = MASCARA
	_material_de_oclusor.set_shader_parameter("es_referencia", false)
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
	var oclusor := MultiMeshInstance3D.new()
	oclusor.multimesh = grupo.multimesh
	var material := _material_de_oclusor.duplicate() as ShaderMaterial
	material.set_shader_parameter("desde", cantidad)
	oclusor.material_override = material
	oclusor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	oclusor.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_ventana.add_child(oclusor)
	oclusor.transform = grupo.global_transform


func preparar_oclusores(mundo: Node) -> void:
	_mundo = mundo
	for nodo: Node in mundo.find_children("*", "MeshInstance3D", true, false):
		_agregar_oclusor(nodo)
	get_tree().node_added.connect(_agregar_oclusor)


func _agregar_oclusor(nodo: Node) -> void:
	var fuente := nodo as MeshInstance3D
	if fuente == null or is_ancestor_of(fuente) or not _mundo.is_ancestor_of(fuente):
		return
	var copia := MeshInstance3D.new()
	copia.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	copia.material_override = _material_de_oclusor
	copia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	copia.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_ventana.add_child(copia)
	_oclusores[fuente] = copia
	_fuentes.append(fuente)
	if _materiales_opacos(fuente):
		_posibles[fuente] = true
	fuente.tree_exiting.connect(_quitar_oclusor.bind(fuente), CONNECT_ONE_SHOT)


## Sale al dejar el árbol, antes de liberarse: el diccionario tipado no acepta una clave liberada.
## Si vuelve al árbol, `node_added` la agrega de nuevo.
func _quitar_oclusor(fuente: MeshInstance3D) -> void:
	if not _oclusores.has(fuente):
		return
	_oclusores[fuente].queue_free()
	_oclusores.erase(fuente)
	_posibles.erase(fuente)
	_fuentes.erase(fuente)


func _es_opaca(fuente: MeshInstance3D) -> bool:
	return fuente.is_visible_in_tree() and _materiales_opacos(fuente)


func _materiales_opacos(fuente: MeshInstance3D) -> bool:
	if fuente.mesh == null:
		return false
	for superficie in fuente.mesh.get_surface_count():
		var material := fuente.get_active_material(superficie) as BaseMaterial3D
		if material == null or material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			return false
	return true


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
	# La cámara del jugador gira sin interpolación. Su getter interpolado conserva la
	# muestra del cuadro anterior, aunque tenga la interpolación apagada.
	_camara.transform = vista.global_transform
	_pantalla.global_transform = _camara.transform
	_pantalla.position -= _pantalla.basis.z
	_revisar_materiales()
	for fuente: MeshInstance3D in _posibles:
		var copia := _oclusores[fuente]
		copia.visible = _es_opaca(fuente)
		if copia.visible:
			copia.mesh = fuente.mesh
			copia.transform = fuente.get_global_transform_interpolated()


## Un material cambiado entra o sale de las posibles en menos de medio segundo. Una posible que
## deja de ser opaca se oculta en el mismo cuadro, porque `_es_opaca` mira otra vez sus materiales.
func _revisar_materiales() -> void:
	for i in mini(REVISION_POR_CUADRO, _fuentes.size()):
		_revision = (_revision + 1) % _fuentes.size()
		var fuente := _fuentes[_revision]
		if _materiales_opacos(fuente):
			_posibles[fuente] = true
		elif _posibles.erase(fuente):
			_oclusores[fuente].visible = false
