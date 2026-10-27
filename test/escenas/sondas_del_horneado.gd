## Las sondas de un horneado, leídas del archivo y muestreadas como lo hace el motor.
##
## **En headless el `.lmbake` se carga sin sondas**: el servidor de render de prueba no las guarda.
## Por eso se leen del formato binario del recurso, y sólo lo que las sondas necesitan.
##
## Lo que no está horneado toma la luz en un punto, el centro de su caja: la interpola entre las
## cuatro sondas del tetraedro que lo contiene, y la evalúa hacia la normal de cada superficie.
extends RefCounted

const CAMPOS_RESERVADOS := 11
const CON_UID := 2
const CON_CLASE := 4
const PROPIEDAD := "probe_data"
const TEXTO := 5
const BOOLEANO := 2
const CAJA := 15
const DICCIONARIO := 26
const ENTEROS := 32
const VECTORES := 35
const COLORES := 36
const COEFICIENTES := 9

## Los pesos de las bandas del SH al evaluarlo hacia una normal, los del shader del motor.
const C1 := 0.429043
const C2 := 0.511664
const C3 := 0.743125
const C4 := 0.886227
const C5 := 0.247708

var puntos := PackedVector3Array()
var tetraedros := PackedInt32Array()
var sh := PackedColorArray()
var _bytes := PackedByteArray()
var _cursor := 0


func _init(ruta: String) -> void:
	_bytes = FileAccess.get_file_as_bytes(ruta)
	# La firma, el orden de los bytes, el tamaño de los reales y la versión.
	_cursor = 4 * 6
	_texto()
	# Dónde están los metadatos de importación.
	_cursor += 8
	var banderas := _entero()
	if banderas & CON_UID:
		_cursor += 8
	if banderas & CON_CLASE:
		_texto()
	_cursor += 4 * CAMPOS_RESERVADOS
	var nombres := PackedStringArray()
	for indice in _entero():
		nombres.append(_texto())
	_cursor = _propiedad(nombres.find(PROPIEDAD))
	var entradas := _entero() & 0x7fffffff
	for entrada in entradas:
		var clave: Variant = _variante()
		var valor: Variant = _variante()
		match clave:
			"points":
				puntos = valor
			"tetrahedra":
				tetraedros = valor
			"sh":
				sh = valor
		if not (puntos.is_empty() or tetraedros.is_empty() or sh.is_empty()):
			return


## La luz que recibe una superficie que mira hacia `normal`, con las sondas tomadas en `punto`.
func luz_hacia(punto: Vector3, normal: Vector3) -> float:
	var c := _interpolado(punto)
	var n := normal.normalized()
	var luz: Color = (
		c[8] * C1 * (n.x * n.x - n.y * n.y)
		+ c[6] * C3 * n.z * n.z
		+ c[0] * C4
		- c[6] * C5
		+ c[4] * 2.0 * C1 * n.x * n.y
		+ c[7] * 2.0 * C1 * n.x * n.z
		+ c[5] * 2.0 * C1 * n.y * n.z
		+ c[3] * 2.0 * C2 * n.x
		+ c[1] * 2.0 * C2 * n.y
		+ c[2] * 2.0 * C2 * n.z
	)
	return (luz.r + luz.g + luz.b) / 3.0


## Los coeficientes en `punto`: los del tetraedro que lo contiene, pesados por cercanía. Si ninguno
## lo contiene, los del que menos se aleja.
func _interpolado(punto: Vector3) -> Array[Color]:
	var elegido := 0
	var pesos := Vector4(-INF, -INF, -INF, -INF)
	@warning_ignore("integer_division")
	var cuantos := tetraedros.size() / 4
	for tetraedro in cuantos:
		var candidatos := _baricentricas(tetraedro, punto)
		if _menor(candidatos) > _menor(pesos):
			elegido = tetraedro
			pesos = candidatos
		if _menor(pesos) >= 0.0:
			break
	var coeficientes: Array[Color] = []
	for k in COEFICIENTES:
		var suma := Color(0, 0, 0, 0)
		for vertice in 4:
			var sonda := tetraedros[elegido * 4 + vertice]
			suma += sh[sonda * COEFICIENTES + k] * maxf(pesos[vertice], 0.0)
		coeficientes.append(suma)
	return coeficientes


func _baricentricas(tetraedro: int, punto: Vector3) -> Vector4:
	var d := puntos[tetraedros[tetraedro * 4 + 3]]
	var base := Basis(
		puntos[tetraedros[tetraedro * 4]] - d,
		puntos[tetraedros[tetraedro * 4 + 1]] - d,
		puntos[tetraedros[tetraedro * 4 + 2]] - d
	)
	if is_zero_approx(base.determinant()):
		return Vector4(-INF, -INF, -INF, -INF)
	var l := base.inverse() * (punto - d)
	return Vector4(l.x, l.y, l.z, 1.0 - l.x - l.y - l.z)


static func _menor(pesos: Vector4) -> float:
	return minf(minf(pesos.x, pesos.y), minf(pesos.z, pesos.w))


## Dónde empieza el valor de la propiedad: su nombre, por índice, seguido del tipo diccionario.
func _propiedad(nombre: int) -> int:
	for desde in range(_cursor, _bytes.size() - 8):
		if _bytes.decode_u32(desde) == nombre and _bytes.decode_u32(desde + 4) == DICCIONARIO:
			return desde + 8
	return _bytes.size()


func _variante() -> Variant:
	var tipo := _entero()
	var valor: Variant = null
	match tipo:
		TEXTO:
			valor = _texto()
		BOOLEANO:
			valor = _entero() != 0
		CAJA:
			_cursor += 4 * 6
		ENTEROS:
			valor = _lote(4).to_int32_array()
		VECTORES:
			var lote := _lote(12).to_float32_array()
			var vectores := PackedVector3Array()
			for i in range(0, lote.size(), 3):
				vectores.append(Vector3(lote[i], lote[i + 1], lote[i + 2]))
			valor = vectores
		COLORES:
			var lote := _lote(16).to_float32_array()
			var colores := PackedColorArray()
			for i in range(0, lote.size(), 4):
				colores.append(Color(lote[i], lote[i + 1], lote[i + 2], lote[i + 3]))
			valor = colores
		_:
			push_error("sondas_del_horneado: tipo %d sin leer" % tipo)
	return valor


func _lote(tamano: int) -> PackedByteArray:
	var cuantos := _entero()
	var lote := _bytes.slice(_cursor, _cursor + cuantos * tamano)
	_cursor += cuantos * tamano
	return lote


func _entero() -> int:
	var valor := _bytes.decode_u32(_cursor)
	_cursor += 4
	return valor


## Los textos guardan su largo con el nulo del final.
func _texto() -> String:
	var largo := _entero()
	var texto := _bytes.slice(_cursor, _cursor + largo - 1).get_string_from_utf8()
	_cursor += largo
	return texto
