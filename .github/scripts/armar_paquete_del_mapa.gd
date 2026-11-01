## Armar el paquete con el mapa de la noche del corte, que en la web viaja aparte.
##
##     "$GODOT_BIN" --headless --path . --script .github/scripts/armar_paquete_del_mapa.gd
##
## El paquete lleva dos archivos y sus rutas de siempre: el horneado oscuro (`.lmbake`) y la
## textura importada que referencia. Las dos rutas son las que el juego busca en `res://`, y
## `ProjectSettings.load_resource_pack` las monta ahí cuando el paquete llega.
##
## **Se arma con `PCKPacker` y no con el preset de exportación** porque `--export-pack` empaqueta
## todos los recursos del proyecto: el paquete salía con 113 MB en vez de 17. Acá entran dos
## archivos, medidos.
extends SceneTree

const DESTINO := "export/web/mapa_del_corte.pck"
const HORNEADO := "res://src/escenas/almacen_sin_luz.lmbake"
const IMPORTADO := "res://src/escenas/almacen_sin_luz.exr.import"


func _init() -> void:
	var textura := _textura_importada()
	if textura.is_empty():
		printerr("El `.exr` del corte no tiene su textura importada: correr `--import` antes.")
		quit(1)
		return
	var paquete := PCKPacker.new()
	if paquete.pck_start(ProjectSettings.globalize_path(DESTINO)) != OK:
		printerr("No se pudo crear `%s`." % DESTINO)
		quit(1)
		return
	for ruta: String in [HORNEADO, IMPORTADO, textura]:
		if not FileAccess.file_exists(ruta):
			printerr("Falta `%s`: el paquete saldría incompleto." % ruta)
			quit(1)
			return
		if paquete.add_file(ruta, ruta) != OK:
			printerr("No se pudo agregar `%s`." % ruta)
			quit(1)
			return
	if paquete.flush() != OK:
		printerr("No se pudo cerrar el paquete.")
		quit(1)
		return
	var tamano := FileAccess.open(DESTINO, FileAccess.READ)
	print("paquete del mapa: %s (%d bytes)" % [DESTINO, tamano.get_length()])
	tamano.close()
	quit(0)


## La textura que el importador dejó para el `.exr` del corte, con su ruta virtual.
static func _textura_importada() -> String:
	var ajustes := ConfigFile.new()
	if ajustes.load(IMPORTADO) != OK:
		return ""
	var destinos: PackedStringArray = ajustes.get_value("deps", "dest_files", PackedStringArray())
	return destinos[0] if not destinos.is_empty() else ""
