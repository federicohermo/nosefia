## Imprime de dónde toma la luz cada objeto visible del local en la noche del corte, y cuánta le
## dan las sondas de cada horneado. Lo que no toma luz del horneado es lo que el corte no apaga.
##
##     "$GODOT_BIN" --headless --path . -s res://test/escenas/listar_la_luz.gd
extends SceneTree

const Luz := preload("res://test/escenas/luz_de_cada_objeto.gd")
const Lector := preload("res://test/escenas/sondas_del_horneado.gd")
const HORNO_CON_LUZ := "res://src/escenas/almacen.lmbake"
const HORNO_SIN_LUZ := "res://src/escenas/almacen_sin_luz.lmbake"


func _initialize() -> void:
	# Las transformaciones valen recién con el árbol andando.
	await process_frame
	var local: Node3D = load("res://src/escenas/almacen.tscn").instantiate()
	local.set(
		"_partida", Partida.desde({"jornada": AnomaliasDeLaJornada.JORNADA_DEL_CORTE, "medios": 0})
	)
	root.add_child(local)
	await process_frame
	var horno: LightmapGI = local.get_node("LightmapGI")
	var con_luz := Luz.clasificar(local, horno, Lector.new(HORNO_CON_LUZ))
	var sin_luz := Luz.clasificar(local, horno, Lector.new(HORNO_SIN_LUZ))
	for indice in sin_luz.size():
		var fila := sin_luz[indice]
		var luz := ""
		if fila.has("luz"):
			luz = "\tcon luz %.3f\tsin luz %.3f" % [con_luz[indice].luz, fila.luz]
		print("%s\t%s%s" % [Luz.Clase.keys()[fila.clase], fila.ruta, luz])
	quit(0)
