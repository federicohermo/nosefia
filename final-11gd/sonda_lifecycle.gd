## Borrador externo. Ejecutar sólo en FIFO tras autorización; stdout/raw son evidencia.
extends SceneTree

const ESCENA := preload("res://src/escenas/objetos/caja_de_productos.tscn")
const SUBCLASE := (
	"C:/Users/fede_/AppData/Local/Temp/nosefia-batch-64-309/"
	+ "c-diagnostico-69ee/caja_predelete.gd"
)

var _fallos := 0


func _initialize() -> void:
	_probar.call_deferred()


func _comprobar(condicion: bool, criterio: String) -> void:
	print("LIFECYCLE ", "OK " if condicion else "FALLO ", criterio)
	if not condicion:
		_fallos += 1


func _probar() -> void:
	var argumentos := OS.get_cmdline_user_args()
	if argumentos.size() != 1 or argumentos[0] not in ["original", "predelete"]:
		quit(2)
		return
	var corregido := argumentos[0] == "predelete"
	var script: Script = load(SUBCLASE) if corregido else null
	if corregido and script == null:
		quit(3)
		return
	var origen := Node3D.new()
	var destino := Node3D.new()
	root.add_child(origen)
	root.add_child(destino)
	var cajas: Array[Node3D] = []
	var materiales: Array[BaseMaterial3D] = []
	var texturas: Array[Texture2D] = []
	var malla_fuente: Mesh
	var generico: Material
	for indice in 2:
		var caja := ESCENA.instantiate() as Node3D
		var datos: Resource = caja.get("datos")
		if corregido:
			var mallas: Array = caja.get("mallas")
			caja.set_script(script)
			caja.set("datos", datos)
			caja.set("mallas", mallas)
		caja.set("producto", Producto.Id.ACTRONCITO)
		origen.add_child(caja)
		var malla := caja.get_node("Malla") as MeshInstance3D
		var material := malla.get_surface_override_material(0) as BaseMaterial3D
		_comprobar(material != null, "etiqueta instalada %s" % indice)
		if material == null:
			origen.free()
			destino.free()
			quit(4)
			return
		if indice == 0:
			malla_fuente = malla.mesh
			generico = malla_fuente.surface_get_material(0)
		else:
			_comprobar(malla.mesh == malla_fuente, "malla fuente compartida")
			_comprobar(material != materiales[0], "materiales de etiqueta propios")
		materiales.append(material)
		texturas.append(material.albedo_texture)
		cajas.append(caja)
		caja.reparent(destino, true)
		_comprobar(caja.get_parent() == destino, "padre nuevo %s" % indice)
		_comprobar(
			malla.get_surface_override_material(0) == material, "material conservado %s" % indice
		)
		_comprobar(material.albedo_texture == texturas[indice], "textura conservada %s" % indice)
		_comprobar(caja.get("datos") == datos, "datos conservados %s" % indice)
		_comprobar(
			caja.get("producto") == Producto.Id.ACTRONCITO, "producto conservado %s" % indice
		)
	_comprobar(malla_fuente.surface_get_material(0) == generico, "generico intacto antes de free")
	# No conservar copias por la sonda: hacerlo cambiaría el ciclo de vida que se mide.
	materiales.clear()
	texturas.clear()
	print("LIFECYCLE ANTES_FREE ", argumentos[0])
	for caja in cajas:
		caja.free()
	cajas.clear()
	print("LIFECYCLE DESPUES_FREE ", argumentos[0])
	_comprobar(malla_fuente.surface_get_material(0) == generico, "generico intacto despues de free")
	origen.free()
	destino.free()
	materiales.clear()
	texturas.clear()
	malla_fuente = null
	generico = null
	script = null
	for _cuadro in 4:
		await process_frame
	print("LIFECYCLE FIN fallos=", _fallos)
	quit(0 if _fallos == 0 else 1)
