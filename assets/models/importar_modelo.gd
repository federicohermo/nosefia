## Corre al importar el modelo del almacén.
##
## El arte conserva su filtro pixelado. El concreto y el revestimiento del depósito usan
## mipmaps con filtro lineal y anisotropía para conservar detalle en superficies oblicuas.
## Esta excepción comparte un filtro y evita añadir variantes por cada material.
@tool
extends EditorScenePostImport

const VIDRIO := preload("res://src/escenas/puestos/vidrio_del_local.tres")


func _post_import(escena: Node) -> Object:
	for malla: MeshInstance3D in escena.find_children("*", "MeshInstance3D", true, false):
		if str(malla.name).begins_with("puerta_heladera_"):
			malla.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
		for i: int in malla.mesh.get_surface_count():
			var material := malla.mesh.surface_get_material(i) as BaseMaterial3D
			if material != null:
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
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
	return escena
