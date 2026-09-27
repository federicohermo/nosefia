## Cuánto se apaga un sonido del espacio según los obstáculos entre él y el oído del jugador.
##
## Trabaja con un nivel y no con la cantidad entera: el nivel se acerca a la cantidad de a poco,
## y así abrir una puerta mientras algo suena no da un salto.
class_name ApagadoPorObstaculos
extends RefCounted

## Desde esta cantidad de obstáculos no apaga más. Primer valor: ver OQ-AMB-008.
const MAXIMO := 3

## Cuánto baja cada obstáculo, en dB. Primer valor: ver OQ-AMB-008.
const VOLUMEN_POR_OBSTACULO_DB := -6.0

const SIN_CORTE_HZ := 20500.0

## El corte del pasa-bajos para cada cantidad de obstáculos, de cero al máximo. Primer valor:
## ver OQ-AMB-008.
const CORTES_HZ: Array[float] = [SIN_CORTE_HZ, 2500.0, 1200.0, 600.0]

## Cuánto tarda el nivel en moverse un obstáculo. Primer valor: ver OQ-AMB-008.
const SEGUNDOS_POR_OBSTACULO := 0.3

## El nombre del método con el que un cuerpo del mundo contesta su puerta.
const METODO_DE_LA_PUERTA := &"puerta"

## En metros. Lo que tapa a menos de esto de lo anterior es el mismo obstáculo: una pared del
## local es más de un sólido.
const GROSOR_DE_UN_OBSTACULO := 0.6


## Cuántos obstáculos hay, hasta el máximo, según a qué distancia, en orden, entra el rayo en
## cada cosa que tapa.
static func contar(entradas: Array[float]) -> int:
	var cantidad := 0
	var anterior := -INF
	for entrada in entradas:
		if entrada - anterior > GROSOR_DE_UN_OBSTACULO:
			cantidad += 1
		anterior = entrada
	return mini(cantidad, MAXIMO)


static func volumen_db(nivel: float) -> float:
	return VOLUMEN_POR_OBSTACULO_DB * clampf(nivel, 0.0, MAXIMO)


static func corte_hz(nivel: float) -> float:
	var acotado := clampf(nivel, 0.0, MAXIMO)
	var abajo := floori(acotado)
	if abajo >= MAXIMO:
		return CORTES_HZ[MAXIMO]
	return lerpf(CORTES_HZ[abajo], CORTES_HZ[abajo + 1], acotado - abajo)


## El nivel después de acercarse, durante esos segundos, a la cantidad de obstáculos.
static func acercar(nivel: float, cantidad: int, segundos: float) -> float:
	return move_toward(nivel, mini(cantidad, MAXIMO), segundos / SEGUNDOS_POR_OBSTACULO)
