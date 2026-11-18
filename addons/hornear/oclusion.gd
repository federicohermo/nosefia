## La oclusión de los rincones, horneada en el atlas del lightmap.
##
## **Qué hace.** El horneador de Godot no da oclusión local: el piso al pie de una pared se hornea
## tan claro como el del pasillo. Este paso calcula, para cada texel de cada pieza del atlas, cuánto
## lo tapan las mallas fijas a menos de un radio, y multiplica la luz de ese texel por un factor.
## El juego no suma nada: el factor queda adentro del atlas.
##
## **Cómo.** La pieza se rasteriza en su UV2, la que usa el atlas: cada texel recibe su posición y
## su normal en el mundo. Desde ahí salen `rayos` rayos al hemisferio, con coseno, contra las mallas
## fijas. Un rayo que pega a menos de `radio` cuenta tanto más cuanto más cerca pegó. El factor
## depende sólo de la geometría: un lugar abierto vale 1, y el factor nunca aclara un texel.
##
## **Lo que no cubre.** Lo que no tiene lightmap no recibe nada: los productos, las cajas, lo que
## se mueve. Y no mira las luces: oscurece una pared tanto de día como de noche.
extends RefCounted

const CANALES := 4
## Texeles de más alrededor de cada pieza: el filtrado del mapa de luz los lee. Reciben el factor
## de su vecino de adentro, para que el borde no deje una costura.
const MARGEN := 1
## Lo que se separa un rayo de la cara de la que sale, en metros. Sin eso, la propia cara lo tapa.
## Es menos que el espesor de una chapa.
const SALIDA := 0.0005
## Cuánto se perdona de un texel que cae justo sobre la arista de dos triángulos.
const TOLERANCIA := 0.001
## Cuánto puede salirse una UV2 de `[0, 1]` por redondeo antes de contar como fuera de su pieza.
const TOLERANCIA_DE_UV2 := 0.001
## Cada cuántas piezas se avisa cómo va: el paso tarda minutos y sin avisos parece colgado.
const PIEZAS_POR_AVISO := 20
const SIN_DUENO := -1
const VACIO := 0
const DILATADO := 1
const CUBIERTO := 2


## Una malla fija con lugar en el atlas. Los tres arreglos van de a tres vértices por triángulo,
## en el mundo, y los tres en el mismo orden.
class Pieza:
	var clave: String
	## Su rectángulo en el atlas, de 0 a 1: es el que dice el `.lmbake`.
	var rect: Rect2
	var rebanada: int = 0
	var posiciones: PackedVector3Array
	var normales: PackedVector3Array
	var uv2: PackedVector2Array


## Lo que dejó el paso. Con `error` no vacío el atlas es el de entrada, sin tocar.
class Resultado:
	var imagen: Image
	var error: String = ""
	## Texeles que recibieron un factor calculado, sin contar los del margen.
	var texeles: int = 0
	var rayos: int = 0


## Los triángulos de `caras` (de a tres vértices) como una sola malla para tirarle rayos.
static func oclusores_de(caras: PackedVector3Array) -> TriangleMesh:
	var arreglos: Array = []
	arreglos.resize(Mesh.ARRAY_MAX)
	arreglos[Mesh.ARRAY_VERTEX] = caras
	var malla := ArrayMesh.new()
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arreglos)
	return malla.generate_triangle_mesh()


## La pieza de una malla puesta en `mundo`, o `null` si la malla no trae UV2: sin ella no hay
## lugar en el atlas. Una pieza sin normales usa la de cada triángulo.
static func pieza_de(
	malla: Mesh, mundo: Transform3D, clave: String, rect: Rect2, rebanada: int
) -> Pieza:
	var pieza := Pieza.new()
	pieza.clave = clave
	pieza.rect = rect
	pieza.rebanada = rebanada
	var para_normales := mundo.basis.inverse().transposed()
	for superficie: int in malla.get_surface_count():
		var arreglos := malla.surface_get_arrays(superficie)
		if arreglos.is_empty():
			continue
		var vertices: PackedVector3Array = arreglos[Mesh.ARRAY_VERTEX]
		var uv2: Variant = arreglos[Mesh.ARRAY_TEX_UV2]
		if uv2 == null or (uv2 as PackedVector2Array).size() != vertices.size():
			return null
		var normales: Variant = arreglos[Mesh.ARRAY_NORMAL]
		var indices: Variant = arreglos[Mesh.ARRAY_INDEX]
		var orden: PackedInt32Array = indices if indices != null else _secuencia(vertices.size())
		for i: int in orden:
			var vertice := mundo * vertices[i]
			pieza.posiciones.append(vertice)
			pieza.uv2.append((uv2 as PackedVector2Array)[i])
			if normales != null:
				pieza.normales.append(
					(para_normales * (normales as PackedVector3Array)[i]).normalized()
				)
			else:
				pieza.normales.append(Vector3.ZERO)
	return pieza


