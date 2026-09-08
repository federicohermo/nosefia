## La app de notas: lo anotado, y el renglón para anotar una más.
##
## **No decide qué llega a ser una nota.** Que una sin título no se guarde es una regla del juego
## y vive en `Cuaderno`, que es donde tiene test: escrita acá nacería sin ninguno y los seis nodos
## darían verde igual.
##
## Va en `diegetica/` porque anotar cuesta minutos del turno, igual que leer.
class_name AppNotas
extends Control

signal escritura_pedida(titulo: String, texto: String)

const TEXTO_DEL_TITULO := "Notas"
const TEXTO_DEL_BOTON := "Anotar"
const PISTA_DEL_TITULO := "Título"
const PISTA_DEL_TEXTO := "Qué viste"
const TEXTO_DE_LA_NOTA := "%s\n%s"

@export var _titulo: Label
@export var _lista: VBoxContainer
@export var _campo_titulo: LineEdit
@export var _campo_texto: TextEdit
@export var _anotar: Button


func _ready() -> void:
	_titulo.text = TEXTO_DEL_TITULO
	_anotar.text = TEXTO_DEL_BOTON
	_campo_titulo.placeholder_text = PISTA_DEL_TITULO
	_campo_texto.placeholder_text = PISTA_DEL_TEXTO
	_anotar.pressed.connect(_al_anotar)


## Repinta el cuaderno entero.
##
## Recibe las notas en vez de ir a buscarlas: esta app no es dueña de ninguna, y el cuaderno vive
## en el sistema — si fuera de acá, cambiar de app lo tiraría.
func mostrar(notas: Array[Nota]) -> void:
	for viejo in _lista.get_children():
		_lista.remove_child(viejo)
		viejo.queue_free()
	for nota in notas:
		var etiqueta := Label.new()
		etiqueta.text = TEXTO_DE_LA_NOTA % [nota.titulo(), nota.texto()]
		etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_lista.add_child(etiqueta)


## Vacía los campos. Lo llama quien haya escrito de verdad: si se vaciaran solos, un título en
## blanco se llevaría puesto el cuerpo que el jugador ya había tipeado.
func limpiar_campos() -> void:
	_campo_titulo.text = ""
	_campo_texto.text = ""


func _al_anotar() -> void:
	escritura_pedida.emit(_campo_titulo.text, _campo_texto.text)
