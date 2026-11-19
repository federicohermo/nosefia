## La oclusión de contacto de un objeto que se levanta, toda dinámica: nada va horneado en el
## objeto, así que al levantarlo el efecto se va solo.
##
## Cuelga del objeto y lanza un rayo hacia abajo desde su base. Con lo que encuentra hace las dos
## partes:
##
## 1. **El objeto oscurece lo de abajo.** Una mancha difusa sobre esa superficie, que se abre
##    `radio` desde lo que del objeto toca la superficie: los vértices de sus mallas más bajos, y
##    no la caja que envuelve su forma, que en un balde es la boca. Se apaga con `activa`.
## 2. **Lo de abajo oscurece al objeto.** Escribe en los materiales de sus mallas la altura de esa
##    superficie, y el shader oscurece sus caras de abajo. Sólo lo hace donde el material es un
##    `ShaderMaterial` que declara los uniformes de `oclusion_de_contacto.gdshaderinc`: un material
##    estándar se saltea, y la mancha de abajo sigue. Se apaga con `intensidad`, de 0 a 1.
##
## **Todo va en uniformes del material, nunca por instancia:** en la web, con el renderizador
## Compatibility, el shader los recibe en cero. Por eso cada objeto lleva sus propios materiales.
##
## **El rayo corre mientras el objeto se mueve y una vez al quedar quieto.** Uno quieto no tira
## ninguno: se entera por el aviso de que cambió su transformación.
extends Node3D

## Cada objeto con el efecto está en este grupo. Quien lo maneja desde afuera busca por acá.
const GRUPO := &"oclusion_de_contacto"
const PARAMETRO_DE_LA_MALLA := &"oclusion_de_contacto"
const SUELO_DE_LA_MALLA := &"suelo_de_contacto"
const ALCANCE_DE_LA_MALLA := &"alcance_de_contacto"
const SOMBRA := preload("res://src/escenas/objetos/sombra_de_contacto.gdshader")

## Los valores con que arrancan las dos propiedades de abajo.
const RADIO_POR_DEFECTO := 0.05
const INTENSIDAD_POR_DEFECTO := 0.25
## Qué tan negra queda la mancha con `intensidad` en 1, de 0 a 1.
const OPACIDAD_MAXIMA := 0.5
## Cuánto más se difumina el borde de la mancha por cada metro de altura.
const DIFUMINADO_POR_ALTURA := 0.5
## Sobre la superficie, para que la mancha no pelee con ella por la profundidad.
const ELEVACION := 0.003
## El rayo sale un poco sobre la base: desde adentro de lo que lo sostiene no lo vería.
const SALIDA := 0.03
## Cuánto sobre el punto más bajo de la malla se cuenta como apoyo, en metros.
const BANDA_DE_APOYO := 0.01
## Cuánto puede diferir hacia dónde queda abajo, visto desde el cuerpo, para seguir contando como el
## mismo: con una malla de medio metro, menos que la banda de apoyo.
const ABAJO_IGUAL := 0.01
## Cuánto puede diferir la pose de una malla respecto de su cuerpo para seguir contando como la
## misma, en metros.
const POSE_IGUAL := 0.001
## Una superficie más empinada que esto no sostiene nada: es una pared.
const NORMAL_MINIMA := 0.6
## La altura que se le escribe a la malla cuando no hay nada abajo.
const SIN_SUELO := -1000.0
## Hasta dónde llega el apoyo en un eje donde no hay borde que cortar, en metros.
const LIMITE_ABIERTO := 1000.0

static var _plano_de_la_sombra: ArrayMesh
static var _vertices_de_las_mallas: Dictionary[Mesh, PackedVector3Array] = {}

## Se apaga y se prende en vivo. Apaga la mancha, y no el oscurecimiento del objeto.
@export var activa := true:
	set(valor):
		activa = valor
		_mostrar()

## Hasta qué altura sobre la superficie de abajo hay efecto, en metros: el de la base del objeto y
## el de la mancha: ésta se abre hacia afuera de la huella la misma distancia que el objeto se
## oscurece hacia arriba. Es también hasta dónde mira el rayo y a qué altura se apaga la mancha.
## Cambiarlo deja todo al día en el momento.
@export var radio := RADIO_POR_DEFECTO:
	set(valor):
		radio = valor
		_al_dia()

