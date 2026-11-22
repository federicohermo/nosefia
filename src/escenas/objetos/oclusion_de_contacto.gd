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
## Ocupación bajo la cual una huella es cóncava (ej. palanca en J o llave) y usa mapa de distancia.
const OCUPACION_PARA_MAPA := 0.72
const LADO_MINIMO_MAPA := 0.015
const GRILLA_OCUPACION := 24
const RESOLUCION_MAPA := 96
const DISTANCIA_INFINITA := 1e20

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
var _cache_triangulos: Array[PackedVector3Array] = []
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
	var mapa_huella: Texture2D = medida[3]
	var mitad_mapa: Vector2 = medida[4]
	var alcance_mapa: float = medida[5]
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
	material.set_shader_parameter(&"usar_mapa", mapa_huella != null)
	if mapa_huella != null:
		material.set_shader_parameter(&"mapa_huella", mapa_huella)
		material.set_shader_parameter(&"mitad_mapa", mitad_mapa)
		material.set_shader_parameter(&"alcance_mapa", alcance_mapa)
	_recortar_en_el_apoyo(material, golpe, Transform3D(giro, origen))


## Reusa `[centro, mitad, esquinas, mapa, mitad_mapa, alcance_mapa]` del grupo en espacio del cuerpo
## mientras la orientación del plano de apoyo no cambie más que `ABAJO_IGUAL`: trasladar o girar en
## plano no recalcula el casco ni el campo de distancia.
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
	var triangulos := (
		_cache_triangulos[indice] if indice < _cache_triangulos.size() else PackedVector3Array()
	)
	var alcance := radio * (1.0 + DIFUMINADO_POR_ALTURA) * 1.05
	var medida := _medir_huella_con_mapa(grupo, triangulos, eje_x, eje_z, alcance)
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
	var calculado := _calcular_grupos(actuales, relativas, abajo)
	_cache_grupos = calculado[0]
	_cache_triangulos = calculado[1]
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
) -> Array:
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
		var vacio_g: Array[PackedVector3Array] = []
		var vacio_t: Array[PackedVector3Array] = []
		return [vacio_g, vacio_t]
	var resultado := _componentes_conectados(por_malla, hondo - radio, abajo)
	var componentes: Array[PackedVector3Array] = resultado[0]
	var triangulos: Array[PackedVector3Array] = resultado[1]
	if componentes.size() > 1:
		resultado = _unir_componentes_cercanos(componentes, triangulos, abajo, radio)
	return resultado


## Mide la huella y, si los triángulos de apoyo dejan huecos grandes dentro del rectángulo
## redondeado (formas cóncavas como la palanca o la llave), genera un mapa de distancia 2D exacto.
static func _medir_huella_con_mapa(
	grupo: PackedVector3Array,
	triangulos: PackedVector3Array,
	eje_x: Vector3,
	eje_z: Vector3,
	alcance_mapa: float
) -> Array:
	var base := _medir_huella_en_ejes(grupo, eje_x, eje_z)
	var centro: Vector2 = base[0]
	var mitad: Vector2 = base[1]
	var esquinas: float = base[2]
	if (
		triangulos.size() < 3
		or mitad.x < LADO_MINIMO_MAPA
		or mitad.y < LADO_MINIMO_MAPA
		or alcance_mapa <= 0.0
	):
		return [centro, mitad, esquinas, null, Vector2.ZERO, 0.0]
	var tris_2d := PackedVector2Array()
	tris_2d.resize(triangulos.size())
	for i in triangulos.size():
		var p := triangulos[i]
		tris_2d[i] = Vector2(p.dot(eje_x), p.dot(eje_z)) - centro
	var ocupacion := _ocupacion_de_triangulos(tris_2d, mitad, esquinas)
	if ocupacion >= OCUPACION_PARA_MAPA:
		return [centro, mitad, esquinas, null, Vector2.ZERO, 0.0]
	var mitad_mapa := mitad + Vector2.ONE * alcance_mapa
	var textura := _crear_mapa_de_distancia(tris_2d, mitad_mapa, alcance_mapa)
	return [centro, mitad, esquinas, textura, mitad_mapa, alcance_mapa]


