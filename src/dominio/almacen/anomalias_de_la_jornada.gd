## Las excepciones de disponibilidad y uso que declara cada jornada.
class_name AnomaliasDeLaJornada
extends RefCounted

## El corte de luz de la séptima noche. `SIN_CORTE` es la apertura de siempre; `CORTADO`, entre las
## 20:58 y el clic sobre el panel; `RESTAURADO`, desde el clic hasta el cierre. No hay vuelta
## atrás: una noche con la luz restaurada no se corta de nuevo.
enum Corte { SIN_CORTE, CORTADO, RESTAURADO }

const JORNADA_SIN_AZUL := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1
const JORNADA_DEL_CORTE := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 3

## La hora de ficción del corte. Se escribe como hora y minuto y no como segundos porque es lo que
## dice el diseño, y el reloj de mesa se queda leyéndola.
const HORA_DEL_CORTE := 20
const MINUTO_DEL_CORTE := 58

## Cuánto del turno pasó cuando llega la hora del corte. Sale de la apertura y no se copia.
const SEGUNDOS_HASTA_EL_CORTE: float = (
	((HORA_DEL_CORTE - Reglas.HORA_DE_APERTURA) * Marcador.MINUTOS_POR_HORA + MINUTO_DEL_CORTE)
	* Marcador.SEGUNDOS_POR_MINUTO
)


static func util_disponible(identidad: StringName, jornada: int) -> bool:
	return jornada != JORNADA_SIN_AZUL or identidad != &"jabon_azul"


static func sustituye_azul(identidad: StringName, jornada: int) -> bool:
	return jornada == JORNADA_SIN_AZUL and identidad == id_de_poetico()


static func id_de_poetico() -> StringName:
	return UnidadDeProducto.new(Catalogo.de(Producto.Id.POETICO)).id


## El corte con el que abre toda jornada: el estado vive sólo en la noche en memoria.
static func corte_al_abrir() -> Corte:
	return Corte.SIN_CORTE


## El corte que sigue a lo que queda del turno. Sólo `SIN_CORTE` cambia, y sólo en la jornada del
## corte: lo demás se conserva, así que evaluarlo cada cuadro no lo repite.
static func corte_tras(estado: Corte, jornada: int, restante: float) -> Corte:
	if estado != Corte.SIN_CORTE or jornada != JORNADA_DEL_CORTE:
		return estado
	if Reglas.DURACION_DEL_TURNO - restante < SEGUNDOS_HASTA_EL_CORTE:
		return estado
	return Corte.CORTADO


## Lo que hace el clic sobre el panel. Sólo restablece un corte cortado: repetirlo no cambia nada.
static func restablecer(estado: Corte) -> Corte:
	if estado == Corte.CORTADO:
		return Corte.RESTAURADO
	return estado


## Si hay luz, y con ella computadora y caja registradora accesibles.
static func hay_luz(estado: Corte) -> bool:
	return estado != Corte.CORTADO


## Si el reloj de mesa ya quedó detenido en la hora del corte, hasta el cierre y aunque la luz
## vuelva: lee lo que el turno gastó y no lo que dice el estado.
static func reloj_detenido(jornada: int, restante: float) -> bool:
	return corte_tras(Corte.SIN_CORTE, jornada, restante) == Corte.CORTADO


## Lo que le queda al turno a la hora del corte: lo que el reloj detenido sigue leyendo.
static func restante_al_cortar() -> float:
	return Reglas.DURACION_DEL_TURNO - SEGUNDOS_HASTA_EL_CORTE
