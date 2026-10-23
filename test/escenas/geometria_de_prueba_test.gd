extends GdUnitTestSuite

const ALMACEN := "res://src/escenas/almacen.tscn"
const ReposicionManual := preload("res://src/escenas/puestos/reposicion_manual.gd")


func _abrir() -> Node3D:
	var escena := load(ALMACEN) as PackedScene
	var local: Node3D = auto_free(escena.instantiate())
	local.set("_partida", Partida.desde({"jornada": 1, "medios": 0}))
	add_child(local)
	local.get("_jugador").set_physics_process(false)
	local.get("_reloj").set_process(false)
	return local


func test_la_prueba_conserva_el_retiro_frontal_del_mapa_completo() -> void:  # AC-STK-103
	var local := _abrir()
	var prueba := _frentes_de_las_tandas(local, 1)
	local.call("_al_abrir_la_jornada", ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA)
	var completa := _frentes_de_las_tandas(local, ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA)
	assert_bool(prueba.is_empty()).is_false()
	for clave: String in prueba:
		assert_bool(completa.has(clave)).override_failure_message(clave).is_true()
		if not completa.has(clave):
			return
		assert_float(prueba[clave]).override_failure_message(clave).is_greater_equal(
			completa[clave] - ReposicionManual.TOLERANCIA_DEL_APOYO
		)


func test_el_aire_entre_filas_de_cabeceras_conserva_la_referencia() -> void:  # AC-STK-102
	var local := _abrir()
	var puesto: Node3D = local.get("_reposicion_manual")
	var aires: Dictionary[Producto.Id, float] = {}
	for id: Producto.Id in [Producto.Id.FERNET_GOD, Producto.Id.MALBARDO, Producto.Id.JORGILLO]:
		aires[id] = _aire_entre_filas(puesto, id)
		assert_float(aires[id] + ReglasDelEstante.TOLERANCIA_DE_EXHIBICION).is_greater_equal(
			ReglasDelEstante.AIRE_MINIMO_ENTRE_FILAS
		)
	local.call("_al_abrir_la_jornada", ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA)
	for id: Producto.Id in aires:
		assert_float(aires[id]).override_failure_message(Catalogo.de(id).nombre).is_greater_equal(
			_aire_entre_filas(puesto, id) - ReposicionManual.TOLERANCIA_DEL_APOYO
		)


func _aire_entre_filas(puesto: Node3D, id: Producto.Id) -> float:
	var disposicion: DisposicionDeLaGondola = puesto.get("disposicion")
	var producto := Catalogo.de(id)
	var grupo: MultiMeshInstance3D = puesto.get_node("ProductosDe" + producto.nombre)
	var vertices := grupo.multimesh.mesh.get_faces()
	var buffer: PackedFloat32Array = disposicion.principales[id]
	var frontales: int = disposicion.filas_de_adelante[id]
	var frente := DisposicionDeLaGondola.frente(buffer, frontales)
	frente.y = 0.0
	frente = frente.normalized()
	var fin_del_frente := -INF
	var inicio_del_fondo := INF
	for indice in DisposicionDeLaGondola.copias(buffer):
		var copia := DisposicionDeLaGondola.copia(buffer, indice)
		for vertice in vertices:
			var v: float = (copia * vertice).dot(-frente)
			if indice < DisposicionDeLaGondola.copias(buffer) - frontales:
				inicio_del_fondo = minf(inicio_del_fondo, v)
			else:
				fin_del_frente = maxf(fin_del_frente, v)
	return inicio_del_fondo - fin_del_frente


