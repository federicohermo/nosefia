## El cuaderno donde el empleado anota lo que va encontrando.
##
## **Es una sola instancia y vive en el sistema, no en la pantalla.** Si lo construyera la app de
## notas, esconder el panel al pasar a los chats tiraría todo lo anotado — sin un solo error, y
## con los seis nodos en verde: `ui/` no lleva test obligatorio.
##
## **Qué llega a ser una nota es una regla del juego** y por eso está acá: una sin título es un
## renglón que el jugador no va a poder encontrar después, y guardarla igual llenaría el cuaderno
## de entradas que no dicen nada.
class_name Cuaderno
extends RefCounted

## En el orden en que se escribieron, que es el orden en que se leen.
var _notas: Array[Nota] = []


## Anota y devuelve la nota, o `null` si no llegó a ser una.
##
## El título se recorta antes de mirarlo: sin eso, un renglón de espacios pasaría por título y la
## nota quedaría en la lista sin nada que la identifique.
func escribir(titulo: String, texto: String) -> Nota:
	if titulo.strip_edges().is_empty():
		return null
	var nota := Nota.new(titulo, texto)
	_notas.append(nota)
	return nota


## Las notas, **como copia**. Medido para los arrays de este repo: uno devuelto sin `duplicate()`
## es el mismo array, y un `clear()` afuera vacía el original — o sea que quien lo mire para
## dibujarlo lo puede borrar.
func notas() -> Array[Nota]:
	return _notas.duplicate()


func cuantas() -> int:
	return _notas.size()
