## Dibuja la oclusión de contacto de un aparato o mueble fijo apoyado sobre una superficie.
##
## Los puestos dinámicos sobre la mesada blanca (router, lector, cafetera) no entran al lightmap, y
## los muebles y aparatos estáticos sobre mesada o piso pierden el pliegue pegado a la base bajo el
## reflejo o el filtrado del atlas. Este script separa las islas conexas dentro de la banda de
## apoyo para seguir la silueta real de patas, ruedas o bases compuestas sin encerrarlas en una
## envolvente rectangular, y agrega cada lote en `MultiMeshInstance3D` reutilizando
## `sombra_de_contacto.gdshader`.
extends MeshInstance3D

const OclusionDeContacto := preload("res://src/escenas/objetos/oclusion_de_contacto.gd")

const BANDA_DE_APOYO := 0.036
const ELEVACION := 0.0018
const PRIORIDAD_DE_LA_MANCHA := -2
const MINIMO_SEMIEJE := 0.004
const MAX_CAJAS := 8
const TOLERANCIA_FUSION := 0.05

@export var radio := 0.022
@export_range(0.0, 1.0) var intensidad := 0.28
@export_range(0.0, 1.0) var esquinas := 0.1
## Altura fija del plano de apoyo en Y del mundo (por ejemplo, la mesada a 1,15 m o el piso a
## 0,1032 m). Si se deja por debajo de -999, usa el punto más bajo de la malla.
@export var altura_de_apoyo := -1000.0
## Altura sobre el plano de apoyo desde la que se juntan vértices para medir la huella.
@export var banda_de_apoyo := BANDA_DE_APOYO
## Si se declara, reemplaza las islas detectadas de la malla por estos rectángulos en XZ del mundo
## (útil para bases cóncavas de una sola pieza como un mostrador en L).
@export var cajas_manuales: Array[Rect2] = []

var _lotes: Array[MultiMeshInstance3D] = []


func _ready() -> void:
	_construir_sombra()


func definir_activa(activa: bool) -> void:
	for lote: MultiMeshInstance3D in _lotes:
		lote.visible = activa


func _construir_sombra() -> void:
	if mesh == null and cajas_manuales.is_empty():
		return
	var mundo := global_transform
	var eje_x := Vector3(mundo.basis.x.x, 0.0, mundo.basis.x.z)
	if not cajas_manuales.is_empty() or eje_x.length_squared() < 1e-6:
		eje_x = Vector3.RIGHT
	else:
		eje_x = eje_x.normalized()
	var eje_z := (
		Vector3.BACK if not cajas_manuales.is_empty() else eje_x.cross(Vector3.UP).normalized()
	)

	var y_superficie := altura_de_apoyo
	var cajas: Array[Rect2] = []
	if not cajas_manuales.is_empty():
		cajas = cajas_manuales.duplicate()
		if y_superficie <= -999.0 and mesh != null:
			y_superficie = (mundo * mesh.get_aabb()).position.y
	else:
		var mallas_mundo := _leer_malla_en_mundo(mundo)
		if mallas_mundo.is_empty():
			return
		var y_min := INF
		for entrada: Array in mallas_mundo:
			var verts: PackedVector3Array = entrada[0]
			for p: Vector3 in verts:
				if p.y < y_min:
					y_min = p.y
		if not is_finite(y_min):
			return
		y_superficie = altura_de_apoyo if altura_de_apoyo > -999.0 else y_min
		var y_banda := maxf(y_min, y_superficie)
		cajas = _islas_en_banda(mallas_mundo, eje_x, eje_z, y_banda + banda_de_apoyo)
		if cajas.is_empty():
			cajas = _islas_en_banda(mallas_mundo, eje_x, eje_z, INF)
	if cajas.is_empty():
		return

	cajas = _compactar_cajas(cajas)
	var grupos := _agrupar_lotes(cajas)
	var inv_mundo := mundo.affine_inverse()
	for idx: int in grupos.size():
		_agregar_lote(idx, grupos[idx], eje_x, eje_z, y_superficie, inv_mundo)