func _frentes_de_las_tandas(local: Node3D, jornada: int) -> Dictionary[String, float]:
	var puesto: Node3D = local.get("_reposicion_manual")
	var contenido: Node3D = puesto.get("contenido")
	var muebles: Array[MeshInstance3D] = []
	for nombre: String in [
		"gondolanueva", "gondolanueva2", "gondolanueva_001", "heladeranueva", "heladeranueva_001"
	]:
		muebles.append(local.get_node("Estructura/" + nombre))
	var frentes: Dictionary[String, float] = {}
	for producto in Catalogo.de_la_jornada(jornada):
		var grupo: MultiMeshInstance3D = puesto.get_node("ProductosDe" + producto.nombre)
		var modelo := contenido.get_child(producto.id) as MeshInstance3D
		var frente_local: Vector3 = modelo.get_meta("frente_del_modelo")
		for indice in grupo.multimesh.instance_count:
			var copia := (
				grupo.global_transform
				* DisposicionDeLaGondola.copia(grupo.multimesh.buffer, indice)
			)
			var limites := copia * grupo.multimesh.mesh.get_aabb()
			var frente := copia.basis * modelo.global_basis * frente_local
			frente.y = 0.0
			frente = frente.normalized().round()
			for mueble in muebles:
				var caja := mueble.global_transform * mueble.mesh.get_aabb()
				if not caja.has_point(limites.get_center()):
					continue
				var nivel := roundi(limites.position.y / ReposicionManual.TOLERANCIA_DEL_APOYO)
				var clave := "%s/%s/%d" % [mueble.name, frente, nivel]
				var borde := INF
				for esquina in 8:
					borde = minf(borde, limites.get_endpoint(esquina).dot(-frente))
				frentes[clave] = minf(frentes.get(clave, borde), borde)
	return frentes


func test_las_tandas_dibujadas_conservan_el_frente_real_de_las_mallas() -> void:  # AC-STK-096
	var local := _abrir()
	var puesto: Node3D = local.get("_reposicion_manual")
	var disposicion: DisposicionDeLaGondola = puesto.get("disposicion")
	var contenido: Node3D = puesto.get("contenido")
	for producto in Catalogo.de_la_jornada(1):
		var modelo := contenido.get_child(producto.id) as MeshInstance3D
		var frente_local: Vector3 = modelo.get_meta("frente_del_modelo")
		var frente_horneado := modelo.global_basis * frente_local
		var frente := DisposicionDeLaGondola.frente(
			disposicion.principales[producto.id], disposicion.filas_de_adelante[producto.id]
		)
		var grupo: MultiMeshInstance3D = puesto.get_node("ProductosDe" + producto.nombre)
		for indice in grupo.multimesh.instance_count:
			var copia := DisposicionDeLaGondola.copia(grupo.multimesh.buffer, indice)
			var real := (copia.basis * frente_horneado).normalized()
			assert_float(real.dot(frente)).override_failure_message(producto.nombre).is_greater(
				0.98
			)
			if real.dot(frente) <= 0.98:
				print(
					(
						"Base original %s, principal %s, buffer %s, modo %s"
						% [
							modelo.global_basis,
							DisposicionDeLaGondola.copia(disposicion.principales[producto.id], 0),
							copia,
							disposicion.base_de_guias
						]
					)
				)
				print(
					(
						"Frente %s, copia %d: real %s, esperado %s"
						% [producto.nombre, indice, real, frente]
					)
				)
				return


func test_los_productos_movidos_conservan_su_orientacion_en_la_mano() -> void:  # AC-STK-098
	var local := _abrir()
	var puesto: Node3D = local.get("_reposicion_manual")
	var agarre: Agarre = local.get("_agarre")
	for id: Producto.Id in [Producto.Id.TERMINATOR, Producto.Id.POETICO]:
		local.call("_al_abrir_la_jornada", 1)
		await get_tree().process_frame
		puesto.call("retirar", id)
		var unidad := agarre.cuerpo_sostenido()
		var orientacion: Basis = unidad.get("orientacion_en_mano")
		assert_object(agarre.manos().sostenido()).is_not_null()
		local.call("_al_abrir_la_jornada", 8)
		await get_tree().process_frame
		puesto.call("retirar", id)
		unidad = agarre.cuerpo_sostenido()
		assert_bool(orientacion.is_equal_approx(unidad.get("orientacion_en_mano"))).is_true()


