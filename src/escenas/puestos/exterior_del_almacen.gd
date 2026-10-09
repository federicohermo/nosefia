@tool
extends Node3D

const FOTO := preload("res://assets/environments/estacion_panoramica_gemini.jpg")
const FONDO := preload("res://assets/environments/estacion_fondo_sin_objetos.png")
const MARQUESINA_SIN_LAMPARA := preload("res://assets/environments/canopy_without_lamp.png")
const PROYECCION := preload("res://src/escenas/puestos/exterior_fotografico.gdshader")
const PAVIMENTO := preload("res://src/escenas/puestos/pavimento_del_exterior.gdshader")
const VEREDA := preload("res://src/escenas/puestos/vereda_del_exterior.gdshader")
const ALTURA_DEL_UMBRAL := 0.10223747
const ALTURA_DEL_SUELO := ALTURA_DEL_UMBRAL - 0.12
const ORIGEN := Vector3(-1.4, 1.8, -1.3)
# El jugador está en el local: la isla cercana queda a unos cinco metros del ventanal.
const FOCAL := Vector2(0.20769, 0.42)
const HORIZONTE := 0.49
const BORDE_SUPERIOR_DEL_CIELO := -1.0
const ESTACION: Array[Vector2] = [
	Vector2(0.360, 0.393),
	Vector2(0.552, 0.260),
	Vector2(0.655, 0.369),
	Vector2(0.655, 0.384),
	Vector2(0.588, 0.394),
	Vector2(0.588, 0.467),
	Vector2(0.596, 0.471),
	Vector2(0.5964, 0.5973),
	Vector2(0.6103, 0.5950),
	Vector2(0.6103, 0.6064),
	Vector2(0.5836, 0.6162),
	Vector2(0.5136, 0.5990),
	Vector2(0.5136, 0.5896),
	Vector2(0.523, 0.588),
	Vector2(0.526, 0.554),
	Vector2(0.544, 0.554),
	Vector2(0.544, 0.581),
	Vector2(0.543, 0.478),
	Vector2(0.548, 0.464),
	Vector2(0.566, 0.463),
	Vector2(0.571, 0.466),
	Vector2(0.571, 0.399),
	Vector2(0.505, 0.414),
	Vector2(0.438, 0.418),
	Vector2(0.438, 0.483),
	Vector2(0.449, 0.485),
	Vector2(0.451, 0.537),
	Vector2(0.464, 0.536),
	Vector2(0.467, 0.552),
	Vector2(0.467, 0.565),
	Vector2(0.4741, 0.5630),
	Vector2(0.4741, 0.5699),
	Vector2(0.4311, 0.5747),
	Vector2(0.4045, 0.5697),
	Vector2(0.4045, 0.5617),
	Vector2(0.4105, 0.5617),
	Vector2(0.424, 0.560),
	Vector2(0.429, 0.486),
	Vector2(0.429, 0.419),
	Vector2(0.360, 0.409),
]


