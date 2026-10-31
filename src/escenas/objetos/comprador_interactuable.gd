## El cuerpo mide el alfa del dibujo actual; la atención decide qué permite el gesto.
extends StaticBody3D

signal interaccion_pedida

@export var figura_de_foco: AnimatedSprite3D
@export var forma: CollisionShape3D
@export var antepecho: MeshInstance3D

var atenciones: Ventanilla
var manos: Manos
var _imagenes: Dictionary[Texture2D, Image] = {}


func _ready() -> void:
	figura_de_foco.sprite_frames_changed.connect(_ajustar_forma)
	figura_de_foco.animation_changed.connect(_ajustar_forma)
	figura_de_foco.frame_changed.connect(_ajustar_forma)
	figura_de_foco.visibility_changed.connect(_actualizar_disponibilidad)
	_ajustar_forma()
	_actualizar_disponibilidad()


## En la web, leer el alfa de una textura espera a la GPU: unos 7 ms por cuadro de la animación.
## Se lee todo detrás de la carga, y no al apuntarle a cada comprador nuevo.
func precargar(animaciones: Array) -> void:
	for cuadros: SpriteFrames in animaciones:
		for animacion: StringName in cuadros.get_animation_names():
			for indice: int in cuadros.get_frame_count(animacion):
				var textura := cuadros.get_frame_texture(animacion, indice)
				if not _imagenes.has(textura):
					_imagenes[textura] = textura.get_image()


func _actualizar_disponibilidad() -> void:
	var vigente := _vigente()
	collision_layer = 2 if vigente else 0
	forma.set_deferred("disabled", not vigente)
	if vigente:
		add_to_group(ReglasDelJugador.GRUPO_INTERACTUABLE)
	else:
		remove_from_group(ReglasDelJugador.GRUPO_INTERACTUABLE)


func _ajustar_forma() -> void:
	if figura_de_foco.sprite_frames == null:
		return
	if not figura_de_foco.sprite_frames.has_animation(figura_de_foco.animation):
		return
	var textura := figura_de_foco.sprite_frames.get_frame_texture(
		figura_de_foco.animation, figura_de_foco.frame
	)
	if textura == null:
		return
	var tamano := textura.get_size() * figura_de_foco.pixel_size
	var volumen := Vector3(tamano.x, tamano.y, 0.001)
	if forma.shape is BoxShape3D and (forma.shape as BoxShape3D).size.is_equal_approx(volumen):
		return
	var caja := BoxShape3D.new()
	caja.size = volumen
	forma.shape = caja


func accionar() -> void:
	if _vigente():
		interaccion_pedida.emit()


func contexto_de_interaccion(sostenido: ObjetoDelAlmacen) -> ReferenciaDeControles.Contexto:
	var contexto := ReferenciaDeControles.contexto_primario(
		ReferenciaDeControles.Linea.NINGUNA, ReferenciaDeControles.Ruta.IGNORAR
	)
	if _vigente():
		contexto = atenciones.atencion().contexto_de_interaccion(sostenido)
		contexto.ruta_primaria = ReferenciaDeControles.Ruta.ACCIONAR
	return contexto


func admite_foco_en(punto: Vector3, ojo: Vector3) -> bool:
	if not _vigente():
		return false
	if _tapado_por_el_antepecho(ojo, punto):
		return false
	# Un producto apuntado al hueco es un intento de entrega aunque la mira caiga en lo
	# transparente de la figura: si no, el clic lo soltaría por la ventana.
	if manos != null and ReglasDeLaVentanilla.se_entrega_al_soltar_en_el_hueco(manos.sostenido()):
		return true
	var textura := figura_de_foco.sprite_frames.get_frame_texture(
		figura_de_foco.animation, figura_de_foco.frame
	)
	if not _imagenes.has(textura):
		_imagenes[textura] = textura.get_image()
	var imagen := _imagenes[textura]
	var local := figura_de_foco.to_local(punto)
	var pixel := Vector2(local.x, -local.y) / figura_de_foco.pixel_size
	pixel += textura.get_size() / 2.0 - figura_de_foco.offset
	if figura_de_foco.flip_h:
		pixel.x = textura.get_width() - pixel.x - 1.0
	if figura_de_foco.flip_v:
		pixel.y = textura.get_height() - pixel.y - 1.0
	var celda := Vector2i(pixel.floor())
	if not Rect2i(Vector2i.ZERO, imagen.get_size()).has_point(celda):
		return false
	return imagen.get_pixelv(celda).a > 0.0


func _tapado_por_el_antepecho(ojo: Vector3, punto: Vector3) -> bool:
	var inversa := antepecho.global_transform.affine_inverse()
	var desde := inversa * ojo
	var hasta := inversa * punto
	if antepecho.get_aabb().intersects_segment(desde, hasta) == null:
		return false
	var caras := antepecho.mesh.get_faces()
	for indice in range(0, caras.size(), 3):
		if (
			Geometry3D.segment_intersects_triangle(
				desde, hasta, caras[indice], caras[indice + 1], caras[indice + 2]
			)
			!= null
		):
			return true
	return false


func _vigente() -> bool:
	return (
		figura_de_foco.is_visible_in_tree()
		and atenciones != null
		and atenciones.atencion() != null
		and not atenciones.atencion().despachada()
	)
