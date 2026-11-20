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

const Apoyo := preload("res://addons/hornear/apoyo.gd")
const Sondas := preload("res://addons/hornear/sondas.gd")
const CorteDeLuz := preload("res://src/escenas/puestos/corte_de_luz.gd")

const ESCENA := "res://src/escenas/almacen.tscn"
const NODO := "LightmapGI"
## El modelo del local: sus mallas cierran los ambientes que las sondas rellenan.
const ESTRUCTURA := "Estructura"
## `hornear.py --sin-luz` la declara: hornea el local de la noche del corte de luz, en otro
## archivo, sin guardar la escena.
const VARIABLE_DE_LA_VARIANTE := "HORNEAR_VARIANTE"
const VARIANTE_SIN_LUZ := "sin_luz"
## `hornear.py` la declara para el segundo horneado del local con luz: el mismo, con los
## obstáculos de `apoyo.gd`. No guarda la escena, y su atlas va a `HORNEADO_CON_APOYO`, de donde
## `mezclar_horneados.gd` lo toma y `hornear.py` lo borra.
const VARIANTE_CON_APOYO := "con_apoyo"
const HORNEADO_CON_APOYO := "res://src/escenas/almacen_con_apoyo.lmbake"
## Las mallas de las góndolas se reconocen por su nombre.
const GONDOLAS := "gondolanueva*"
## El texto del botón en inglés: el script lanza el editor con `-l en` para que sea este.
const BOTON := "Bake Lightmaps"
const PAUSA := 2.0
const INTENTOS := 30

var _paso := 0
var _espera := 0.0
var _intentos := 0
var _operacion_en_curso: bool = false
## Se arma antes de apagar el local: la noche sin luz cambia los vidrios, y el juego no.
var _cascara: Sondas.Cascara
## Los vidrios a la calle como estaban antes de emitir la luz de afuera, para devolverlos antes de
## guardar la escena.
var _vidrios: Dictionary[MeshInstance3D, Array] = {}


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
		# El editor restaura las pestañas de la sesión anterior después del primer cuadro, y la
		# que queda al frente puede ser otra: se vuelve a pedir la escena, que la trae al frente.
		EditorInterface.open_scene_from_path(ESCENA)
		return
	var horno := raiz.get_node_or_null(NODO) as LightmapGI
	if horno == null:
		_fallar("la escena no tiene un %s" % NODO)
		return
	_cascara = Sondas.Cascara.new(
		raiz.get_node(ESTRUCTURA), horno.global_transform.affine_inverse()
	)
	if _sin_luz():
		_apagar_el_local(raiz, horno)
	else:
		_vidrios = CorteDeLuz.emitir_por_los_vidrios(raiz)
	if _con_apoyo():
		_agregar_los_obstaculos(raiz, horno)
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(horno)
	EditorInterface.edit_node(horno)
	_avanzar(2)


func _sin_luz() -> bool:
	return OS.get_environment(VARIABLE_DE_LA_VARIANTE) == VARIANTE_SIN_LUZ


func _con_apoyo() -> bool:
	return OS.get_environment(VARIABLE_DE_LA_VARIANTE) == VARIANTE_CON_APOYO


## Suma en la copia del editor los volúmenes de `apoyo.gd` bajo cada góndola. **Nada de esto se
## guarda**: la escena queda como estaba. Sin datos previos, el horneado pide dónde guardarse y
## deja un archivo nuevo, que no es el de siempre.
func _agregar_los_obstaculos(raiz: Node, horno: LightmapGI) -> void:
	horno.light_data = null
	var obstaculos := Node3D.new()
	obstaculos.name = "ObstaculosDelHorneado"
	raiz.get_node(ESTRUCTURA).add_child(obstaculos)
	obstaculos.owner = raiz
	var negro := StandardMaterial3D.new()
	negro.albedo_color = Color.BLACK
	negro.roughness = 1.0
	negro.metallic_specular = 0.0
	for nodo: Node in raiz.get_node(ESTRUCTURA).find_children(
		GONDOLAS, "MeshInstance3D", true, false
	):
		var malla := nodo as MeshInstance3D
		# Lo dinámico toma la luz de las sondas y no se hornea: sus obstáculos no tendrían sentido.
		if malla.mesh == null or not malla.is_visible_in_tree():
			continue
		if malla.gi_mode != GeometryInstance3D.GI_MODE_STATIC:
			continue
		var caras: PackedVector3Array = malla.global_transform * malla.mesh.get_faces()
		for volumen: AABB in Apoyo.volumenes(caras, _suelo_de(caras)):
			_agregar_caja(obstaculos, volumen, negro)
	print("[hornear] con apoyo: %d obstaculos" % obstaculos.get_child_count())


