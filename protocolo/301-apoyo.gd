extends SceneTree

func _initialize() -> void:
	call_deferred("ejecutar")

func ejecutar() -> void:
	var almacen: Node3D=load("res://src/escenas/almacen.tscn").instantiate()
	root.add_child(almacen)
	var jugador: CharacterBody3D=almacen.get("_jugador")
	jugador.set_physics_process(false)
	var tacho: MeshInstance3D=almacen.get_node("Estructura/tachitobasura")
	var args:=OS.get_cmdline_user_args()
	var modo:=args[0] if not args.is_empty() else "final"
	if modo=="candidato":
		tacho.position+=Vector3(-0.66,0,0.45)
	for i: int in 3:
		await physics_frame
	var limites:=tacho.global_transform*tacho.get_aabb()
	var cuerpo: StaticBody3D=tacho.get_node("StaticBody3D")
	var muestras: Array[Dictionary]=[]
	var errores: Array[String]=[]
	for lateral: Vector3 in [Vector3.ZERO,Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
		var punto:=limites.get_center()+lateral*0.15
		punto.y=limites.position.y
		var q:=PhysicsRayQueryParameters3D.create(punto+Vector3.UP*0.05,punto+Vector3.DOWN*0.1,1)
		q.exclude=[cuerpo.get_rid()]
		var golpe:=tacho.get_world_3d().direct_space_state.intersect_ray(q)
		if golpe.is_empty():
			errores.append("Sin apoyo en "+var_to_str(punto))
			continue
		var ruta:=str(almacen.get_path_to(golpe.collider))
		var hueco: float=punto.y-golpe.position.y
		muestras.append({"pie":var_to_str(punto),"apoyo":var_to_str(golpe.position),"cuerpo":ruta,"hueco":hueco})
		if not ruta.begins_with("Estructura/almacen") and not ruta.begins_with("Estructura/SueloSolido"):
			errores.append("Apoyo ajeno a piso "+ruta)
		if absf(hueco)>0.01:
			errores.append("Tacho flota o se hunde "+str(hueco))
	var f:=FileAccess.open("C:/Users/fede_/AppData/Local/Temp/nosefia-batch-364-370-20261010/301-evidencia/"+modo+"-apoyo.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"muestras":muestras,"errores":errores},"\t"))
	f.close()
	print("301_APOYO_FINAL ",modo," ",errores)
	almacen.queue_free()
	call_deferred("cerrar",errores.is_empty())

func cerrar(ok: bool) -> void:
	await process_frame
	await process_frame
	quit(0 if ok else 1)
