extends SceneTree

const SALIDA := "C:/Users/fede_/AppData/Local/Temp/nosefia-batch-364-370-20261010/301-evidencia/bolsas.json"
var fallos: Array[String] = []
var pasos: Array[Dictionary] = []
var almacen: Node3D
var jugador: CharacterBody3D
var agarre: Agarre
var recolector: RecolectorDeBasura
var bolsa: ObjetoAgarrable

func _initialize() -> void:
	call_deferred("ejecutar")

func comprobar(ok: bool,texto: String) -> void:
	if not ok:
		fallos.append(texto)
		push_error(texto)

func clic(objetivo: Node3D,boton: MouseButton) -> void:
	jugador.set("_enfocado",objetivo)
	var evento := InputEventMouseButton.new()
	evento.button_index=boton
	evento.pressed=true
	jugador.call("_unhandled_input",evento)

func soltar_y_recoger(nombre: String,punto: Vector3) -> void:
	comprobar(agarre.pedir_agarrar(bolsa.datos,bolsa),"No agarra antes de "+nombre)
	agarre.punto_de_soltado.global_position=punto
	comprobar(agarre.soltar(true)==bolsa,"No suelta en "+nombre)
	for cuadro: int in 90:
		await physics_frame
	var posicion := bolsa.global_position
	var contadas := recolector.tarea().depositadas()
	comprobar(contadas==0,"Cuenta automaticamente en "+nombre)
	comprobar(bolsa.visible,"Oculta automaticamente en "+nombre)
	comprobar(agarre.pedir_agarrar(bolsa.datos,bolsa),"No recoge despues de "+nombre)
	comprobar(agarre.manos().sostenido()==bolsa.datos,"No tiene bolsa recogida en "+nombre)
	pasos.append({"paso":nombre,"posicion":var_to_str(posicion),"contadas":contadas,"recogible":agarre.manos().sostenido()==bolsa.datos})
	# El siguiente paso empieza sin llevar nada, pero con la bolsa libre y visible.
	agarre.soltar(true)

func ejecutar() -> void:
	almacen=load("res://src/escenas/almacen.tscn").instantiate()
	root.add_child(almacen)
	current_scene=almacen
	jugador=almacen.get("_jugador")
	jugador.set_physics_process(false)
	agarre=almacen.get("_agarre")
	recolector=almacen.get("_recolector")
	bolsa=almacen.get("_bolsas")[0]
	for cuadro: int in 3:
		await physics_frame
	var tacho: MeshInstance3D=almacen.get_node("Estructura/tachitobasura")
	var cuerpo_tacho: StaticBody3D=tacho.get_node("StaticBody3D")
	comprobar(not cuerpo_tacho.is_in_group("interactuable"),"Tacho adquirio interaccion")
	comprobar(not cuerpo_tacho.has_method("interactuar"),"Tacho adquirio metodo interactuar")
	var limites := tacho.global_transform*tacho.get_aabb()
	await soltar_y_recoger("sobre_tacho",Vector3(limites.get_center().x,limites.end.y+0.15,limites.get_center().z))
	var contenedor: StaticBody3D=almacen.get("_contenedor")
	var tapa: Node3D=almacen.get("_tapa_del_contenedor")
	jugador.global_position=contenedor.global_position+Vector3.BACK
	await soltar_y_recoger("cerca_contenedor",contenedor.global_position+Vector3(0,0.4,0.8))
	comprobar(tapa.call("recibe_objetos"),"Tapa no empieza completamente abierta")
	await soltar_y_recoger("por_boca_abierta",contenedor.global_position+Vector3.UP*1.2)
	comprobar(agarre.pedir_agarrar(bolsa.datos,bolsa),"No agarra bolsa final")
	clic(contenedor,MOUSE_BUTTON_RIGHT)
	tapa.set_physics_process(false)
	tapa.call("_physics_process",1.0)
	await physics_frame
	await physics_frame
	comprobar(not tapa.call("recibe_objetos"),"Derecho no cerro tapa")
	clic(contenedor,MOUSE_BUTTON_LEFT)
	comprobar(agarre.manos().sostenido()==bolsa.datos,"Izquierdo cerrado perdio bolsa")
	comprobar(recolector.tarea().depositadas()==0,"Izquierdo cerrado conto")
	clic(contenedor,MOUSE_BUTTON_RIGHT)
	comprobar(recolector.tarea().depositadas()==0,"Derecho abriendo conto")
	clic(contenedor,MOUSE_BUTTON_LEFT)
	comprobar(recolector.tarea().depositadas()==0,"Izquierdo durante giro conto")
	tapa.call("_physics_process",1.0)
	await physics_frame
	await physics_frame
	comprobar(tapa.call("recibe_objetos"),"No termino abierta")
	comprobar(recolector.tarea().depositadas()==0,"Abrir deposito automaticamente")
	clic(contenedor,MOUSE_BUTTON_LEFT)
	comprobar(recolector.tarea().depositadas()==1,"Izquierdo abierto no conto")
	comprobar(agarre.manos().sostenido()==null,"Izquierdo abierto retuvo bolsa")
	comprobar(not bolsa.visible,"Izquierdo abierto no oculto bolsa")
	pasos.append({"paso":"clic_cerrada_girando_abierta","contadas":recolector.tarea().depositadas(),"solo_izquierdo_abierta":fallos.is_empty()})
	var archivo := FileAccess.open(SALIDA,FileAccess.WRITE)
	archivo.store_string(JSON.stringify({"pasos":pasos,"fallos":fallos},"\t"))
	archivo.close()
	print("301_BOLSAS_FINAL ",fallos)
	current_scene=null
	almacen.queue_free()
	almacen=null
	jugador=null
	agarre=null
	recolector=null
	bolsa=null
	call_deferred("cerrar")

func cerrar() -> void:
	await process_frame
	await process_frame
	quit(0 if fallos.is_empty() else 1)
