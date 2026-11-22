## La oclusión de contacto de un objeto que se levanta, toda dinámica: nada va horneado en el
## objeto, así que al levantarlo el efecto se va solo.
##
## Cuelga del objeto y busca las partes de sus mallas a menos de `radio` de su base, medidas hacia
## abajo del mundo. Si esas partes forman zonas separadas, cada zona lanza su rayo hacia abajo y
## deja su propia mancha. Con lo que encuentra hace las dos partes:
##
## 1. **El objeto oscurece lo de abajo.** Una mancha difusa por cada zona de contacto sobre la
##    superficie que tiene debajo, con su forma e intensidad según su altura. Las manchas extra se
##    crean sólo cuando una pose las pide y se reusan. Se apagan con `activa`.
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
const LOCAL_DE_LA_MALLA := &"contacto_en_base_local"
const EJE_DE_LA_MALLA := &"eje_de_contacto"
const SOMBRA := preload("res://src/escenas/objetos/sombra_de_contacto.gdshader")

## Los valores con que arrancan las dos propiedades de abajo.
const RADIO_POR_DEFECTO := 0.05
const INTENSIDAD_POR_DEFECTO := 0.25
## Valores de los envases de producto, compartidos con la góndola para que una unidad suelta y una
## acomodada se vean iguales.
const RADIO_DEL_PRODUCTO := 0.015
const INTENSIDAD_DEL_PRODUCTO := 0.5
## Qué tan negra queda la mancha con `intensidad` en 1, de 0 a 1.
const OPACIDAD_MAXIMA := 0.5
## Cuánto más se difumina el borde de la mancha por cada metro de altura.
const DIFUMINADO_POR_ALTURA := 0.5
## Sobre la superficie, para que la mancha no pelee con ella por la profundidad.
const ELEVACION := 0.003
## El rayo sale un poco sobre la base: desde adentro de lo que lo sostiene no lo vería.
const SALIDA := 0.03
## Banda usada por `oclusion_de_la_gondola.gd` para medir la base de envases parados en fila.
const BANDA_DE_APOYO := 0.01
## Cuánto puede diferir hacia dónde queda abajo, visto desde el cuerpo, para seguir contando como el
## mismo: con una malla de medio metro, menos que un centímetro.
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
## Resolución para unir vértices duplicados en costuras UV o normales partidas, en 1/m.
const RESOLUCION_DE_VERTICES := 1000.0
## Mitad mínima de huella para distinguir su forma sin ruido numérico, en metros.
const LADO_MINIMO_PARA_FORMA := 0.001
## Ocupación bajo la cual una huella conectada es cóncava (ej. palanca en J o llave) y se parte.
const OCUPACION_CONCAVA := 0.48
const LADO_MINIMO_CONCAVO := 0.045
const FAJAS_CONCAVAS := 10
const HUECO_TRANSVERSAL := 0.045

static var _plano_de_la_sombra: ArrayMesh
static var _vertices_de_las_mallas: Dictionary[Mesh, PackedVector3Array] = {}
static var _geometrias_de_las_mallas: Dictionary[Mesh, Array] = {}

## Se apaga y se prende en vivo. Apaga las manchas, y no el oscurecimiento del objeto.
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

## La mancha principal (primera del pool), visible sólo si hay al menos una zona apoyada.
var sombra: MeshInstance3D

## Todas las manchas creadas para este objeto. Las extra nacen bajo demanda y se reusan.
var sombras: Array[MeshInstance3D] = []

## Cuántos rayos lanzó. Lo mira el test de que un objeto quieto no los repite.
var rayos := 0

## Cuántas veces recalculó los grupos de apoyo. Lo mira el test del ahorro en mano.
var calculos_de_apoyo := 0

## Cuántas veces midió la huella y su forma (casco convexo). Lo mira el test del ahorro al moverse.
var calculos_de_forma := 0