## Cuánto se oscurecen el objeto y la mancha, de 0 a 1, con la misma escala: en 1, cada uno llega a
## su máximo. Se apaga y se prende en vivo, y cambiarla deja todo al día en el momento.
@export_range(0.0, 1.0) var intensidad := INTENSIDAD_POR_DEFECTO:
	set(valor):
		intensidad = valor
		_al_dia()

## Las mallas del objeto: en sus materiales se escribe la altura de lo que tiene debajo.
var mallas: Array[MeshInstance3D] = []

## La mancha, sólo si hay una superficie a menos de `radio`.
var sombra: MeshInstance3D

## Cuántos rayos lanzó. Lo mira el test de que un objeto quieto no los repite.
var rayos := 0

var _esquinas := 0.0
var _apoyos: Dictionary[MeshInstance3D, Array] = {}
var _hay_sombra := false
var _suelo := SIN_SUELO
var _movido := true
var _asentado := false


## De las mallas del objeto salen su huella y su base. `esquinas` va de 0 (una caja) a 1 (un balde).
func configurar(mallas_del_objeto: Array[MeshInstance3D], esquinas: float) -> void:
	mallas = mallas_del_objeto
	_esquinas = esquinas


func _ready() -> void:
	add_to_group(GRUPO)
	sombra = MeshInstance3D.new()
	sombra.top_level = true
	sombra.mesh = _plano()
	sombra.material_override = _material()
	sombra.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sombra.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	sombra.visible = false
	sombra.add_to_group(ReglasDeLosObjetos.GRUPO_SIN_CONTORNO)
	add_child(sombra)
	_escribir_en_la_malla()
	set_notify_transform(true)
	set_physics_process(true)


func _notification(que: int) -> void:
	if que == NOTIFICATION_TRANSFORM_CHANGED:
		_movido = true
		set_physics_process(true)


## El rayo se lanza acá porque el espacio físico sólo se consulta en el paso de la física.
##
## Cuando deja de haber aviso se lanza uno más, que es el de cuando quedó quieto, y se duerme
## hasta el próximo aviso.
func _physics_process(_delta: float) -> void:
	if _movido:
		_movido = false
		_asentado = true
	elif _asentado:
		_asentado = false
	else:
		set_physics_process(false)
		return
	actualizar()


## Lanza el rayo y deja las dos partes como corresponde a lo que encontró.
func actualizar() -> void:
	rayos += 1
	var cuerpo := get_parent() as CollisionObject3D
	var apoyo := cuerpo.global_transform * _apoyo_del_objeto(cuerpo)
	if apoyo.is_empty():
		_hay_sombra = false
		_mostrar()
		return
	var minimo := Vector3.INF
	var maximo := -Vector3.INF
	for punto: Vector3 in apoyo:
		minimo = minimo.min(punto)
		maximo = maximo.max(punto)
	var centro := (minimo + maximo) / 2.0
	var origen := Vector3(centro.x, minimo.y + SALIDA, centro.z)
	var consulta := PhysicsRayQueryParameters3D.create(
		origen,
		origen + Vector3.DOWN * (SALIDA + radio),
		ReglasDeLosObjetos.MASCARA_DEL_PRODUCTO & ~ReglasDeLosObjetos.CAPA_DEL_HUECO
	)
	consulta.exclude = [cuerpo.get_rid()]
	var golpe := cuerpo.get_world_3d().direct_space_state.intersect_ray(consulta)
	if golpe.is_empty() or (golpe["normal"] as Vector3).y < NORMAL_MINIMA:
		_hay_sombra = false
		_suelo = SIN_SUELO
		_escribir_en_la_malla()
		_mostrar()
		return
	var punto: Vector3 = golpe["position"]
	_suelo = punto.y
	_escribir_en_la_malla()
	_poner_la_sombra(cuerpo, golpe, maxf(minimo.y - punto.y, 0.0), apoyo)


## Qué tan oscura queda la mancha a esa altura de la superficie, de 0 a `OPACIDAD_MAXIMA`.
func intensidad_a(altura: float) -> float:
	return intensidad * OPACIDAD_MAXIMA * (1.0 - smoothstep(0.0, radio, altura))


