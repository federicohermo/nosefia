## Los valores fijos del juego, en un solo lugar.
##
## Viven acá y no adentro de `turno.gd` porque son los números que se van a tocar todas las
## semanas balanceando, y un valor que vive al lado de la lógica que lo usa termina copiado en
## el segundo lugar que lo necesita. Dos copias de un número no son dos números: son un bug
## esperando a que alguien cambie una.
##
## Son un **primer valor**, no una medición: el GDD no dice cuánto dura un turno ni cuánto
## consume cada tarea. Se ajustan jugando, y ajustarlos no debe obligar a tocar `turno.gd`.
class_name Reglas
extends RefCounted

## Ocho horas de ficción. El reloj de la escena escala esto a los minutos reales de sesión, así
## que cambiarlo cambia también cuánto dura jugar una noche.
const DURACION_DEL_TURNO := 28800.0

const COSTO_DE_LA_CAJA := 1800.0
const COSTO_DE_REPONER := 3600.0
const COSTO_DE_REGISTRAR := 2700.0
const COSTO_DE_LIMPIAR := 3600.0

## Es la más barata en manipulación y la más cara en trayecto: obliga a cruzar el almacén hasta
## el fondo, que es una zona que ninguna otra obligatoria visita.
const COSTO_DE_SACAR_LA_BASURA := 1200.0

## Segundos **reales** de reloj de pared que el jugador pasa caminando en un turno completo, sin
## contar lo que camine investigando. Es el único término del presupuesto que no está en
## segundos de ficción, y por eso es el único que pasa por el `Ritmo`.
##
## Derivado el 2026-09-01, y es una estimación declarada, no una medición: el blockout del
## almacén todavía no existe. Lo único medido acá es `ReglasDelJugador.VELOCIDAD_DE_CAMINATA`,
## 3,5 m/s. Lo supuesto son dos cosas: un almacén de unos 20 m de punta a punta, y unos 18
## cruces para hacer las cinco obligatorias más atender a los dos compradores de la ventanilla
## —dos por tarea y cuatro por comprador, contando que `SACAR_LA_BASURA` va hasta el fondo—.
## Eso da 360 m, o sea 103 segundos en línea recta. El valor declarado no los redondea: los
## sube a 180, un 75 % más, porque nadie camina en línea recta por un local a oscuras que no
## conoce. Ese margen es la parte más blanda de la estimación y está inflado a propósito:
## sobrestimar el trayecto aprieta el presupuesto, subestimarlo lo afloja sin que nadie se entere.
##
## **Es el número de este archivo que va a quedar viejo primero**, y cuando el layout exista hay
## que volver a medirlo acá. Que quede viejo no miente en silencio: el AC7 de `reglas_test.gd`
## se pone en rojo apenas el trayecto se come el piso de investigación.
const SEGUNDOS_DE_TRAYECTO_ESTIMADOS := 180.0

## El piso de investigación, en segundos de ficción: **3600, o sea 60 minutos de juego**, una de
## las ocho horas de la noche.
##
## Existe para que el AC7 sea una afirmación con contenido y no un `> 0` disfrazado. Un margen
## de tres segundos es aritméticamente válido y un juego injugable, y sin este piso la salida
## fácil a un balance roto —agrandar el turno— no le costaría nada a nadie: con el piso, agrandar
## el turno es una decisión de diseño que hay que escribir acá.
const MARGEN_MINIMO := 3600.0

## A los cuatro apercibimientos lo echan, y se compara con `>=` y no con `==`: una jornada grave
## sube de a dos, así que el contador puede saltar de 3 a 5 sin pisar el 4.
##
## El 4 es una decisión de balance y no la lectura literal de la fuente: el GDD dice «más de dos
## días seguidos» y el formulario de la primera entrega dice «tres jornadas consecutivas», o sea
## que las dos piden **tres** jornadas graves. El prototipo elige **dos**, a propósito, porque
## con 4 los tres caminos al despido quedan a la misma distancia y la progresión se lee de un
## vistazo: dos jornadas graves despiden, una grave más dos avisos despiden, y cuatro avisos
## despiden. Queda escrito acá para que nadie lo «arregle» de vuelta.
const APERCIBIMIENTOS_HASTA_EL_DESPIDO := 4

const APERCIBIMIENTOS_POR_AVISO := 1

## Vale el doble que un aviso, y eso es lo que hace que las tres bandas pesen distinto también
## sobre el despido: a la banda grave le alcanza con una jornada menos.
const APERCIBIMIENTOS_POR_BANDA_GRAVE := 2


## Cuántos segundos de turno consume hacer una tarea de este tipo.
##
## Un tipo sin costo devuelve `0.0`, y eso pone en rojo a `reglas_test.gd`: es la forma de que
## agregar un sexto valor al enum sin darle costo no pase en silencio.
static func costo_de(tipo: Tarea.Tipo) -> float:
	match tipo:
		Tarea.Tipo.CAJA:
			return COSTO_DE_LA_CAJA
		Tarea.Tipo.REPONER:
			return COSTO_DE_REPONER
		Tarea.Tipo.REGISTRAR:
			return COSTO_DE_REGISTRAR
		Tarea.Tipo.LIMPIAR:
			return COSTO_DE_LIMPIAR
		Tarea.Tipo.SACAR_LA_BASURA:
			return COSTO_DE_SACAR_LA_BASURA
	return 0.0
