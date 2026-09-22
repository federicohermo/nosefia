## Una conversación de los chats: con quién es y qué se dijo.
##
## **Es el guión y es inmutable.** Qué está leído NO vive acá: vive en `Bandeja`, que nunca se
## guarda. Está medido que dos `load()` del mismo `.tres` devuelven **la misma instancia**, así
## que una marca de leído adentro del recurso sobreviviría a la partida entera — el jugador
## empezaría la noche dos con todo leído, sin un solo error.
##
## Es un `Resource` y no un `RefCounted` porque cada conversación se escribe a mano en un `.tres`
## de esta carpeta: agregar contenido investigativo es poner un archivo, sin tocar código.
##
## El `load()` de `de()` no rompe la pureza de la capa: se ejerce headless, sin escena y sin
## frame, que es la propiedad de la que cuelga todo lo demás. Lo que sí está prohibido acá —y lo
## verifica el gate— es **escribir** al disco.
class_name Conversacion
extends Resource

## Con quién chatea el empleado. Es un `enum` porque el conjunto es cerrado, y cada valor tiene
## su `.tres`: uno sin archivo es una pestaña que el jugador abre y encuentra vacía.
enum Interlocutor { JEFE, PROVEEDOR, DESCONOCIDO }

const CARPETA := "res://src/dominio/investigacion/"

## Qué archivo es de quién. Se busca por el `enum` y no por el orden de la carpeta: un `.tres`
## renombrado tiene que dar rojo acá y no aparecer como la conversación de otro.
const ARCHIVOS := {
	Interlocutor.JEFE: "conversacion_con_el_jefe.tres",
	Interlocutor.PROVEEDOR: "conversacion_con_el_proveedor.tres",
	Interlocutor.DESCONOCIDO: "conversacion_con_el_desconocido.tres",
}

@export var interlocutor: Interlocutor = Interlocutor.JEFE

## Cómo lo lee el jugador en la lista. Va en el recurso y no en la pantalla: los nombres son
## contenido, y escritos en `ui/` se cambiarían en dos lados.
@export var nombre: String = ""

@export var mensajes: Array[Mensaje] = []


## La conversación de ese interlocutor, o `null`.
##
## Un valor del enum sin archivo devuelve `null` en vez de indexar y reventar, y es la misma forma
## que `Catalogo.de()`: con `null` el rojo lo produce una aserción, mientras que un error del
## motor gdUnit4 lo cuenta como *error* y deja el archivo diciendo `PASSED`.
##
## Se usa `load()` y no `preload()` justamente por eso: un `preload` de un archivo que falta es un
## error de parseo, y una suite que no parsea **se descarta en silencio** con exit code 0.
static func de(quien: Interlocutor) -> Conversacion:
	if not ARCHIVOS.has(quien):
		return null
	var recurso := load(CARPETA + ARCHIVOS[quien])
	return recurso as Conversacion


## Todas las conversaciones que hay en disco, en el orden del `enum`.
##
## Saltea la que falta para no meter un `null` en la lista que después recorre la pantalla: así la
## ausencia se lee como una conversación que no está y el conteo del test se pone en rojo
## afirmando, en vez de romperse al desreferenciar.
static func desde_disco() -> Array[Conversacion]:
	var todas: Array[Conversacion] = []
	for quien: Interlocutor in Interlocutor.values():
		var una := de(quien)
		if una == null:
			continue
		todas.append(una)
	return todas
