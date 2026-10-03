## Ecuación de onda 2D con bordes reflectantes y pasos acotados por estabilidad.
## Las alturas son sólo dibujo; no representan agua disponible para limpiar.
extends RefCounted

const LADO := 25
const PASO := 1.0 / 120.0
const PROPAGACION := 900.0

var _alturas := PackedFloat32Array()
var _velocidades := PackedFloat32Array()
var _siguientes := PackedFloat32Array()
var _interior := PackedByteArray()
var _activa := false


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


func reiniciar() -> void:
	_alturas.fill(0.0)
	_velocidades.fill(0.0)
	_siguientes.fill(0.0)
	_activa = false


func perturbar(centro: Vector2, fuerza: float) -> void:
	_activa = true
	var suma := 0.0
	var cantidad := 0
	for y: int in LADO:
		for x: int in LADO:
			var indice := y * LADO + x
			if _interior[indice] == 0:
				continue
			var punto := Vector2(x, y) / float(LADO - 1) * 2.0 - Vector2.ONE
			var distancia := punto.distance_squared_to(centro)
			_velocidades[indice] += fuerza * exp(-distancia / 0.045)
			suma += _velocidades[indice]
			cantidad += 1
	# El impulso levanta una cresta y baja su entorno; no eleva todo el nivel del agua.
	for indice: int in _velocidades.size():
		if _interior[indice] != 0:
			_velocidades[indice] -= suma / cantidad


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
		for y: int in LADO:
			for x: int in LADO:
				var indice := y * LADO + x
				if _interior[indice] == 0:
					continue
				var altura := _alturas[indice]
				var laplaciano := 0.0
				for vecino: Vector2i in [
					Vector2i(x - 1, y), Vector2i(x + 1, y), Vector2i(x, y - 1), Vector2i(x, y + 1)
				]:
					if vecino.x < 0 or vecino.y < 0 or vecino.x >= LADO or vecino.y >= LADO:
						continue
					var otra := vecino.y * LADO + vecino.x
					if _interior[otra] != 0:
						laplaciano += _alturas[otra] - altura
				var punto := Vector2(x, y) / float(LADO - 1) * 2.0 - Vector2.ONE
				var fuerza := -aceleracion.dot(punto) * 0.035
				_velocidades[indice] += (laplaciano * PROPAGACION + fuerza) * paso
				_velocidades[indice] *= exp(-paso * 2.8)
				_siguientes[indice] = clampf(altura + _velocidades[indice] * paso, -0.028, 0.028)
		_alturas = _siguientes.duplicate()
		restante -= paso
	var suma := 0.0
	var cantidad := 0
	for indice: int in _alturas.size():
		if _interior[indice] != 0:
			suma += _alturas[indice]
			cantidad += 1
	for indice: int in _alturas.size():
		if _interior[indice] != 0:
			_alturas[indice] -= suma / cantidad
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


## Extiende la altura de la pared: muestrear fuera no fija el borde del agua a cero.
func _altura_de_celda(x: int, y: int) -> float:
	var indice := y * LADO + x
	if _interior[indice] != 0:
		return _alturas[indice]
	var menor := INF
	var altura := 0.0
	for fila: int in range(maxi(0, y - 2), mini(LADO, y + 3)):
		for columna: int in range(maxi(0, x - 2), mini(LADO, x + 3)):
			var otra := fila * LADO + columna
			var distancia := float((fila - y) * (fila - y) + (columna - x) * (columna - x))
			if _interior[otra] != 0 and distancia < menor:
				menor = distancia
				altura = _alturas[otra]
	return altura