func _leer_malla_en_mundo(mundo: Transform3D) -> Array[Array]:
	var salida: Array[Array] = []
	for s: int in mesh.get_surface_count():
		var arreglos := mesh.surface_get_arrays(s)
		if arreglos.is_empty():
			continue
		var vertices: PackedVector3Array = arreglos[Mesh.ARRAY_VERTEX]
		if vertices.is_empty():
			continue
		var transformados := PackedVector3Array()
		transformados.resize(vertices.size())
		for i: int in vertices.size():
			transformados[i] = mundo * vertices[i]
		var indices: Variant = arreglos[Mesh.ARRAY_INDEX]
		salida.append([transformados, indices])
	return salida


func _agregar_lote(
	indice: int,
	cajas: Array[Rect2],
	eje_x: Vector3,
	eje_z: Vector3,
	y_superficie: float,
	inv_mundo: Transform3D,
) -> void:
	var total := cajas[0]
	for i: int in range(1, cajas.size()):
		total = total.merge(cajas[i])

	var hx := maxf(MINIMO_SEMIEJE, 0.5 * total.size.x)
	var hz := maxf(MINIMO_SEMIEJE, 0.5 * total.size.y)
	var mid_u := total.position.x + 0.5 * total.size.x
	var mid_w := total.position.y + 0.5 * total.size.y
	var centro := eje_x * mid_u + eje_z * mid_w + Vector3(0.0, y_superficie + ELEVACION, 0.0)

	var huella := Vector2(hx, hz)
	var tamano := huella * 2.0 + Vector2.ONE * (radio * 2.0)
	var pose_mundo := Transform3D(Basis(eje_x * tamano.x, Vector3.UP, eje_z * tamano.y), centro)
	var pose_local := inv_mundo * pose_mundo

	var lote := MultiMeshInstance3D.new()
	lote.name = "SombraDeContacto" if indice == 0 else "SombraDeContacto_%d" % indice
	lote.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	lote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lote.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	lote.add_to_group(ReglasDeLosObjetos.GRUPO_SIN_CONTORNO)

	var material := ShaderMaterial.new()
	material.shader = OclusionDeContacto.SOMBRA
	material.render_priority = PRIORIDAD_DE_LA_MANCHA
	material.set_shader_parameter(&"tamano", tamano)
	material.set_shader_parameter(&"huella", huella)
	material.set_shader_parameter(&"esquinas", esquinas)
	material.set_shader_parameter(&"suavidad", radio)
	material.set_shader_parameter(&"intensidad", intensidad * OclusionDeContacto.OPACIDAD_MAXIMA)
	if cajas.size() > 1:
		var arreglo_cajas: Array[Vector4] = []
		for rect: Rect2 in cajas:
			var cx := rect.position.x + 0.5 * rect.size.x - mid_u
			var cw := rect.position.y + 0.5 * rect.size.y - mid_w
			var rx := maxf(MINIMO_SEMIEJE, 0.5 * rect.size.x)
			var rw := maxf(MINIMO_SEMIEJE, 0.5 * rect.size.y)
			arreglo_cajas.append(Vector4(cx, cw, rx, rw))
		while arreglo_cajas.size() < MAX_CAJAS:
			arreglo_cajas.append(Vector4.ZERO)
		material.set_shader_parameter(&"usar_cajas", true)
		material.set_shader_parameter(&"cantidad_cajas", cajas.size())
		material.set_shader_parameter(&"cajas", arreglo_cajas)
	lote.material_override = material

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = OclusionDeContacto.plano()
	mm.instance_count = 1
	mm.set_instance_transform(0, pose_local)
	lote.multimesh = mm
	add_child(lote)
	_lotes.append(lote)


