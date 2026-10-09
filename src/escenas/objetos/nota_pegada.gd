## La hoja artística conserva su cuerpo y su imagen. El puesto le declara qué dice.
extends StaticBody3D

signal apertura_pedida

@export var id: NotaPegada.Id
@export var mallas: Array[MeshInstance3D]
@export var titulo_del_papel: Label3D
@export var renglones_del_papel: Label3D
@export var grafica_de_tareas: Node3D
@export var grafica_de_orden: Node3D

var _nota: NotaPegada


func declarar(nota: NotaPegada) -> void:
	_nota = nota
	if titulo_del_papel != null:
		titulo_del_papel.text = nota.titulo()
		renglones_del_papel.text = NotaEncuadrada.texto_de_renglones(nota)
	if grafica_de_tareas != null and grafica_de_orden != null:
		titulo_del_papel.visible = false
		grafica_de_tareas.visible = id == NotaPegada.Id.TAREAS_A_REALIZAR
		grafica_de_orden.visible = id == NotaPegada.Id.LOCAL_ORDENADO
		renglones_del_papel.position.z = (-0.77 if id == NotaPegada.Id.TAREAS_A_REALIZAR else -0.58)


func dato() -> NotaPegada:
	return _nota


func imagen() -> Texture2D:
	if id in [NotaPegada.Id.TAREAS_A_REALIZAR, NotaPegada.Id.LOCAL_ORDENADO]:
		return null
	# La superficie cero es el papel vacío; la uno trae el frente que pintó el artista.
	var frente := mallas[0].get_active_material(1) as BaseMaterial3D
	return frente.albedo_texture


func accionar() -> void:
	apertura_pedida.emit()
