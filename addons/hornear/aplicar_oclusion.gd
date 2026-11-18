## Aplica la oclusión de los rincones al atlas del local. Lo lanza `hornear.py`.
##
##     godot --headless --path . -s res://addons/hornear/aplicar_oclusion.gd -- \
##         BASE.lmbake ATLAS_DE_ENTRADA.exr ATLAS_DE_SALIDA.exr RADIO NIVEL RAYOS
##
## Lee del atlas de entrada y escribe el de salida: pueden ser el mismo archivo. El `.lmbake` dice,
## por pieza, la ruta de su malla —relativa al `LightmapGI` de `almacen.tscn`—, su rectángulo y su
## rebanada. La malla y su lugar en el mundo salen de la escena, que se instancia sin entrar al
## árbol: ningún script del juego corre, igual que en el editor del horneado. Qué calcula, en
## `oclusion.gd`. Sale con 0 sólo si el atlas quedó escrito; con otro código `hornear.py` devuelve
## los archivos a como estaban.
extends SceneTree

const Mezcla := preload("res://addons/hornear/mezcla.gd")
const Oclusion := preload("res://addons/hornear/oclusion.gd")

const ESCENA := "res://src/escenas/almacen.tscn"
const NODO := "LightmapGI"


## Lo que el paso necesita leer antes de calcular.
class Entrada:
	var atlas: Image
	var piezas: Array[Oclusion.Pieza] = []


func _initialize() -> void:
	quit(_aplicar(OS.get_cmdline_user_args()))


func _aplicar(argumentos: PackedStringArray) -> int:
	if argumentos.size() != 6 or not argumentos[3].is_valid_float():
		printerr(
			"[oclusion] error: se esperan BASE.lmbake ENTRADA.exr SALIDA.exr RADIO NIVEL RAYOS"
		)
		return 2
	var entrada := _leer(argumentos[0], argumentos[1])
	if entrada == null:
		return 1
	var caras := PackedVector3Array()
	for pieza: Oclusion.Pieza in entrada.piezas:
		caras.append_array(pieza.posiciones)
	var desde := Time.get_ticks_msec()
	var resultado := Oclusion.aplicar(
		entrada.atlas,
		entrada.piezas,
		Oclusion.oclusores_de(caras),
		argumentos[3].to_float(),
		argumentos[4].to_float(),
		argumentos[5].to_int()
	)
	if resultado.error != "":
		printerr("[oclusion] error: %s" % resultado.error)
		return 1
	var error := resultado.imagen.save_exr(ProjectSettings.globalize_path(argumentos[2]))
	if error != OK:
		printerr("[oclusion] error: no pude guardar el atlas (%s)" % error_string(error))
		return 1
	print(
		(
			"[oclusion] %d piezas, %d texeles, %d rayos en %.1f s, radio %s, nivel %s"
			% [
				entrada.piezas.size(),
				resultado.texeles,
				resultado.rayos,
				(Time.get_ticks_msec() - desde) / 1000.0,
				argumentos[3],
				argumentos[4],
			]
		)
	)
	return 0


## El atlas y las piezas del `.lmbake` con su malla puesta en el mundo. `null`, y dicho, si algo no
## se lee o una pieza no se ubica.
func _leer(ruta_del_horneado: String, ruta_del_atlas: String) -> Entrada:
	var datos := load(ruta_del_horneado) as LightmapGIData
	var atlas := Image.load_from_file(ProjectSettings.globalize_path(ruta_del_atlas))
	var raiz := (load(ESCENA) as PackedScene).instantiate()
	var horno := raiz.get_node_or_null(NODO)
	if datos == null or atlas == null or horno == null:
		printerr(
			"[oclusion] error: no pude leer el horneado, el atlas ni el %s de la escena" % NODO
		)
		raiz.free()
		return null
	var entrada := Entrada.new()
	entrada.atlas = atlas
	var user_data: Array = datos.get("user_data")
	for i: int in range(0, user_data.size(), Mezcla.CAMPOS_POR_PIEZA):
		var ruta: NodePath = user_data[i + Mezcla.CAMPO_RUTA]
		var malla := horno.get_node_or_null(ruta) as MeshInstance3D
		var pieza: Oclusion.Pieza = null
		if malla != null and malla.mesh != null:
			pieza = Oclusion.pieza_de(
				malla.mesh,
				_en_el_mundo(malla),
				"%s#%s" % [ruta, user_data[i + Mezcla.CAMPO_INSTANCIA]],
				user_data[i + Mezcla.CAMPO_RECTANGULO],
				user_data[i + Mezcla.CAMPO_REBANADA]
			)
		if pieza == null:
			printerr("[oclusion] error: la pieza %s no es una malla con UV2 de la escena" % ruta)
			raiz.free()
			return null
		entrada.piezas.append(pieza)
	raiz.free()
	return entrada


## La escena no entró al árbol, así que no hay `global_transform`: se compone cada nivel.
func _en_el_mundo(nodo: Node) -> Transform3D:
	var mundo := Transform3D.IDENTITY
	var actual := nodo
	while actual != null:
		if actual is Node3D:
			mundo = (actual as Node3D).transform * mundo
		actual = actual.get_parent()
	return mundo
