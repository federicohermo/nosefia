## Los valores fijos de agarrar, llevar y examinar los objetos del almacén.
##
## Es un archivo aparte de `reglas.gd` y de `reglas_del_jugador.gd` por el mismo criterio que
## separa a esos dos: no es de qué trata el número, es quién lo toca y probando qué. `reglas.gd`
## se toca discutiendo el balance de la noche; `reglas_del_jugador.gd`, probando el movimiento;
## esto, probando cuánto cuesta levantar una lata y mirarla de cerca. Entre los tres no hay una
## sola constante repetida.
class_name ReglasDeLosObjetos
extends RefCounted

## Cuántas cosas se pueden llevar a la vez. Vale 1 y no es un detalle de comodidad: es la mitad
## del precio en tiempo de sacar la basura, que el contrato escribe como
## `BOLSAS_DE_LA_JORNADA > MANOS_DISPONIBLES` — o sea, más de un viaje. Subirlo a 2 acorta los
## viajes de sacar la basura.
const MANOS_DISPONIBLES := 1

## Metros desde el ojo, y las tres se ordenan de la más cerca a la más lejos.
##
## Examinar acerca el objeto a la cara, llevarlo lo deja a la altura de la mano y soltarlo lo
## aleja. Ninguna llega a `ReglasDelJugador.ALCANCE_DE_LA_MIRA`: una que se pasara dejaría al
## jugador soltando cosas afuera del rayo, o sea que no las podría volver a levantar.
const DISTANCIA_DE_EXAMEN := 0.5
const DISTANCIA_DE_CARGA := 0.75
const DISTANCIA_DE_SOLTADO := 1.2

## A cuántos radios de lo examinado queda su centro del ojo, cuando no entra a
## `DISTANCIA_DE_EXAMEN`.
##
## Sale de la cámara y de lo que se lleva, y el margen entre los dos es chico a propósito. Con
## menos de 1 alguna rotación lo mete adentro de la cámara. Con menos de la inversa del seno de
## medio campo de visión, las esquinas salen del cuadro. Con más, la caja grande queda más lejos
## que donde se la lleva, y examinarla la aleja en vez de acercarla. Cuánto margen dejar con el
## borde del cuadro no lo fija el GDD: es pregunta abierta.
const RADIOS_DE_EXAMEN := 1.7

## Los nombres de las dos acciones que este spec agrega al `InputMap`. Tienen que coincidir letra
## por letra con la sección `[input]` de `project.godot`, y el test del objeto agarrable afirma
## justamente eso: es la única forma de que ese par de `String` no se separe en silencio.
##
## El clic izquierdo hace las dos cosas —agarrar y soltar— a propósito: es el mismo gesto, y
## pedirle al jugador dos teclas para levantar y dejar una lata le agrega ceremonia a lo que
## tiene que ser barato.
const ACCION_AGARRAR := "agarrar"
const ACCION_EXAMINAR := "examinar"

## El contrato de «con esto se puede interactuar» es el nombre de un MÉTODO, y eso no es una
## preferencia de estilo: `sistemas/` no puede nombrar un `class_name` de `escenas/` —el gate de
## capas lo caza sin que haya un solo `preload`— y `dominio/` tampoco, porque lo que se agarra es
## un `Node3D`. O sea que el contrato no se puede escribir como tipo desde ninguna de las capas
## que lo necesitan. Vive acá, al lado del grupo de Godot que declara `ReglasDelJugador`, porque
## son las dos mitades de la misma cosa: el grupo dice que se puede mirar, el método que
## contesta algo.
const METODO_INTERACTUAR := "interactuar"

## Y «esto se corre de un empujón» es otro nombre de método, por la misma razón: el jugador no
## puede nombrar la caja sin cruzar la dirección de las capas.
const METODO_EMPUJAR := "empujar"

## Dónde arrancó la noche lo que se agarra, en coordenadas del mundo. Es un método por el mismo
## motivo: la red de seguridad, en `sistemas/`, no puede nombrar el tipo que lo contesta.
const METODO_LUGAR_DE_ORIGEN := "lugar_de_origen"

## La señal de la caja que se va a correr. La escuchan el puesto y la red de seguridad.
const SENAL_EMPUJADA := &"empujada"

## Qué parte del paso que el jugador no pudo dar recibe lo que le estorba. Con 1 la caja se
## mueve a su velocidad y no pesa nada; con 0 no se mueve y le tapa el paso. El medio es lo que
## hace que correr una caja cueste caminar más lento, que es el peso que se quiere.
const ARRASTRE_DE_LA_CAJA := 0.5

## Cuánto tiene que mirar hacia arriba una superficie para que se pueda apoyar una caja encima.
## Es la componente vertical de su normal: con 1 sólo valdría lo perfectamente plano, con 0
## valdría una pared.
const APOYO_HORIZONTAL := 0.7

## La capa de física donde viven los contornos de los muebles: la caja que envuelve a cada uno.
## Es la número 4, y su nombre está declarado en `project.godot`. Quien la mira no entra al
## mueble: el jugador, y el lugar donde se deja un producto soltado.
const CAPA_DEL_CONTORNO := 8

## Cuánto se le descuenta a una forma para preguntar si entra o si atraviesa algo, en metros.
## Apoyarse sobre algo es tocarlo, así que la medida exacta contesta que choca. Lo preguntan el
## puesto al ubicar la caja y el test al comprobar que no atraviesa nada: es el mismo número.
const ROCE := 0.004

## Cuánto gira por segundo lo examinado con cada tecla de movimiento, en radianes. Media vuelta
## tarda poco más de un segundo: alcanza para leer la cara de atrás sin pasarse de largo.
const VELOCIDAD_DE_GIRO_DEL_EXAMEN := 2.5


## Si a una caja se le puede sacar una unidad: a toda la que esté apoyada, en cualquier lado.
##
## **Lo que cobra el traslado es que la caja llevada no entrega**, no la altura a la que quede.
## Antes el corte era una altura, y una caja apoyada en un mostrador, en un estante o sobre otra
## caja no entregaba nada sin que nada dijera por qué.
static func se_puede_retirar(la_lleva_el_jugador: bool) -> bool:
	return not la_lleva_el_jugador


static func se_puede_apoyar_en(inclinacion: float) -> bool:
	return inclinacion >= APOYO_HORIZONTAL


## Si lo soltado se puede dejar sobre la superficie que la mira toca. `debajo` es `null` cuando
## la superficie es del mundo fijo.
static func admite_lo_soltado(inclinacion: float, debajo: ObjetoDelAlmacen) -> bool:
	return se_puede_apoyar_en(inclinacion) and (debajo == null or debajo.admite_encima)


## El giro de lo examinado en este cuadro: `x` sobre el eje vertical, `y` sobre el horizontal.
static func giro_del_examen(entrada: Vector2, segundos: float) -> Vector2:
	return entrada * VELOCIDAD_DE_GIRO_DEL_EXAMEN * segundos


## Metros desde el ojo hasta el centro de lo examinado, según el radio de la esfera que lo
## envuelve alrededor de donde gira.
##
## Lo que entra a `DISTANCIA_DE_EXAMEN` se examina ahí: una lata no tiene por qué alejarse
## porque exista una caja grande.
static func distancia_de_examen(radio: float) -> float:
	return maxf(DISTANCIA_DE_EXAMEN, radio * RADIOS_DE_EXAMEN)