## Separa las islas conexas tomando sólo vértices y aristas dentro de la banda de apoyo: así las
## cuatro patas de una silla o estantería no se funden a través del asiento ni del estante superior.
static func _islas_en_banda(
	mallas_mundo: Array[Array],
	eje_x: Vector3,
	eje_z: Vector3,
	y_techo: float,
) -> Array[Rect2]:
	var claves: Dictionary = {}
	var posiciones: Array[Vector3] = []
	var padres := PackedInt32Array()

	for entrada: Array in mallas_mundo:
		var vertices: PackedVector3Array = entrada[0]
		var indices: Variant = entrada[1]
		var mapa_local := PackedInt32Array()
		mapa_local.resize(vertices.size())
		mapa_local.fill(-1)
		for i: int in vertices.size():
			var p := vertices[i]
			if p.y > y_techo:
				continue
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
				_unir_triangulo(
					padres, mapa_local[idx[t]], mapa_local[idx[t + 1]], mapa_local[idx[t + 2]]
				)
		else:
			for t: int in range(0, vertices.size() - 2, 3):
				_unir_triangulo(padres, mapa_local[t], mapa_local[t + 1], mapa_local[t + 2])

	if posiciones.is_empty():
		return []

	var grupos: Dictionary = {}
	for i: int in posiciones.size():
		var p := posiciones[i]
		var r := _raiz(padres, i)
		var u := p.x * eje_x.x + p.z * eje_x.z
		var w := p.x * eje_z.x + p.z * eje_z.z
		if not grupos.has(r):
			grupos[r] = [u, u, w, w, 1]
		else:
			var g: Array = grupos[r]
			g[0] = minf(g[0] as float, u)
			g[1] = maxf(g[1] as float, u)
			g[2] = minf(g[2] as float, w)
			g[3] = maxf(g[3] as float, w)
			g[4] = (g[4] as int) + 1

	var cajas: Array[Rect2] = []
	for g_var: Variant in grupos.values():
		var g: Array = g_var
		if (g[4] as int) < 3:
			continue
		var min_u: float = g[0]
		var max_u: float = g[1]
		var min_w: float = g[2]
		var max_w: float = g[3]
		var sx := maxf(MINIMO_SEMIEJE * 2.0, max_u - min_u)
		var sw := maxf(MINIMO_SEMIEJE * 2.0, max_w - min_w)
		var cu := 0.5 * (min_u + max_u)
		var cw := 0.5 * (min_w + max_w)
		cajas.append(Rect2(Vector2(cu - 0.5 * sx, cw - 0.5 * sw), Vector2(sx, sw)))
	return cajas


static func _unir_triangulo(padres: PackedInt32Array, a: int, b: int, c: int) -> void:
	if a >= 0 and b >= 0:
		_unir(padres, a, b)
	if b >= 0 and c >= 0:
		_unir(padres, b, c)
	if c >= 0 and a >= 0:
		_unir(padres, c, a)


static func _compactar_cajas(entrada: Array[Rect2]) -> Array[Rect2]:
	var cajas: Array[Rect2] = entrada.duplicate()
	var cambio := true
	while cambio and cajas.size() > 1:
		cambio = false
		for i: int in range(cajas.size()):
			for j: int in range(i + 1, cajas.size()):
				var a := cajas[i]
				var b := cajas[j]
				var unido := a.merge(b)
				if a.encloses(b) or b.encloses(a):
					cajas[i] = unido
					cajas.remove_at(j)
					cambio = true
					break
				if not a.intersects(b, true):
					continue
				var inter := a.intersection(b)
				var area_real := a.get_area() + b.get_area() - inter.get_area()
				if unido.get_area() <= area_real * (1.0 + TOLERANCIA_FUSION):
					cajas[i] = unido
					cajas.remove_at(j)
					cambio = true
					break
			if cambio:
				break
	return cajas


## Reparte en lotes de hasta `MAX_CAJAS` rectángulos cercanos para no fusionar islas separadas por
## pasillos cuando una sola malla agrupa varios cuerpos (como las góndolas).
static func _agrupar_lotes(cajas: Array[Rect2]) -> Array[Array]:
	if cajas.size() <= MAX_CAJAS:
		return [cajas]
	var ordenadas: Array[Rect2] = cajas.duplicate()
	ordenadas.sort_custom(
		func(a: Rect2, b: Rect2) -> bool:
			var ca := a.get_center()
			var cb := b.get_center()
			return ca.y < cb.y if not is_equal_approx(ca.y, cb.y) else ca.x < cb.x
	)
	var grupos: Array[Array] = []
	for inicio: int in range(0, ordenadas.size(), MAX_CAJAS):
		var sub: Array[Rect2] = []
		for k: int in range(inicio, mini(inicio + MAX_CAJAS, ordenadas.size())):
			sub.append(ordenadas[k])
		grupos.append(sub)
	return grupos


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