func test_cada_unidad_dibujada_tiene_el_apoyo_de_la_malla_real() -> void:  # AC-STK-103
	var local := _abrir()
	var puesto: Node3D = local.get("_reposicion_manual")
	var modelos: Array = puesto.get("_modelos")
	var chapas: Array[PackedVector3Array] = []
	for nombre: String in [
		"gondolanueva", "gondolanueva2", "gondolanueva_001", "heladeranueva", "heladeranueva_001"
	]:
		var mueble: MeshInstance3D = local.get_node("Estructura/" + nombre)
		var caras := mueble.mesh.get_faces()
		for i in caras.size():
			caras[i] = mueble.to_global(caras[i])
		chapas.append(caras)
	for producto in Catalogo.de_la_jornada(1):
		var grupo: MultiMeshInstance3D = puesto.get_node("ProductosDe" + producto.nombre)
		var modelo: Mesh = modelos[producto.id]
		for indice in grupo.multimesh.instance_count:
			var copia := DisposicionDeLaGondola.copia(grupo.multimesh.buffer, indice)
			var limites := copia * modelo.get_aabb()
			var pie := limites.get_center() - Vector3.UP * limites.size.y / 2.0
			var error := _distancia_al_apoyo(chapas, pie)
			(
				assert_float(error)
				. override_failure_message("%s/%d en %s" % [producto.nombre, indice, pie])
				. is_less(0.006)
			)
			if error >= 0.006:
				return


func _distancia_al_apoyo(chapas: Array[PackedVector3Array], pie: Vector3) -> float:
	var menor := INF
	for caras in chapas:
		for i in range(0, caras.size(), 3):
			var golpe: Variant = Geometry3D.segment_intersects_triangle(
				pie + Vector3.UP * 0.03,
				pie + Vector3.DOWN * 0.03,
				caras[i],
				caras[i + 1],
				caras[i + 2]
			)
			if golpe != null:
				menor = minf(menor, absf((golpe as Vector3).y - pie.y))
	return menor


func test_las_cabeceras_tienen_aire_y_margen_en_ambos_costados() -> void:  # AC-STK-102
	var local := _abrir()
	var referencias := _referencias_de_separacion(local)
	var filas := _filas_de_exhibicion(local)
	var cabeceras := 0
	for fila in filas:
		var frente: Vector3 = fila.frente
		if absf(frente.z) <= absf(frente.x):
			continue
		cabeceras += 1
		_comprobar_ritmo(fila, _referencia_de_exhibicion(referencias, fila.producto))
		var mueble: MeshInstance3D = fila.mueble
		var soporte := mueble.global_transform * mueble.mesh.get_aabb()
		var caja := _envolvente(fila.cajas)
		var margen := minf(caja.position.x - soporte.position.x, soporte.end.x - caja.end.x)
		(
			assert_float(margen + ReglasDelEstante.TOLERANCIA_DE_EXHIBICION)
			. override_failure_message(fila.producto)
			. is_greater_equal(ReglasDelEstante.MARGEN_LATERAL_DE_EXHIBICION)
		)
		for lateral in filas:
			if lateral.mueble != mueble or lateral.nivel != fila.nivel:
				continue
			var otra: Vector3 = lateral.frente
			if absf(otra.x) <= absf(otra.z):
				continue
			for a: AABB in fila.cajas:
				for b: AABB in lateral.cajas:
					var distancia := (
						Vector2(
							maxf(0, maxf(a.position.x - b.end.x, b.position.x - a.end.x)),
							maxf(0, maxf(a.position.z - b.end.z, b.position.z - a.end.z))
						)
						. length()
					)
					(
						assert_float(distancia + ReglasDelEstante.TOLERANCIA_DE_EXHIBICION)
						. override_failure_message(
							"%s contra %s" % [fila.producto, lateral.producto]
						)
						. is_greater_equal(
							maxf(
								ReglasDelEstante.AIRE_MINIMO_ENTRE_CARAS,
								maxf(referencias[fila.producto], referencias[lateral.producto])
							)
						)
					)
	assert_int(cabeceras).is_greater(0)