var _sombras_activas := 0
var _suelo := SIN_SUELO
var _movido := true
var _asentado := false
var _cache_valido := false
var _cache_mallas: Array[Mesh] = []
var _cache_relativas: Array[Transform3D] = []
var _cache_abajo := Vector3.ZERO
var _cache_radio := -1.0
var _cache_grupos: Array[PackedVector3Array] = []
var _cache_ejes_x: Array[Vector3] = []
var _cache_ejes_z: Array[Vector3] = []
var _cache_medidas: Array[Array] = []


## De las mallas del objeto salen su huella, su forma y su base.
func configurar(mallas_del_objeto: Array[MeshInstance3D]) -> void:
	mallas = mallas_del_objeto
	_cache_valido = false
	_invalidar_medidas()


func _ready() -> void:
	add_to_group(GRUPO)
	sombra = _crear_sombra()
	sombras = [sombra]
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


## Lanza un rayo por cada zona cercana a la base y deja las dos partes al día.
func actualizar() -> void:
	var cuerpo := get_parent() as CollisionObject3D
	var grupos := _grupos_del_objeto(cuerpo)
	if grupos.is_empty():
		_sombras_activas = 0
		_suelo = SIN_SUELO
		_escribir_en_la_malla()
		_mostrar()
		return
	var espacio := cuerpo.get_world_3d().direct_space_state
	var mascara := ReglasDeLosObjetos.MASCARA_DEL_PRODUCTO & ~ReglasDeLosObjetos.CAPA_DEL_HUECO
	var excluidos: Array[RID] = [cuerpo.get_rid()]
	var usadas := 0
	var suelo_encontrado := SIN_SUELO
	var hay_suelo := false
	for indice_grupo in grupos.size():
		var grupo := grupos[indice_grupo]
		var apoyo := cuerpo.global_transform * grupo
		var minimo := Vector3.INF
		var maximo := -Vector3.INF
		for punto: Vector3 in apoyo:
			minimo = minimo.min(punto)
			maximo = maximo.max(punto)
		var centro := (minimo + maximo) / 2.0
		var origen := Vector3(centro.x, minimo.y + SALIDA, centro.z)
		var consulta := PhysicsRayQueryParameters3D.create(
			origen, origen + Vector3.DOWN * (SALIDA + radio), mascara
		)
		consulta.exclude = excluidos
		rayos += 1
		var golpe := espacio.intersect_ray(consulta)
		if golpe.is_empty() or (golpe["normal"] as Vector3).y < NORMAL_MINIMA:
			continue
		var punto: Vector3 = golpe["position"]
		var altura := maxf(minimo.y - punto.y, 0.0)
		if not hay_suelo:
			suelo_encontrado = punto.y
			hay_suelo = true
		else:
			suelo_encontrado = maxf(suelo_encontrado, punto.y)
		var valor := intensidad_a(altura)
		if valor <= 0.0:
			continue
		_poner_la_sombra(_sombra(usadas), cuerpo, golpe, altura, grupo, indice_grupo, valor)
		usadas += 1
	_sombras_activas = usadas
	_suelo = suelo_encontrado if hay_suelo else SIN_SUELO
	_escribir_en_la_malla()
	_mostrar()


## Qué tan oscura queda la mancha a esa altura de la superficie, de 0 a `OPACIDAD_MAXIMA`.
func intensidad_a(altura: float) -> float:
	return intensidad * OPACIDAD_MAXIMA * (1.0 - smoothstep(0.0, radio, altura))


func _crear_sombra() -> MeshInstance3D:
	var nueva := MeshInstance3D.new()
	nueva.top_level = true
	nueva.mesh = plano()
	nueva.material_override = _material()
	nueva.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	nueva.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	nueva.visible = false
	nueva.add_to_group(ReglasDeLosObjetos.GRUPO_SIN_CONTORNO)
	add_child(nueva)
	return nueva


func _sombra(indice: int) -> MeshInstance3D:
	while sombras.size() <= indice:
		sombras.append(_crear_sombra())
	return sombras[indice]