func _ready() -> void:
	if get_child_count() > 0:
		return
	var suelo := _material(PAVIMENTO, FONDO)
	# Las sombras se centran entre los apoyos reales, no sobre el plano vertical de la foto.
	suelo.set_shader_parameter(
		"surtidor_cercano", (_pie(Vector2(0.5136, 0.5990)) + _pie(Vector2(0.6103, 0.6064))) * 0.5
	)
	suelo.set_shader_parameter(
		"surtidor_lejano", (_pie(Vector2(0.4045, 0.5697)) + _pie(Vector2(0.4741, 0.5699))) * 0.5
	)
	suelo.set_shader_parameter(
		"auto_estacionado",
		(_pie(Vector2(0.32489, 0.55911)) + _pie(Vector2(0.35292, 0.55826))) * 0.5
	)
	for limites: Rect2 in [
		Rect2(-18, -24, 13.30, 39),
		Rect2(-4.70, -8.25, 2.22, 23.25),
		Rect2(-4.70, -24, 2.22, 8.40),
		Rect2(14.5, -24, 7.5, 39),
		Rect2(-2.48, 6.28, 16.98, 8.72),
		Rect2(-2.48, -24, 16.98, 7.5),
	]:
		var esquina := Vector3(limites.position.x, ALTURA_DEL_SUELO, limites.position.y)
		var pavimento := _malla(
			"Pavimento",
			PackedVector3Array(
				[
					esquina,
					esquina + Vector3(limites.size.x, 0, 0),
					esquina + Vector3(limites.size.x, 0, limites.size.y),
					esquina + Vector3(0, 0, limites.size.y),
				]
			),
			PackedInt32Array([0, 2, 1, 0, 3, 2]),
			suelo
		)
		pavimento.create_trimesh_collision()
		var cuerpo := pavimento.get_child(0) as StaticBody3D
		var forma := cuerpo.get_child(0) as CollisionShape3D
		# El dibujo usa ambas caras: el soporte conserva sus triángulos y recibe desde arriba.
		(forma.shape as ConcavePolygonShape3D).backface_collision = true
	var fondo := _material(PROYECCION, FONDO)
	_tarjeta(
		"Fondo",
		PackedVector2Array(
			[
				Vector2(0, BORDE_SUPERIOR_DEL_CIELO),
				Vector2(1, BORDE_SUPERIOR_DEL_CIELO),
				Vector2(1, 0.54),
				Vector2(0, 0.54),
			]
		),
		Vector2(0.3, 0.54),
		Vector2(0.7, 0.54),
		fondo
	)
	var foto := _material(PROYECCION)
	_tarjeta(
		"Estacion",
		PackedVector2Array(ESTACION),
		Vector2(0.449, 0.574),
		Vector2(0.567, 0.612),
		foto,
		PackedVector2Array(
			[
				Vector2(0.6103, 0.6064),
				Vector2(0.5836, 0.6162),
				Vector2(0.5136, 0.5990),
				Vector2(0.4741, 0.5699),
				Vector2(0.4311, 0.5747),
				Vector2(0.4045, 0.5697),
			]
		),
		PackedVector2Array(
			[
				Vector2(0.6103, 0.5950),
				Vector2(0.5136, 0.5896),
				Vector2(0.4741, 0.5630),
				Vector2(0.4045, 0.5617),
				Vector2(0.4105, 0.5617),
			]
		)
	)
	_tarjeta(
		"Auto",
		PackedVector2Array(
			[
				Vector2(0.30504, 0.53481),
				Vector2(0.31029, 0.52987),
				Vector2(0.31724, 0.52951),
				Vector2(0.32176, 0.51452),
				Vector2(0.33261, 0.51398),
				Vector2(0.33939, 0.51379),
				Vector2(0.35095, 0.51562),
				Vector2(0.35258, 0.52037),
				Vector2(0.35556, 0.52878),
				Vector2(0.35782, 0.52987),
				Vector2(0.36017, 0.53262),
				Vector2(0.36089, 0.53517),
				Vector2(0.36098, 0.54925),
				Vector2(0.35909, 0.55034),
				Vector2(0.35647, 0.55052),
				Vector2(0.35583, 0.55363),
				Vector2(0.35475, 0.55619),
				Vector2(0.35321, 0.55802),
				Vector2(0.35195, 0.55875),
				Vector2(0.35041, 0.55857),
				Vector2(0.34860, 0.55619),
				Vector2(0.34761, 0.55290),
				Vector2(0.34707, 0.55016),
				Vector2(0.34535, 0.55016),
				Vector2(0.34445, 0.55308),
				Vector2(0.34300, 0.55546),
				Vector2(0.34146, 0.55656),
				Vector2(0.33993, 0.55619),
				Vector2(0.33848, 0.55345),
				Vector2(0.33740, 0.55052),
				Vector2(0.33143, 0.55034),
				Vector2(0.33053, 0.55345),
				Vector2(0.32917, 0.55656),
				Vector2(0.32782, 0.55838),
				Vector2(0.32628, 0.55930),
				Vector2(0.32475, 0.55930),
				Vector2(0.32267, 0.55692),
				Vector2(0.32158, 0.55400),
				Vector2(0.32104, 0.55089),
				Vector2(0.31752, 0.55107),
				Vector2(0.31670, 0.55400),
				Vector2(0.31526, 0.55637),
				Vector2(0.31363, 0.55710),
				Vector2(0.31209, 0.55619),
				Vector2(0.31074, 0.55418),
				Vector2(0.30965, 0.55089),
				Vector2(0.30730, 0.55162),
				Vector2(0.30685, 0.54724),
				Vector2(0.30550, 0.54541),
			]
		),
		Vector2(0.3, 0.558),
		Vector2(0.36, 0.558),
		foto,
		PackedVector2Array(
			[
				Vector2(0.35195, 0.55875),
				Vector2(0.35041, 0.55857),
				Vector2(0.34146, 0.55656),
				Vector2(0.33993, 0.55619),
				Vector2(0.32628, 0.55930),
				Vector2(0.32475, 0.55930),
				Vector2(0.31526, 0.55637),
				Vector2(0.31363, 0.55710),
				Vector2(0.31209, 0.55619),
			]
		)
	)
	_tarjeta(
		"Poste",
		PackedVector2Array(
			[
				Vector2(0.151, 0.172),
				Vector2(0.164, 0.172),
				Vector2(0.166, 0.193),
				Vector2(0.206, 0.190),
				Vector2(0.207, 0.209),
				Vector2(0.165, 0.214),
				Vector2(0.165, 0.640),
				Vector2(0.149, 0.640),
			]
		),
		Vector2(0.15, 0.64),
		Vector2(0.20, 0.64),
		foto
	)

	_vereda()
	_borde_verde()
	_estacionamiento()
	_periferia(fondo)


