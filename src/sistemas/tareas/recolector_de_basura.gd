## Traduce el tiro aceptado: entrega el cuerpo, descuenta la unidad y cuenta sólo las bolsas.
class_name RecolectorDeBasura
extends Node

signal bolsa_depositada(depositadas: int)
signal objeto_tirado(nodo: Node3D)

@export var reloj: RelojDelTurno
@export var agarre: Agarre
@export var repositor: Repositor

var _tarea: TareaDeLaBasura


func arrancar(una_tarea: TareaDeLaBasura) -> void:
	_tarea = una_tarea


func tarea() -> TareaDeLaBasura:
	return _tarea


func pedir_tirar(recibe: bool) -> ReglasDeLaBasura.Tiro:
	if _tarea == null or reloj == null or agarre == null or repositor == null:
		push_error("Recolector sin cablear: revisar almacen.tscn y almacen.gd")
		return ReglasDeLaBasura.Tiro.MANO_VACIA
	var sostenido := agarre.manos().sostenido()
	var resultado := ReglasDeLaBasura.tiro(sostenido, recibe)
	if resultado != ReglasDeLaBasura.Tiro.TIRADO:
		return resultado
	if sostenido is UnidadDeProducto:
		repositor.estante().desechar(sostenido)
	var nodo := agarre.entregar()
	objeto_tirado.emit(nodo)
	if _tarea.depositar(sostenido.id) != TareaDeLaBasura.Resultado.DEPOSITADA:
		return resultado
	bolsa_depositada.emit(_tarea.depositadas())
	if _tarea.completada():
		reloj.completar(reloj.obligatoria(Tarea.Tipo.SACAR_LA_BASURA))
	return resultado
