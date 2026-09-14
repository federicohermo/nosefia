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
## del precio en tiempo de sacar la basura, que el spec 015 escribe como
## `BOLSAS_DE_LA_JORNADA > MANOS_DISPONIBLES` — o sea, más de un viaje. Subirlo a 2 le afloja el
## costo a media tarea obligatoria sin tocar `reglas.gd`.
const MANOS_DISPONIBLES := 1

## Metros desde el ojo, y las tres se ordenan de la más cerca a la más lejos.
##
## Examinar acerca el objeto a la cara, llevarlo lo deja a la altura de la mano y soltarlo lo
## aleja. Ninguna llega a `ReglasDelJugador.ALCANCE_DE_LA_MIRA`: una que se pasara dejaría al
## jugador soltando cosas afuera del rayo, o sea que no las podría volver a levantar.
const DISTANCIA_DE_EXAMEN := 0.5
const DISTANCIA_DE_CARGA := 0.75
const DISTANCIA_DE_SOLTADO := 1.2

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
