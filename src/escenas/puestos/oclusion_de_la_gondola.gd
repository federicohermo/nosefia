## La oclusión de contacto de los productos acomodados en la góndola, sin costo por unidad.
##
## Dos partes, cada una se prende y se apaga en vivo:
##
## 1. **Base oscurecida (`base_activa`).** Escribe la base local de cada producto en los materiales
##    del lote (`producto_de_la_gondola.gdshader`). Sin rayos ni dibujos extra.
## 2. **Mancha debajo de cada unidad (`manchas_activas`).** Un `MultiMeshInstance3D` compartido
##    con `sombra_de_contacto.gdshader`, el recorte de su estante en `INSTANCE_CUSTOM`, `esquinas`
##    en `COLOR.r` y el tamaño de cada producto en `MODEL_MATRIX`. Sigue la inclinación real del
##    estante —también en una rampa— y se sincroniza cuando se saca o repone una unidad.
##
## Reusa la banda de apoyo y el shader de `oclusion_de_contacto.gd` para conservar la forma de la
## mancha de las unidades sueltas, con su propio alcance e intensidad por defecto para envases
## chicos apoyados en fila.
extends Node3D

const OclusionDeContacto := preload("res://src/escenas/objetos/oclusion_de_contacto.gd")

## Grupo desde el cual se prende o apaga cada parte en vivo.
const GRUPO := &"oclusion_de_la_gondola"
## Valores por defecto de la góndola, compartidos con las unidades de producto sueltas.
const RADIO_POR_DEFECTO := OclusionDeContacto.RADIO_DEL_PRODUCTO
const INTENSIDAD_POR_DEFECTO := OclusionDeContacto.INTENSIDAD_DEL_PRODUCTO
## Flotantes por copia en un `MultiMesh` 3D con `use_colors` y `use_custom_data`: 12 de la pose,
## 4 del color (`esquinas`, 0, 0, 1) y 4 del recorte.
const FLOTANTES_POR_MANCHA := 20
## Prioridad menor que el vidrio (0) y que el pre-pase del foco (-1): la mancha nunca se dibuja
## delante de las puertas de las heladeras.
const PRIORIDAD_DE_LA_MANCHA := -2
## Pasos de bisección para encontrar el canto de un estante cuando la mancha lo desborda.
const PASOS_DEL_BORDE := 6
## Altura sobre el estante para detectar un panel trasero o divisor que corta la mancha.
const ALTURA_DEL_OBSTACULO := 0.015
## Diferencia máxima de altura sobre el plano del estante para seguir contando como el mismo apoyo.
const TOLERANCIA_DEL_PLANO := 0.015
## Coseno mínimo entre dos normales para seguir contando como la misma superficie.
const MISMA_NORMAL := 0.95
## Hasta qué alcance de radio se mide el borde del estante al armar la disposición.
const ALCANCE_MINIMO_DE_RECORTE := 0.15

## Prende o apaga el oscurecimiento en la base de los productos, sin tocar las manchas.
@export var base_activa := true:
	set(valor):
		base_activa = valor
		_aplicar_base_a_todos()

## Prende o apaga las manchas debajo de los productos, sin tocar el oscurecimiento de la base.
@export var manchas_activas := true:
	set(valor):
		manchas_activas = valor
		_aplicar_visibilidad_del_lote()

## Alcance compartido de las dos partes, en metros.
@export var radio := RADIO_POR_DEFECTO:
	set(valor):
		radio = maxf(valor, 0.001)
		_aplicar_base_a_todos()
		_actualizar_tamano_de_manchas()

## Intensidad compartida de las dos partes, de 0 a 1.
@export_range(0.0, 1.0) var intensidad := INTENSIDAD_POR_DEFECTO:
	set(valor):
		intensidad = clampf(valor, 0.0, 1.0)
		_aplicar_base_a_todos()
		_aplicar_material_del_lote()
		_aplicar_visibilidad_del_lote()

var _bloques: Dictionary[int, Dictionary] = {}
var _lote: MultiMeshInstance3D
var _total_visibles := 0


func _ready() -> void:
	add_to_group(GRUPO)


## Borra todos los bloques de manchas armados para la disposición anterior.
func limpiar() -> void:
	if is_instance_valid(_lote):
		if _lote.get_parent() == self:
			remove_child(_lote)
		_lote.queue_free()
	_lote = null
	_total_visibles = 0
	_bloques.clear()