func _poner_la_sombra(
	mancha: MeshInstance3D,
	cuerpo: CollisionObject3D,
	golpe: Dictionary,
	altura: float,
	grupo: PackedVector3Array,
	indice_grupo: int,
	intensidad_mancha: float
) -> void:
	var normal: Vector3 = golpe["normal"]
	var punto: Vector3 = golpe["position"]
	var giro := _orientacion_en_la_superficie(cuerpo, normal)
	var medida := _medida_del_grupo(indice_grupo, grupo, cuerpo.global_basis, giro)
	var centro_en_cuerpo: Vector2 = medida[0]
	var mitad: Vector2 = medida[1]
	var esquinas: float = medida[2]
	var origen_cuerpo := cuerpo.global_position
	var centro_plano := (
		centro_en_cuerpo + Vector2(origen_cuerpo.dot(giro.x), origen_cuerpo.dot(giro.z))
	)
	var punto_plano := Vector2(punto.dot(giro.x), punto.dot(giro.z))
	var desfase := centro_plano - punto_plano
	var origen := punto + giro.x * desfase.x + giro.z * desfase.y
	var suavidad := radio + DIFUMINADO_POR_ALTURA * altura
	var tamano := mitad * 2.0 + Vector2.ONE * (suavidad * 2.0)
	mancha.global_transform = Transform3D(
		giro.scaled_local(Vector3(tamano.x, 1.0, tamano.y)), origen + normal * ELEVACION
	)
	var material := mancha.material_override as ShaderMaterial
	material.set_shader_parameter(&"tamano", tamano)
	material.set_shader_parameter(&"huella", mitad)
	material.set_shader_parameter(&"esquinas", esquinas)
	material.set_shader_parameter(&"suavidad", suavidad)
	material.set_shader_parameter(&"intensidad", intensidad_mancha)
	_recortar_en_el_apoyo(material, golpe, Transform3D(giro, origen))


## Reusa `[centro, mitad, esquinas]` del grupo en espacio del cuerpo mientras la orientación del
## plano de apoyo no cambie más que `ABAJO_IGUAL`: trasladar o girar en plano no recalcula el casco.
func _medida_del_grupo(indice: int, grupo: PackedVector3Array, base: Basis, giro: Basis) -> Array:
	var traspuesta := base.transposed()
	var eje_x := traspuesta * giro.x
	var eje_z := traspuesta * giro.z
	if (
		indice < _cache_medidas.size()
		and not _cache_medidas[indice].is_empty()
		and _cache_ejes_x[indice].distance_to(eje_x) < ABAJO_IGUAL
		and _cache_ejes_z[indice].distance_to(eje_z) < ABAJO_IGUAL
	):
		return _cache_medidas[indice]
	while _cache_medidas.size() <= indice:
		_cache_ejes_x.append(Vector3.ZERO)
		_cache_ejes_z.append(Vector3.ZERO)
		_cache_medidas.append([])
	calculos_de_forma += 1
	var medida := _medir_huella_en_ejes(grupo, eje_x, eje_z)
	_cache_ejes_x[indice] = eje_x
	_cache_ejes_z[indice] = eje_z
	_cache_medidas[indice] = medida
	return medida


func _invalidar_medidas() -> void:
	_cache_ejes_x.clear()
	_cache_ejes_z.clear()
	_cache_medidas.clear()


## Elige el eje del cuerpo más paralelo a la superficie: un objeto alargado girado sobre su eje
## queda alineado con su huella en cualquier ángulo y nunca forma un cuadrado diagonal.
static func _orientacion_en_la_superficie(cuerpo: CollisionObject3D, normal: Vector3) -> Basis:
	var mejor := cuerpo.global_basis.x.normalized()
	var mejor_dot := absf(mejor.dot(normal))
	for eje_bruto: Vector3 in [cuerpo.global_basis.y, cuerpo.global_basis.z]:
		var eje := eje_bruto.normalized()
		var proyeccion := absf(eje.dot(normal))
		if proyeccion < mejor_dot:
			mejor_dot = proyeccion
			mejor = eje
	var costado := (mejor - normal * normal.dot(mejor)).normalized()
	return Basis(costado, normal, costado.cross(normal))


## Vuelve a lanzar el rayo, para que un cambio se vea sin esperar a que el objeto se mueva.
func _al_dia() -> void:
	if is_node_ready() and is_inside_tree():
		actualizar()