static func _ocupacion_de_triangulos(
	tris_2d: PackedVector2Array, mitad: Vector2, esquinas: float
) -> float:
	var w := GRILLA_OCUPACION
	var h := GRILLA_OCUPACION
	var grilla := PackedByteArray()
	grilla.resize(w * h)
	_rasterizar_triangulos(tris_2d, mitad, w, h, 0.2, grilla)
	var cubiertas := 0
	for valor: int in grilla:
		if valor != 0:
			cubiertas += 1
	var area_caja := 4.0 * mitad.x * mitad.y
	var r := esquinas * minf(mitad.x, mitad.y)
	var area_forma := maxf(area_caja - (4.0 - PI) * r * r, 1e-6)
	var area_cubierta := (float(cubiertas) / float(w * h)) * area_caja
	return area_cubierta / area_forma


static func _crear_mapa_de_distancia(
	tris_2d: PackedVector2Array, mitad_mapa: Vector2, alcance_mapa: float
) -> ImageTexture:
	var ancho := mitad_mapa.x * 2.0
	var alto := mitad_mapa.y * 2.0
	var mayor := maxf(ancho, alto)
	var w := clampi(roundi(RESOLUCION_MAPA * ancho / mayor), 24, RESOLUCION_MAPA)
	var h := clampi(roundi(RESOLUCION_MAPA * alto / mayor), 24, RESOLUCION_MAPA)
	var grilla := PackedByteArray()
	grilla.resize(w * h)
	_rasterizar_triangulos(tris_2d, mitad_mapa, w, h, 0.55, grilla)
	var paso_x := ancho / float(w)
	var paso_y := alto / float(h)
	var fila_in := PackedFloat32Array()
	fila_in.resize(w)
	var fila_out := PackedFloat32Array()
	fila_out.resize(w)
	var paso1 := PackedFloat32Array()
	paso1.resize(w * h)
	for iy in h:
		var base := iy * w
		for ix in w:
			fila_in[ix] = 0.0 if grilla[base + ix] != 0 else DISTANCIA_INFINITA
		_dt_1d(fila_in, w, paso_x, fila_out)
		for ix in w:
			paso1[base + ix] = fila_out[ix]
	var col_in := PackedFloat32Array()
	col_in.resize(h)
	var col_out := PackedFloat32Array()
	col_out.resize(h)
	var bytes := PackedByteArray()
	bytes.resize(w * h)
	var inv_alcance := 1.0 / alcance_mapa
	for ix in w:
		for iy in h:
			col_in[iy] = paso1[iy * w + ix]
		_dt_1d(col_in, h, paso_y, col_out)
		for iy in h:
			var dist := sqrt(maxf(col_out[iy], 0.0))
			var norm := clampf(dist * inv_alcance, 0.0, 1.0)
			bytes[iy * w + ix] = roundi(norm * 255.0)
	var imagen := Image.create_from_data(w, h, false, Image.FORMAT_R8, bytes)
	return ImageTexture.create_from_image(imagen)


static func _rasterizar_triangulos(
	tris_2d: PackedVector2Array,
	mitad: Vector2,
	w: int,
	h: int,
	margen_px: float,
	grilla: PackedByteArray
) -> void:
	var sx := float(w) / (mitad.x * 2.0)
	var sy := float(h) / (mitad.y * 2.0)
	var m2 := margen_px * margen_px
	for k in range(0, tris_2d.size(), 3):
		var a := Vector2((tris_2d[k].x + mitad.x) * sx, (tris_2d[k].y + mitad.y) * sy)
		var b := Vector2((tris_2d[k + 1].x + mitad.x) * sx, (tris_2d[k + 1].y + mitad.y) * sy)
		var c := Vector2((tris_2d[k + 2].x + mitad.x) * sx, (tris_2d[k + 2].y + mitad.y) * sy)
		var min_x := minf(a.x, minf(b.x, c.x))
		var max_x := maxf(a.x, maxf(b.x, c.x))
		var min_y := minf(a.y, minf(b.y, c.y))
		var max_y := maxf(a.y, maxf(b.y, c.y))
		var x0 := clampi(floori(min_x - margen_px), 0, w - 1)
		var x1 := clampi(ceili(max_x + margen_px), 0, w - 1)
		var y0 := clampi(floori(min_y - margen_px), 0, h - 1)
		var y1 := clampi(ceili(max_y + margen_px), 0, h - 1)
		for iy in range(y0, y1 + 1):
			var py := float(iy) + 0.5
			var base := iy * w
			for ix in range(x0, x1 + 1):
				if grilla[base + ix] != 0:
					continue
				var p := Vector2(float(ix) + 0.5, py)
				if _en_triangulo_o_borde(p, a, b, c, m2):
					grilla[base + ix] = 255