## Arma la base oscurecida y agrega las manchas de un producto al lote compartido.
func preparar_bloque(
	id: int,
	_nombre: String,
	malla_del_modelo: Mesh,
	materiales_del_bloque: Array[ShaderMaterial],
	derecho: Basis,
	bloque: PackedFloat32Array
) -> void:
	var apoyo := _medir_apoyo_local(malla_del_modelo, derecho)
	var copias := DisposicionDeLaGondola.copias(bloque)
	var poses: Array[Transform3D] = []
	var recortes: Array[Color] = []
	var inversa := global_transform.affine_inverse() if is_inside_tree() else Transform3D.IDENTITY
	var espacio := get_world_3d().direct_space_state if is_inside_tree() else null
	var consulta := PhysicsRayQueryParameters3D.new()
	consulta.collision_mask = _mascara_del_estante()
	var alcance_recorte := maxf(radio, ALCANCE_MINIMO_DE_RECORTE)
	for indice in copias:
		var copia := DisposicionDeLaGondola.copia(bloque, indice)
		var medido := _pose_y_recorte(copia, apoyo, inversa, espacio, consulta, alcance_recorte)
		poses.append(medido[0] as Transform3D)
		recortes.append(medido[1] as Color)
	_asegurar_lote()
	var datos := {
		"materiales": materiales_del_bloque.duplicate(),
		"eje": apoyo["eje"] as Vector3,
		"base": apoyo["base"] as float,
		"huella": apoyo["huella"] as Vector2,
		"esquinas": apoyo["esquinas"] as float,
		"poses": poses,
		"recortes": recortes,
		"buffer_completo": PackedFloat32Array(),
		"buffer_visible": PackedFloat32Array(),
		"orden": [],
		"ocupados": 0,
		"inicio": 0,
	}
	_bloques[id] = datos
	_rearmar_buffer(datos)
	_aplicar_base(datos)
	_aplicar_material_del_lote()
	if copias > 0:
		var orden_inicial: Array[int] = []
		for indice in copias:
			orden_inicial.append(indice)
		sincronizar(id, orden_inicial, copias)
	else:
		_subir_lote()


## Suma materiales de otra malla del mismo producto (por ejemplo `VencidosDeCindolor`) para que
## compartan el oscurecimiento de base y sus cambios en vivo.
func agregar_materiales(id: int, malla: Mesh) -> void:
	if not _bloques.has(id) or malla == null:
		return
	var datos: Dictionary = _bloques[id]
	var materiales: Array = datos["materiales"]
	for superficie in malla.get_surface_count():
		var material := malla.surface_get_material(superficie) as ShaderMaterial
		if material != null and not materiales.has(material):
			materiales.append(material)
	_aplicar_base(datos)


## Reordena las manchas del bloque en el mismo orden que `ReposicionManual._mostrar_lo_puesto`:
## los `cantidad_ocupados` primeros lugares (sanos y vencidos) quedan visibles; los huecos, fuera.
func sincronizar(id: int, orden: Array, cantidad_ocupados: int) -> void:
	if not _bloques.has(id):
		return
	var datos: Dictionary = _bloques[id]
	datos["orden"] = orden.duplicate()
	datos["ocupados"] = cantidad_ocupados
	var completo: PackedFloat32Array = datos["buffer_completo"]
	var visibles := PackedFloat32Array()
	if not completo.is_empty() and cantidad_ocupados > 0:
		var contar := mini(cantidad_ocupados, orden.size())
		visibles.resize(contar * FLOTANTES_POR_MANCHA)
		var destino := 0
		for indice in contar:
			var puesto: int = orden[indice]
			var desde := puesto * FLOTANTES_POR_MANCHA
			for paso in FLOTANTES_POR_MANCHA:
				visibles[destino + paso] = completo[desde + paso]
			destino += FLOTANTES_POR_MANCHA
	datos["buffer_visible"] = visibles
	_subir_lote()


## El `MultiMeshInstance3D` compartido que dibuja las manchas, o `null` si el bloque no existe.
func sombras_de(id: int) -> MultiMeshInstance3D:
	if not _bloques.has(id):
		return null
	return _lote


## `(inicio, cantidad)` de las instancias visibles de un producto dentro del lote compartido.
func rango_de(id: int) -> Vector2i:
	if not _bloques.has(id):
		return Vector2i.ZERO
	var datos: Dictionary = _bloques[id]
	return Vector2i(datos["inicio"] as int, datos["ocupados"] as int)


