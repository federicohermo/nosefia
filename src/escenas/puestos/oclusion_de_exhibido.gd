## Dibuja la oclusión de contacto de las facturas exhibidas en el mostrador siguiendo su silueta
## curva real.
##
## Las mallas `exhibido_*` se importan como dinámicas para no recibir cortes del lightmap, así que
## tampoco proyectan sombra horneada sobre sus estantes. Este nodo separa la malla en islas conexas,
## distingue medialunas curvas de croissants y coloca sus manchas en dos `MultiMeshInstance3D`
## reutilizando la silueta de cápsulas de `sombra_de_contacto.gdshader`.
extends MeshInstance3D

const OclusionDeContacto := preload("res://src/escenas/objetos/oclusion_de_contacto.gd")

const BANDA_DE_APOYO := 0.012
const ELEVACION := 0.0020
const PRIORIDAD_DE_LA_MANCHA := -2
const SUAVIDAD := 0.015
const INTENSIDAD := 0.42
const UMBRAL_CURVATURA := 0.11

const TAMANO_MEDIALUNA := Vector2(0.155, 0.105)
const TAMANO_CROISSANT := Vector2(0.165, 0.105)


func _ready() -> void:
	_construir_sombras()


func _construir_sombras() -> void:
	if mesh == null:
		return
	var poses_medialuna: Array[Transform3D] = []
	var poses_croissant: Array[Transform3D] = []
	_clasificar_islas(poses_medialuna, poses_croissant)

	if not poses_medialuna.is_empty():
		var caps_m: Array[Vector4] = [
			Vector4(-0.0404, -0.0082, -0.0220, 0.0023),
			Vector4(-0.0220, 0.0023, 0.0, 0.0062),
			Vector4(0.0, 0.0062, 0.0220, 0.0023),
			Vector4(0.0220, 0.0023, 0.0404, -0.0082),
		]
		var radios_m: Array[float] = [0.010, 0.017, 0.017, 0.010]
		_agregar_lote("SombrasDeMedialunas", poses_medialuna, TAMANO_MEDIALUNA, caps_m, radios_m)

	if not poses_croissant.is_empty():
		var caps_c: Array[Vector4] = [
			Vector4(-0.0443, -0.0027, -0.0223, 0.0008),
			Vector4(-0.0223, 0.0008, 0.0, 0.0020),
			Vector4(0.0, 0.0020, 0.0223, 0.0008),
			Vector4(0.0223, 0.0008, 0.0443, -0.0027),
		]
		var radios_c: Array[float] = [0.011, 0.020, 0.020, 0.011]
		_agregar_lote("SombrasDeCroissants", poses_croissant, TAMANO_CROISSANT, caps_c, radios_c)


func _agregar_lote(
	nombre: String,
	poses: Array[Transform3D],
	tamano: Vector2,
	capsulas: Array[Vector4],
	radios: Array[float],
) -> void:
	var lote := MultiMeshInstance3D.new()
	lote.name = nombre
	lote.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	lote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lote.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	lote.add_to_group(ReglasDeLosObjetos.GRUPO_SIN_CONTORNO)

	var cantidad := capsulas.size()
	var caps: Array[Vector4] = capsulas.duplicate()
	var rads: Array[float] = radios.duplicate()
	while caps.size() < OclusionDeContacto.MAX_CAPSULAS:
		caps.append(Vector4.ZERO)
		rads.append(0.0)

	var material := ShaderMaterial.new()
	material.shader = OclusionDeContacto.SOMBRA
	material.render_priority = PRIORIDAD_DE_LA_MANCHA
	material.set_shader_parameter(&"tamano", tamano)
	material.set_shader_parameter(&"suavidad", SUAVIDAD)
	material.set_shader_parameter(&"intensidad", INTENSIDAD * OclusionDeContacto.OPACIDAD_MAXIMA)
	material.set_shader_parameter(&"usar_silueta", true)
	material.set_shader_parameter(&"cantidad_capsulas", cantidad)
	material.set_shader_parameter(&"capsulas", caps)
	material.set_shader_parameter(&"radios_capsulas", rads)
	material.set_shader_parameter(&"aro_silueta", Vector4.ZERO)
	lote.material_override = material

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = OclusionDeContacto.plano()
	mm.instance_count = poses.size()
	for i: int in poses.size():
		var pose := poses[i]
		var escalada := Transform3D(
			pose.basis.scaled_local(Vector3(tamano.x, 1.0, tamano.y)), pose.origin
		)
		mm.set_instance_transform(i, escalada)
	lote.multimesh = mm
	add_child(lote)


