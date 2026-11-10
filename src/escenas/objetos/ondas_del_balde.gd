## Las ondas del balde como ocho modos de un recipiente redondo, cada uno un oscilador amortiguado.
## La CPU sólo avanza los ocho osciladores. El shader suma las formas en cada vértice y píxel.
## Las alturas son sólo dibujo; no representan agua disponible para limpiar.
extends RefCounted

const MODOS := 8
const PASO := 1.0 / 60.0
const AMORTIGUACION := 2.8
# Con la velocidad de la onda en 2,5 radios por segundo, cada forma vibra a 2,5 por su número de
# onda. El orden es el de `forma_en`.
const FRECUENCIAS: Array[float] = [7.9, 11.8, 11.8, 7.6, 7.6, 10.5, 10.5, 15.7]
# La integral de cada forma al cuadrado sobre el disco de radio uno.
const NORMAS: Array[float] = [1.0548, 0.8208, 0.8208, 0.9074, 0.9074, 0.7915, 0.7915, 1.5708]
# Lo que una gota de ancho 0,045 aporta a cada modo, por unidad de su forma en el centro.
const AREA_DE_LA_GOTA := 0.045 * PI
# La aceleración empuja el agua en plano: sólo la forma de un nodo radial la recibe.
const EMPUJE := 0.035 * 0.4179
# El modo axial se corre para que el agua no suba ni baje de nivel al oscilar.
const MEDIA_DEL_MODO_AXIAL := 0.405

var _amplitudes := PackedFloat32Array()
var _velocidades := PackedFloat32Array()
var _activa := false


func _init() -> void:
	_amplitudes.resize(MODOS)
	_velocidades.resize(MODOS)


func reiniciar() -> void:
	_amplitudes.fill(0.0)
	_velocidades.fill(0.0)
	_activa = false


## Un golpe en `centro`, en coordenadas del disco de radio uno.
func perturbar(centro: Vector2, fuerza: float) -> void:
	_activa = true
	for modo: int in MODOS:
		_velocidades[modo] += fuerza * forma_en(modo, centro) * AREA_DE_LA_GOTA / NORMAS[modo]


## Una cota de la altura mayor: la suma de cada amplitud por el máximo de su forma.
func amplitud() -> float:
	var suma := absf(_amplitudes[0]) * (1.0 + MEDIA_DEL_MODO_AXIAL)
	for modo: int in range(1, MODOS):
		suma += absf(_amplitudes[modo])
	return suma


func avanzar(delta: float, aceleracion: Vector2) -> void:
	if not _activa and aceleracion.length_squared() < 0.0001:
		return
	_activa = true
	var restante := minf(delta, 0.1)
	while restante > 0.0:
		var paso := minf(PASO, restante)
		var amortiguacion := exp(-paso * AMORTIGUACION)
		for modo: int in MODOS:
			var omega: float = FRECUENCIAS[modo]
			var fuerza := -omega * omega * _amplitudes[modo]
			if modo == 1:
				fuerza += aceleracion.x * EMPUJE
			elif modo == 2:
				fuerza += aceleracion.y * EMPUJE
			_velocidades[modo] = (_velocidades[modo] + fuerza * paso) * amortiguacion
			_amplitudes[modo] += _velocidades[modo] * paso
		restante -= paso
	if amplitud() < 0.000001 and aceleracion.length_squared() < 0.0001:
		var rapidez := 0.0
		for velocidad: float in _velocidades:
			rapidez = maxf(rapidez, absf(velocidad))
		if rapidez < 0.00001:
			reiniciar()


## Las ocho amplitudes, en el orden de `forma_en`, para el shader.
func amplitudes() -> PackedFloat32Array:
	return _amplitudes.duplicate()


func altura_en(punto: Vector2) -> float:
	var altura := 0.0
	for modo: int in MODOS:
		altura += _amplitudes[modo] * forma_en(modo, punto)
	return altura


## Cada forma tiene pendiente radial cero en la pared, así la onda se refleja contra ella.
## `agua_y_manchas.gdshader` repite estas formas; un cambio acá va también allá.
static func forma_en(modo: int, punto: Vector2) -> float:
	var radio := minf(punto.length(), 1.0)
	var angulo := punto.angle()
	var anillo := sin(radio * PI * 0.5)
	match modo:
		0:
			return cos(radio * PI) + MEDIA_DEL_MODO_AXIAL
		1:
			return sin(radio * PI * 1.5) * cos(angulo)
		2:
			return sin(radio * PI * 1.5) * sin(angulo)
		3:
			return anillo * anillo * cos(angulo * 2.0)
		4:
			return anillo * anillo * sin(angulo * 2.0)
		5:
			return anillo * anillo * anillo * cos(angulo * 3.0)
		6:
			return anillo * anillo * anillo * sin(angulo * 3.0)
		_:
			return cos(radio * TAU)
