## Traduce el tiro aceptado: entrega el cuerpo, descuenta la unidad y cuenta sólo las bolsas y los
## vencidos.
class_name RecolectorDeBasura
extends Node

signal bolsa_sacada(tacho: TareaDeLaBasura.Tacho)

signal bolsa_depositada(depositadas: int)
signal objeto_tirado(nodo: Node3D)
## Cada pedido de tirar, con lo que se llevaba y cómo salió: lo lee el pensamiento del gesto.
signal tiro_pedido(sostenido: ObjetoDelAlmacen, tiro: ReglasDeLaBasura.Tiro)

@export var reloj: RelojDelTurno
@export var agarre: Agarre
@export var repositor: Repositor
@export var bolsas: Array[Node3D] = []

var _tarea: TareaDeLaBasura
var _vencidos: TareaDeLosVencidos


func arrancar(una_tarea: TareaDeLaBasura, los_vencidos: TareaDeLosVencidos = null) -> void:
	_tarea = una_tarea
	_vencidos = los_vencidos


func tarea() -> TareaDeLaBasura:
	return _tarea


func vencidos() -> TareaDeLosVencidos:
	return _vencidos


func sacar_bolsa(tacho: TareaDeLaBasura.Tacho) -> bool:
	if _tarea == null or agarre == null or tacho < 0 or tacho >= bolsas.size():
		return false
	var cuerpo := bolsas[tacho]
	if not is_instance_valid(cuerpo) or agarre.punto_de_carga == null:
		return false
	var datos: ObjetoDelAlmacen = cuerpo.get(ReglasDeLosObjetos.PROPIEDAD_DATOS)
	if datos == null or not datos.es_levantable():
		return false
	var id := _tarea.sacar(tacho, agarre.manos().sostenido() == null)
	if id == ObjetoDelAlmacen.SIN_ID:
		return false
	if not agarre.pedir_agarrar(datos, cuerpo, true):
		return false
	bolsa_sacada.emit(tacho)
	return true


func pedir_tirar(recibe: bool) -> ReglasDeLaBasura.Tiro:
	if _tarea == null or reloj == null or agarre == null or repositor == null:
		push_error("Recolector sin cablear: revisar almacen.tscn y almacen.gd")
		return ReglasDeLaBasura.Tiro.MANO_VACIA
	var sostenido := agarre.manos().sostenido()
	var resultado := ReglasDeLaBasura.tiro(sostenido, recibe)
	tiro_pedido.emit(sostenido, resultado)
	if resultado != ReglasDeLaBasura.Tiro.TIRADO:
		return resultado
	if sostenido is UnidadDeProducto:
		repositor.estante().desechar(sostenido)
	var nodo := agarre.entregar()
	objeto_tirado.emit(nodo)
	if _vencidos != null and _vencidos.desechar(sostenido) and _vencidos.completada():
		reloj.completar(reloj.obligatoria(Tarea.Tipo.DESECHAR_VENCIDOS))
	if _tarea.depositar(sostenido.id) != TareaDeLaBasura.Resultado.DEPOSITADA:
		return resultado
	bolsa_depositada.emit(_tarea.depositadas())
	if _tarea.completada():
		reloj.completar(reloj.obligatoria(Tarea.Tipo.SACAR_LA_BASURA))
	return resultado