func huella_de(id: int) -> Vector2:
	if not _bloques.has(id):
		return Vector2.ZERO
	return _bloques[id]["huella"] as Vector2


func esquinas_de(id: int) -> float:
	if not _bloques.has(id):
		return 0.0
	return _bloques[id]["esquinas"] as float


func _asegurar_lote() -> void:
	if is_instance_valid(_lote):
		return
	var lote := MultiMeshInstance3D.new()
	lote.name = "SombrasDeLaGondola"
	lote.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	lote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lote.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	lote.add_to_group(ReglasDeLosObjetos.GRUPO_SIN_CONTORNO)
	var material := ShaderMaterial.new()
	material.shader = OclusionDeContacto.SOMBRA
	material.render_priority = PRIORIDAD_DE_LA_MANCHA
	material.set_shader_parameter(&"parametros_por_instancia", true)
	material.set_shader_parameter(&"recorte_por_instancia", true)
	lote.material_override = material
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = OclusionDeContacto.plano()
	mm.instance_count = 0
	mm.visible_instance_count = 0
	lote.multimesh = mm
	lote.visible = false
	add_child(lote)
	_lote = lote


func _subir_lote() -> void:
	if not is_instance_valid(_lote):
		return
	var capacidad := 0
	var visibles := 0
	for datos: Dictionary in _bloques.values():
		capacidad += (datos["poses"] as Array).size()
		datos["inicio"] = visibles
		visibles += (datos["buffer_visible"] as PackedFloat32Array).size() / FLOTANTES_POR_MANCHA
	_total_visibles = visibles
	var mm := _lote.multimesh
	if capacidad == 0:
		mm.instance_count = 0
		mm.visible_instance_count = 0
		_aplicar_visibilidad_del_lote()
		return
	if mm.instance_count != capacidad:
		mm.instance_count = capacidad
	var salida := PackedFloat32Array()
	salida.resize(capacidad * FLOTANTES_POR_MANCHA)
	var destino := 0
	for datos: Dictionary in _bloques.values():
		var bloque_visible: PackedFloat32Array = datos["buffer_visible"]
		for indice in bloque_visible.size():
			salida[destino + indice] = bloque_visible[indice]
		destino += bloque_visible.size()
	mm.buffer = salida
	mm.visible_instance_count = visibles
	_aplicar_visibilidad_del_lote()


func _rearmar_buffer(datos: Dictionary) -> void:
	var huella: Vector2 = datos["huella"]
	var esquinas: float = datos["esquinas"]
	var tamano := huella * 2.0 + Vector2.ONE * (radio * 2.0)
	var poses: Array = datos["poses"]
	var recortes: Array = datos["recortes"]
	var salida := PackedFloat32Array()
	salida.resize(poses.size() * FLOTANTES_POR_MANCHA)
	var destino := 0
	for indice in poses.size():
		var base_pose: Transform3D = poses[indice]
		var escalada := Transform3D(
			base_pose.basis.scaled_local(Vector3(tamano.x, 1.0, tamano.y)), base_pose.origin
		)
		var b := escalada.basis
		var o := escalada.origin
		var recorte: Color = recortes[indice]
		salida[destino + 0] = b.x.x
		salida[destino + 1] = b.y.x
		salida[destino + 2] = b.z.x
		salida[destino + 3] = o.x
		salida[destino + 4] = b.x.y
		salida[destino + 5] = b.y.y
		salida[destino + 6] = b.z.y
		salida[destino + 7] = o.y
		salida[destino + 8] = b.x.z
		salida[destino + 9] = b.y.z
		salida[destino + 10] = b.z.z
		salida[destino + 11] = o.z
		salida[destino + 12] = esquinas
		salida[destino + 13] = 0.0
		salida[destino + 14] = 0.0
		salida[destino + 15] = 1.0
		salida[destino + 16] = recorte.r
		salida[destino + 17] = recorte.g
		salida[destino + 18] = recorte.b
		salida[destino + 19] = recorte.a
		destino += FLOTANTES_POR_MANCHA
	datos["buffer_completo"] = salida


func _aplicar_base_a_todos() -> void:
	for datos: Dictionary in _bloques.values():
		_aplicar_base(datos)