func test_los_laterales_tienen_ritmo_y_aire_en_la_union_de_las_mitades() -> void:  # AC-STK-101
	var local := _abrir()
	var referencias := _referencias_de_separacion(local)
	var filas := _filas_de_exhibicion(local)
	var tandas: Dictionary[String, Array] = {}
	for fila in filas:
		var frente: Vector3 = fila.frente
		if absf(frente.x) <= absf(frente.z):
			continue
		_comprobar_ritmo(fila, _referencia_de_exhibicion(referencias, fila.producto))
		var clave := "%s/%s/%s" % [fila.mueble.name, frente, fila.nivel]
		if not tandas.has(clave):
			tandas[clave] = []
		var caja := _envolvente(fila.cajas)
		var encontrada := false
		for tanda: Dictionary in tandas[clave]:
			if tanda.producto == fila.producto:
				tanda.caja = (tanda.caja as AABB).merge(caja)
				encontrada = true
		if not encontrada:
			tandas[clave].append({"producto": fila.producto, "caja": caja})
	assert_bool(tandas.is_empty()).is_false()
	for clave: String in tandas:
		var par: Array = tandas[clave]
		assert_int(par.size()).override_failure_message(clave).is_equal(2)
		if par.size() != 2:
			return
		var a: AABB = par[0].caja
		var b: AABB = par[1].caja
		var aire := maxf(a.position.z - b.end.z, b.position.z - a.end.z)
		(
			assert_float(aire + ReglasDelEstante.TOLERANCIA_DE_EXHIBICION)
			. override_failure_message(clave)
			. is_greater_equal(ReglasDelEstante.AIRE_MINIMO_ENTRE_TANDAS)
		)


func test_el_reparto_con_aire_no_superpone_unidades() -> void:  # AC-STK-103
	var filas := _filas_de_exhibicion(_abrir())
	var cajas: Array[AABB] = []
	for fila in filas:
		for caja: AABB in fila.cajas:
			cajas.append(caja)
	assert_bool(cajas.is_empty()).is_false()
	for i in cajas.size():
		for j in range(i):
			(
				assert_bool(
					cajas[i].grow(-ReglasDelEstante.TOLERANCIA_DE_EXHIBICION).intersects(cajas[j])
				)
				. is_false()
			)


func test_el_encuentro_de_dos_productos_deja_el_paso_de_sus_unidades() -> void:  # AC-STK-105
	var estantes: Dictionary[String, Dictionary] = {}
	for fila in _filas_de_exhibicion(_abrir()):
		var clave := "%s/%s/%s" % [fila.mueble.name, fila.frente, fila.nivel]
		if not estantes.has(clave):
			estantes[clave] = {
				"eje": (fila.frente as Vector3).cross(Vector3.UP).abs(), "productos": {}
			}
		var productos: Dictionary = estantes[clave].productos
		if not productos.has(fila.producto):
			productos[fila.producto] = {"cajas": [], "pasos": []}
		productos[fila.producto].cajas.append_array(fila.cajas)
		productos[fila.producto].pasos.append_array(_huecos_de(fila))
	var con_dos := 0
	for clave: String in estantes:
		var eje: Vector3 = estantes[clave].eje
		var productos: Array = estantes[clave].productos.values()
		if productos.size() != 2:
			continue
		con_dos += 1
		productos.sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool:
				return (
					_envolvente(a.cajas).get_center().dot(eje)
					< _envolvente(b.cajas).get_center().dot(eje)
				)
		)
		var encuentro := (
			_envolvente(productos[1].cajas).position.dot(eje)
			- _envolvente(productos[0].cajas).end.dot(eje)
		)
		var esperado := maxf(
			ReglasDelEstante.AIRE_MINIMO_ENTRE_TANDAS,
			maxf(_promedio(productos[0].pasos), _promedio(productos[1].pasos))
		)
		(
			assert_float(absf(encuentro - esperado))
			. override_failure_message(
				"%s: encuentro %f, esperado %f" % [clave, encuentro, esperado]
			)
			. is_less_equal(ReglasDelEstante.TOLERANCIA_DE_EXHIBICION)
		)
	assert_int(con_dos).is_greater(0)


