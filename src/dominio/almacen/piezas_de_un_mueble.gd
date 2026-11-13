## Las estanterías sueltas que arma una misma malla, cada una con su caja.
##
## Un mueble de varias piezas, como la góndola alta con sus estanterías contra dos paredes, no
## ocupa la caja que las envuelve a todas: ahí caben el pasillo y lo que se suelte en él. Las
## piezas se separan a lo largo de Z por un hueco de al menos `HUECO_ENTRE_PIEZAS`; lo que se toca
## o se separa menos es de la misma pieza.
class_name PiezasDeUnMueble
extends RefCounted

## El hueco, en metros, desde el que dos partes de una malla son piezas distintas.
const HUECO_ENTRE_PIEZAS := 0.01

static var _memoria: Dictionary = {}


## Las cajas de las piezas de una malla, de menor a mayor Z y en su espacio local.
static func de_la_malla(malla: Mesh) -> Array[AABB]:
	if not _memoria.has(malla):
		_memoria[malla] = de_triangulos(malla.get_faces())
	return _memoria[malla]


## Lo mismo desde sus triángulos, de a tres puntos.
static func de_triangulos(caras: PackedVector3Array) -> Array[AABB]:
	var cuantos := caras.size() / 3
	var desde := PackedFloat32Array()
	var hasta := PackedFloat32Array()
	var orden: Array[int] = []
	for triangulo in cuantos:
		var z := PackedFloat32Array(
			[caras[3 * triangulo].z, caras[3 * triangulo + 1].z, caras[3 * triangulo + 2].z]
		)
		desde.append(minf(z[0], minf(z[1], z[2])))
		hasta.append(maxf(z[0], maxf(z[1], z[2])))
		orden.append(triangulo)
	orden.sort_custom(func(a: int, b: int) -> bool: return desde[a] < desde[b])
	var piezas: Array[AABB] = []
	var actual := AABB()
	var abierta := false
	var tope := 0.0
	for triangulo in orden:
		if abierta and desde[triangulo] > tope + HUECO_ENTRE_PIEZAS:
			piezas.append(actual)
			abierta = false
		if not abierta:
			actual = AABB(caras[3 * triangulo], Vector3.ZERO)
			tope = hasta[triangulo]
			abierta = true
		for punto in 3:
			actual = actual.expand(caras[3 * triangulo + punto])
		tope = maxf(tope, hasta[triangulo])
	if abierta:
		piezas.append(actual)
	return piezas
