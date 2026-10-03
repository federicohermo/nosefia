## Ecuación de onda 2D con bordes reflectantes y pasos acotados por estabilidad.
## Las alturas son sólo dibujo; no representan agua disponible para limpiar.
extends RefCounted

const LADO := 25
# Con este coeficiente, 1/60 s queda por debajo del límite 1/sqrt(2 * PROPAGACION).
const PASO := 1.0 / 60.0
const PROPAGACION := 900.0

var _alturas := PackedFloat32Array()
var _velocidades := PackedFloat32Array()
var _siguientes := PackedFloat32Array()
var _interior := PackedByteArray()
var _activa := false
var _celdas := PackedInt32Array()
var _vecinos := PackedInt32Array()
var _puntos := PackedVector2Array()
var _extension := PackedInt32Array()
var _muestras := PackedInt32Array()
var _pesos := PackedVector2Array()


func _init() -> void:
	_alturas.resize(LADO * LADO)
	_velocidades.resize(LADO * LADO)
	_siguientes.resize(LADO * LADO)
	_interior.resize(LADO * LADO)
	for y: int in LADO:
		for x: int in LADO:
			var p := Vector2(x, y) / float(LADO - 1) * 2.0 - Vector2.ONE
			var dentro := true
			for pared: int in 12:
				var normal := Vector2(cos(pared * PI / 6.0), sin(pared * PI / 6.0))
				dentro = dentro and normal.dot(p) <= 0.97
			_interior[y * LADO + x] = int(dentro)
	# La pared y sus vecinos no cambian durante la simulación.
	_puntos.resize(LADO * LADO)
	_extension.resize(LADO * LADO)
	_extension.fill(-1)
	for y: int in LADO:
		for x: int in LADO:
			var indice := y * LADO + x
			_puntos[indice] = Vector2(x, y) / float(LADO - 1) * 2.0 - Vector2.ONE
			if _interior[indice] != 0:
				_celdas.append(indice)
				_extension[indice] = indice
				for vecino: Vector2i in [
					Vector2i(x - 1, y), Vector2i(x + 1, y), Vector2i(x, y - 1), Vector2i(x, y + 1)
				]:
					var otra := vecino.y * LADO + vecino.x
					_vecinos.append(
						(
							otra
							if otra >= 0 and otra < _interior.size() and _interior[otra] != 0
							else indice
						)
					)
			else:
				var menor := INF
				for fila: int in range(maxi(0, y - 2), mini(LADO, y + 3)):
					for columna: int in range(maxi(0, x - 2), mini(LADO, x + 3)):
						var otra := fila * LADO + columna
						var distancia := float(
							(fila - y) * (fila - y) + (columna - x) * (columna - x)
						)
						if _interior[otra] != 0 and distancia < menor:
							menor = distancia
							_extension[indice] = otra


func reiniciar() -> void:
	_alturas.fill(0.0)
	_velocidades.fill(0.0)
	_siguientes.fill(0.0)
	_activa = false


func perturbar(centro: Vector2, fuerza: float) -> void:
	_activa = true
	var suma := 0.0
	for indice: int in _celdas:
		var distancia := _puntos[indice].distance_squared_to(centro)
		_velocidades[indice] += fuerza * exp(-distancia / 0.045)
		suma += _velocidades[indice]
	# El impulso levanta una cresta y baja su entorno; no eleva todo el nivel del agua.
	var media := suma / _celdas.size()
	for indice: int in _celdas:
		_velocidades[indice] -= media


func amplitud() -> float:
	var mayor := 0.0
	for altura: float in _alturas:
		mayor = maxf(mayor, absf(altura))
	return mayor


func avanzar(delta: float, aceleracion: Vector2) -> void:
	if not _activa and aceleracion.length_squared() < 0.0001:
		return
	_activa = true
	var restante := minf(delta, 0.1)
	while restante > 0.0:
		var paso := minf(PASO, restante)
		var amortiguacion := exp(-paso * 2.8)
		for celda: int in _celdas.size():
			var indice := _celdas[celda]
			var altura := _alturas[indice]
			var vecino := celda * 4
			var laplaciano := (
				_alturas[_vecinos[vecino]]
				+ _alturas[_vecinos[vecino + 1]]
				+ _alturas[_vecinos[vecino + 2]]
				+ _alturas[_vecinos[vecino + 3]]
				- altura * 4.0
			)
			var fuerza := -aceleracion.dot(_puntos[indice]) * 0.035
			_velocidades[indice] += (laplaciano * PROPAGACION + fuerza) * paso
			_velocidades[indice] *= amortiguacion
			_siguientes[indice] = clampf(altura + _velocidades[indice] * paso, -0.028, 0.028)
		_alturas = _siguientes.duplicate()
		restante -= paso
	var suma := 0.0
	for indice: int in _celdas:
		suma += _alturas[indice]
	var media := suma / _celdas.size()
	for indice: int in _celdas:
		_alturas[indice] -= media
	_siguientes = _alturas.duplicate()
	if amplitud() < 0.000001 and aceleracion.length_squared() < 0.0001:
		var rapidez := 0.0
		for velocidad: float in _velocidades:
			rapidez = maxf(rapidez, absf(velocidad))
		if rapidez < 0.00001:
			reiniciar()


func altura_en(punto: Vector2) -> float:
	var p := (punto.clamp(-Vector2.ONE, Vector2.ONE) + Vector2.ONE) * 0.5 * (LADO - 1)
	var x := mini(int(p.x), LADO - 2)
	var y := mini(int(p.y), LADO - 2)
	var a := lerpf(_altura_de_celda(x, y), _altura_de_celda(x + 1, y), p.x - x)
	var b := lerpf(_altura_de_celda(x, y + 1), _altura_de_celda(x + 1, y + 1), p.x - x)
	return lerpf(a, b, p.y - y)


## La malla del recipiente siempre consulta los mismos puntos del campo.
func preparar_muestras(puntos: PackedVector2Array) -> void:
	_muestras.clear()
	_pesos.clear()
	for punto: Vector2 in puntos:
		var p := (punto.clamp(-Vector2.ONE, Vector2.ONE) + Vector2.ONE) * 0.5 * (LADO - 1)
		var x := mini(int(p.x), LADO - 2)
		var y := mini(int(p.y), LADO - 2)
		_pesos.append(Vector2(p.x - x, p.y - y))
		for celda: int in [
			y * LADO + x, y * LADO + x + 1, (y + 1) * LADO + x, (y + 1) * LADO + x + 1
		]:
			_muestras.append(maxi(0, _extension[celda]))


func alturas_muestreadas() -> PackedFloat32Array:
	var alturas := PackedFloat32Array()
	alturas.resize(_pesos.size())
	for indice: int in alturas.size():
		var celda := indice * 4
		var peso := _pesos[indice]
		var a := lerpf(_alturas[_muestras[celda]], _alturas[_muestras[celda + 1]], peso.x)
		var b := lerpf(_alturas[_muestras[celda + 2]], _alturas[_muestras[celda + 3]], peso.x)
		alturas[indice] = lerpf(a, b, peso.y)
	return alturas


## Extiende la altura de la pared: muestrear fuera no fija el borde del agua a cero.
func _altura_de_celda(x: int, y: int) -> float:
	var indice := _extension[y * LADO + x]
	return _alturas[indice] if indice >= 0 else 0.0
