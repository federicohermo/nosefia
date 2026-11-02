extends SceneTree
func _initialize() -> void:
	var a: Object = ClassDB.instantiate("AreaLight3D")
	for p in a.get_property_list():
		if p.usage & PROPERTY_USAGE_EDITOR:
			print(p.name, " = ", a.get(p.name))
	var e: Node = (load("res://src/escenas/puestos/ambiente_del_almacen.tscn") as PackedScene).instantiate()
	for n in e.find_children("*", "AreaLight3D", true, false):
		print(n.name, " ", n.get("area_size"), " ", n.get("area_angle_attenuation") if n.get("area_angle_attenuation") != null else "")
		break
	quit()
