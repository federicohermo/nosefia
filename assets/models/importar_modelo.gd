## Corre al importar el modelo del almacén.
##
## El arte conserva su filtro pixelado. El concreto y el revestimiento del depósito y las paredes
## pintadas usan mipmaps con filtro lineal y anisotropía: su detalle es fino.
## Esta excepción comparte un filtro y evita añadir variantes por cada material.
@tool
extends EditorScenePostImport

const VIDRIO := preload("res://src/escenas/puestos/vidrio_del_local.tres")
## Los materiales con detalle fino: pixelados, su piel se lee como cuadraditos.
const FILTRO_LINEAL: Array[String] = [
	"deposito_concreto",
	"local_pared_pintada",
	"bano_pared_clara",
	# Las huellas y los rayones del metal son trazos finos: pixelados se leen como escalones.
	"bano_acero",
	"bano_griferia",
	"bano_desague",
	"MESA | Base cromada",
	"MOSTRADOR | Acero satinado",
	"local_aluminio",
]
## Las piezas de las jambas toman la luz de las sondas y de las luces en tiempo real, y salen más
## claras que la pared horneada que tienen al lado: 1,6 veces en el portón y en el cuartito de
## limpieza. Con este tinte tienen el mismo brillo.
const TINTE_DE_LAS_PIEZAS := 0.62
## La compuerta del mostrador también es dinámica y suma las luces en tiempo real del salón a las
## sondas: sin este tinte sale más clara y amarillenta que el frente horneado.
const TINTE_DE_LA_COMPUERTA := Color(0.77, 0.78, 0.81, 1.0)
## Las hojas de las cabinas del baño también: sin este tinte salían casi el doble de claras que
## las mamparas horneadas de al lado, y parecían emitir luz.
const TINTE_DE_LAS_CABINAS := Color(0.66, 0.66, 0.66, 1.0)
## Cuántas veces más fino que el resto del modelo se hornea el mapa de luz de las sillas: a 20 cm
## por texel, el asiento entero eran dos texeles y dejaba manchas claras donde lo tocan las patas.
const DETALLE_DE_LUZ_DE_LAS_SILLAS := 8.0
## La variación grande de las paredes pintadas, horneada por `hornear_paredes.py`: los retoques y
## manchas de la pintura, sin repetirse. Su color lleva sólo el grano fino, que se repite cada
## pocos metros sin que se note.
const VARIACION_DE_LAS_PAREDES := preload("res://assets/models/pared_variacion.png")
## Cada cuántos metros se repite la variación: `METROS_DEL_MOSAICO` de `hornear_paredes.py`.
const METROS_DE_LA_VARIACION := 14.0
## El baño va más liso: sin variación (`paredes_con_foto.py`).
const PAREDES_PINTADAS: Array[String] = ["local_pared_pintada"]


