## Los obstáculos del horneado con apoyo: volúmenes que sólo existen mientras se hornea.
##
## **Por qué hacen falta.** Las góndolas son chapas finas y los estantes de abajo quedan abiertos
## al pasillo. Por esa abertura entra la luz al piso, y el piso al pie del mueble se hornea tan
## claro como el del pasillo: el mueble parece flotar. Un volumen que llene el hueco entre el piso
## y el estante le saca esa luz al horneado. El juego no lo ve: el volumen no se guarda en la
## escena ni en el `.lmbake`.
##
## **De dónde salen.** De la malla de cada góndola, no de una tabla de coordenadas: si una
## góndola se mueve y se vuelve a hornear, su sombra la sigue. Cada cara de abajo de un estante
## (una cara que mira hacia abajo, sin pasar de `ALTO_MAXIMO` sobre el piso) pide un volumen del
## piso hasta ella, con el rectángulo que ocupa.
extends RefCounted

## Hasta qué altura sobre el piso un estante deja un hueco que se rellena. Más arriba el hueco
## es de mercadería, que se mueve y no se hornea.
const ALTO_MAXIMO := 0.30
## Un estante que casi toca el piso no deja hueco.
const ALTO_MINIMO := 0.01
## Lo que se achica cada volumen para no tocar las chapas del mueble: una cara pegada a un
## obstáculo se hornea negra.
const HOLGURA := 0.005
## Una cara que mira hacia abajo cuenta si su normal apunta a menos de este valor en `y`.
const NORMAL_HACIA_ABAJO := -0.9
## Lo que mide, al menos, la parte de abajo de un estante: menos es un detalle, no un estante.
const AREA_MINIMA := 0.05
## Cuánto se redondea una posición para saber que dos caras comparten un vértice.
const SOLDADURA := 0.001


## Los volúmenes que pide una malla. `caras` son sus triángulos en el mundo, de a tres vértices.
## `suelo` es la altura del piso donde apoya.
static func volumenes(caras: PackedVector3Array, suelo: float) -> Array[AABB]:
	var abajo := _caras_hacia_abajo(caras)
	var componentes := _componentes(abajo)
	var salida: Array[AABB] = []
	for componente: Array in componentes:
		var limites := _limites(abajo, componente)
		var hueco := limites.position.y - suelo
		if hueco < ALTO_MINIMO or hueco > ALTO_MAXIMO or _area(abajo, componente) < AREA_MINIMA:
			continue
		var volumen := AABB(
			Vector3(limites.position.x, suelo, limites.position.z),
			Vector3(limites.size.x, hueco, limites.size.z)
		)
		salida.append(volumen.grow(-HOLGURA))
	return salida


## El triángulo `t` es `abajo[3 * t]`, `abajo[3 * t + 1]` y `abajo[3 * t + 2]`.
static func _caras_hacia_abajo(caras: PackedVector3Array) -> PackedVector3Array:
	var abajo := PackedVector3Array()
	@warning_ignore("integer_division")
	var cuantas: int = caras.size() / 3
	for t: int in cuantas:
		var a := caras[3 * t]
		var b := caras[3 * t + 1]
		var c := caras[3 * t + 2]
		var normal := (b - a).cross(c - a)
		if normal.length_squared() > 0.0 and normal.normalized().y < NORMAL_HACIA_ABAJO:
			abajo.append_array(PackedVector3Array([a, b, c]))
	return abajo


## Agrupa los triángulos que comparten un vértice: el fondo de un estante es una sola pieza.
static func _componentes(abajo: PackedVector3Array) -> Array[Array]:
	@warning_ignore("integer_division")
	var cuantas: int = abajo.size() / 3
	var padre: Array[int] = []
	for t: int in cuantas:
		padre.append(t)
	var dueno := {}
	for v: int in abajo.size():
		var clave := Vector3i((abajo[v] / SOLDADURA).round())
		@warning_ignore("integer_division")
		var t: int = v / 3
		if dueno.has(clave):
			padre[_raiz(padre, t)] = _raiz(padre, dueno[clave] as int)
		else:
			dueno[clave] = t
	var grupos := {}
	for t: int in cuantas:
		var raiz := _raiz(padre, t)
		if not grupos.has(raiz):
			grupos[raiz] = []
		(grupos[raiz] as Array).append(t)
	var salida: Array[Array] = []
	for grupo: Array in grupos.values():
		salida.append(grupo)
	return salida


static func _raiz(padre: Array[int], t: int) -> int:
	while padre[t] != t:
		padre[t] = padre[padre[t]]
		t = padre[t]
	return t


static func _limites(abajo: PackedVector3Array, triangulos: Array) -> AABB:
	var primero: int = triangulos[0]
	var limites := AABB(abajo[3 * primero], Vector3.ZERO)
	for t: int in triangulos:
		for v: int in 3:
			limites = limites.expand(abajo[3 * t + v])
	return limites


static func _area(abajo: PackedVector3Array, triangulos: Array) -> float:
	var area := 0.0
	for t: int in triangulos:
		area += (
			(abajo[3 * t + 1] - abajo[3 * t]).cross(abajo[3 * t + 2] - abajo[3 * t]).length() * 0.5
		)
	return area
