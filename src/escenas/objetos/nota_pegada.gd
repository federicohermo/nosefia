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
var _tachados: Array[Sprite3D] = []
var _filas_tachadas: Array[int] = []


func declarar(nota: NotaPegada) -> void:
	_nota = nota
	if titulo_del_papel != null:
		titulo_del_papel.text = nota.titulo()
		renglones_del_papel.text = NotaEncuadrada.texto_de_renglones(nota)
		_pintar_tachados(nota)
	if grafica_de_tareas != null and grafica_de_orden != null:
		titulo_del_papel.visible = false
		grafica_de_tareas.visible = id == NotaPegada.Id.TAREAS_A_REALIZAR
		grafica_de_orden.visible = id == NotaPegada.Id.LOCAL_ORDENADO
		renglones_del_papel.position.z = (-0.77 if id == NotaPegada.Id.TAREAS_A_REALIZAR else -0.58)


## Los renglones del papel que van tachados.
func filas_tachadas() -> Array[int]:
	return _filas_tachadas.duplicate()


func tachados_visibles() -> Array[Sprite3D]:
	return _tachados.duplicate()


## Por tarea cumplida, una línea sobre toda la oración.
func _pintar_tachados(nota: NotaPegada) -> void:
	for tachado in _tachados:
		renglones_del_papel.remove_child(tachado)
		tachado.queue_free()
	_tachados.clear()
	_filas_tachadas.clear()
	var papel := renglones_del_papel
	var alto := (papel.font.get_height(papel.font_size) + papel.line_spacing) * papel.pixel_size
	var oraciones := papel.text.split("\n")
	var linea := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	linea.fill(Color.WHITE)
	var textura_de_la_linea := ImageTexture.create_from_image(linea)
	for fila in nota.renglones().size():
		if not nota.cumplida(fila):
			continue
		var largo := (
			(
				papel
				. font
				. get_string_size(oraciones[fila], HORIZONTAL_ALIGNMENT_LEFT, -1, papel.font_size)
				. x
			)
			* papel.pixel_size
		)
		var tachado := Sprite3D.new()
		tachado.texture = textura_de_la_linea
		tachado.pixel_size = 1.0
		tachado.scale = Vector3(largo, NotaEncuadrada.GROSOR_DEL_TACHADO * alto, 1.0)
		tachado.modulate = NotaEncuadrada.COLOR_DEL_TACHADO
		tachado.shaded = papel.shaded
		tachado.gi_mode = papel.gi_mode
		tachado.render_priority = papel.render_priority + 1
		tachado.position = Vector3(
			largo / 2.0, -(fila + NotaEncuadrada.ALTURA_DEL_TACHADO) * alto, 0.001
		)
		papel.add_child(tachado)
		_tachados.append(tachado)
		_filas_tachadas.append(fila)


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


## Cada hoja con el mismo contenido dice lo mismo, esté pegada donde esté.
func texto_al_examinar() -> String:
	return SubtitulosAlExaminar.de_lo_fijo(SubtitulosAlExaminar.id_de_la_nota(id))
