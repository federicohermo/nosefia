## Que la luz de los muebles salga del horneado.
##
## Una malla con GI estático que no entró al horneado queda negra: ni tiene lightmap ni toma la
## luz de las sondas. Es lo que le pasa a todo lo que no viene del modelo, que no trae UV2.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const PuertaDelLocal := preload("res://src/escenas/puestos/puerta_del_local.gd")


func test_el_local_tiene_su_luz_horneada() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	var horno := almacen.get_node("LightmapGI") as LightmapGI
	assert_object(horno.light_data).is_not_null()
	assert_int(horno.light_data.get_user_count()).is_greater(0)


func test_toda_malla_con_gi_estatico_entro_al_horneado() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	var negras: Array[String] = []
	for geometria: GeometryInstance3D in almacen.find_children(
		"*", "GeometryInstance3D", true, false
	):
		if geometria.gi_mode != GeometryInstance3D.GI_MODE_STATIC:
			continue
		# Un MultiMesh no se hornea nunca; una malla, sólo si trae UV2 en todas sus superficies.
		if geometria is MultiMeshInstance3D or not _con_uv2(geometria):
			negras.append(String(almacen.get_path_to(geometria)))
	(
		assert_array(negras)
		. override_failure_message("quedan negras al lado del lightmap: %s" % ", ".join(negras))
		. is_empty()
	)


func test_las_hojas_que_abren_no_llevan_sombras_de_la_posicion_cerrada() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	var horno := almacen.get_node("LightmapGI") as LightmapGI
	var horneadas: Array[NodePath] = []
	for indice: int in horno.light_data.get_user_count():
		horneadas.append(horno.light_data.get_user_path(indice))
	var moviles: Array[MeshInstance3D] = []
	for cuerpo: Node in almacen.find_children("*", "AnimatableBody3D", true, false):
		if cuerpo is PuertaDelLocal and cuerpo.traba == PuertaDelLocal.Traba.NINGUNA:
			moviles.append(cuerpo.hoja)
	assert_array(moviles).is_not_empty()
	for hoja: MeshInstance3D in moviles:
		(
			assert_int(hoja.gi_mode)
			. override_failure_message("La hoja móvil %s no puede hornearse cerrada" % hoja.name)
			. is_equal(GeometryInstance3D.GI_MODE_DYNAMIC)
		)
		assert_bool(horneadas.has(horno.get_path_to(hoja))).is_false()


func _con_uv2(geometria: GeometryInstance3D) -> bool:
	if not geometria is MeshInstance3D:
		return true
	var malla: Mesh = (geometria as MeshInstance3D).mesh
	if malla == null:
		return true
	for superficie in malla.get_surface_count():
		if malla.surface_get_format(superficie) & Mesh.ARRAY_FORMAT_TEX_UV2 == 0:
			return false
	return true
