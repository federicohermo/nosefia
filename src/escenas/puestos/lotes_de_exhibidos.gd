## Consolida los productos exhibidos repetidos del freezer en `MultiMeshInstance3D`.
##
## Los exhibidos del freezer (`exhibido_*`) son mallas dinámicas que comparten recurso de malla.
## Agruparlas reduce llamadas de dibujo en el salón y conserva nombres `exhibido_*` para que
## `Almacen.mostrar_el_freezer` siga alternándolas.
extends RefCounted


static func consolidar(estructura: Node) -> int:
	if estructura == null:
		return 0
	var freezer := estructura.get_node_or_null("freezer_helados") as Node3D
	if freezer == null:
		return 0

	var grupos: Dictionary = {}
	for nodo: Node in freezer.find_children("exhibido_*", "MeshInstance3D", true, false):
		var mi := nodo as MeshInstance3D
		if not _es_consolidable(mi):
			continue
		var clave := _clave_del_lote(mi)
		if not grupos.has(clave):
			grupos[clave] = []
		(grupos[clave] as Array).append(mi)

	var ahorrados := 0
	var indice := 0
	for lista_var: Variant in grupos.values():
		var lista: Array = lista_var
		if lista.size() < 2:
			continue
		indice += 1
		var primero := lista[0] as MeshInstance3D
		var lote := MultiMeshInstance3D.new()
		lote.name = "exhibido_lote_%02d" % indice
		lote.gi_mode = primero.gi_mode
		lote.cast_shadow = primero.cast_shadow
		lote.layers = primero.layers
		lote.visible = primero.visible
		lote.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = primero.mesh
		mm.instance_count = lista.size()
		var buffer := PackedFloat32Array()
		buffer.resize(lista.size() * 12)
		for i: int in lista.size():
			var mi := lista[i] as MeshInstance3D
			var t := _transform_relativo(mi, freezer)
			var base := i * 12
			buffer[base] = t.basis.x.x
			buffer[base + 1] = t.basis.y.x
			buffer[base + 2] = t.basis.z.x
			buffer[base + 3] = t.origin.x
			buffer[base + 4] = t.basis.x.y
			buffer[base + 5] = t.basis.y.y
			buffer[base + 6] = t.basis.z.y
			buffer[base + 7] = t.origin.y
			buffer[base + 8] = t.basis.x.z
			buffer[base + 9] = t.basis.y.z
			buffer[base + 10] = t.basis.z.z
			buffer[base + 11] = t.origin.z
		mm.buffer = buffer
		lote.multimesh = mm
		freezer.add_child(lote)

		for mi_var: Variant in lista:
			var mi := mi_var as MeshInstance3D
			var padre := mi.get_parent()
			if padre != null:
				padre.remove_child(mi)
			mi.free()
		ahorrados += lista.size() - 1

	return ahorrados


static func _es_consolidable(mi: MeshInstance3D) -> bool:
	if mi == null or mi.mesh == null:
		return false
	if mi.get_script() != null or mi.get_child_count() > 0:
		return false
	if mi.material_override != null or mi.material_overlay != null:
		return false
	if not is_zero_approx(mi.transparency):
		return false
	for s: int in mi.get_surface_override_material_count():
		if mi.get_surface_override_material(s) != null:
			return false
	return mi.mesh.get_surface_count() == 1 and mi.gi_mode != GeometryInstance3D.GI_MODE_STATIC


static func _clave_del_lote(mi: MeshInstance3D) -> String:
	return (
		"%d|%d|%d|%d|%s"
		% [
			mi.mesh.get_instance_id(),
			mi.gi_mode,
			mi.cast_shadow,
			mi.layers,
			str(mi.visible),
		]
	)


static func _transform_relativo(nodo: Node3D, ancestro: Node3D) -> Transform3D:
	var acumulado := Transform3D.IDENTITY
	var actual: Node = nodo
	while actual != null and actual != ancestro:
		if actual is Node3D:
			acumulado = (actual as Node3D).transform * acumulado
		actual = actual.get_parent()
	return acumulado
