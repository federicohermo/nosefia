## Escribe sobre el papel lo que dice su ticket, con el diseño de Figma `976:324`.
##
## Las coordenadas son las del frame, en píxeles de la textura. Qué se escribe lo decide `Ticket`:
## acá sólo se coloca. Se dibuja una sola vez, y la textura es de este papel y de ningún otro.
extends SubViewport

const FUENTE := preload("res://assets/ui/manada/unscii-16.ttf")
const PAPEL := preload("res://assets/ui/manada/ticket_papel.png")
const SEPARADOR := preload("res://assets/ui/manada/ticket_separador.svg")
## El dorso del diseño de Figma `1578:535`: papel sin escritura y con el mismo borde dentado.
const DORSO := preload("res://assets/ui/manada/ticket_dorso.png")
const TINTA := Color("191b1a")

## Medio frame: a esa resolución sobra para leerlo al examinarlo, y pesa un cuarto por papel.
const ESCALA_DE_LA_TEXTURA := 0.5
const TAMANO_DEL_PAPEL := Vector2i(739, 1281)
const TAMANO_CHICO := 51.86
const TAMANO_GRANDE := 82.04
const TAMANO_DE_LA_FECHA := 31.45
const ALTO_DE_LA_LINEA := 57.0
const ANCHO_DEL_CUERPO := 549.0
const IZQUIERDA_DEL_CUERPO := 96.0
const PRIMER_RENGLON := 449.0
const ENTRE_RENGLONES := 120.0
const SEPARADORES: Array[Vector2] = [
	Vector2(96.22, 317.33), Vector2(96.22, 408.22), Vector2(92.37, 791.71)
]

@export var malla: MeshInstance3D

var _raiz: Control


## Cambiar de padre saca al viewport del árbol: se dibuja otra vez al volver, y cuesta un cuadro.
func _enter_tree() -> void:
	render_target_update_mode = SubViewport.UPDATE_ONCE


func _ready() -> void:
	var ticket := (get_parent() as ObjetoAgarrable).datos as Ticket
	if ticket == null or malla == null or malla.mesh == null:
		return
	size = Vector2i(Vector2(TAMANO_DEL_PAPEL) * ESCALA_DE_LA_TEXTURA)
	transparent_bg = true
	disable_3d = true
	gui_disable_input = true
	canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	_raiz = Control.new()
	_raiz.scale = Vector2.ONE * ESCALA_DE_LA_TEXTURA
	add_child(_raiz)
	_escribir(ticket)
	malla.mesh = _repartida_en_frente_y_dorso(malla.mesh)
	malla.set_surface_override_material(0, _material_de(get_texture()))
	malla.set_surface_override_material(1, _material_de(DORSO))


## La textura cubre la caja de borde a borde, canto incluido: así el canto sigue los dientes del
## frente. El dorso es una superficie aparte para que no lleve la escritura.
static func _repartida_en_frente_y_dorso(origen: Mesh) -> ArrayMesh:
	var caja := origen.get_aabb()
	var arrays := origen.surface_get_arrays(0)
	var posiciones: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normales: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var cuadros := PackedVector2Array()
	for posicion in posiciones:
		cuadros.append(
			Vector2(
				(caja.end.z - posicion.z) / caja.size.z, (caja.end.y - posicion.y) / caja.size.y
			)
		)
	arrays[Mesh.ARRAY_TEX_UV] = cuadros
	var del_frente := PackedInt32Array()
	var del_dorso := PackedInt32Array()
	for indice: int in arrays[Mesh.ARRAY_INDEX]:
		(del_dorso if normales[indice].x < 0.0 else del_frente).append(indice)
	var malla_nueva := ArrayMesh.new()
	for indices: PackedInt32Array in [del_frente, del_dorso]:
		arrays[Mesh.ARRAY_INDEX] = indices
		malla_nueva.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return malla_nueva


## Un papel sin escritura con la malla y los materiales del real, oculto. El calentamiento lo dibuja
## para compilar el recorte por alfa antes de la primera impresión: ninguna otra malla lo usa.
static func papel_para_calentar(origen: Mesh) -> MeshInstance3D:
	var papel := MeshInstance3D.new()
	papel.mesh = _repartida_en_frente_y_dorso(origen)
	papel.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	for superficie: int in papel.mesh.get_surface_count():
		papel.set_surface_override_material(superficie, _material_de(DORSO))
	papel.visible = false
	return papel


static func _material_de(textura: Texture2D) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = textura
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	material.texture_repeat = false
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.5
	return material


func _escribir(ticket: Ticket) -> void:
	var fondo := TextureRect.new()
	fondo.texture = PAPEL
	fondo.size = Vector2(TAMANO_DEL_PAPEL)
	_raiz.add_child(fondo)
	for posicion: Vector2 in SEPARADORES:
		var linea := TextureRect.new()
		linea.texture = SEPARADOR
		linea.position = posicion - Vector2(0.0, 1.5)
		_raiz.add_child(linea)
	_texto("TICKET", Vector2(92.98, 69.46), 156.0, TAMANO_CHICO, HORIZONTAL_ALIGNMENT_LEFT)
	_texto(
		ticket.texto_del_numero(),
		Vector2(488.81, 69.49),
		156.0,
		TAMANO_CHICO,
		HORIZONTAL_ALIGNMENT_RIGHT
	)
	_texto("NO SE FÍA", Vector2(0.0, 213.33), 738.0, TAMANO_GRANDE, HORIZONTAL_ALIGNMENT_CENTER)
	_texto(
		ticket.texto_de_la_fecha(),
		Vector2(0.0, 347.57),
		738.0,
		TAMANO_DE_LA_FECHA,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	# Un renglón que no entra en las columnas del diseño achica su letra y no se corta.
	var tamano_del_renglon := TAMANO_CHICO * Ticket.COLUMNAS_MINIMAS / ticket.columnas()
	var lineas := ticket.lineas_impresas()
	for indice in lineas.size():
		_texto(
			lineas[indice],
			Vector2(IZQUIERDA_DEL_CUERPO, PRIMER_RENGLON + ENTRE_RENGLONES * indice),
			ANCHO_DEL_CUERPO,
			tamano_del_renglon,
			HORIZONTAL_ALIGNMENT_LEFT
		)
	_texto("TOTAL", Vector2(101.0, 822.59), 130.0, TAMANO_CHICO, HORIZONTAL_ALIGNMENT_LEFT)
	_texto(
		ticket.texto_del_total(),
		Vector2(480.0, 823.0),
		156.0,
		TAMANO_CHICO,
		HORIZONTAL_ALIGNMENT_RIGHT
	)
	_texto("¡GRACIAS!", Vector2(0.0, 970.1), 738.0, TAMANO_GRANDE, HORIZONTAL_ALIGNMENT_CENTER)


func _texto(
	contenido: String,
	posicion: Vector2,
	ancho: float,
	tamano: float,
	alineacion: HorizontalAlignment
) -> void:
	var etiqueta := Label.new()
	etiqueta.text = contenido
	etiqueta.position = posicion
	etiqueta.size = Vector2(ancho, ALTO_DE_LA_LINEA)
	etiqueta.horizontal_alignment = alineacion
	etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	etiqueta.add_theme_font_override("font", FUENTE)
	etiqueta.add_theme_font_size_override("font_size", roundi(tamano))
	etiqueta.add_theme_color_override("font_color", TINTA)
	_raiz.add_child(etiqueta)