## Las direcciones de los rayos, en un hemisferio con la normal en `z`: reparto de Hammersley con
## coseno, así los rayos cercanos a la normal pesan más.
static func direcciones(rayos: int) -> PackedVector3Array:
	var salida := PackedVector3Array()
	for i: int in rayos:
		var u := (i + 0.5) / rayos
		var v := _inversa_radical(i)
		var radio := sqrt(u)
		var angulo := TAU * v
		salida.append(Vector3(radio * cos(angulo), radio * sin(angulo), sqrt(1.0 - u)))
	return salida


## El factor de un punto: 1 si nada lo tapa a menos de `radio`, y menos mientras más cerca lo tapan.
## `normal` dice hacia dónde mira la cara; `giro` rota el reparto de los rayos, en radianes, para
## que texeles vecinos no repitan el mismo patrón.
static func factor_en(
	oclusores: TriangleMesh,
	origen: Vector3,
	normal: Vector3,
	radio: float,
	reparto: PackedVector3Array,
	giro: float
) -> float:
	var ayuda := Vector3.RIGHT if absf(normal.x) < 0.9 else Vector3.UP
	var tangente := normal.cross(ayuda).normalized()
	var bitangente := normal.cross(tangente)
	var seno := sin(giro)
	var coseno := cos(giro)
	var tapado := 0.0
	for local: Vector3 in reparto:
		var x := local.x * coseno - local.y * seno
		var y := local.x * seno + local.y * coseno
		var direccion := tangente * x + bitangente * y + normal * local.z
		var choque := oclusores.intersect_segment(origen, origen + direccion * radio)
		if not choque.is_empty():
			tapado += 1.0 - origen.distance_to(choque["position"] as Vector3) / radio
	return clampf(1.0 - tapado / reparto.size(), 0.0, 1.0)


## Multiplica la luz de cada pieza por su factor. `atlas` es una pila de capas cuadradas: la luz y,
## de a tres, su dirección. Con `nivel` 0 el resultado es el atlas, y con 1 el factor entero.
## Una pieza con UV2 fuera de su rectángulo frena todo y se nombra en `error`.
static func aplicar(
	atlas: Image, piezas: Array, oclusores: TriangleMesh, radio: float, nivel: float, rayos: int
) -> Resultado:
	var resultado := Resultado.new()
	resultado.imagen = atlas
	for pieza: Pieza in piezas:
		if _uv2_fuera_del_rectangulo(pieza):
			resultado.error = "la pieza %s tiene UV2 fuera de su rectángulo" % pieza.clave
			return resultado
	var ancho := atlas.get_width()
	@warning_ignore("integer_division")
	var capas := atlas.get_height() / ancho
	var rebanadas := _rebanadas(piezas)
	if capas % rebanadas != 0:
		resultado.error = (
			"el atlas trae %d capas y las piezas usan %d rebanadas" % [capas, rebanadas]
		)
		return resultado
	@warning_ignore("integer_division")
	var capas_por_rebanada := capas / rebanadas
	var mapa := _Mapa.new(ancho, rebanadas)
	var reparto := direcciones(rayos)
	for i: int in piezas.size():
		if i > 0 and i % PIEZAS_POR_AVISO == 0:
			print("[oclusion] %d de %d piezas" % [i, piezas.size()])
		_rasterizar(piezas[i] as Pieza, i, mapa, oclusores, radio, reparto, resultado)
	for i: int in piezas.size():
		_dilatar(piezas[i] as Pieza, i, mapa)
	resultado.imagen = _multiplicar(atlas, mapa, capas_por_rebanada, nivel)
	return resultado


