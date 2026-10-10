extends SceneTree

const SALIDA := "C:/Users/fede_/AppData/Local/Temp/nosefia-batch-364-370-20261010/301-evidencia"
var almacen: Node3D
var jugador: CharacterBody3D
var espacio: PhysicsDirectSpaceState3D
var forma: CollisionShape3D
var fallos: Array[String] = []
var rechazos: Dictionary = {}

func rechazo(razon: String) -> void:
	rechazos[razon] = int(rechazos.get(razon,0))+1

func _initialize() -> void:
	call_deferred("ejecutar")

func comprobar(condicion: bool, mensaje: String) -> void:
	if not condicion:
		fallos.append(mensaje)
		push_error(mensaje)

func lista(v: Vector3) -> Array[float]:
	return [v.x,v.y,v.z]

func limites(m: MeshInstance3D) -> AABB:
	return m.global_transform * m.get_aabb()

func resumen() -> Dictionary:
	var datos: Dictionary = {}
	for n: Node3D in almacen.find_children("*","Node3D",true,false):
		var d: Dictionary = {"clase": n.get_class(), "transform": var_to_str(n.transform),"mundo":var_to_str(n.global_transform)}
		if n is MeshInstance3D:
			var m: MeshInstance3D = n
			d["bounds"] = var_to_str(limites(m))
			d["malla"] = var_to_bytes(m.mesh.get_faces()).hex_encode().sha256_text() if m.mesh != null else "null"
			d["materiales"] = []
			if m.mesh != null:
				for s: int in m.mesh.get_surface_count():
					d["materiales"].append(m.get_active_material(s).resource_path if m.get_active_material(s) != null else "null")
		if n is CollisionShape3D:
			var c: CollisionShape3D = n
			d["disabled"] = c.disabled
			d["forma"] = var_to_bytes(c.shape.get_debug_mesh().get_faces()).hex_encode().sha256_text() if c.shape != null else "null"
		datos[str(almacen.get_path_to(n))] = d
	return datos

func consulta_en(pie: Vector3) -> PhysicsShapeQueryParameters3D:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = forma.shape
	q.transform = Transform3D(jugador.global_basis,pie) * forma.transform
	q.collision_mask = jugador.collision_mask
	q.exclude = [jugador.get_rid()]
	return q

func pie_caminable(x: float,z: float) -> Variant:
	var r := PhysicsRayQueryParameters3D.create(Vector3(x,0.5,z),Vector3(x,-0.5,z),1)
	r.exclude = [jugador.get_rid()]
	var golpe := espacio.intersect_ray(r)
	if golpe.is_empty() or golpe.normal.y < 0.9:
		rechazo("sin_piso_o_normal")
		return null
	var ruta := str(almacen.get_path_to(golpe.collider))
	var suelo: CollisionShape3D = almacen.get_node("Estructura/SueloSolido/Local")
	var piso := (suelo.global_transform * suelo.shape.get_debug_mesh().get_aabb()).end.y
	# El spawn pisa la alfombra real, no directamente el casco del edificio.
	# Se aceptan superficies estructurales horizontales al nivel del piso, no muebles altos.
	if not ruta.begins_with("Estructura/") or absf(golpe.position.y-piso)>0.06:
		rechazo("apoyo_ajeno:"+ruta)
		return null
	var pie: Vector3 = golpe.position + Vector3.UP * 0.02
	if not espacio.intersect_shape(consulta_en(pie)).is_empty():
		rechazo("capsula_solapada")
		return null
	return pie

func circulacion() -> Dictionary:
	var paso := 0.20
	var nodos: Dictionary = {}
	for ix: int in range(-55,51):
		for iz: int in range(-110,16):
			var pie: Variant = pie_caminable(jugador.position.x+ix*paso,jugador.position.z+iz*paso)
			if pie != null:
				nodos[Vector2i(ix,iz)] = pie
	var origen := Vector2i.ZERO
	comprobar(nodos.has(origen),"Origen de circulacion no caminable")
	if not nodos.has(origen):
		print("301_CIRCULACION_RECHAZOS ",nodos.size()," ",rechazos)
		return {"libres":nodos.size(),"rechazos":rechazos,"sin_origen":true}
	var pendientes: Array[Vector2i] = [origen]
	var visitados: Dictionary = {origen:true}
	var indice := 0
	while indice < pendientes.size():
		var aqui := pendientes[indice]
		indice += 1
		for delta: Vector2i in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var vecino := aqui+delta
			if not nodos.has(vecino) or visitados.has(vecino):
				continue
			var q := consulta_en(nodos[aqui])
			q.motion = nodos[vecino]-nodos[aqui]
			var barrido := espacio.cast_motion(q)
			if barrido[0] < 0.999:
				continue
			visitados[vecino] = true
			pendientes.append(vecino)
	var resultado: Dictionary = {"paso":paso,"libres":nodos.size(),"alcanzados":visitados.size(),"rechazos":rechazos,"destinos":{}}
	for ruta: String in ["Estructura/puerta","Estructura/puerta2","Estructura/bano_puerta_1","Estructura/bano_puerta_2","Estructura/Ventanilla","Estructura/EscritorioComputadora"]:
		var destino: Node3D = almacen.get_node(ruta)
		var centro := limites(destino).get_center() if destino is MeshInstance3D else destino.global_position
		var distancia := INF
		var pie := Vector3.ZERO
		for celda: Vector2i in visitados:
			if not nodos.has(celda):
				continue
			var p: Vector3 = nodos[celda]
			var d := Vector2(p.x,p.z).distance_to(Vector2(centro.x,centro.z))
			if d<distancia:
				distancia=d
				pie=p
		resultado["destinos"][ruta] = {"centro":lista(centro),"pie":lista(pie),"distancia":distancia}
		comprobar(distancia < 1.8,"Sin acceso a "+ruta)
	return resultado

