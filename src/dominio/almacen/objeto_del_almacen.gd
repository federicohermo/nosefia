## Qué es una cosa del almacén: su identidad, cómo se llama, si se puede levantar y qué esconde.
##
## Un objeto no hace nada, **es** — igual que `Producto`. La diferencia con aquél es de qué lado
## de la tensión está: `Producto` es lo que se vende y se repone, esto es lo que se agarra y se
## mira. Una lata puede ser las dos cosas, y por eso la identidad es un `StringName` opaco y no
## un `Producto.Id`: atarlos acá obligaría a que todo lo que se puede levantar esté en el
## catálogo, y la mitad de lo que hay para investigar justamente no lo está.
##
## Es un `Resource` y no un `RefCounted` porque cada objeto se escribe a mano en un `.tres` de
## esta carpeta: el contenido investigativo se agrega poniendo un archivo, sin tocar código.
class_name ObjetoDelAlmacen
extends Resource

## El centinela de «no hay nada en la mano». Un `StringName` vacío y no `null`, para que quien
## pregunta no tenga que distinguir dos formas de la misma respuesta.
const SIN_ID := &""

@export var id: StringName = SIN_ID
@export var nombre: String = ""

## Lo fijo del almacén —la puerta, la ventanilla, el comprador— se puede mirar y examinar, y no
## se puede llevar a ningún lado. Arranca en `true` porque la mayoría de los `.tres` son cosas
## sueltas: el que se olvide de declararlo va a estar bien más veces de las que no.
@export var levantable: bool = true

@export var revelacion: Revelacion = null


func es_levantable() -> bool:
	return levantable


func tiene_revelacion() -> bool:
	return revelacion != null and revelacion.dice_algo()


## Lo que el jugador lee de este objeto, antes y después de examinarlo.
##
## Las dos mitades del mordisco del spec: si la revelación ya se viera sin examinar, examinar no
## costaría tiempo y la tensión aritmética del turno se aflojaría sin que nadie lo decida. Un
## objeto sin nada abajo contesta lo mismo las dos veces, y eso es lo que deja escribir la vista
## sin un `if` propio.
func texto_visible(examinado: bool) -> String:
	if examinado and tiene_revelacion():
		return "%s\n%s" % [nombre, revelacion.texto]
	return nombre
