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
var _ticks: Array[Sprite3D] = []
var _filas_con_tick: Array[int] = []


func declarar(nota: NotaPegada) -> void:
	_nota = nota
	if titulo_del_papel != null:
		titulo_del_papel.text = nota.titulo()
		renglones_del_papel.text = NotaEncuadrada.texto_de_renglones(nota)
		_pintar_ticks(nota)
	if grafica_de_tareas != null and grafica_de_orden != null:
		titulo_del_papel.visible = false
		grafica_de_tareas.visible = id == NotaPegada.Id.TAREAS_A_REALIZAR
		grafica_de_orden.visible = id == NotaPegada.Id.LOCAL_ORDENADO
		renglones_del_papel.position.z = (-0.77 if id == NotaPegada.Id.TAREAS_A_REALIZAR else -0.58)


## Los renglones del papel que llevan tick.
func filas_con_tick() -> Array[int]:
	return _filas_con_tick.duplicate()


func ticks_visibles() -> Array[Sprite3D]:
	return _ticks.duplicate()


## Un tick por tarea cumplida, a la izquierda del número, con el alto del renglón.
func _pintar_ticks(nota: NotaPegada) -> void:
	for tick in _ticks:
		renglones_del_papel.remove_child(tick)
		tick.queue_free()
	_ticks.clear()
	_filas_con_tick.clear()
	var papel := renglones_del_papel
	var alto := (papel.font.get_height(papel.font_size) + papel.line_spacing) * papel.pixel_size
	var tamano_del_pixel := alto / NotaEncuadrada.TICK.get_height()
	var ancho := NotaEncuadrada.TICK.get_width() * tamano_del_pixel
	for fila in nota.renglones().size():
		if not nota.cumplida(fila):
			continue
		var tick := Sprite3D.new()
		tick.texture = NotaEncuadrada.TICK
		tick.pixel_size = tamano_del_pixel
		tick.modulate = NotaEncuadrada.COLOR_DEL_TICK
		tick.shaded = papel.shaded
		tick.gi_mode = papel.gi_mode
		tick.render_priority = papel.render_priority
		tick.position = Vector3(
			-(ancho / 2.0 + NotaEncuadrada.SEPARACION_DEL_TICK * alto), -(fila + 0.5) * alto, 0.0
		)
		papel.add_child(tick)
		_ticks.append(tick)
		_filas_con_tick.append(fila)


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