func _material(shader: Shader, imagen: Texture2D = FOTO) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("fotografia", imagen)
	material.set_shader_parameter("origen", ORIGEN)
	material.set_shader_parameter("focal", FOCAL)
	material.set_shader_parameter("horizonte", HORIZONTE)
	if shader == PROYECCION:
		material.set_shader_parameter("fundir_apoyo", imagen == FOTO)
		material.set_shader_parameter("altura_del_suelo", ALTURA_DEL_SUELO)
		material.set_shader_parameter("fundir_cielo", imagen == FONDO)
		material.set_shader_parameter("fundir_suelo", imagen == FONDO)
		material.set_shader_parameter("fondo_continuo", imagen == FONDO)
		if imagen == FOTO:
			material.set_shader_parameter("quitar_lampara", true)
			material.set_shader_parameter("marquesina_sin_lampara", MARQUESINA_SIN_LAMPARA)
	return material


func _rayo(uv: Vector2) -> Vector3:
	return Vector3(-1, (HORIZONTE - uv.y) / FOCAL.y, -(uv.x - 0.5) / FOCAL.x)


func _pie(uv: Vector2) -> Vector3:
	var rayo := _rayo(uv)
	return ORIGEN + rayo * ((ALTURA_DEL_SUELO - ORIGEN.y) / rayo.y)


func _tarjeta(
	nombre: String,
	contorno: PackedVector2Array,
	pie_a: Vector2,
	pie_b: Vector2,
	material: ShaderMaterial,
	apoyos: PackedVector2Array = PackedVector2Array(),
	bordes_elevados: PackedVector2Array = PackedVector2Array()
) -> void:
	# Los pies definen el plano. Cambiar el jugador no cambia la cámara de la fotografía.
	var a := _pie(pie_a)
	var b := _pie(pie_b)
	var normal := (b - a).cross(Vector3.UP).normalized()
	var puntos := PackedVector3Array()
	for uv: Vector2 in contorno:
		var rayo := _rayo(uv)
		var punto := ORIGEN + rayo * ((a - ORIGEN).dot(normal) / rayo.dot(normal))
		var altura := maxf(punto.y, ALTURA_DEL_SUELO)
		if apoyos.has(uv):
			altura = ALTURA_DEL_SUELO
		elif bordes_elevados.has(uv):
			altura = ALTURA_DEL_SUELO + 0.17
		if altura != punto.y:
			# Desplazar sobre el rayo conserva la silueta; cambiar sólo Y aplastaba el recorte.
			punto = ORIGEN + rayo * ((altura - ORIGEN.y) / rayo.y)
		puntos.append(punto)
	_malla(nombre, puntos, Geometry2D.triangulate_polygon(contorno), material)


func _malla(
	nombre: String, puntos: PackedVector3Array, indices: PackedInt32Array, material: ShaderMaterial
) -> MeshInstance3D:
	var datos: Array = []
	datos.resize(Mesh.ARRAY_MAX)
	datos[Mesh.ARRAY_VERTEX] = puntos
	datos[Mesh.ARRAY_INDEX] = indices
	var malla := ArrayMesh.new()
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, datos)
	var instancia := MeshInstance3D.new()
	instancia.name = nombre
	instancia.mesh = malla
	instancia.material_override = material
	instancia.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	instancia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instancia, true)
	return instancia