func _aplicar_base(datos: Dictionary) -> void:
	var valor := intensidad if base_activa else 0.0
	var eje: Vector3 = datos["eje"]
	var base: float = datos["base"]
	for material: ShaderMaterial in datos["materiales"]:
		material.set_shader_parameter(OclusionDeContacto.LOCAL_DE_LA_MALLA, true)
		material.set_shader_parameter(OclusionDeContacto.EJE_DE_LA_MALLA, eje)
		material.set_shader_parameter(OclusionDeContacto.SUELO_DE_LA_MALLA, base)
		material.set_shader_parameter(OclusionDeContacto.ALCANCE_DE_LA_MALLA, radio)
		material.set_shader_parameter(OclusionDeContacto.PARAMETRO_DE_LA_MALLA, valor)


func _aplicar_material_del_lote() -> void:
	if not is_instance_valid(_lote):
		return
	var material := _lote.material_override as ShaderMaterial
	material.set_shader_parameter(&"suavidad", radio)
	material.set_shader_parameter(&"intensidad", intensidad * OclusionDeContacto.OPACIDAD_MAXIMA)


func _actualizar_tamano_de_manchas() -> void:
	_aplicar_material_del_lote()
	for id: int in _bloques:
		var datos: Dictionary = _bloques[id]
		_rearmar_buffer(datos)
		var orden: Array = datos["orden"]
		var ocupados: int = datos["ocupados"]
		var completo: PackedFloat32Array = datos["buffer_completo"]
		var visibles := PackedFloat32Array()
		if not completo.is_empty() and ocupados > 0:
			var contar := mini(ocupados, orden.size())
			visibles.resize(contar * FLOTANTES_POR_MANCHA)
			var destino := 0
			for indice in contar:
				var puesto: int = orden[indice]
				var desde := puesto * FLOTANTES_POR_MANCHA
				for paso in FLOTANTES_POR_MANCHA:
					visibles[destino + paso] = completo[desde + paso]
				destino += FLOTANTES_POR_MANCHA
		datos["buffer_visible"] = visibles
	_subir_lote()


func _aplicar_visibilidad_del_lote() -> void:
	if not is_instance_valid(_lote):
		return
	_lote.visible = manchas_activas and intensidad > 0.0 and _total_visibles > 0


## Mide la huella de apoyo de una malla en su espacio local usando la misma banda de apoyo que
## `OclusionDeContacto`: los vértices a menos de `BANDA_DE_APOYO` de su base.
static func _medir_apoyo_local(malla: Mesh, derecho: Basis) -> Dictionary:
	var eje := (derecho.inverse() * Vector3.UP).normalized()
	var x_local := Vector3.RIGHT - eje * eje.dot(Vector3.RIGHT)
	if x_local.length_squared() < 0.0001:
		x_local = Vector3.BACK - eje * eje.dot(Vector3.BACK)
	x_local = x_local.normalized()
	var z_local := x_local.cross(eje).normalized()
	var vertices := OclusionDeContacto.vertices_de(malla)
	var base := INF
	for vertice: Vector3 in vertices:
		base = minf(base, vertice.dot(eje))
	var puntos := PackedVector2Array()
	for vertice: Vector3 in vertices:
		if vertice.dot(eje) <= base + OclusionDeContacto.BANDA_DE_APOYO:
			puntos.append(Vector2(vertice.dot(x_local), vertice.dot(z_local)))
	if not is_finite(base) or puntos.is_empty():
		return {
			"eje": eje,
			"x": x_local,
			"z": z_local,
			"base": 0.0,
			"huella": Vector2.ZERO,
			"esquinas": 0.0,
			"centro_base": Vector3.ZERO,
		}
	var medida := OclusionDeContacto.medir_huella_2d(puntos)
	var centro_xz: Vector2 = medida[0]
	return {
		"eje": eje,
		"x": x_local,
		"z": z_local,
		"base": base,
		"huella": medida[1] as Vector2,
		"esquinas": medida[2] as float,
		"centro_base": x_local * centro_xz.x + eje * base + z_local * centro_xz.y,
	}


