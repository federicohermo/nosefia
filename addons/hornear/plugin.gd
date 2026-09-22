@tool
## Hornea los lightmaps del local y cierra el editor. Lo lanza `.claude/scripts/hornear.py`.
##
## **El horneado no tiene método de script**: el editor lo expone sólo como el botón
## «Bake Lightmaps», y sin editor no hay horneador. Este plugin es la mano que aprieta el botón.
## Lo prende el script y sólo mientras corre, así que abrir el editor a mano nunca lo ejecuta.
##
## **El horneado y el guardado bombean el bucle principal** mientras trabajan, y `_process` vuelve
## a entrar en el medio. El siguiente paso debe esperar a que termine la llamada anterior:
## guardar durante el horneado puede usar datos viejos, y cerrar interrumpe el trabajo del editor.
extends EditorPlugin

const Sondas := preload("res://addons/hornear/sondas.gd")

const ESCENA := "res://src/escenas/almacen.tscn"
const NODO := "LightmapGI"
## El texto del botón en inglés: el script lanza el editor con `-l en` para que sea este.
const BOTON := "Bake Lightmaps"
const PAUSA := 2.0
const INTENTOS := 30

var _paso := 0
var _espera := 0.0
var _intentos := 0
var _operacion_en_curso: bool = false


func _process(delta: float) -> void:
	if _operacion_en_curso:
		return
	_espera -= delta
	if _espera > 0.0:
		return
	_operacion_en_curso = true
	match _paso:
		0:
			_abrir()
		1:
			_seleccionar()
		2:
			_hornear()
		3:
			_guardar()
		4:
			print("[hornear] listo")
			get_tree().quit(0)
	_operacion_en_curso = false


func _abrir() -> void:
	if EditorInterface.get_resource_filesystem().is_scanning():
		return
	_avanzar(1)
	EditorInterface.open_scene_from_path(ESCENA)


func _seleccionar() -> void:
	var raiz := EditorInterface.get_edited_scene_root()
	if raiz == null or raiz.scene_file_path != ESCENA:
		return
	var horno := raiz.get_node_or_null(NODO) as LightmapGI
	if horno == null:
		_fallar("la escena no tiene un %s" % NODO)
		return
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(horno)
	EditorInterface.edit_node(horno)
	_avanzar(2)


func _hornear() -> void:
	var boton := _buscar_boton(EditorInterface.get_base_control())
	if boton == null:
		_fallar("no encuentro el botón «%s»" % BOTON)
		return
	var primera_vez := _horno().light_data == null
	_avanzar(3)
	var desde := Time.get_ticks_msec()
	boton.pressed.emit()
	if primera_vez:
		# Sin datos previos el editor pregunta dónde guardar. Contestarle es lo mismo que elegir
		# la ruta en su diálogo: al lado de la escena.
		var dialogo := _buscar_dialogo(EditorInterface.get_base_control())
		if dialogo == null:
			_fallar("no encuentro el diálogo de guardado")
			return
		dialogo.hide()
		dialogo.file_selected.emit(ESCENA.get_basename() + ".lmbake")
	print("[hornear] horneado en %d ms" % (Time.get_ticks_msec() - desde))


func _guardar() -> void:
	var datos := _horno().light_data
	if datos == null:
		# Después de una reimportación el editor difiere el horneado un rato: se le da tiempo.
		_intentos += 1
		if _intentos < INTENTOS:
			_espera = PAUSA
			return
		_fallar("el horneado no dejó datos")
		return
	_avanzar(4)
	var cuenta := Sondas.rellenar(datos)
	print("[hornear] sondas negras rellenadas: %d de %d" % [cuenta.rellenadas, cuenta.total])
	ResourceSaver.save(datos, datos.resource_path)
	# La primera vez la escena cambió: ahora apunta a los datos. Las siguientes no.
	EditorInterface.save_scene()


func _horno() -> LightmapGI:
	return EditorInterface.get_edited_scene_root().get_node(NODO) as LightmapGI


func _avanzar(paso: int) -> void:
	_paso = paso
	_espera = PAUSA


func _fallar(motivo: String) -> void:
	_paso = -1
	printerr("[hornear] error: %s" % motivo)
	get_tree().quit(1)


func _buscar_boton(nodo: Node) -> Button:
	if nodo is Button and (nodo as Button).text == BOTON:
		return nodo
	for hijo in nodo.get_children(true):
		var boton := _buscar_boton(hijo)
		if boton:
			return boton
	return null


## El diálogo del horneador es el único `EditorFileDialog` que filtra por `.lmbake`.
func _buscar_dialogo(nodo: Node) -> EditorFileDialog:
	if nodo is EditorFileDialog:
		for filtro: String in (nodo as EditorFileDialog).filters:
			if filtro.contains("lmbake"):
				return nodo
	for hijo in nodo.get_children(true):
		var dialogo := _buscar_dialogo(hijo)
		if dialogo:
			return dialogo
	return null
