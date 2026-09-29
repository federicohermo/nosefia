## Las miniaturas de la planilla: un render transparente de 512 × 512 de cada producto pedido, con
## su malla de `contenido_del_estante.tscn`, la cámara hacia el frente de su tanda y sin la
## inclinación de la rampa. Así salieron las ocho de los productos que entraron en #262.
##
##     godot --path . --rendering-driver opengl3 \
##         --script assets/models/generar_miniaturas.gd \
##         -- assets/ui/manada 23 24 25 26 27 28 29 30
##
## Los números son `Producto.Id`, y la carpeta es adonde van los `.png`, con el nombre que la
## planilla carga. **Necesita pantalla**: con `--headless` no se dibuja nada, y en una máquina sin
## monitor va con `xvfb-run -a` delante. Después va `--import`, para que Godot tome las imágenes.
##
## Vive al lado de `extraer_mallas.gd`, que escribe las mallas que dibuja: los dos sacan recursos
## del modelo, como `importar_modelo.gd`.
extends SceneTree

const ExtraerMallas := preload("res://assets/models/extraer_mallas.gd")

const CONTENIDO := "res://src/escenas/puestos/contenido_del_estante.tscn"
const DISPOSICION := "res://src/escenas/puestos/disposicion_de_la_gondola.tres"

## El lado de la imagen, en píxeles.
const LADO := 512

## El ángulo de visión vertical de la cámara, en grados. La imagen es cuadrada: es también el
## horizontal.
const CAMPO := 30.0

## Cuánto se corre la cámara hacia la derecha y hacia arriba por cada metro hacia el frente: deja
## ver un costado y la tapa sin perder el frente.
const DE_COSTADO := 0.45
const DE_ARRIBA := 0.32

## Cuánto más lejos que lo justo va la cámara, para que el envase no toque el borde.
const MARGEN := 1.05

## Cuántos cuadros se dejan pasar antes de leer la imagen, para que la malla y la cámara nuevas
## ya estén dibujadas.
const CUADROS := 8


## Diferido: en `_initialize()` el árbol todavía no está andando, y no dibuja.
func _initialize() -> void:
	_generar.call_deferred()


func _generar() -> void:
	var argumentos := OS.get_cmdline_user_args()
	if argumentos.size() < 2:
		push_error("generar_miniaturas: faltan la carpeta y algún Producto.Id")
		quit(1)
		return
	root.size = Vector2i(LADO, LADO)
	root.transparent_bg = true
	RenderingServer.set_default_clear_color(Color(0, 0, 0, 0))
	var contenido: Node3D = (load(CONTENIDO) as PackedScene).instantiate()
	var disposicion: DisposicionDeLaGondola = load(DISPOSICION)
	var camara := Camera3D.new()
	camara.fov = CAMPO
	var luz := DirectionalLight3D.new()
	luz.light_energy = 0.9
	var vista := MeshInstance3D.new()
	var mundo := Node3D.new()
	for nodo: Node in [_entorno(), luz, camara, vista]:
		mundo.add_child(nodo)
	root.add_child(mundo)
	camara.make_current()
	var fallas := 0
	for texto: String in argumentos.slice(1):
		var producto: Producto = null
		if texto.is_valid_int():
			producto = Catalogo.de(texto.to_int() as Producto.Id)
		if producto == null:
			push_error("generar_miniaturas: %s no es un Producto.Id del catálogo" % texto)
			fallas += 1
			continue
		var nodo := contenido.get_child(producto.id) as MeshInstance3D
		var bloque := disposicion.principales[producto.id]
		var fila := disposicion.filas_de_adelante[producto.id]
		var frente := DisposicionDeLaGondola.frente(bloque, fila)
		vista.mesh = nodo.mesh
		var derecho := enderezar(normal_del_estante(bloque, fila))
		vista.transform = Transform3D(derecho * nodo.basis, Vector3.ZERO)
		var caja := vista.transform * nodo.mesh.get_aabb()
		var centro := caja.get_center()
		camara.look_at_from_position(lugar_de_la_camara(caja, frente), centro)
		var derecha := Vector3.UP.cross(frente).normalized()
		var hacia_la_luz := (frente - derecha * 0.6 + Vector3.UP).normalized()
		luz.look_at_from_position(centro + hacia_la_luz, centro)
		for _cuadro in CUADROS:
			await process_frame
		await RenderingServer.frame_post_draw
		var ruta := argumentos[0].path_join(nombre_de_archivo(producto))
		var error := root.get_texture().get_image().save_png(ruta)
		if error != OK:
			push_error("generar_miniaturas: no se pudo guardar %s (%d)" % [ruta, error])
			fallas += 1
			continue
		print("miniatura: ", ruta)
	contenido.free()
	quit(1 if fallas > 0 else 0)


## El nombre del `.png` de un producto: el de su malla, con la misma regla.
static func nombre_de_archivo(producto: Producto) -> String:
	return ExtraerMallas.slug(producto.nombre) + ".png"


## Dónde va la cámara para ver entero un envase que ocupa `caja` y mira hacia `frente`: delante,
## un poco a la derecha y arriba, y tan lejos como pide la esfera que lo envuelve para entrar en
## el campo de visión.
static func lugar_de_la_camara(caja: AABB, frente: Vector3) -> Vector3:
	var derecha := Vector3.UP.cross(frente).normalized()
	var hacia := (frente + derecha * DE_COSTADO + Vector3.UP * DE_ARRIBA).normalized()
	var radio := caja.size.length() / 2.0
	var distancia := radio / sin(deg_to_rad(CAMPO / 2.0)) * MARGEN
	return caja.get_center() + hacia * distancia


## La normal del estante de un bloque, hacia arriba. Sale de las dos filas: a lo largo de la de
## adelante y de ahí hacia la de atrás. No sale del giro de la unidad, que depende de cómo está
## puesto cada envase.
static func normal_del_estante(bloque: PackedFloat32Array, fila_de_adelante: int) -> Vector3:
	var primera := DisposicionDeLaGondola.copia(bloque, fila_de_adelante).origin
	var a_lo_largo := DisposicionDeLaGondola.copia(bloque, fila_de_adelante + 1).origin - primera
	var al_fondo := DisposicionDeLaGondola.copia(bloque, 0).origin - primera
	var normal := a_lo_largo.cross(al_fondo).normalized()
	return -normal if normal.y < 0.0 else normal


## El giro que lleva la normal del estante a la vertical: en una rampa endereza el envase, y en un
## estante plano no gira nada.
static func enderezar(normal: Vector3) -> Basis:
	return Basis(Quaternion(normal, Vector3.UP))


func _entorno() -> WorldEnvironment:
	var ambiente := Environment.new()
	ambiente.background_mode = Environment.BG_CLEAR_COLOR
	ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.ambient_light_color = Color(1, 1, 1)
	ambiente.ambient_light_energy = 0.55
	var entorno := WorldEnvironment.new()
	entorno.environment = ambiente
	return entorno