## El piso donde apoya una malla es lo más bajo que tiene.
func _suelo_de(caras: PackedVector3Array) -> float:
	var suelo := INF
	for punto: Vector3 in caras:
		suelo = minf(suelo, punto.y)
	return suelo


## Un `LightmapGI` sólo cuenta una malla con dueño, segundo juego de UV y tamaño de atlas. El
## tamaño mínimo es el que menos lugar ocupa en el atlas.
func _agregar_caja(padre: Node3D, volumen: AABB, material: Material) -> void:
	var caja := BoxMesh.new()
	caja.size = volumen.size
	caja.add_uv2 = true
	caja.lightmap_size_hint = Vector2i(2, 2)
	var instancia := MeshInstance3D.new()
	instancia.mesh = caja
	instancia.material_override = material
	instancia.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	padre.add_child(instancia)
	instancia.owner = padre.owner
	instancia.global_position = volumen.get_center()


## Deja encendida la luz de emergencia y la de afuera, que emiten los vidrios a la calle: las
## otras luces no entran al horneado y los emisivos del local no alumbran. Es lo mismo que apaga
## el juego al cortar la luz (`corte_de_luz.gd`). Sin datos previos, el horneado pide dónde
## guardarse y deja un archivo nuevo. **Nada de esto se guarda**: la escena queda como estaba.
func _apagar_el_local(raiz: Node, horno: LightmapGI) -> void:
	horno.light_data = null
	var apagadas := CorteDeLuz.luces_del_local(raiz)
	for luz in apagadas:
		luz.light_bake_mode = Light3D.BAKE_DISABLED
	var emision := CorteDeLuz.emision_del_local(raiz)
	for material: BaseMaterial3D in emision:
		material.emission_energy_multiplier = 0.0
	CorteDeLuz.reforzar_la_emergencia(raiz)
	CorteDeLuz.abrir_a_la_calle(raiz, horno)
	print(
		(
			"[hornear] sin luz: %d luces y %d materiales emisivos apagados"
			% [apagadas.size(), emision.size()]
		)
	)


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
		var ruta := ESCENA.get_basename() + ".lmbake"
		if _sin_luz():
			ruta = CorteDeLuz.HORNEADO_SIN_LUZ
		elif _con_apoyo():
			ruta = HORNEADO_CON_APOYO
		dialogo.file_selected.emit(ruta)
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
	CorteDeLuz.cerrar_los_vidrios(_vidrios)
	if _con_apoyo():
		# Sólo se necesita su atlas y la disposición de sus piezas: las sondas son las del otro.
		ResourceSaver.save(datos, datos.resource_path)
		return
	var cuenta := Sondas.rellenar(datos, _cascara)
	print("[hornear] sondas de afuera rellenadas: %d de %d" % [cuenta.rellenadas, cuenta.total])
	# La noche del corte las luces están apagadas: no hay luz que devolverle a la mercadería.
	if not _sin_luz():
		var reforzadas := Sondas.reforzar(datos, EditorInterface.get_edited_scene_root(), _horno())
		print("[hornear] sondas con ganancia: %d" % reforzadas)
	ResourceSaver.save(datos, datos.resource_path)
	if _sin_luz():
		return
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
