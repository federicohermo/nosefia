## Qué suena en el juego: una fila por evento, en un archivo que se edita sin tocar código.
##
## **Es la decisión entera del spec.** La versión ingenua —un autoload con un `match` gigante en
## `sistemas/`— tiene cobertura cero para siempre: un sistema de audio sólo se prueba escuchando.
## Con la tabla acá abajo, lo que se puede afirmar es que **cubre todos los eventos** y que
## **ninguna fila sale por un bus que no existe**, y las dos cosas corren headless.
##
## Es un `Resource` porque agregar un sonido tiene que ser editar un `.tres`. El `load()` no rompe
## la pureza de la capa: se ejerce sin escena y sin frame, que es la propiedad de la que cuelga
## todo lo demás. Lo que sí está prohibido acá —y lo verifica el gate— es **escribir** al disco.
class_name TablaDeSonidos
extends Resource

const RUTA := "res://src/dominio/ambiente/tabla_de_sonidos.tres"

@export var entradas: Array[EntradaSonora] = []


## La tabla que está en disco, o `null` si no se pudo leer.
##
## Se usa `load()` y no `preload()` a propósito: un `preload` de un archivo que falta es un error
## de parseo, y **una suite que no parsea se descarta en silencio** con exit code 0. Con `load()`
## el rojo lo produce una aserción sobre un nulo.
static func desde_disco() -> TablaDeSonidos:
	var recurso := load(RUTA)
	return recurso as TablaDeSonidos


## La fila de ese evento, o `null` si no tiene.
##
## `null` y no una fila vacía: quien pide un sonido que no está tiene que poder declararlo, y una
## fila muda inventada acá lo dejaría creyendo que pidió bien.
func de(evento: EntradaSonora.Evento) -> EntradaSonora:
	for entrada in entradas:
		if entrada != null and entrada.evento == evento:
			return entrada
	return null


## Si hay una fila por cada valor del `enum`.
##
## Se recorre el `enum` y no se cuentan las filas: dos filas del mismo evento darían el número
## correcto con un evento sin sonido, y el jugador no escucharía nada sin que nada lo diga.
func cubre_todos() -> bool:
	return eventos_sin_fila().is_empty()


## Los eventos que la tabla no cubre, para que el rojo diga cuál falta y no sólo que falta uno.
func eventos_sin_fila() -> Array:
	var faltan := []
	for evento: EntradaSonora.Evento in EntradaSonora.Evento.values():
		if de(evento) == null:
			faltan.append(evento)
	return faltan


## Las filas que saldrían por un bus que no está declarado. Ésas son las que no se pueden dejar
## pasar: caen a `Master` en silencio.
func filas_invalidas() -> Array[EntradaSonora]:
	var invalidas: Array[EntradaSonora] = []
	for entrada in entradas:
		if entrada == null or not entrada.es_valida():
			invalidas.append(entrada)
	return invalidas