func test_terminator_toma_el_paso_de_zucarachas() -> void:  # AC-STK-106
	var local := _abrir()
	var producto := Catalogo.de(Producto.Id.TERMINATOR)
	var repositor: Repositor = local.get("_repositor")
	assert_int(repositor.estante().cupo(producto)).is_equal(40)
	var terminator := Catalogo.de(Producto.Id.TERMINATOR).nombre
	var zucarachas := Catalogo.de(Producto.Id.ZUCARACHAS).nombre
	var pasos: Dictionary[String, Array] = {terminator: [], zucarachas: []}
	var filas_de_terminator := 0
	for fila in _filas_de_exhibicion(local):
		if fila.producto == terminator:
			filas_de_terminator += 1
			assert_int(fila.cajas.size()).is_equal(10)
		if pasos.has(fila.producto):
			pasos[fila.producto].append_array(_huecos_de(fila))
	assert_int(filas_de_terminator).is_equal(8)
	for nombre: String in pasos:
		assert_array(pasos[nombre]).override_failure_message(nombre).is_not_empty()
	assert_float(absf(_promedio(pasos[terminator]) - _promedio(pasos[zucarachas]))).is_less_equal(
		ReglasDelEstante.TOLERANCIA_DE_EXHIBICION
	)
	for hueco: float in pasos[terminator]:
		assert_float(absf(hueco - _promedio(pasos[zucarachas]))).is_less_equal(
			ReglasDelEstante.TOLERANCIA_DE_EXHIBICION
		)


func _referencia_de_exhibicion(referencias: Dictionary[String, float], nombre: String) -> float:
	if nombre == Catalogo.de(Producto.Id.TERMINATOR).nombre:
		return referencias[Catalogo.de(Producto.Id.ZUCARACHAS).nombre]
	return referencias[nombre]


func _huecos_de(fila: Dictionary) -> Array[float]:
	var eje := (fila.frente as Vector3).cross(Vector3.UP).abs()
	var cajas: Array = (fila.cajas as Array).duplicate()
	cajas.sort_custom(
		func(a: AABB, b: AABB) -> bool: return a.get_center().dot(eje) < b.get_center().dot(eje)
	)
	var huecos: Array[float] = []
	for i in range(1, cajas.size()):
		huecos.append((cajas[i] as AABB).position.dot(eje) - (cajas[i - 1] as AABB).end.dot(eje))
	return huecos


func _promedio(valores: Array) -> float:
	var suma := 0.0
	for valor: float in valores:
		suma += valor
	return suma / maxf(valores.size(), 1.0)


func _referencias_de_separacion(local: Node3D) -> Dictionary[String, float]:
	local.call("_al_abrir_la_jornada", ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA)
	var puesto: Node3D = local.get("_reposicion_manual")
	var disposicion: DisposicionDeLaGondola = puesto.get("disposicion")
	var resultado: Dictionary[String, float] = {}
	for producto in Catalogo.de_la_jornada(1):
		var grupo: MultiMeshInstance3D = puesto.get_node("ProductosDe" + producto.nombre)
		var buffer: PackedFloat32Array = disposicion.principales[producto.id]
		var frontales: int = disposicion.filas_de_adelante[producto.id]
		var frente := DisposicionDeLaGondola.frente(buffer, frontales).round()
		var eje := frente.cross(Vector3.UP).abs()
		var cajas: Array[AABB] = []
		for i in range(
			DisposicionDeLaGondola.copias(buffer) - frontales, DisposicionDeLaGondola.copias(buffer)
		):
			var copia := DisposicionDeLaGondola.copia(buffer, i)
			var vertices := grupo.multimesh.mesh.get_faces()
			var caja := AABB(copia * vertices[0], Vector3.ZERO)
			for vertice in vertices:
				caja = caja.expand(copia * vertice)
			cajas.append(caja)
		cajas.sort_custom(
			func(a: AABB, b: AABB) -> bool: return a.get_center().dot(eje) < b.get_center().dot(eje)
		)
		assert_int(cajas.size()).is_greater(1)
		var aire := 0.0
		for i in range(1, cajas.size()):
			aire += cajas[i].position.dot(eje) - cajas[i - 1].end.dot(eje)
		resultado[producto.nombre] = aire / (cajas.size() - 1)
	local.call("_al_abrir_la_jornada", 1)
	return resultado