func captura(nombre: String,camara: Camera3D) -> void:
	camara.make_current()
	for i: int in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var imagen := root.get_texture().get_image()
	comprobar(imagen.save_png(SALIDA+"/"+nombre+".png")==OK,"No guardo captura "+nombre)

func ejecutar() -> void:
	DirAccess.make_dir_recursive_absolute(SALIDA)
	var args := OS.get_cmdline_user_args()
	var modo := args[0] if not args.is_empty() else "base"
	root.size = Vector2i(1600,900)
	almacen = load("res://src/escenas/almacen.tscn").instantiate()
	root.add_child(almacen)
	current_scene = almacen
	jugador = almacen.get("_jugador")
	forma = jugador.get_node("Cuerpo")
	jugador.set_physics_process(false)
	var tacho: MeshInstance3D = almacen.get_node("Estructura/tachitobasura")
	var entrada: MeshInstance3D = almacen.get_node("Estructura/puertaentrada")
	if modo == "candidato":
		tacho.position += Vector3(-0.66,0,0.45)
	for i: int in 12:
		await physics_frame
	# No deshabilitar process_mode: CollisionObject3D quitaría los cuerpos del mundo.
	espacio = jugador.get_world_3d().direct_space_state
	var a := limites(tacho)
	var b := limites(entrada)
	var distancia := Vector2(a.get_center().x,a.get_center().z).distance_to(Vector2(b.get_center().x,b.get_center().z))
	var solapamientos := espacio.intersect_shape(consulta_en(jugador.global_position))
	var choque_tacho := false
	var cuerpos: Array[String] = []
	for golpe: Dictionary in solapamientos:
		cuerpos.append(str(almacen.get_path_to(golpe.collider)))
		if tacho.is_ancestor_of(golpe.collider):
			choque_tacho = true
	comprobar(not choque_tacho,"Jugador arranca dentro tacho")
	comprobar(solapamientos.is_empty(),"Capsula inicial solapada: "+str(cuerpos))
	if modo != "base":
		comprobar(distancia <= 2.0,"Centros superan 2 m")
	var resultado: Dictionary = {"modo":modo,"tacho_origen":lista(tacho.global_position),"tacho_min":lista(a.position),"tacho_max":lista(a.end),"tacho_centro":lista(a.get_center()),"entrada_min":lista(b.position),"entrada_max":lista(b.end),"entrada_centro":lista(b.get_center()),"distancia_centros_xz":distancia,"spawn":lista(jugador.global_position),"spawn_solapamientos":cuerpos,"nodos":resumen()}
	var ojo: Camera3D = jugador.get_node("Giro/Camara")
	if modo != "candidato":
		await captura(modo+"-arranque",ojo)
		ojo.look_at(a.get_center()+Vector3.UP*0.10)
		await captura(modo+"-desde-arranque-hacia-entrada",ojo)
		var camara := Camera3D.new()
		almacen.add_child(camara)
		camara.global_position = Vector3(5.0,2.1,3.4)
		camara.look_at(Vector3(6.9,0.35,5.55))
		await captura(modo+"-posicion-y-sombras",camara)
		camara.queue_free()
	# Abrir solo las puertas interiores, conservando la entrada trabada.
	for ruta: String in ["Estructura/puerta/CuerpoDeLaHoja","Estructura/puerta2/CuerpoDeLaHoja","Estructura/bano_puerta_1/CuerpoDeLaHoja","Estructura/bano_puerta_2/CuerpoDeLaHoja"]:
		almacen.get_node(ruta).call("usar")
	for i: int in 90:
		await physics_frame
	resultado["circulacion"] = circulacion()
	resultado["fallos"] = fallos
	var f := FileAccess.open(SALIDA+"/"+modo+"-escena.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(resultado,"\t"))
	f.close()
	print("301_ESCENA_FINAL ", modo, " centros=",distancia," fallos=",fallos)
	current_scene = null
	almacen.queue_free()
	almacen = null
	jugador = null
	forma = null
	espacio = null
	call_deferred("cerrar")

func cerrar() -> void:
	await process_frame
	await process_frame
	quit(0 if fallos.is_empty() else 1)
