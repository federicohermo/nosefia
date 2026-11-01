## De dónde toma la luz cada objeto visible del local: del horneado, de las sondas, de sí mismo o
## de ningún lado. Lo que no la toma de ningún lado no se oscurece con el corte.
extends RefCounted

enum Clase { HORNEADO, SONDAS, EMISOR, TRANSPARENTE, SIN_SOMBREADO, SIN_GI, ESTATICO_SIN_HORNEAR }

const Lector := preload("res://test/escenas/sondas_del_horneado.gd")
const CorteDeLuz := preload("res://src/escenas/puestos/corte_de_luz.gd")


## Cada objeto visible del mundo del local con su clase. Los de sondas, con la luz más alta que
## reciben del horneado de `sondas`, tomada en el centro de su caja como el motor.
static func clasificar(raiz: Node3D, horno: LightmapGI, sondas: Lector) -> Array[Dictionary]:
	var horneados := {}
	for indice: int in horno.light_data.get_user_count():
		horneados[horno.get_node(horno.light_data.get_user_path(indice))] = true
	var al_horno := horno.global_transform.affine_inverse()
	var objetos: Array[Dictionary] = []
	for nodo: Node in raiz.find_children("*", "GeometryInstance3D", true, false):
		var objeto := nodo as GeometryInstance3D
		if not objeto.is_visible_in_tree() or objeto.get_viewport() != raiz.get_viewport():
			continue
		var fila := {
			"objeto": objeto,
			"ruta": String(raiz.get_path_to(objeto)),
			"clase": _clase(objeto, horneados.has(objeto)),
		}
		if fila.clase == Clase.SONDAS:
			fila["centro"] = al_horno * (objeto.global_transform * _caja(objeto)).get_center()
			fila["luz"] = sondas.luz_en(fila.centro)
		objetos.append(fila)
	return objetos


static func _clase(objeto: GeometryInstance3D, horneado: bool) -> Clase:
	# Un texto que no toma luz es una pantalla: el reloj de mesa.
	if objeto is Label3D and not (objeto as Label3D).shaded:
		return Clase.EMISOR
	if objeto is SpriteBase3D and not (objeto as SpriteBase3D).shaded:
		return Clase.SIN_SOMBREADO
	for material in _materiales(objeto):
		if material is BaseMaterial3D:
			var base := material as BaseMaterial3D
			if base.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
				if base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
					return Clase.TRANSPARENTE
				return Clase.SIN_SOMBREADO
			if (
				base.emission_enabled
				and not CorteDeLuz.MATERIALES_EMISIVOS.has(StringName(base.resource_name))
			):
				return Clase.EMISOR
		elif material is ShaderMaterial:
			var shader := (material as ShaderMaterial).shader
			if shader != null and shader.code.contains("unshaded"):
				if shader.code.contains("ALPHA"):
					return Clase.TRANSPARENTE
				return Clase.SIN_SOMBREADO
	if horneado:
		return Clase.HORNEADO
	match objeto.gi_mode:
		GeometryInstance3D.GI_MODE_DYNAMIC:
			return Clase.SONDAS
		GeometryInstance3D.GI_MODE_STATIC:
			return Clase.ESTATICO_SIN_HORNEAR
	return Clase.SIN_GI


static func _materiales(objeto: GeometryInstance3D) -> Array[Material]:
	var materiales: Array[Material] = []
	if objeto.material_override != null:
		materiales.append(objeto.material_override)
	if objeto is MeshInstance3D:
		var malla := objeto as MeshInstance3D
		for superficie in malla.get_surface_override_material_count():
			var material := malla.get_active_material(superficie)
			if material != null:
				materiales.append(material)
	elif objeto is MultiMeshInstance3D:
		var multimesh := (objeto as MultiMeshInstance3D).multimesh
		if multimesh != null and multimesh.mesh != null:
			for superficie in multimesh.mesh.get_surface_count():
				var material := multimesh.mesh.surface_get_material(superficie)
				if material != null:
					materiales.append(material)
	return materiales


## En headless un `MultiMesh` no tiene caja: se arma con la de sus copias.
static func _caja(objeto: GeometryInstance3D) -> AABB:
	if not objeto is MultiMeshInstance3D:
		return objeto.get_aabb()
	var multimesh := (objeto as MultiMeshInstance3D).multimesh
	if multimesh == null or multimesh.mesh == null or multimesh.instance_count == 0:
		return AABB()
	var malla := multimesh.mesh.get_aabb()
	var caja := multimesh.get_instance_transform(0) * malla
	for indice in range(1, multimesh.instance_count):
		caja = caja.merge(multimesh.get_instance_transform(indice) * malla)
	return caja
