## La app de la caja: qué hay que registrar hoy y qué le falta a la góndola.
##
## **No decide nada.** Cuáles son los del día, cuál ya se pasó y qué cuenta como faltante son
## preguntas de `CajaRegistradora` y de `Inventario`, que es donde tienen test. Acá se arman
## botones con lo que ellos contestan.
##
## Va en `diegetica/` y no en `interrupciones/`, que es el criterio de esa carpeta —si el reloj
## sigue corriendo—: mirar la caja cuesta minutos del turno.
class_name AppCaja
extends Control

signal registro_pedido(producto: Producto)

## Lo único propio de esta capa son las palabras. Viven acá y **no** además en el `.tscn`.
const TEXTO_DEL_TITULO := "Caja — registrar los del día"
const TEXTO_DEL_FALTANTE := "Falta en góndola: %s"
const TEXTO_SIN_FALTANTES := "La góndola está al día."
const TEXTO_DEL_BOTON := "%s — sin registrar"
const TEXTO_YA_REGISTRADO := "%s — registrado"

@export var _titulo: Label
@export var _botones: VBoxContainer
@export var _faltantes: Label


func _ready() -> void:
	_titulo.text = TEXTO_DEL_TITULO


## Repinta la lista del día y el aviso de lo que falta.
##
## Recibe la caja en vez de ir a buscarla: esta app no es dueña de nada, y quien la tiene es el
## sistema. Es lo que la deja dibujarse sin conocer al inventario.
func mostrar(caja: CajaRegistradora) -> void:
	for viejo in _botones.get_children():
		_botones.remove_child(viejo)
		viejo.queue_free()
	for producto in caja.del_dia():
		_botones.add_child(_boton_de(producto, caja.esta_registrado(producto)))
	_faltantes.text = _aviso_de(caja.faltantes())


## Un botón por producto del día, deshabilitado si ya se pasó.
func _boton_de(producto: Producto, registrado: bool) -> Button:
	var boton := Button.new()
	boton.text = (TEXTO_YA_REGISTRADO if registrado else TEXTO_DEL_BOTON) % producto.nombre
	boton.disabled = registrado
	boton.pressed.connect(func() -> void: registro_pedido.emit(producto))
	return boton


func _aviso_de(faltantes: Array[Producto]) -> String:
	if faltantes.is_empty():
		return TEXTO_SIN_FALTANTES
	var nombres: Array[String] = []
	for producto in faltantes:
		nombres.append(producto.nombre)
	return TEXTO_DEL_FALTANTE % ", ".join(nombres)