func _mostrar() -> void:
	for indice in sombras.size():
		sombras[indice].visible = activa and indice < _sombras_activas


## Los materiales se leen cada vez: el balde y la mopa visten su malla después de `_ready`.
func _escribir_en_la_malla() -> void:
	for malla in mallas:
		for superficie in malla.get_surface_override_material_count():
			var material := malla.get_surface_override_material(superficie) as ShaderMaterial
			if material == null:
				continue
			material.set_shader_parameter(PARAMETRO_DE_LA_MALLA, intensidad)
			material.set_shader_parameter(SUELO_DE_LA_MALLA, _suelo)
			material.set_shader_parameter(ALCANCE_DE_LA_MALLA, radio)


## Centro, mitad y redondez (`esquinas`) de la huella sobre los dos ejes de la mancha.
static func medir_huella_en_el_plano(apoyo: PackedVector3Array, giro: Basis) -> Array:
	return _medir_huella_en_ejes(apoyo, giro.x, giro.z)


static func _medir_huella_en_ejes(
	puntos_3d: PackedVector3Array, eje_x: Vector3, eje_z: Vector3
) -> Array:
	var puntos := PackedVector2Array()
	puntos.resize(puntos_3d.size())
	for indice in puntos_3d.size():
		var punto := puntos_3d[indice]
		puntos[indice] = Vector2(punto.dot(eje_x), punto.dot(eje_z))
	return medir_huella_2d(puntos)


## Centro, mitad y redondez (`esquinas`, de 0 a 1) de una nube de puntos 2D.
##
## `sombra_de_contacto.gdshader` dibuja un rectángulo con radio de esquina
## `r = esquinas * min(hx, hz)`, cuya área es `4 * hx * hz - (4 - PI) * r^2`. Invertir esa relación
## contra el área del casco convexo devuelve 0 en un rectángulo y 1 en un círculo o una cápsula.
static func medir_huella_2d(puntos: PackedVector2Array) -> Array:
	var minimo := Vector2(INF, INF)
	var maximo := Vector2(-INF, -INF)
	for punto: Vector2 in puntos:
		minimo = minimo.min(punto)
		maximo = maximo.max(punto)
	if not is_finite(minimo.x):
		return [Vector2.ZERO, Vector2.ZERO, 0.0]
	var centro := (minimo + maximo) / 2.0
	var mitad := (maximo - minimo) / 2.0
	return [centro, mitad, _esquinas_de_la_huella(puntos, mitad)]


static func _esquinas_de_la_huella(puntos: PackedVector2Array, mitad: Vector2) -> float:
	var menor := minf(mitad.x, mitad.y)
	if puntos.size() < 3 or menor <= LADO_MINIMO_PARA_FORMA:
		return 0.0
	var area_casco := _area_del_casco_convexo(puntos)
	if area_casco <= 0.0:
		return 0.0
	var area_caja := 4.0 * mitad.x * mitad.y
	var faltante := maxf(0.0, area_caja - area_casco)
	var fraccion := faltante / ((4.0 - PI) * menor * menor)
	if fraccion <= 0.0001:
		return 0.0
	return clampf(sqrt(fraccion), 0.0, 1.0)


static func _area_del_casco_convexo(puntos: PackedVector2Array) -> float:
	var ordenados: Array[Vector2] = []
	ordenados.resize(puntos.size())
	for indice in puntos.size():
		ordenados[indice] = puntos[indice]
	ordenados.sort_custom(
		func(a: Vector2, b: Vector2) -> bool: return a.x < b.x if a.x != b.x else a.y < b.y
	)
	var inferior: Array[Vector2] = []
	for punto in ordenados:
		while inferior.size() >= 2 and _giro_2d(inferior[-2], inferior[-1], punto) <= 0.0:
			inferior.pop_back()
		inferior.append(punto)
	var superior: Array[Vector2] = []
	for indice in range(ordenados.size() - 1, -1, -1):
		var punto := ordenados[indice]
		while superior.size() >= 2 and _giro_2d(superior[-2], superior[-1], punto) <= 0.0:
			superior.pop_back()
		superior.append(punto)
	inferior.pop_back()
	superior.pop_back()
	var casco: Array[Vector2] = inferior + superior
	if casco.size() < 3:
		return 0.0
	var doble_area := 0.0
	for indice in casco.size():
		var a := casco[indice]
		var b := casco[(indice + 1) % casco.size()]
		doble_area += a.x * b.y - b.x * a.y
	return absf(doble_area) * 0.5