## Pose sin escalar (en espacio local de este nodo) y recorte sobre el estante de una copia.
func _pose_y_recorte(
	copia: Transform3D,
	apoyo: Dictionary,
	inversa: Transform3D,
	espacio: PhysicsDirectSpaceState3D,
	consulta: PhysicsRayQueryParameters3D,
	alcance_recorte: float
) -> Array:
	var copia_mundo := (global_transform * copia) if is_inside_tree() else copia
	var eje: Vector3 = apoyo["eje"]
	var x_local: Vector3 = apoyo["x"]
	var z_local: Vector3 = apoyo["z"]
	var huella: Vector2 = apoyo["huella"]
	var pie_mundo := copia_mundo * (apoyo["centro_base"] as Vector3)
	var arriba := (copia_mundo.basis * eje).normalized()
	var costado_copia := (copia_mundo.basis * x_local).normalized()
	var normal := arriba
	var punto := pie_mundo
	var con_estante := false
	if espacio != null:
		var golpe := _rayo_al_estante(espacio, consulta, pie_mundo, arriba)
		if (
			not golpe.is_empty()
			and (golpe["normal"] as Vector3).y >= OclusionDeContacto.NORMAL_MINIMA
		):
			normal = (golpe["normal"] as Vector3).normalized()
			punto = golpe["position"] as Vector3
			con_estante = true
	var costado := costado_copia - normal * normal.dot(costado_copia)
	if costado.length_squared() < 0.0001:
		var frente_copia := (copia_mundo.basis * z_local).normalized()
		costado = frente_copia - normal * normal.dot(frente_copia)
	costado = costado.normalized()
	var giro := Basis(costado, normal, costado.cross(normal))
	var pose := inversa * Transform3D(giro, punto + normal * OclusionDeContacto.ELEVACION)
	var abierto := OclusionDeContacto.LIMITE_ABIERTO
	var recorte := Color(-abierto, -abierto, abierto, abierto)
	if con_estante and espacio != null:
		var max_x := huella.x + alcance_recorte
		var max_z := huella.y + alcance_recorte
		recorte = Color(
			-_borde_del_estante(espacio, consulta, punto, normal, -giro.x, max_x),
			-_borde_del_estante(espacio, consulta, punto, normal, -giro.z, max_z),
			_borde_del_estante(espacio, consulta, punto, normal, giro.x, max_x),
			_borde_del_estante(espacio, consulta, punto, normal, giro.z, max_z)
		)
	return [pose, recorte]


static func _mascara_del_estante() -> int:
	return ReglasDeLosObjetos.MASCARA_DEL_PRODUCTO & ~ReglasDeLosObjetos.CAPA_DEL_HUECO


static func _rayo_al_estante(
	espacio: PhysicsDirectSpaceState3D,
	consulta: PhysicsRayQueryParameters3D,
	pie: Vector3,
	arriba: Vector3
) -> Dictionary:
	consulta.from = pie + arriba * OclusionDeContacto.SALIDA
	consulta.to = pie - arriba * (OclusionDeContacto.SALIDA + RADIO_POR_DEFECTO)
	return espacio.intersect_ray(consulta)


static func _hay_estante(
	espacio: PhysicsDirectSpaceState3D,
	consulta: PhysicsRayQueryParameters3D,
	base: Vector3,
	normal: Vector3,
	prueba: Vector3
) -> bool:
	consulta.from = prueba + normal * OclusionDeContacto.SALIDA
	consulta.to = prueba - normal * OclusionDeContacto.SALIDA
	var golpe := espacio.intersect_ray(consulta)
	if golpe.is_empty():
		return false
	var desnivel := absf(((golpe["position"] as Vector3) - base).dot(normal))
	return (
		desnivel <= TOLERANCIA_DEL_PLANO
		and (golpe["normal"] as Vector3).dot(normal) >= MISMA_NORMAL
	)


static func _borde_del_estante(
	espacio: PhysicsDirectSpaceState3D,
	consulta: PhysicsRayQueryParameters3D,
	base: Vector3,
	normal: Vector3,
	direccion: Vector3,
	hasta: float
) -> float:
	var tope := hasta
	var cortado := false
	var sobre := base + normal * ALTURA_DEL_OBSTACULO
	consulta.from = sobre
	consulta.to = sobre + direccion * hasta
	var pared := espacio.intersect_ray(consulta)
	if not pared.is_empty():
		var distancia := ((pared["position"] as Vector3) - sobre).dot(direccion)
		if distancia < tope:
			tope = maxf(distancia, 0.0)
			cortado = true
			if tope <= 0.0:
				return 0.0
	if _hay_estante(espacio, consulta, base, normal, base + direccion * tope):
		return tope if cortado else OclusionDeContacto.LIMITE_ABIERTO
	var cerca := 0.0
	var lejos := tope
	for _paso in PASOS_DEL_BORDE:
		var medio := (cerca + lejos) / 2.0
		if _hay_estante(espacio, consulta, base, normal, base + direccion * medio):
			cerca = medio
		else:
			lejos = medio
	return cerca