func _poner_la_sombra(
	cuerpo: CollisionObject3D, golpe: Dictionary, altura: float, apoyo: PackedVector3Array
) -> void:
	var intensidad := intensidad_a(altura)
	_hay_sombra = intensidad > 0.0
	_mostrar()
	if not _hay_sombra:
		return
	var normal: Vector3 = golpe["normal"]
	var punto: Vector3 = golpe["position"]
	# Mira para donde mira el objeto, proyectado sobre la superficie: así la huella no se tuerce.
	var costado := cuerpo.global_basis.x - normal * normal.dot(cuerpo.global_basis.x)
	if costado.length_squared() < 0.0001:
		costado = cuerpo.global_basis.z - normal * normal.dot(cuerpo.global_basis.z)
	costado = costado.normalized()
	var giro := Basis(costado, normal, costado.cross(normal))
	var mitad := _mitad_de(apoyo, giro)
	var suavidad := radio + DIFUMINADO_POR_ALTURA * altura
	var tamano := mitad * 2.0 + Vector2.ONE * (suavidad * 2.0)
	sombra.global_transform = Transform3D(
		giro.scaled_local(Vector3(tamano.x, 1.0, tamano.y)), punto + normal * ELEVACION
	)
	var material := sombra.material_override as ShaderMaterial
	material.set_shader_parameter(&"tamano", tamano)
	material.set_shader_parameter(&"huella", mitad)
	material.set_shader_parameter(&"esquinas", _esquinas)
	material.set_shader_parameter(&"suavidad", suavidad)
	material.set_shader_parameter(&"intensidad", intensidad)
	_recortar_en_el_apoyo(material, golpe, Transform3D(giro, punto))


## Vuelve a lanzar el rayo, para que un cambio se vea sin esperar a que el objeto se mueva.
func _al_dia() -> void:
	if is_node_ready() and is_inside_tree():
		actualizar()


func _mostrar() -> void:
	if sombra != null:
		sombra.visible = activa and _hay_sombra


## Los materiales se leen cada vez: el balde viste su malla después de `_ready`.
func _escribir_en_la_malla() -> void:
	for malla in mallas:
		for superficie in malla.get_surface_override_material_count():
			var material := malla.get_surface_override_material(superficie) as ShaderMaterial
			if material == null:
				continue
			material.set_shader_parameter(PARAMETRO_DE_LA_MALLA, intensidad)
			material.set_shader_parameter(SUELO_DE_LA_MALLA, _suelo)
			material.set_shader_parameter(ALCANCE_DE_LA_MALLA, radio)


## La mitad de lo que mide el apoyo sobre los dos ejes de la mancha. Se mide sobre el plano y no en
## el cuerpo, que puede estar de costado.
func _mitad_de(apoyo: PackedVector3Array, giro: Basis) -> Vector2:
	var minimo := Vector2(INF, INF)
	var maximo := Vector2(-INF, -INF)
	for punto: Vector3 in apoyo:
		var en_el_plano := Vector2(punto.dot(giro.x), punto.dot(giro.z))
		minimo = minimo.min(en_el_plano)
		maximo = maximo.max(en_el_plano)
	return (maximo - minimo) / 2.0


## Hasta dónde llega lo que sostiene al objeto, medido en el espacio de su forma: así la mancha se
## corta en el borde de lo de abajo aunque éste esté girado respecto del objeto. Sin esto, una caja
## corrida sobre otra dejaría la mancha colgando en el aire.
func _recortar_en_el_apoyo(
	material: ShaderMaterial, golpe: Dictionary, de_la_mancha: Transform3D
) -> void:
	var minimo := Vector3.ONE * -LIMITE_ABIERTO
	var maximo := Vector3.ONE * LIMITE_ABIERTO
	var al_apoyo := Transform3D.IDENTITY
	var apoyo := golpe["collider"] as CollisionObject3D
	if apoyo != null:
		var dueno := apoyo.shape_find_owner(golpe["shape"])
		var forma := apoyo.shape_owner_get_shape(dueno, 0)
		var de_la_forma := apoyo.global_transform * apoyo.shape_owner_get_transform(dueno)
		var limites := LimitesDeForma.de(forma)
		var escala := de_la_forma.basis.get_scale().abs()
		minimo = limites.position * escala
		maximo = limites.end * escala
		al_apoyo = de_la_forma.orthonormalized().affine_inverse() * de_la_mancha
		# La mancha está sobre una cara de la forma: en ese eje no hay borde que cortar.
		var cara := al_apoyo.basis.y.abs().max_axis_index()
		minimo[cara] = -LIMITE_ABIERTO
		maximo[cara] = LIMITE_ABIERTO
	material.set_shader_parameter(&"al_apoyo", al_apoyo)
	material.set_shader_parameter(&"apoyo_minimo", minimo)
	material.set_shader_parameter(&"apoyo_maximo", maximo)


