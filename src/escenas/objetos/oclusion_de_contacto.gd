## La oclusión de contacto de un objeto que se levanta, toda dinámica: nada va horneado en el
## objeto, así que al levantarlo el efecto se va solo.
##
## Cuelga del objeto y lanza un rayo hacia abajo desde su base. Con lo que encuentra hace las dos
## partes:
##
## 1. **El objeto oscurece lo de abajo.** Una mancha difusa sobre esa superficie, del tamaño de la
##    huella del objeto. Se apaga con `activa`.
## 2. **Lo de abajo oscurece al objeto.** Escribe en los materiales de la malla la altura de esa
##    superficie, y el shader oscurece sus caras de abajo. Se apaga con `base`, de 0 a 1.
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

## Más arriba que esto de la superficie de abajo no hay efecto, en metros.
const ALCANCE := 0.4
## Qué tan negra queda la mancha pegada al objeto, de 0 a 1.
const OPACIDAD := 0.5
## Cuánto se difumina el borde de la mancha, en metros: pegado, y por cada metro de altura.
const SUAVIDAD := 0.06
const DIFUMINADO_POR_ALTURA := 0.5
## Sobre la superficie, para que la mancha no pelee con ella por la profundidad.
const ELEVACION := 0.003
## El rayo sale un poco sobre la base: desde adentro de lo que lo sostiene no lo vería.
const SALIDA := 0.03
## Una superficie más empinada que esto no sostiene nada: es una pared.
const NORMAL_MINIMA := 0.6
## La altura que se le escribe a la malla cuando no hay nada abajo.
const SIN_SUELO := -1000.0

static var _plano_de_la_sombra: ArrayMesh
static var _limites_de_las_formas: Dictionary[Shape3D, AABB] = {}

## Se apaga y se prende en vivo. Apaga la mancha, y no el oscurecimiento del objeto.
@export var activa := true:
	set(valor):
		activa = valor
		_mostrar()

## Cuánto oscurece la superficie de abajo al objeto, de 0 a 1. Se apaga y se prende en vivo.
@export_range(0.0, 1.0) var base := 1.0:
	set(valor):
		base = valor
		_escribir_en_la_malla()

## La malla del objeto: en sus materiales se escribe la altura de lo que tiene debajo.
var malla: MeshInstance3D

## La mancha, sólo si hay una superficie a menos de `ALCANCE`.
var sombra: MeshInstance3D

## Cuántos rayos lanzó. Lo mira el test de que un objeto quieto no los repite.
var rayos := 0

var _forma: CollisionShape3D
var _limites_de_la_forma: AABB
var _esquinas := 0.0
var _mitad := Vector2.ZERO
var _hay_sombra := false
var _suelo := SIN_SUELO
var _movido := true
var _asentado := false


## `forma` es el volumen del objeto: de ahí salen su huella y su base. `esquinas` va de 0 (una caja)
## a 1 (un balde).
func configurar(malla_del_objeto: MeshInstance3D, forma: CollisionShape3D, esquinas: float) -> void:
	malla = malla_del_objeto
	_forma = forma
	_esquinas = esquinas


func _ready() -> void:
	add_to_group(GRUPO)
	_limites_de_la_forma = _limites_de(_forma.shape)
	sombra = MeshInstance3D.new()
	sombra.top_level = true
	sombra.mesh = _plano()
	sombra.material_override = _material()
	sombra.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sombra.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	sombra.visible = false
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
	var del_objeto := _forma.transform * _limites_de_la_forma
	var en_el_mundo := cuerpo.global_transform * del_objeto
	_mitad = Vector2(del_objeto.size.x, del_objeto.size.z) / 2.0
	var centro := en_el_mundo.get_center()
	var origen := Vector3(centro.x, en_el_mundo.position.y + SALIDA, centro.z)
	var consulta := PhysicsRayQueryParameters3D.create(
		origen,
		origen + Vector3.DOWN * (SALIDA + ALCANCE),
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
	_poner_la_sombra(cuerpo, golpe, maxf(en_el_mundo.position.y - punto.y, 0.0))


## Qué tan oscura queda la mancha a esa altura de la superficie, de 0 a `OPACIDAD`.
static func intensidad_a(altura: float) -> float:
	return OPACIDAD * (1.0 - smoothstep(0.0, ALCANCE, altura))


func _poner_la_sombra(cuerpo: CollisionObject3D, golpe: Dictionary, altura: float) -> void:
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
	var suavidad := SUAVIDAD + DIFUMINADO_POR_ALTURA * altura
	var tamano := _mitad * 2.0 + Vector2.ONE * (suavidad * 2.0)
	sombra.global_transform = Transform3D(
		giro.scaled_local(Vector3(tamano.x, 1.0, tamano.y)), punto + normal * ELEVACION
	)
	var material := sombra.material_override as ShaderMaterial
	material.set_shader_parameter(&"tamano", tamano)
	material.set_shader_parameter(&"huella", _mitad)
	material.set_shader_parameter(&"esquinas", _esquinas)
	material.set_shader_parameter(&"suavidad", suavidad)
	material.set_shader_parameter(&"intensidad", intensidad)
	material.set_shader_parameter(&"recorte", _recorte_del_apoyo(golpe, giro, punto))


func _mostrar() -> void:
	if sombra != null:
		sombra.visible = activa and _hay_sombra


## Los materiales se leen cada vez: el balde viste su malla después de `_ready`.
func _escribir_en_la_malla() -> void:
	if malla == null:
		return
	for superficie in malla.get_surface_override_material_count():
		var material := malla.get_surface_override_material(superficie) as ShaderMaterial
		if material == null:
			continue
		material.set_shader_parameter(PARAMETRO_DE_LA_MALLA, base)
		material.set_shader_parameter(SUELO_DE_LA_MALLA, _suelo)
		material.set_shader_parameter(ALCANCE_DE_LA_MALLA, ALCANCE)


## Hasta dónde llega lo que sostiene al objeto, en el plano de la mancha. Sin esto, una caja
## corrida sobre otra dejaría la mancha colgando en el aire.
func _recorte_del_apoyo(golpe: Dictionary, giro: Basis, punto: Vector3) -> Vector4:
	var apoyo := golpe["collider"] as CollisionObject3D
	if apoyo == null:
		return Vector4(-100.0, -100.0, 100.0, 100.0)
	var dueno := apoyo.shape_find_owner(golpe["shape"])
	var forma := apoyo.shape_owner_get_shape(dueno, 0)
	var de_la_forma := apoyo.global_transform * apoyo.shape_owner_get_transform(dueno)
	var limites := _limites_de(forma)
	var minimo := Vector2(INF, INF)
	var maximo := Vector2(-INF, -INF)
	for indice in 8:
		var esquina := giro.inverse() * (de_la_forma * limites.get_endpoint(indice) - punto)
		minimo = minimo.min(Vector2(esquina.x, esquina.z))
		maximo = maximo.max(Vector2(esquina.x, esquina.z))
	return Vector4(minimo.x, minimo.y, maximo.x, maximo.y)


static func _limites_de(forma: Shape3D) -> AABB:
	if not _limites_de_las_formas.has(forma):
		_limites_de_las_formas[forma] = forma.get_debug_mesh().get_aabb()
	return _limites_de_las_formas[forma]


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