func _clasificar_islas(
	poses_medialuna: Array[Transform3D],
	poses_croissant: Array[Transform3D],
) -> void:
	var mundo := global_transform
	var inversa := mundo.affine_inverse()
	var claves: Dictionary = {}
	var posiciones: Array[Vector3] = []
	var padres: PackedInt32Array = PackedInt32Array()

	for s: int in mesh.get_surface_count():
		var arreglos := mesh.surface_get_arrays(s)
		if arreglos.is_empty():
			continue
		var vertices: PackedVector3Array = arreglos[Mesh.ARRAY_VERTEX]
		var indices: Variant = arreglos[Mesh.ARRAY_INDEX]
		var mapa_local := PackedInt32Array()
		mapa_local.resize(vertices.size())
		for i: int in vertices.size():
			var p := mundo * vertices[i]
			var clave := Vector3i(
				roundi(p.x * OclusionDeContacto.RESOLUCION_DE_VERTICES),
				roundi(p.y * OclusionDeContacto.RESOLUCION_DE_VERTICES),
				roundi(p.z * OclusionDeContacto.RESOLUCION_DE_VERTICES)
			)
			if not claves.has(clave):
				var nuevo_id := posiciones.size()
				claves[clave] = nuevo_id
				posiciones.append(p)
				padres.append(nuevo_id)
			mapa_local[i] = claves[clave] as int

		if indices != null:
			var idx: PackedInt32Array = indices
			for t: int in range(0, idx.size() - 2, 3):
				_unir(padres, mapa_local[idx[t]], mapa_local[idx[t + 1]])
				_unir(padres, mapa_local[idx[t + 1]], mapa_local[idx[t + 2]])
		else:
			for t: int in range(0, vertices.size() - 2, 3):
				_unir(padres, mapa_local[t], mapa_local[t + 1])
				_unir(padres, mapa_local[t + 1], mapa_local[t + 2])

	var grupos: Dictionary = {}
	for i: int in posiciones.size():
		var r := _raiz(padres, i)
		if not grupos.has(r):
			grupos[r] = []
		(grupos[r] as Array).append(posiciones[i])

	for pts_var: Variant in grupos.values():
		var pts: Array = pts_var
		if pts.size() < 4:
			continue
		var resultado := _medir_isla(pts)
		var pose_local: Transform3D = inversa * (resultado["pose"] as Transform3D)
		if resultado["curva"] as bool:
			poses_medialuna.append(pose_local)
		else:
			poses_croissant.append(pose_local)


static func _medir_isla(pts: Array) -> Dictionary:
	var y_min := INF
	for v_var: Variant in pts:
		var v: Vector3 = v_var
		if v.y < y_min:
			y_min = v.y

	var base_pts: Array[Vector2] = []
	var suma := Vector2.ZERO
	for v_var: Variant in pts:
		var v: Vector3 = v_var
		if v.y <= y_min + BANDA_DE_APOYO:
			var p2 := Vector2(v.x, v.z)
			base_pts.append(p2)
			suma += p2

	if base_pts.size() < 3:
		base_pts.clear()
		suma = Vector2.ZERO
		for v_var: Variant in pts:
			var v: Vector3 = v_var
			var p2 := Vector2(v.x, v.z)
			base_pts.append(p2)
			suma += p2

	var centro_medio := suma / float(base_pts.size())
	var sxx := 0.0
	var szz := 0.0
	var sxz := 0.0
	for p2: Vector2 in base_pts:
		var d := p2 - centro_medio
		sxx += d.x * d.x
		szz += d.y * d.y
		sxz += d.x * d.y

	var theta := 0.5 * atan2(2.0 * sxz, sxx - szz)
	var cos_t := cos(theta)
	var sin_t := sin(theta)

	var min_u := INF
	var max_u := -INF
	for p2: Vector2 in base_pts:
		var d := p2 - centro_medio
		var u := d.x * cos_t + d.y * sin_t
		min_u = minf(min_u, u)
		max_u = maxf(max_u, u)
	var mid_u := 0.5 * (min_u + max_u)
	var span_u := maxf(0.01, max_u - min_u)

	# Orienta `+e_z` hacia la panza convexa comparando el centro contra las puntas.
	var w_centro := 0.0
	var n_centro := 0
	var w_puntas := 0.0
	var n_puntas := 0
	for p2: Vector2 in base_pts:
		var d := p2 - centro_medio
		var u := (d.x * cos_t + d.y * sin_t) - mid_u
		var w := -d.x * sin_t + d.y * cos_t
		if absf(u) <= 0.22 * span_u:
			w_centro += w
			n_centro += 1
		elif absf(u) >= 0.34 * span_u:
			w_puntas += w
			n_puntas += 1

	var desvio := 0.0
	if n_centro > 0 and n_puntas > 0:
		desvio = (w_centro / float(n_centro)) - (w_puntas / float(n_puntas))
		if desvio < 0.0:
			cos_t = -cos_t
			sin_t = -sin_t
			desvio = -desvio

	min_u = INF
	max_u = -INF
	var min_w := INF
	var max_w := -INF
	for p2: Vector2 in base_pts:
		var d := p2 - centro_medio
		var u := d.x * cos_t + d.y * sin_t
		var w := -d.x * sin_t + d.y * cos_t
		min_u = minf(min_u, u)
		max_u = maxf(max_u, u)
		min_w = minf(min_w, w)
		max_w = maxf(max_w, w)

	mid_u = 0.5 * (min_u + max_u)
	var mid_w := 0.5 * (min_w + max_w)
	var cx := centro_medio.x + mid_u * cos_t - mid_w * sin_t
	var cz := centro_medio.y + mid_u * sin_t + mid_w * cos_t
	var eje_x := Vector3(cos_t, 0.0, sin_t)
	var eje_z := Vector3(-sin_t, 0.0, cos_t)
	return {
		"pose": Transform3D(Basis(eje_x, Vector3.UP, eje_z), Vector3(cx, y_min + ELEVACION, cz)),
		"curva": (desvio / span_u) > UMBRAL_CURVATURA,
	}


static func _raiz(padres: PackedInt32Array, x: int) -> int:
	var r := x
	while padres[r] != r:
		r = padres[r]
	var cur := x
	while padres[cur] != r:
		var sig := padres[cur]
		padres[cur] = r
		cur = sig
	return r


static func _unir(padres: PackedInt32Array, a: int, b: int) -> void:
	var ra := _raiz(padres, a)
	var rb := _raiz(padres, b)
	if ra != rb:
		padres[rb] = ra