## El factor de cada texel del atlas, por rebanada, y de qué pieza es y cómo se obtuvo.
class _Mapa:
	var ancho: int
	var factor := PackedFloat32Array()
	var dueno := PackedInt32Array()
	var estado := PackedByteArray()

	func _init(lado: int, rebanadas: int) -> void:
		ancho = lado
		var cuantos := lado * lado * rebanadas
		factor.resize(cuantos)
		factor.fill(1.0)
		dueno.resize(cuantos)
		dueno.fill(SIN_DUENO)
		estado.resize(cuantos)


static func _rasterizar(
	pieza: Pieza,
	indice: int,
	mapa: _Mapa,
	oclusores: TriangleMesh,
	radio: float,
	reparto: PackedVector3Array,
	resultado: Resultado
) -> void:
	var ancho := mapa.ancho
	@warning_ignore("integer_division")
	var triangulos: int = pieza.posiciones.size() / 3
	for t: int in triangulos:
		var p := [
			_a_texeles(pieza.uv2[3 * t], pieza.rect, ancho),
			_a_texeles(pieza.uv2[3 * t + 1], pieza.rect, ancho),
			_a_texeles(pieza.uv2[3 * t + 2], pieza.rect, ancho),
		]
		var area := ((p[1] as Vector2) - (p[0] as Vector2)).cross(
			(p[2] as Vector2) - (p[0] as Vector2)
		)
		if absf(area) < 0.000001:
			continue
		var desde := (p[0] as Vector2).min(p[1] as Vector2).min(p[2] as Vector2)
		var hasta := (p[0] as Vector2).max(p[1] as Vector2).max(p[2] as Vector2)
		var normal_de_cara := (
			(pieza.posiciones[3 * t + 1] - pieza.posiciones[3 * t])
			. cross(pieza.posiciones[3 * t + 2] - pieza.posiciones[3 * t])
			. normalized()
		)
		for y: int in range(maxi(floori(desde.y), 0), mini(ceili(hasta.y), ancho)):
			for x: int in range(maxi(floori(desde.x), 0), mini(ceili(hasta.x), ancho)):
				var centro := Vector2(x + 0.5, y + 0.5)
				var w0 := ((p[1] as Vector2) - centro).cross((p[2] as Vector2) - centro) / area
				var w1 := ((p[2] as Vector2) - centro).cross((p[0] as Vector2) - centro) / area
				var w2 := 1.0 - w0 - w1
				if w0 < -TOLERANCIA or w1 < -TOLERANCIA or w2 < -TOLERANCIA:
					continue
				var punto := (
					pieza.posiciones[3 * t] * w0
					+ pieza.posiciones[3 * t + 1] * w1
					+ pieza.posiciones[3 * t + 2] * w2
				)
				var normal := (
					pieza.normales[3 * t] * w0
					+ pieza.normales[3 * t + 1] * w1
					+ pieza.normales[3 * t + 2] * w2
				)
				var cara := normal_de_cara
				if normal.length_squared() < 0.000001:
					normal = cara
				normal = normal.normalized()
				if cara.dot(normal) < 0.0:
					cara = -cara
				var factor := factor_en(
					oclusores, punto + cara * SALIDA, normal, radio, reparto, _giro_de(x, y)
				)
				var lugar := (pieza.rebanada * ancho + y) * ancho + x
				mapa.factor[lugar] = factor
				mapa.dueno[lugar] = indice
				mapa.estado[lugar] = CUBIERTO
				resultado.texeles += 1
				resultado.rayos += reparto.size()