static func _giro_2d(origen: Vector2, a: Vector2, b: Vector2) -> float:
	return (a.x - origen.x) * (b.y - origen.y) - (a.y - origen.y) * (b.x - origen.x)


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


## Zonas separadas de vértices a menos de `radio` del punto más bajo, en espacio del cuerpo.
## Se recalcula sólo si cambia alguna malla, su pose respecto del cuerpo, `radio` o hacia dónde
## queda abajo: llevar un objeto en la mano sin girarlo conserva el caché.
func _grupos_del_objeto(cuerpo: Node3D) -> Array[PackedVector3Array]:
	var inversa := cuerpo.global_transform.affine_inverse()
	var abajo := (cuerpo.global_basis.inverse() * Vector3.DOWN).normalized()
	var actuales: Array[Mesh] = []
	var relativas: Array[Transform3D] = []
	for malla in mallas:
		actuales.append(malla.mesh)
		relativas.append(inversa * malla.global_transform)
	if _cache_coincide(actuales, relativas, abajo):
		return _cache_grupos
	calculos_de_apoyo += 1
	_cache_mallas = actuales
	_cache_relativas = relativas
	_cache_abajo = abajo
	_cache_radio = radio
	_cache_grupos = _calcular_grupos(actuales, relativas, abajo)
	_invalidar_medidas()
	_cache_valido = true
	return _cache_grupos


func _cache_coincide(actuales: Array[Mesh], relativas: Array[Transform3D], abajo: Vector3) -> bool:
	if (
		not _cache_valido
		or absf(_cache_radio - radio) >= 0.0001
		or _cache_abajo.distance_to(abajo) >= ABAJO_IGUAL
		or _cache_mallas.size() != actuales.size()
	):
		return false
	for indice in actuales.size():
		if (
			_cache_mallas[indice] != actuales[indice]
			or not _misma_pose(_cache_relativas[indice], relativas[indice])
		):
			return false
	return true


func _calcular_grupos(
	actuales: Array[Mesh], relativas: Array[Transform3D], abajo: Vector3
) -> Array[PackedVector3Array]:
	var por_malla: Array[Array] = []
	var hondo := -INF
	for indice in actuales.size():
		var malla := actuales[indice]
		if malla == null:
			continue
		var geometria := _geometria_de(malla)
		var vertices: PackedVector3Array = relativas[indice] * (geometria[0] as PackedVector3Array)
		if vertices.is_empty():
			continue
		for vertice: Vector3 in vertices:
			hondo = maxf(hondo, vertice.dot(abajo))
		por_malla.append([vertices, geometria[1]])
	if not is_finite(hondo):
		return []
	var componentes := _componentes_conectados(por_malla, hondo - radio, abajo)
	if componentes.size() > 1:
		componentes = _unir_componentes_cercanos(componentes, abajo, radio)
	var resultado: Array[PackedVector3Array] = []
	for grupo: PackedVector3Array in componentes:
		resultado.append_array(_dividir_si_concavo(grupo, abajo))
	return resultado


