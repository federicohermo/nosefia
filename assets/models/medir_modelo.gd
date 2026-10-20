## Mide las poses y cascos del GLB para integrar_modelo.py, sin modificar el arte.
extends SceneTree


func _initialize() -> void:
	_inventariar.call_deferred()


func _inventariar() -> void:
	var escena: PackedScene = load("res://assets/models/SEPT_JUEGOS_PROTOTIPO.glb")
	var modelo: Node3D = escena.instantiate()
	root.add_child(modelo)
	var datos: Dictionary = {}
	var minimos: Dictionary = {}
	for producto in Catalogo.todos():
		var minimo := 1
		for numero: int in ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA:
			var faltantes := Apertura.pedidos_de(
				Compradores.de_la_jornada(numero + ReglasDeLaPartida.PRIMERA_JORNADA)
			)
			minimo = maxi(minimo, faltantes.get(producto.id, 0))
		minimos[str(Producto.Id.keys()[producto.id])] = minimo
	datos[":minimos"] = {"tipo": "Catalogo", "valores": minimos}
	for nodo: Node in modelo.find_children("*", "Node3D", true, false):
		var fila: Dictionary = {"tipo": nodo.get_class()}
		var objeto := nodo as Node3D
		fila["transform"] = var_to_str(objeto.transform)
		fila["global_transform"] = var_to_str(objeto.global_transform)
		if objeto is MeshInstance3D:
			if objeto.name == &"cajaregistradora":
				# El centro y los extremos de la ranura se leen del atlas de la cara superior.
				var centro := Vector3(0.644, 0.2351, -0.407)
				var ancho := objeto.global_basis.z.length() * 0.484
				var derecha := objeto.global_basis.z.normalized()
				var base := Basis(Vector3.UP.cross(derecha), Vector3.UP, derecha)
				var alto := 0.121548 * ancho / 0.074995
				var pose := Transform3D(
					base, objeto.to_global(centro) + Vector3.UP * (alto / 2 - 0.002)
				)
				fila["pose_ticket"] = var_to_str(objeto.global_transform.affine_inverse() * pose)
				fila["ancho_ticket"] = ancho
			if (
				objeto.name == &"deposito_techo_chapa"
				or str(objeto.name).begins_with("local_vidrio_")
			):
				var caras: Array[float] = []
				for punto: Vector3 in objeto.mesh.get_faces():
					caras.append_array([punto.x, punto.y, punto.z])
				fila["caras"] = caras
			if objeto.name == &"reloj":
				var frente := -objeto.global_basis.x.normalized()
				var derecha := Vector3.UP.cross(frente).normalized()
				var arriba := frente.cross(derecha).normalized()
				var base := objeto.global_basis.inverse() * Basis(derecha, arriba, frente)
				fila["pose_hora"] = var_to_str(
					Transform3D(base, Vector3(objeto.get_aabb().position.x - 0.006, 0, 0))
				)
			var computadora: Node3D = modelo.get_node("base compu")
			fila["a_computadora"] = var_to_str(
				computadora.global_transform.affine_inverse() * objeto.global_transform
			)
			fila["aabb"] = var_to_str(objeto.get_aabb())
			fila["global_aabb"] = var_to_str(objeto.global_transform * objeto.get_aabb())
			var puntos: Array[float] = []
			for punto: Vector3 in objeto.mesh.create_convex_shape(true, false).points:
				puntos.append_array([punto.x, punto.y, punto.z])
			fila["casco"] = puntos
			var cuerpo := Transform3D(
				objeto.global_basis.orthonormalized(),
				objeto.to_global(objeto.get_aabb().get_center())
			)
			var a_cuerpo := cuerpo.affine_inverse() * objeto.global_transform
			fila["cuerpo_transform"] = var_to_str(objeto.global_transform.affine_inverse() * cuerpo)
			var puntos_del_cuerpo: Array[float] = []
			for punto: Vector3 in objeto.mesh.create_convex_shape(true, false).points:
				var transformado := a_cuerpo * punto
				puntos_del_cuerpo.append_array([transformado.x, transformado.y, transformado.z])
			fila["casco_del_cuerpo"] = puntos_del_cuerpo
		datos[str(modelo.get_path_to(nodo))] = fila
	DirAccess.make_dir_recursive_absolute("res://build")
	var objetos: Node3D = load("res://src/escenas/puestos/objetos_del_almacen.tscn").instantiate()
	root.add_child(objetos)
	for caja: Node in objetos.get_children():
		if str(caja.name).begins_with("CajaDe"):
			datos[":" + str(caja.name)] = {"tipo": "Caja", "media": caja.get_node("Cuerpo").scale.y}
		if str(caja.name).begins_with("BolsaDeBasura"):
			var forma: CollisionShape3D = caja.get_node("Forma")
			var limites := forma.global_transform * forma.shape.get_debug_mesh().get_aabb()
			datos[":" + str(caja.name)] = {
				"tipo": "Bolsa", "pie": caja.global_position.y - limites.position.y
			}
	objetos.free()
	var estructura: Node3D = (
		load("res://src/escenas/puestos/estructura_del_almacen.tscn").instantiate()
	)
	var habitaciones: Node3D = estructura.get_node("HabitacionesDelAlmacen")
	var a_mundo := estructura.transform * habitaciones.transform
	var techos: Array[Vector3] = []
	for nombre: String in [
		"almacen",
		"bano_cielorraso",
		"deposito_techo_industrial/deposito_techo_chapa",
		"cuartito_techo",
	]:
		var malla: MeshInstance3D = modelo.get_node(nombre)
		for punto: Vector3 in malla.mesh.get_faces():
			techos.append(malla.to_global(punto))
	var limites_de_habitaciones: Dictionary = {}
	for nombre: String in ["local", "deposito", "bano", "cuartito"]:
		var partes: Array[String] = []
		for caja: AABB in habitaciones.get(nombre):
			var origen := a_mundo * caja.get_center()
			origen.y = (a_mundo * caja.position).y + 0.05
			var altura := INF
			for indice in range(0, techos.size(), 3):
				var choque: Variant = Geometry3D.ray_intersects_triangle(
					origen, Vector3.UP, techos[indice], techos[indice + 1], techos[indice + 2]
				)
				if choque != null:
					altura = minf(altura, (a_mundo.affine_inverse() * choque).y)
			if not is_finite(altura):
				push_error("Sin techo para " + nombre + " " + str(caja))
				estructura.free()
				modelo.free()
				quit(1)
				return
			caja.size.y = altura - caja.position.y
			partes.append(var_to_str(caja))
		limites_de_habitaciones[nombre] = partes
	datos[":habitaciones"] = {"tipo": "Habitaciones", "valores": limites_de_habitaciones}
	estructura.free()
	var archivo := FileAccess.open("res://build/integracion_modelo.json", FileAccess.WRITE)
	archivo.store_string(JSON.stringify(datos))
	modelo.free()
	quit()