## Los texeles de la pieza que ningún triángulo cubre —el margen y los huecos entre sus islas— toman
## el promedio de sus vecinos de la misma pieza. Dos pasadas alcanzan el margen y los huecos que el
## horneador rellena. Un texel cubierto, de ésta o de otra pieza, no se toca.
static func _dilatar(pieza: Pieza, indice: int, mapa: _Mapa) -> void:
	var ancho := mapa.ancho
	var desde := (pieza.rect.position * ancho).floor() - Vector2(MARGEN, MARGEN)
	var hasta := ((pieza.rect.position + pieza.rect.size) * ancho).ceil() + Vector2(MARGEN, MARGEN)
	var x0 := maxi(int(desde.x), 0)
	var y0 := maxi(int(desde.y), 0)
	var x1 := mini(int(hasta.x), ancho)
	var y1 := mini(int(hasta.y), ancho)
	for pasada: int in MARGEN + 1:
		var nuevos := {}
		for y: int in range(y0, y1):
			for x: int in range(x0, x1):
				var lugar := (pieza.rebanada * ancho + y) * ancho + x
				if mapa.estado[lugar] != VACIO:
					continue
				var suma := 0.0
				var vecinos := 0
				# Los vecinos de al lado ganan sobre los de la diagonal.
				for lejos: int in 2:
					for dy: int in range(-1, 2):
						for dx: int in range(-1, 2):
							if absi(dx) + absi(dy) != 1 + lejos:
								continue
							var vx := x + dx
							var vy := y + dy
							if vx < 0 or vy < 0 or vx >= ancho or vy >= ancho:
								continue
							var vecino := (pieza.rebanada * ancho + vy) * ancho + vx
							if mapa.estado[vecino] != VACIO and mapa.dueno[vecino] == indice:
								suma += mapa.factor[vecino]
								vecinos += 1
					if vecinos > 0:
						break
				if vecinos > 0:
					nuevos[lugar] = suma / vecinos
		for lugar: int in nuevos:
			mapa.factor[lugar] = nuevos[lugar]
			mapa.dueno[lugar] = indice
			mapa.estado[lugar] = DILATADO


static func _multiplicar(atlas: Image, mapa: _Mapa, capas_por_rebanada: int, nivel: float) -> Image:
	var formato := atlas.get_format()
	var copia := Image.create_from_data(
		atlas.get_width(), atlas.get_height(), false, formato, atlas.get_data()
	)
	copia.convert(Image.FORMAT_RGBAF)
	var luz := copia.get_data().to_float32_array()
	var ancho := mapa.ancho
	var texeles := ancho * ancho
	@warning_ignore("integer_division")
	var rebanadas: int = mapa.factor.size() / texeles
	for rebanada: int in rebanadas:
		for lugar: int in range(rebanada * texeles, (rebanada + 1) * texeles):
			if mapa.estado[lugar] == VACIO:
				continue
			var factor := 1.0 + (mapa.factor[lugar] - 1.0) * nivel
			if factor >= 1.0:
				continue
			var en_la_rebanada := lugar - rebanada * texeles
			for capa: int in capas_por_rebanada:
				var inicio := (
					((rebanada * capas_por_rebanada + capa) * texeles + en_la_rebanada) * CANALES
				)
				luz[inicio] *= factor
				luz[inicio + 1] *= factor
				luz[inicio + 2] *= factor
	var salida := Image.create_from_data(
		ancho, atlas.get_height(), false, Image.FORMAT_RGBAF, luz.to_byte_array()
	)
	salida.convert(formato)
	return salida


static func _uv2_fuera_del_rectangulo(pieza: Pieza) -> bool:
	var limite := 1.0 + TOLERANCIA_DE_UV2
	for punto: Vector2 in pieza.uv2:
		if punto.x < -TOLERANCIA_DE_UV2 or punto.y < -TOLERANCIA_DE_UV2:
			return true
		if punto.x > limite or punto.y > limite:
			return true
	return false


static func _a_texeles(uv2: Vector2, rect: Rect2, ancho: int) -> Vector2:
	return (rect.position + uv2 * rect.size) * ancho


static func _rebanadas(piezas: Array) -> int:
	var cuantas := 1
	for pieza: Pieza in piezas:
		cuantas = maxi(cuantas, pieza.rebanada + 1)
	return cuantas


## Un giro distinto por texel, sin patrón: el ruido de pocos rayos se reparte en vez de formar
## bandas.
static func _giro_de(x: int, y: int) -> float:
	var base := fposmod(0.06711056 * x + 0.00583715 * y, 1.0)
	return fposmod(52.9829189 * base, 1.0) * TAU


static func _inversa_radical(indice: int) -> float:
	var bits := indice
	var resultado := 0.0
	var peso := 0.5
	while bits > 0:
		resultado += peso * (bits & 1)
		bits >>= 1
		peso *= 0.5
	return resultado


static func _secuencia(cuantos: int) -> PackedInt32Array:
	var salida := PackedInt32Array()
	salida.resize(cuantos)
	for i: int in cuantos:
		salida[i] = i
	return salida