## Si una huella conectada deja más de la mitad de su caja vacía (como una palanca curva en J o una
## llave), la parte en fajas angostas a lo largo de su eje largo y separa huecos transversales para
## que la mancha siga el trazo del objeto en vez de tapar el piso vacío del medio.
static func _dividir_si_concavo(
	grupo: PackedVector3Array, abajo: Vector3
) -> Array[PackedVector3Array]:
	if grupo.size() < 8:
		return [grupo]
	var mejor := Vector3.RIGHT
	var mejor_dot := absf(mejor.dot(abajo))
	for candidato: Vector3 in [Vector3.UP, Vector3.BACK]:
		var proyeccion := absf(candidato.dot(abajo))
		if proyeccion < mejor_dot:
			mejor_dot = proyeccion
			mejor = candidato
	var eje_x := (mejor - abajo * abajo.dot(mejor)).normalized()
	var eje_z := eje_x.cross(abajo).normalized()
	var u_min := INF
	var u_max := -INF
	var v_min := INF
	var v_max := -INF
	var coords: Array[Vector2] = []
	coords.resize(grupo.size())
	for i in grupo.size():
		var p := Vector2(grupo[i].dot(eje_x), grupo[i].dot(eje_z))
		coords[i] = p
		u_min = minf(u_min, p.x)
		u_max = maxf(u_max, p.x)
		v_min = minf(v_min, p.y)
		v_max = maxf(v_max, p.y)
	var du := u_max - u_min
	var dv := v_max - v_min
	if du < LADO_MINIMO_CONCAVO or dv < LADO_MINIMO_CONCAVO:
		return [grupo]
	var largo_en_u := du >= dv
	var l_min := u_min if largo_en_u else v_min
	var l_span := du if largo_en_u else dv
	var c_span := dv if largo_en_u else du
	var fajas: Array[Array] = []
	var c_mins: Array[float] = []
	var c_maxs: Array[float] = []
	for _k in FAJAS_CONCAVAS:
		fajas.append([])
		c_mins.append(INF)
		c_maxs.append(-INF)
	for i in grupo.size():
		var l_val := coords[i].x if largo_en_u else coords[i].y
		var c_val := coords[i].y if largo_en_u else coords[i].x
		var idx := clampi(int(((l_val - l_min) / l_span) * FAJAS_CONCAVAS), 0, FAJAS_CONCAVAS - 1)
		fajas[idx].append(i)
		c_mins[idx] = minf(c_mins[idx], c_val)
		c_maxs[idx] = maxf(c_maxs[idx], c_val)
	var area_fajas := 0.0
	var ancho_faja := l_span / float(FAJAS_CONCAVAS)
	for k in FAJAS_CONCAVAS:
		if not fajas[k].is_empty():
			area_fajas += maxf(c_maxs[k] - c_mins[k], 0.015) * ancho_faja
	if area_fajas / (du * dv) >= OCUPACION_CONCAVA:
		return [grupo]
	# Unir fajas consecutivas que mantienen un ancho transversal angosto (tramo recto continuo).
	var tope_ancho := maxf(0.06, c_span * 0.28)
	var tramos: Array[Array] = []
	var actual_indices: Array = []
	var actual_cmin := INF
	var actual_cmax := -INF
	for k in FAJAS_CONCAVAS:
		if fajas[k].is_empty():
			if not actual_indices.is_empty():
				tramos.append(actual_indices)
				actual_indices = []
				actual_cmin = INF
				actual_cmax = -INF
			continue
		var nuevo_cmin := minf(actual_cmin, c_mins[k])
		var nuevo_cmax := maxf(actual_cmax, c_maxs[k])
		if not actual_indices.is_empty() and (nuevo_cmax - nuevo_cmin) > tope_ancho:
			tramos.append(actual_indices)
			actual_indices = fajas[k].duplicate()
			actual_cmin = c_mins[k]
			actual_cmax = c_maxs[k]
		else:
			actual_indices.append_array(fajas[k])
			actual_cmin = nuevo_cmin
			actual_cmax = nuevo_cmax
	if not actual_indices.is_empty():
		tramos.append(actual_indices)
	# Si algún tramo (como la U del gancho) tiene un hueco transversal vacío, separarlo en dos.
	var salida: Array[PackedVector3Array] = []
	for tramo in tramos:
		var orden: Array[Array] = []
		for idx: int in tramo:
			var c_val := coords[idx].y if largo_en_u else coords[idx].x
			orden.append([c_val, idx])
		orden.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		var corte := -1
		var mayor_hueco := HUECO_TRANSVERSAL
		for j in range(1, orden.size()):
			var hueco: float = orden[j][0] - orden[j - 1][0]
			if hueco > mayor_hueco:
				mayor_hueco = hueco
				corte = j
		if corte > 0:
			var parte_a := PackedVector3Array()
			var parte_b := PackedVector3Array()
			for j in orden.size():
				if j < corte:
					parte_a.append(grupo[orden[j][1]])
				else:
					parte_b.append(grupo[orden[j][1]])
			if not parte_a.is_empty():
				salida.append(parte_a)
			if not parte_b.is_empty():
				salida.append(parte_b)
		else:
			var sub := PackedVector3Array()
			for idx: int in tramo:
				sub.append(grupo[idx])
			if not sub.is_empty():
				salida.append(sub)
	return salida if not salida.is_empty() else [grupo]