## Dónde toca el objeto lo que tiene debajo, en el espacio del cuerpo: lo más bajo de sus mallas,
## hasta `BANDA_DE_APOYO` de ahí, midiendo hacia abajo del mundo. Vacío si no tiene nada que
## dibujar.
func _apoyo_del_objeto(cuerpo: Node3D) -> PackedVector3Array:
	var inversa := cuerpo.global_transform.affine_inverse()
	var abajo := (cuerpo.global_basis.inverse() * Vector3.DOWN).normalized()
	var partes: Array[Array] = []
	var hondo := -INF
	for malla in mallas:
		if malla.mesh == null:
			continue
		var parte := _apoyo_de(malla, inversa * malla.global_transform, abajo)
		if (parte[1] as PackedVector3Array).is_empty():
			continue
		partes.append(parte)
		hondo = maxf(hondo, parte[0])
	var apoyo := PackedVector3Array()
	for parte in partes:
		if parte[0] >= hondo - BANDA_DE_APOYO:
			apoyo.append_array(parte[1])
	return apoyo


## De una malla, qué tan hondo llega su punto más bajo y los vértices a menos de `BANDA_DE_APOYO` de
## él, vistos desde el cuerpo. Se recalcula sólo si cambia la pose de la malla respecto del cuerpo o
## hacia dónde queda abajo, no si el cuerpo se mueve: es lo que mantiene barato el rayo de un objeto
## que se lleva en la mano.
func _apoyo_de(malla: MeshInstance3D, relativa: Transform3D, abajo: Vector3) -> Array:
	var guardado: Array = _apoyos.get(malla, [])
	if (
		not guardado.is_empty()
		and guardado[0] == malla.mesh
		and _misma_pose(guardado[1], relativa)
		and (guardado[2] as Vector3).distance_to(abajo) < ABAJO_IGUAL
	):
		return guardado[3]
	var vertices := relativa * _vertices_de(malla.mesh)
	var hondo := -INF
	for vertice: Vector3 in vertices:
		hondo = maxf(hondo, vertice.dot(abajo))
	var puntos := PackedVector3Array()
	for vertice: Vector3 in vertices:
		if vertice.dot(abajo) >= hondo - BANDA_DE_APOYO:
			puntos.append(vertice)
	var apoyo := [hondo, puntos]
	_apoyos[malla] = [malla.mesh, relativa, abajo, apoyo]
	return apoyo


static func _misma_pose(una: Transform3D, otra: Transform3D) -> bool:
	return (
		una.origin.distance_to(otra.origin) < POSE_IGUAL
		and una.basis.x.distance_to(otra.basis.x) < POSE_IGUAL
		and una.basis.y.distance_to(otra.basis.y) < POSE_IGUAL
		and una.basis.z.distance_to(otra.basis.z) < POSE_IGUAL
	)


## Una malla armada en juego, como la de un ticket o las que el balde y la mopa se arman al
## prepararse, no se guarda acá: se quedaría viva toda la sesión.
static func _vertices_de(malla: Mesh) -> PackedVector3Array:
	if malla.resource_path.is_empty():
		return _leer_los_vertices(malla)
	if not _vertices_de_las_mallas.has(malla):
		_vertices_de_las_mallas[malla] = _leer_los_vertices(malla)
	return _vertices_de_las_mallas[malla]


static func _leer_los_vertices(malla: Mesh) -> PackedVector3Array:
	var todos := PackedVector3Array()
	for superficie in malla.get_surface_count():
		todos.append_array(malla.surface_get_arrays(superficie)[Mesh.ARRAY_VERTEX])
	return todos


## Un `ArrayMesh` y no un `PlaneMesh`: lo que recorre las mallas del local espera superficies.
static func _plano() -> ArrayMesh:
	if _plano_de_la_sombra == null:
		var plano := PlaneMesh.new()
		plano.size = Vector2.ONE
		_plano_de_la_sombra = ArrayMesh.new()
		_plano_de_la_sombra.add_surface_from_arrays(
			Mesh.PRIMITIVE_TRIANGLES, plano.get_mesh_arrays()
		)
	return _plano_de_la_sombra


static func _material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SOMBRA
	return material