func _comprobar_ritmo(fila: Dictionary, referencia: float) -> void:
	var cajas: Array = fila.cajas
	var frente: Vector3 = fila.frente
	var eje := frente.cross(Vector3.UP).abs()
	cajas.sort_custom(
		func(a: AABB, b: AABB) -> bool: return a.get_center().dot(eje) < b.get_center().dot(eje)
	)
	var anterior := -INF
	for i in range(1, cajas.size()):
		var a: AABB = cajas[i - 1]
		var b: AABB = cajas[i]
		var hueco := b.position.dot(eje) - a.end.dot(eje)
		(
			assert_float(hueco + ReglasDelEstante.TOLERANCIA_DE_EXHIBICION)
			. override_failure_message(fila.producto)
			. is_greater_equal(ReglasDelEstante.SEPARACION_MINIMA_DE_EXHIBICION)
		)
		(
			assert_float(absf(hueco - referencia))
			. override_failure_message(fila.producto)
			. is_less_equal(ReposicionManual.TOLERANCIA_DEL_APOYO)
		)
		if anterior != -INF:
			(
				assert_float(absf(hueco - anterior))
				. override_failure_message(fila.producto)
				. is_less_equal(ReglasDelEstante.TOLERANCIA_DE_EXHIBICION)
			)
		anterior = hueco


func _envolvente(cajas: Array) -> AABB:
	var caja: AABB = cajas[0]
	for otra: AABB in cajas:
		caja = caja.merge(otra)
	return caja


func _filas_de_exhibicion(local: Node3D) -> Array[Dictionary]:
	var puesto: Node3D = local.get("_reposicion_manual")
	var disposicion: DisposicionDeLaGondola = puesto.get("disposicion")
	var muebles: Array[MeshInstance3D] = [
		local.get_node("Estructura/gondolanueva"),
		local.get_node("Estructura/gondolanueva2"),
		local.get_node("Estructura/gondolanueva_001")
	]
	var filas: Dictionary[String, Dictionary] = {}
	for producto in Catalogo.de_la_jornada(1):
		var grupo: MultiMeshInstance3D = puesto.get_node("ProductosDe" + producto.nombre)
		var vertices := grupo.multimesh.mesh.get_faces()
		var frente := (
			DisposicionDeLaGondola
			. frente(
				disposicion.principales[producto.id], disposicion.filas_de_adelante[producto.id]
			)
			. round()
		)
		for indice in grupo.multimesh.instance_count:
			var copia := (
				grupo.global_transform
				* DisposicionDeLaGondola.copia(grupo.multimesh.buffer, indice)
			)
			var caja := AABB(copia * vertices[0], Vector3.ZERO)
			for vertice in vertices:
				caja = caja.expand(copia * vertice)
			for mueble in muebles:
				var soporte := mueble.global_transform * mueble.mesh.get_aabb()
				if not soporte.has_point(caja.get_center()):
					continue
				var nivel := snappedf(caja.position.y, ReposicionManual.TOLERANCIA_DEL_APOYO)
				var fondo := snappedf(
					caja.get_center().dot(frente), ReposicionManual.TOLERANCIA_DEL_APOYO
				)
				var clave := "%s/%s/%s/%s/%s" % [mueble.name, frente, producto.id, nivel, fondo]
				if not filas.has(clave):
					filas[clave] = {
						"cajas": [],
						"frente": frente,
						"mueble": mueble,
						"producto": producto.nombre,
						"nivel": nivel
					}
				filas[clave].cajas.append(caja)
	var resultado: Array[Dictionary] = []
	for fila: Dictionary in filas.values():
		resultado.append(fila)
	return resultado