## Une los vértices dentro de la banda que comparten triángulos o coinciden en posición.
static func _componentes_conectados(
	por_malla: Array[Array], umbral: float, abajo: Vector3
) -> Array[PackedVector3Array]:
	var puntos := PackedVector3Array()
	var padres: Array[int] = []
	var repetidos: Dictionary[Vector3i, int] = {}
	for entrada in por_malla:
		var vertices: PackedVector3Array = entrada[0]
		var triangulos: PackedInt32Array = entrada[1]
		var mapa := PackedInt32Array()
		mapa.resize(vertices.size())
		for indice in vertices.size():
			var vertice := vertices[indice]
			if vertice.dot(abajo) < umbral:
				mapa[indice] = -1
				continue
			var clave := Vector3i(
				roundi(vertice.x * RESOLUCION_DE_VERTICES),
				roundi(vertice.y * RESOLUCION_DE_VERTICES),
				roundi(vertice.z * RESOLUCION_DE_VERTICES)
			)
			if repetidos.has(clave):
				mapa[indice] = repetidos[clave]
			else:
				var id := puntos.size()
				puntos.append(vertice)
				padres.append(id)
				repetidos[clave] = id
				mapa[indice] = id
		for paso in range(0, triangulos.size(), 3):
			var a := mapa[triangulos[paso]]
			var b := mapa[triangulos[paso + 1]]
			var c := mapa[triangulos[paso + 2]]
			if a >= 0 and b >= 0:
				_unir(padres, a, b)
			if b >= 0 and c >= 0:
				_unir(padres, b, c)
			if c >= 0 and a >= 0:
				_unir(padres, c, a)
	if puntos.is_empty():
		return []
	var agrupados: Dictionary[int, PackedVector3Array] = {}
	for indice in puntos.size():
		var raiz := _raiz(padres, indice)
		if not agrupados.has(raiz):
			agrupados[raiz] = PackedVector3Array()
		agrupados[raiz].append(puntos[indice])
	var salida: Array[PackedVector3Array] = []
	for lista: PackedVector3Array in agrupados.values():
		salida.append(lista)
	return salida


## Junta piezas separadas de la malla (como las hebras del cepillo) si sus cajas horizontales se
## acercan a menos de `margen`. Los ejes siguen al cuerpo para no inflar cajas en diagonal.
static func _unir_componentes_cercanos(
	componentes: Array[PackedVector3Array], abajo: Vector3, margen: float
) -> Array[PackedVector3Array]:
	var mejor := Vector3.RIGHT
	var mejor_dot := absf(mejor.dot(abajo))
	for candidato: Vector3 in [Vector3.UP, Vector3.BACK]:
		var proyeccion := absf(candidato.dot(abajo))
		if proyeccion < mejor_dot:
			mejor_dot = proyeccion
			mejor = candidato
	var eje_x := (mejor - abajo * abajo.dot(mejor)).normalized()
	var eje_z := eje_x.cross(abajo).normalized()
	var minimos: Array[Vector2] = []
	var maximos: Array[Vector2] = []
	var padres: Array[int] = []
	for indice in componentes.size():
		padres.append(indice)
		var minimo := Vector2(INF, INF)
		var maximo := Vector2(-INF, -INF)
		for punto: Vector3 in componentes[indice]:
			var p2 := Vector2(punto.dot(eje_x), punto.dot(eje_z))
			minimo = minimo.min(p2)
			maximo = maximo.max(p2)
		minimos.append(minimo)
		maximos.append(maximo)
	var margen_sq := margen * margen
	for i in componentes.size():
		for j in range(i + 1, componentes.size()):
			if _raiz(padres, i) == _raiz(padres, j):
				continue
			var dx := maxf(0.0, maxf(minimos[i].x - maximos[j].x, minimos[j].x - maximos[i].x))
			var dz := maxf(0.0, maxf(minimos[i].y - maximos[j].y, minimos[j].y - maximos[i].y))
			if dx * dx + dz * dz <= margen_sq:
				_unir(padres, i, j)
	var unidos: Dictionary[int, PackedVector3Array] = {}
	for indice in componentes.size():
		var raiz := _raiz(padres, indice)
		if not unidos.has(raiz):
			unidos[raiz] = PackedVector3Array()
		unidos[raiz].append_array(componentes[indice])
	var salida: Array[PackedVector3Array] = []
	for lista: PackedVector3Array in unidos.values():
		salida.append(lista)
	return salida


