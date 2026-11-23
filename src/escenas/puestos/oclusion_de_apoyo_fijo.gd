## Dibuja la oclusión de contacto de un aparato o mueble fijo apoyado sobre una mesada.
##
## Los puestos dinámicos sobre la mesada blanca (router, lector) no entran al lightmap, y los
## estáticos chicos (base de la compu, teclado, mouse, registradora) se lavan bajo el reflejo
## brillante de la mesada. Este script mide la huella apoyada en el plano horizontal de la malla
## y agrega una mancha suave en un `MultiMeshInstance3D` reutilizando `sombra_de_contacto.gdshader`.
extends MeshInstance3D

const OclusionDeContacto := preload("res://src/escenas/objetos/oclusion_de_contacto.gd")

const BANDA_DE_APOYO := 0.028
const ELEVACION := 0.0018
const PRIORIDAD_DE_LA_MANCHA := -2
const MINIMO_SEMIEJE := 0.015

@export var radio := 0.022
@export_range(0.0, 1.0) var intensidad := 0.28
@export_range(0.0, 1.0) var esquinas := 0.1
## Altura fija del plano de apoyo en Y del mundo (por ejemplo, la mesada a 1,15 m). Si se deja
## por debajo de -999, usa el punto más bajo de la malla.
@export var altura_de_apoyo := -1000.0

var _lote: MultiMeshInstance3D = null


func _ready() -> void:
	_construir_sombra()


func definir_activa(activa: bool) -> void:
	if _lote != null:
		_lote.visible = activa


func _construir_sombra() -> void:
	if mesh == null:
		return
	var mundo := global_transform
	var eje_x := Vector3(mundo.basis.x.x, 0.0, mundo.basis.x.z)
	if eje_x.length_squared() < 1e-6:
		eje_x = Vector3.RIGHT
	else:
		eje_x = eje_x.normalized()
	var eje_z := eje_x.cross(Vector3.UP).normalized()

	var puntos: Array[Vector3] = []
	var y_min := INF
	for s: int in mesh.get_surface_count():
		var arreglos := mesh.surface_get_arrays(s)
		if arreglos.is_empty():
			continue
		var vertices: PackedVector3Array = arreglos[Mesh.ARRAY_VERTEX]
		for v: Vector3 in vertices:
			var p := mundo * v
			puntos.append(p)
			if p.y < y_min:
				y_min = p.y

	if puntos.is_empty():
		return

	var y_superficie := altura_de_apoyo if altura_de_apoyo > -999.0 else y_min
	var y_banda := maxf(y_min, y_superficie)
	var min_u := INF
	var max_u := -INF
	var min_w := INF
	var max_w := -INF
	var cuenta := 0
	for p: Vector3 in puntos:
		if p.y <= y_banda + BANDA_DE_APOYO:
			var u := p.x * eje_x.x + p.z * eje_x.z
			var w := p.x * eje_z.x + p.z * eje_z.z
			min_u = minf(min_u, u)
			max_u = maxf(max_u, u)
			min_w = minf(min_w, w)
			max_w = maxf(max_w, w)
			cuenta += 1

	if cuenta < 3:
		for p: Vector3 in puntos:
			var u := p.x * eje_x.x + p.z * eje_x.z
			var w := p.x * eje_z.x + p.z * eje_z.z
			min_u = minf(min_u, u)
			max_u = maxf(max_u, u)
			min_w = minf(min_w, w)
			max_w = maxf(max_w, w)

	var hx := maxf(MINIMO_SEMIEJE, 0.5 * (max_u - min_u))
	var hz := maxf(MINIMO_SEMIEJE, 0.5 * (max_w - min_w))
	var mid_u := 0.5 * (min_u + max_u)
	var mid_w := 0.5 * (min_w + max_w)
	var centro := eje_x * mid_u + eje_z * mid_w + Vector3(0.0, y_superficie + ELEVACION, 0.0)

	var huella := Vector2(hx, hz)
	var tamano := huella * 2.0 + Vector2.ONE * (radio * 2.0)
	var pose_mundo := Transform3D(Basis(eje_x * tamano.x, Vector3.UP, eje_z * tamano.y), centro)
	var pose_local := mundo.affine_inverse() * pose_mundo

	_lote = MultiMeshInstance3D.new()
	_lote.name = "SombraDeContacto"
	_lote.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_lote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lote.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	_lote.add_to_group(ReglasDeLosObjetos.GRUPO_SIN_CONTORNO)

	var material := ShaderMaterial.new()
	material.shader = OclusionDeContacto.SOMBRA
	material.render_priority = PRIORIDAD_DE_LA_MANCHA
	material.set_shader_parameter(&"tamano", tamano)
	material.set_shader_parameter(&"huella", huella)
	material.set_shader_parameter(&"esquinas", esquinas)
	material.set_shader_parameter(&"suavidad", radio)
	material.set_shader_parameter(&"intensidad", intensidad * OclusionDeContacto.OPACIDAD_MAXIMA)
	_lote.material_override = material

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = OclusionDeContacto.plano()
	mm.instance_count = 1
	mm.set_instance_transform(0, pose_local)
	_lote.multimesh = mm
	add_child(_lote)