func _post_import(escena: Node) -> Object:
	var bloques_de_las_piezas: BaseMaterial3D = null
	var madera_de_la_compuerta: BaseMaterial3D = null
	var panel_de_las_cabinas: BaseMaterial3D = null
	for malla: MeshInstance3D in escena.find_children("*", "MeshInstance3D", true, false):
		if str(malla.name).begins_with("puerta_heladera_"):
			malla.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
		if (
			str(malla.name).begins_with("exhibido_")
			or str(malla.name).begins_with("estanteria_precios")
		):
			# Los productos de exhibición y los portaprecios de la estantería son más finos que un
			# texel del mapa de luz y se horneaban negros: toman la luz de las sondas, como la
			# góndola.
			malla.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
		if str(malla.name).begins_with("salon_silla"):
			malla.gi_lightmap_texel_scale = DETALLE_DE_LUZ_DE_LAS_SILLAS
		if str(malla.name).begins_with("deposito_esquinas_"):
			# Se dibujan a toda distancia: con un alcance, la pared cambiaba de tono al acercarse
			# y el usuario lo veía como una sombra que aparecía y se iba.
			# Horneadas, le dejaban a la pared la sombra de cada jamba: los texeles de la pared que
			# la pieza tapa se hornean negros y tiñen a los de al lado. De lejos la pieza no se
			# dibuja y la sombra quedaba sola. Dinámicas no entran al horneado. Apagar su sombra
			# no alcanza: el horneador la ignora.
			malla.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
		if str(malla.name).begins_with("local_vidrio_ventanilla"):
			# La ventanilla es un hueco abierto. La malla queda en el modelo porque los mapas de
			# luz ya la nombran, y sólo se esconde.
			malla.visible = false
		if str(malla.name).begins_with("board"):
			# Despegado de la pared y con texeles de 20 cm, el corcho le horneaba a la pared cuñas
			# de sombra que salían de sus esquinas.
			malla.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
		for i: int in malla.mesh.get_surface_count():
			var material := malla.mesh.surface_get_material(i) as BaseMaterial3D
			if material != null:
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
				if (
					material.resource_name
					in [
						"CONTENEDOR | Paneles negros industriales",
						"CONTENEDOR | Tapas negras con desgaste"
					]
				):
					# El acabado negro pierde sus relieves con el tonemapeo del juego. Se calibra
					# su respuesta al horneado conservando el atlas, sin una luz de apoyo.
					material.albedo_color = Color(3.0, 3.0, 3.0, 1.0)
				if material.resource_name == "TOPE | Publicidad":
					# Un separador mide menos que un texel del mapa de luz y se horneaba negro.
					# Toma la luz de las sondas, como los productos que tiene encima.
					malla.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
				if material.resource_name == "local_ceramica":
					# El piso satinado recoge reflejos difusos sin convertirse en un espejo.
					material.roughness = 0.34
				if material.resource_name == "MOSTRADOR | Mesada blanca":
					# Las luces horneadas no dejan brillo: el de la mesada pulida sale de la sonda,
					# que refleja los paneles del techo.
					material.roughness = 0.1
					material.metallic_specular = 0.8
				if material.resource_name == "MOSTRADOR | Acero satinado":
					# El zócalo refleja el piso y el salón desde la sonda: la rugosidad del mapa
					# ORM baja a la mitad.
					material.roughness = 0.5
				if (
					malla.name == &"compuerta_mostrador"
					and material.resource_name == "MOSTRADOR | Frente de madera"
				):
					if madera_de_la_compuerta == null:
						madera_de_la_compuerta = material.duplicate()
						madera_de_la_compuerta.albedo_color = TINTE_DE_LA_COMPUERTA
					malla.set_surface_override_material(i, madera_de_la_compuerta)
				if (
					str(malla.name).begins_with("bano_puerta")
					and material.resource_name == "bano_panel_verde_gris"
				):
					if panel_de_las_cabinas == null:
						panel_de_las_cabinas = material.duplicate()
						panel_de_las_cabinas.albedo_color = TINTE_DE_LAS_CABINAS
					malla.set_surface_override_material(i, panel_de_las_cabinas)
				if material.resource_name == "local_vidrio":
					# Una sola cara por paño evita superponer transparencias y sombras opacas.
					material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					material.cull_mode = BaseMaterial3D.CULL_DISABLED
					malla.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
					malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					malla.set_surface_override_material(i, VIDRIO)
				# El motor genera un shader por cada combinación de caras y de canal de rugosidad.
				# Con una sola, los materiales con relieve del depósito comparten sus programas.
				if material.normal_enabled and material.resource_name.begins_with("deposito_"):
					material.cull_mode = BaseMaterial3D.CULL_DISABLED
					material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
				if material.resource_name in PAREDES_PINTADAS:
					# La variación se lee en coordenadas del mundo, por la segunda capa de UV: la
					# primera ya lleva el grano. La capa del mapa de luz no cambia.
					material.detail_enabled = true
					material.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
					material.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
					material.detail_albedo = VARIACION_DE_LAS_PAREDES
					material.uv2_triplanar = true
					material.uv2_world_triplanar = true
					material.uv2_scale = Vector3.ONE / METROS_DE_LA_VARIACION
				if (
					material.resource_name in FILTRO_LINEAL
					or material.resource_name.begins_with("deposito_revestimiento_")
				):
					material.texture_filter = (
						BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
					)
					# Ajuste para la iluminación horneada del juego, sin aumentar los mapas.
					if material.resource_name == "deposito_concreto":
						material.normal_scale = 0.8
					elif material.resource_name == "deposito_revestimiento_bloques":
						material.normal_scale = 1.0
						if str(malla.name).begins_with("deposito_esquinas_"):
							if bloques_de_las_piezas == null:
								bloques_de_las_piezas = material.duplicate()
								bloques_de_las_piezas.albedo_color = Color(
									TINTE_DE_LAS_PIEZAS,
									TINTE_DE_LAS_PIEZAS,
									TINTE_DE_LAS_PIEZAS,
									1.0
								)
							malla.set_surface_override_material(i, bloques_de_las_piezas)
	return escena