func _periferia(material: ShaderMaterial) -> void:
	# Todas las paredes comparten la proyección mundial; sus encuentros no cortan el fondo.
	var izquierda := _pie(Vector2(0, 0.54))
	var derecha := _pie(Vector2(1, 0.54))
	izquierda.z = 14.0
	derecha.z = -24.0
	# Los encuentros superiores quedan por encima de las nubes, en el cielo ya uniforme.
	var altura := (
		ALTURA_DEL_SUELO
		+ (ORIGEN.y - ALTURA_DEL_SUELO) * (0.54 - BORDE_SUPERIOR_DEL_CIELO) / (0.54 - HORIZONTE)
	)
	var planos: Array[PackedVector3Array] = [
		PackedVector3Array(
			[
				izquierda,
				Vector3(22, ALTURA_DEL_SUELO, izquierda.z),
				Vector3(22, altura, izquierda.z),
				Vector3(izquierda.x, altura, izquierda.z),
			]
		),
		PackedVector3Array(
			[
				Vector3(22, ALTURA_DEL_SUELO, derecha.z),
				derecha,
				Vector3(derecha.x, altura, derecha.z),
				Vector3(22, altura, derecha.z),
			]
		),
		PackedVector3Array(
			[
				Vector3(22, ALTURA_DEL_SUELO, izquierda.z),
				Vector3(22, ALTURA_DEL_SUELO, derecha.z),
				Vector3(22, altura, derecha.z),
				Vector3(22, altura, izquierda.z),
			]
		),
		# Cerrar arriba con la misma proyección evita ver el límite al mirar por el ventanal.
		PackedVector3Array(
			[
				Vector3(izquierda.x, altura, izquierda.z),
				Vector3(22, altura, izquierda.z),
				Vector3(22, altura, derecha.z),
				Vector3(derecha.x, altura, derecha.z),
			]
		),
	]
	for puntos: PackedVector3Array in planos:
		_malla("Periferia", puntos, PackedInt32Array([0, 1, 2, 0, 2, 3]), material)


func _vereda() -> void:
	var material := _material(VEREDA)
	material.set_shader_parameter("altura_superior", ALTURA_DEL_UMBRAL)
	for limites: Rect2 in [
		Rect2(-3.40, -8.25, 0.92, 15.45),
		Rect2(-5.62, -16.50, 0.92, 8.25),
		Rect2(-5.62, -8.25, 2.22, 0.92),
		Rect2(-2.48, 6.28, 16.98, 0.92),
		Rect2(14.5, -17.40, 0.90, 24.60),
		Rect2(-2.48, -17.40, 16.98, 0.90),
	]:
		_bloque("Vereda", limites, ALTURA_DEL_UMBRAL, material)


func _borde_verde() -> void:
	var material := _material(VEREDA)
	material.set_shader_parameter("es_vegetacion", true)
	material.set_shader_parameter("altura_superior", ALTURA_DEL_SUELO + 0.06)
	for limites: Rect2 in [
		Rect2(-17, 13, 39, 1),
		Rect2(-17, -24, 39, 1),
		Rect2(21, -23, 1, 36),
	]:
		_bloque("BordeVerde", limites, ALTURA_DEL_SUELO + 0.06, material)


func _bloque(nombre: String, limites: Rect2, altura: float, material: ShaderMaterial) -> void:
	var esquina := Vector3(limites.position.x, altura, limites.position.y)
	var puntos := PackedVector3Array(
		[
			esquina,
			esquina + Vector3(limites.size.x, 0, 0),
			esquina + Vector3(limites.size.x, 0, limites.size.y),
			esquina + Vector3(0, 0, limites.size.y),
		]
	)
	for i: int in 4:
		puntos.append(Vector3(puntos[i].x, ALTURA_DEL_SUELO, puntos[i].z))
	# La cara vertical del cordón hace visible el desnivel; la vereda sigue al nivel del local.
	_malla(
		nombre,
		puntos,
		PackedInt32Array(
			[
				0,
				2,
				1,
				0,
				3,
				2,
				0,
				1,
				5,
				0,
				5,
				4,
				1,
				2,
				6,
				1,
				6,
				5,
				2,
				3,
				7,
				2,
				7,
				6,
				3,
				0,
				4,
				3,
				4,
				7,
			]
		),
		material
	)


func _estacionamiento() -> void:
	var material := _material(VEREDA)
	material.set_shader_parameter("es_pintura", true)
	for inicio: float in [-0.5, 10.0]:
		for limites: Rect2 in [
			Rect2(inicio, 8.3, 0.06, 3.8),
			Rect2(inicio + 2.8, 8.3, 0.06, 3.8),
			Rect2(inicio, 8.3, 2.86, 0.06),
		]:
			_bloque("MarcaDeEstacionamiento", limites, ALTURA_DEL_SUELO + 0.002, material)