static func _en_triangulo_o_borde(
	p: Vector2, a: Vector2, b: Vector2, c: Vector2, m2: float
) -> bool:
	var c1 := (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x)
	var c2 := (c.x - b.x) * (p.y - b.y) - (c.y - b.y) * (p.x - b.x)
	var c3 := (a.x - c.x) * (p.y - c.y) - (a.y - c.y) * (p.x - c.x)
	var neg := (c1 < 0.0) or (c2 < 0.0) or (c3 < 0.0)
	var pos := (c1 > 0.0) or (c2 > 0.0) or (c3 > 0.0)
	if not (neg and pos):
		return true
	return (
		_dist_sq_segmento(p, a, b) <= m2
		or _dist_sq_segmento(p, b, c) <= m2
		or _dist_sq_segmento(p, c, a) <= m2
	)


static func _dist_sq_segmento(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 <= 1e-8:
		return p.distance_squared_to(a)
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_squared_to(a + ab * t)


## Transformada de distancia euclidiana 1D al cuadrado en O(n) (Felzenszwalb-Huttenlocher).
static func _dt_1d(f: PackedFloat32Array, n: int, paso: float, destino: PackedFloat32Array) -> void:
	var v := PackedInt32Array()
	v.resize(n)
	var z := PackedFloat32Array()
	z.resize(n + 1)
	var k := 0
	v[0] = 0
	z[0] = -INF
	z[1] = INF
	var paso2 := paso * paso
	var inv_paso2 := 1.0 / paso2
	for q in range(1, n):
		var fq := f[q]
		if fq >= 1e18:
			continue
		while true:
			var r := v[k]
			var fr := f[r]
			if fr >= 1e18:
				if k == 0:
					v[0] = q
					z[0] = -INF
					z[1] = INF
					break
				k -= 1
				continue
			var s := ((fq - fr) * inv_paso2 + float(q * q - r * r)) / (2.0 * float(q - r))
			if s <= z[k]:
				k -= 1
			else:
				k += 1
				v[k] = q
				z[k] = s
				z[k + 1] = INF
				break
	k = 0
	for q in n:
		while z[k + 1] < float(q):
			k += 1
		var d := float(q - v[k])
		destino[q] = paso2 * d * d + f[v[k]]


## Une los vértices dentro de la banda que comparten triángulos o coinciden en posición, y junta
## los triángulos recortados a la banda de apoyo para cada componente.
static func _componentes_conectados(
	por_malla: Array[Array], umbral: float, abajo: Vector3
) -> Array:
	var puntos := PackedVector3Array()
	var padres: Array[int] = []
	var repetidos: Dictionary[Vector3i, int] = {}
	var tris_registrados: Array[Array] = []
	for entrada in por_malla:
		var vertices: PackedVector3Array = entrada[0]
		var triangulos: PackedInt32Array = entrada[1]
		var mapa := PackedInt32Array()
		mapa.resize(vertices.size())
		var profs := PackedFloat32Array()
		profs.resize(vertices.size())
		for indice in vertices.size():
			var vertice := vertices[indice]
			var prof := vertice.dot(abajo)
			profs[indice] = prof
			if prof < umbral:
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
			var ia := triangulos[paso]
			var ib := triangulos[paso + 1]
			var ic := triangulos[paso + 2]
			var a := mapa[ia]
			var b := mapa[ib]
			var c := mapa[ic]
			if a < 0 and b < 0 and c < 0:
				continue
			if a >= 0 and b >= 0:
				_unir(padres, a, b)
			if b >= 0 and c >= 0:
				_unir(padres, b, c)
			if c >= 0 and a >= 0:
				_unir(padres, c, a)
			var dueno := a if a >= 0 else (b if b >= 0 else c)
			_recortar_triangulo_a_banda(
				vertices[ia],
				vertices[ib],
				vertices[ic],
				profs[ia],
				profs[ib],
				profs[ic],
				umbral,
				dueno,
				tris_registrados
			)
	if puntos.is_empty():
		var vacio_g: Array[PackedVector3Array] = []
		var vacio_t: Array[PackedVector3Array] = []
		return [vacio_g, vacio_t]
	var agrupados: Dictionary[int, PackedVector3Array] = {}
	var tris_por_grupo: Dictionary[int, PackedVector3Array] = {}
	for indice in puntos.size():
		var raiz := _raiz(padres, indice)
		if not agrupados.has(raiz):
			agrupados[raiz] = PackedVector3Array()
			tris_por_grupo[raiz] = PackedVector3Array()
		agrupados[raiz].append(puntos[indice])
	for reg: Array in tris_registrados:
		var raiz := _raiz(padres, reg[0] as int)
		var destino: PackedVector3Array = tris_por_grupo[raiz]
		destino.append(reg[1] as Vector3)
		destino.append(reg[2] as Vector3)
		destino.append(reg[3] as Vector3)
	var salida_g: Array[PackedVector3Array] = []
	var salida_t: Array[PackedVector3Array] = []
	for raiz: int in agrupados.keys():
		salida_g.append(agrupados[raiz])
		salida_t.append(tris_por_grupo[raiz])
	return [salida_g, salida_t]


static func _recortar_triangulo_a_banda(
	va: Vector3,
	vb: Vector3,
	vc: Vector3,
	da: float,
	db: float,
	dc: float,
	umbral: float,
	dueno: int,
	salida: Array[Array]
) -> void:
	var in_a := da >= umbral
	var in_b := db >= umbral
	var in_c := dc >= umbral
	if in_a and in_b and in_c:
		salida.append([dueno, va, vb, vc])
		return
	var dentro_v: Array[Vector3] = []
	var dentro_d: Array[float] = []
	var fuera_v: Array[Vector3] = []
	var fuera_d: Array[float] = []
	for par: Array in [[va, da, in_a], [vb, db, in_b], [vc, dc, in_c]]:
		if par[2]:
			dentro_v.append(par[0] as Vector3)
			dentro_d.append(par[1] as float)
		else:
			fuera_v.append(par[0] as Vector3)
			fuera_d.append(par[1] as float)
	if dentro_v.size() == 1:
		var v0 := dentro_v[0]
		var d0 := dentro_d[0]
		var p1 := v0.lerp(fuera_v[0], (umbral - d0) / (fuera_d[0] - d0))
		var p2 := v0.lerp(fuera_v[1], (umbral - d0) / (fuera_d[1] - d0))
		salida.append([dueno, v0, p1, p2])
	elif dentro_v.size() == 2:
		var v0 := dentro_v[0]
		var v1 := dentro_v[1]
		var vf := fuera_v[0]
		var df := fuera_d[0]
		var p0 := v0.lerp(vf, (umbral - dentro_d[0]) / (df - dentro_d[0]))
		var p1 := v1.lerp(vf, (umbral - dentro_d[1]) / (df - dentro_d[1]))
		salida.append([dueno, v0, v1, p1])
		salida.append([dueno, v0, p1, p0])


## Junta piezas separadas de la malla (como las hebras del cepillo) si sus cajas horizontales se
## acercan a menos de `margen`. Los ejes siguen al cuerpo para no inflar cajas en diagonal.
static func _unir_componentes_cercanos(
	componentes: Array[PackedVector3Array],
	triangulos: Array[PackedVector3Array],
	abajo: Vector3,
	margen: float
) -> Array:
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
	var unidos_g: Dictionary[int, PackedVector3Array] = {}
	var unidos_t: Dictionary[int, PackedVector3Array] = {}
	for indice in componentes.size():
		var raiz := _raiz(padres, indice)
		if not unidos_g.has(raiz):
			unidos_g[raiz] = PackedVector3Array()
			unidos_t[raiz] = PackedVector3Array()
		unidos_g[raiz].append_array(componentes[indice])
		unidos_t[raiz].append_array(triangulos[indice])
	var salida_g: Array[PackedVector3Array] = []
	var salida_t: Array[PackedVector3Array] = []
	for raiz: int in unidos_g.keys():
		salida_g.append(unidos_g[raiz])
		salida_t.append(unidos_t[raiz])
	return [salida_g, salida_t]


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
