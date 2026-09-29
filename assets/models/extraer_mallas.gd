## Guarda la malla de cada producto del modelo importado. Es el último paso del acomodador, y el
## único que corre adentro de Godot y no de Blender.
##
##     godot --headless --path . --script assets/models/extraer_mallas.gd
##
## Va después de `.claude/scripts/exportar_modelo.py`, que reimporta el `.glb`, y de
## `.claude/scripts/blender/disponer.py`, que escribe la disposición: la unidad de cada producto es
## **el nodo del modelo parado sobre una copia de su tanda**, y se la encuentra por esa posición y
## no por su nombre, que lo decide el `.glb`. Es el mismo criterio de `modelo_exportado_test.gd`.
##
## Vive al lado de las mallas que escribe, y no con los scripts de `.claude/scripts/blender/`, que
## son de Blender: éste es de Godot.
##
## La malla viaja intacta, con su material: la vuelta y la escala las lleva el nodo de
## `contenido_del_estante.tscn`. El archivo se llama como el producto, con la misma regla que
## `.claude/scripts/lib/gondola.py` (`slug()`): si difieren, la escena apunta a un archivo que
## nadie escribió.
extends SceneTree

const MODELO := "res://assets/models/SEPT_JUEGOS_PROTOTIPO.glb"
const DISPOSICION := "res://src/escenas/puestos/disposicion_de_la_gondola.tres"
const CARPETA := "res://assets/models/"

## Cuánto puede separarse la unidad horneada de la copia sobre la que está parada, en metros.
const TOLERANCIA := 0.002

## Las letras que el nombre de un archivo no lleva, con la que va en su lugar.
const SIN_ACENTO := {"á": "a", "é": "e", "í": "i", "ó": "o", "ú": "u", "ü": "u", "ñ": "n"}


## Diferido: en `_initialize()` el árbol todavía no está andando, y un nodo agregado ahí no tiene
## posición en el mundo —`global_position` contesta cero con un error por cada nodo—.
func _initialize() -> void:
	_extraer.call_deferred()


func _extraer() -> void:
	var escena: PackedScene = load(MODELO)
	var modelo: Node3D = escena.instantiate()
	root.add_child(modelo)
	var disposicion: DisposicionDeLaGondola = load(DISPOSICION)
	var mallas: Array[MeshInstance3D] = []
	for nodo: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
		mallas.append(nodo)
	var fallas := 0
	for producto in Catalogo.todos():
		var bloque := disposicion.principales[producto.id]
		var encima: Array[MeshInstance3D] = []
		for malla in mallas:
			for indice in DisposicionDeLaGondola.copias(bloque):
				var copia := DisposicionDeLaGondola.copia(bloque, indice)
				if malla.global_position.distance_to(copia.origin) < TOLERANCIA:
					encima.append(malla)
					break
		if encima.size() != 1:
			push_error("%s: %d nodos del modelo sobre su tanda" % [producto.nombre, encima.size()])
			fallas += 1
			continue
		var ruta := ruta_de_la_malla(producto)
		var error := ResourceSaver.save(encima[0].mesh, ruta)
		if error != OK:
			push_error("%s: no se pudo guardar %s (%d)" % [producto.nombre, ruta, error])
			fallas += 1
			continue
		print("guardada: ", ruta)
	modelo.free()
	quit(1 if fallas > 0 else 0)


## Dónde se guarda la malla de un producto.
static func ruta_de_la_malla(producto: Producto) -> String:
	return CARPETA + "producto_%s.res" % slug(producto.nombre)


## El nombre de archivo de un producto: minúsculas, sin acentos y con guion bajo.
static func slug(nombre: String) -> String:
	var salida := ""
	for letra in nombre.to_lower():
		salida += SIN_ACENTO.get(letra, letra)
	return "_".join(salida.split(" ", false))