static func _raiz(padres: Array[int], indice: int) -> int:
	while padres[indice] != indice:
		padres[indice] = padres[padres[indice]]
		indice = padres[indice]
	return indice


static func _unir(padres: Array[int], a: int, b: int) -> void:
	var ra := _raiz(padres, a)
	var rb := _raiz(padres, b)
	if ra != rb:
		padres[ra] = rb


static func _misma_pose(una: Transform3D, otra: Transform3D) -> bool:
	return (
		una.origin.distance_to(otra.origin) < POSE_IGUAL
		and una.basis.x.distance_to(otra.basis.x) < POSE_IGUAL
		and una.basis.y.distance_to(otra.basis.y) < POSE_IGUAL
		and una.basis.z.distance_to(otra.basis.z) < POSE_IGUAL
	)


## Una malla armada en juego, como la de un ticket o las que el balde y la mopa se arman al
## prepararse, no se guarda acá: se quedaría viva toda la sesión.
static func vertices_de(malla: Mesh) -> PackedVector3Array:
	if malla.resource_path.is_empty():
		return _leer_los_vertices(malla)
	if not _vertices_de_las_mallas.has(malla):
		_vertices_de_las_mallas[malla] = _leer_los_vertices(malla)
	return _vertices_de_las_mallas[malla]


static func _geometria_de(malla: Mesh) -> Array:
	if malla.resource_path.is_empty():
		return _leer_geometria(malla)
	if not _geometrias_de_las_mallas.has(malla):
		_geometrias_de_las_mallas[malla] = _leer_geometria(malla)
	return _geometrias_de_las_mallas[malla]


static func _leer_los_vertices(malla: Mesh) -> PackedVector3Array:
	var todos := PackedVector3Array()
	for superficie in malla.get_surface_count():
		todos.append_array(malla.surface_get_arrays(superficie)[Mesh.ARRAY_VERTEX])
	return todos


static func _leer_geometria(malla: Mesh) -> Array:
	var vertices := PackedVector3Array()
	var triangulos := PackedInt32Array()
	var desplazamiento := 0
	for superficie in malla.get_surface_count():
		var arreglos := malla.surface_get_arrays(superficie)
		var puntos: PackedVector3Array = arreglos[Mesh.ARRAY_VERTEX]
		vertices.append_array(puntos)
		var indices: Variant = arreglos[Mesh.ARRAY_INDEX]
		if indices != null:
			for indice: int in indices as PackedInt32Array:
				triangulos.append(indice + desplazamiento)
		else:
			for indice in puntos.size():
				triangulos.append(indice + desplazamiento)
		desplazamiento += puntos.size()
	return [vertices, triangulos]


## Un `ArrayMesh` y no un `PlaneMesh`: lo que recorre las mallas del local espera superficies.
static func plano() -> ArrayMesh:
	if _plano_de_la_sombra == null:
		var cuadricula := PlaneMesh.new()
		cuadricula.size = Vector2.ONE
		_plano_de_la_sombra = ArrayMesh.new()
		_plano_de_la_sombra.add_surface_from_arrays(
			Mesh.PRIMITIVE_TRIANGLES, cuadricula.get_mesh_arrays()
		)
	return _plano_de_la_sombra


static func _material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SOMBRA
	return material
