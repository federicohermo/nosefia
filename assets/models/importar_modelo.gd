## Corre al importar el modelo del almacén.
##
## El arte conserva su filtro pixelado. El concreto y el revestimiento del depósito usan
## mipmaps con filtro lineal y anisotropía para conservar detalle en superficies oblicuas.
## Esta excepción comparte un filtro y evita añadir variantes por cada material.
@tool
extends EditorScenePostImport

const VIDRIO := preload("res://src/escenas/puestos/vidrio_del_local.tres")
## Las piezas de las jambas toman la luz de las sondas y de las luces en tiempo real, y salen más
## claras que la pared horneada que tienen al lado: 1,6 veces en el portón y en el cuartito de
## limpieza. Con este tinte tienen el mismo brillo.
const TINTE_DE_LAS_PIEZAS := 0.62


func _post_import(escena: Node) -> Object:
	var bloques_de_las_piezas: BaseMaterial3D = null
	for malla: MeshInstance3D in escena.find_children("*", "MeshInstance3D", true, false):
		if str(malla.name).begins_with("puerta_heladera_"):
			malla.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
		if (
			str(malla.name).begins_with("exhibido_")
			or str(malla.name).begins_with("salon_silla")
			or str(malla.name).begins_with("estanteria_precios")
		):
			# Los productos de exhibición, el respaldo de las sillas y los portaprecios de la
			# estantería son más finos que un texel del mapa de luz y se horneaban negros: toman
			# la luz de las sondas, como la góndola.
			malla.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
		if str(malla.name).begins_with("deposito_esquinas_"):
			# Los bloques que salen de las jambas sólo se ven de cerca: de lejos los cubre la textura.
			malla.visibility_range_end = 6.0
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
				if (
					material.resource_name == "deposito_concreto"
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
