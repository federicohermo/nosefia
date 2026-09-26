## Las dos puertas cableadas en el almacén: que se las pueda tocar, que giren sobre su borde
## hacia adentro del cuarto, y que recién abiertas dejen pasar al jugador.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")

## Las dos hojas, con el tramo de 4,5 m que va desde piso libre del local hasta adentro del
## cuarto. La altura y el largo están medidos:
##
## **La cápsula no nace tocando el piso.** A 0,9 m `cast_motion` devolvía 0,37 aun con las hojas
## sin colisión: contaba el contacto con el suelo y el número dejaba de hablar de la puerta.
##
## **El tramo arranca lejos de la hoja a propósito.** Con 3 m arrancaba a 1,5 m de la puerta,
## justo donde estaba la fila de cajas de reposición, y el caso daba verde igual: `cast_motion`
## **ignora lo que ya está tocando la cápsula al partir**. Por eso `_avance()` afirma aparte que
## el arranque está libre.
const VANOS := {
	"Estructura/puerta": [Vector3(5.494, 1.05, -5.0), Vector3(5.494, 1.05, -9.5)],
	"Estructura/puerta2": [Vector3(5.0, 1.05, -4.658), Vector3(9.5, 1.05, -4.658)],
}

## Las tres que no abren, con la señal que da cada una al tocarla.
const TRABADAS := {
	"Estructura/puertaentrada": &"puerta_trabada",
	"Estructura/porton": &"porton_trabado",
	"Estructura/puertajefe": &"puerta_trabada",
}

## Las señales de un gesto sobre una puerta.
const AVISOS := [&"puerta_abierta", &"puerta_cerrada", &"puerta_trabada", &"porton_trabado"]


func test_las_dos_puertas_cumplen_el_contrato_de_interaccion() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	for hoja: String in VANOS:
		var cuerpo: StaticBody3D = almacen.get_node(hoja + "/CuerpoDeLaHoja")
		assert_bool(cuerpo.is_in_group(ReglasDelJugador.GRUPO_INTERACTUABLE)).is_true()
		assert_bool(cuerpo.has_method("interactuar")).is_true()
		var mallas: Variant = cuerpo.get("mallas")
		assert_bool(mallas is Array and not mallas.is_empty()).is_true()


func test_interactuar_abre_la_puerta_y_no_se_la_lleva_en_la_mano() -> void:
	# Devolver un `ObjetoDelAlmacen` dejaría al clic de agarrar cargándose la hoja entera.
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	for hoja: String in VANOS:
		var cuerpo: StaticBody3D = almacen.get_node(hoja + "/CuerpoDeLaHoja")
		assert_object(cuerpo.call("interactuar")).is_null()
		assert_bool(cuerpo.call("puerta").abierta()).is_true()


func test_el_vano_se_cruza_solo_con_la_puerta_abierta() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	for hoja: String in VANOS:
		assert_float(await _avance(almacen, hoja)).is_less(0.7)
	for hoja: String in VANOS:
		almacen.get_node(hoja + "/CuerpoDeLaHoja").call("interactuar")
	await _esperar_el_giro(almacen)
	for hoja: String in VANOS:
		assert_float(await _avance(almacen, hoja)).is_equal(1.0)


func test_la_hoja_gira_sobre_su_borde_y_no_sobre_su_centro() -> void:
	# Girando sobre el centro la hoja se mete media hoja en cada pared, y el vano queda tapado
	# por el canto en vez de libre.
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	var antes := {}
	for hoja: String in VANOS:
		antes[hoja] = _bordes(almacen.get_node(hoja))
		almacen.get_node(hoja + "/CuerpoDeLaHoja").call("interactuar")
	await _esperar_el_giro(almacen)
	for hoja: String in VANOS:
		var despues := _bordes(almacen.get_node(hoja))
		var quietos := 0
		var movidos := 0
		for indice in range(2):
			var corrimiento: float = antes[hoja][indice].distance_to(despues[indice])
			if corrimiento < 0.001:
				quietos += 1
			elif corrimiento > 1.0:
				movidos += 1
		assert_int(quietos).override_failure_message(hoja).is_equal(1)
		assert_int(movidos).override_failure_message(hoja).is_equal(1)


func test_la_hoja_abierta_entra_al_cuarto_y_no_al_local() -> void:
	# Es el caso que elige de qué lado gira cada hoja. Un rayo de borde a borde no lo puede
	# contestar: arranca pegado a la jamba y dice de qué lado nace la hoja, no dónde termina.
	# El muro tampoco elige: las cuatro combinaciones de bisagra y sentido dejan libre el
	# barrido de la hoja, que ya nace embutida en la jamba con el vano cerrado.
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	for hoja: String in VANOS:
		almacen.get_node(hoja + "/CuerpoDeLaHoja").call("interactuar")
	await _esperar_el_giro(almacen)
	for hoja: String in VANOS:
		# El tramo de `VANOS` va del local hacia adentro del cuarto: su dirección es la que la
		# hoja abierta tiene que seguir, y la hoja mide 1,72 m.
		var tramo: Array = VANOS[hoja]
		var bordes := _bordes(almacen.get_node(hoja))
		var adentro: float = (bordes[1] - bordes[0]).dot((tramo[1] - tramo[0]).normalized())
		assert_float(adentro).override_failure_message(hoja).is_greater(1.5)


## Los dos bordes verticales de la hoja, en coordenadas del mundo.
func _bordes(hoja: MeshInstance3D) -> Array[Vector3]:
	var caja := hoja.get_aabb()
	return [
		hoja.global_transform * Vector3(caja.position.x, 0.0, 0.0),
		hoja.global_transform * Vector3(caja.position.x + caja.size.x, 0.0, 0.0),
	]


## Qué fracción del tramo recorre una cápsula del tamaño del jugador antes de chocar.
##
## Afirma primero que el punto de partida está libre, y esa mitad no es de adorno: es la que
## `cast_motion` no mira. Ver el comentario de `VANOS`.
func _avance(almacen: Node3D, hoja: String) -> float:
	await get_tree().physics_frame
	var tramo: Array = VANOS[hoja]
	var forma := CapsuleShape3D.new()
	forma.radius = 0.4
	forma.height = 1.8
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma
	consulta.transform = Transform3D(Basis(), tramo[0])
	var espacio := almacen.get_world_3d().direct_space_state
	var estorbos: Array[String] = []
	for choque in espacio.intersect_shape(consulta, 8):
		estorbos.append(str(almacen.get_path_to(choque["collider"])))
	(
		assert_array(estorbos)
		. override_failure_message("%s: el tramo arranca contra %s" % [hoja, estorbos])
		. is_empty()
	)
	consulta.motion = tramo[1] - tramo[0]
	return espacio.cast_motion(consulta)[1]


## Corre cuadros de física hasta que las dos hojas llegaron al tope, o se rinde.
func _esperar_el_giro(almacen: Node3D) -> void:
	for _cuadro in range(120):
		await get_tree().physics_frame
		var listas := 0
		for hoja: String in VANOS:
			var puerta: Puerta = almacen.get_node(hoja + "/CuerpoDeLaHoja").call("puerta")
			if is_equal_approx(puerta.angulo(), Puerta.ANGULO_ABIERTA):
				listas += 1
		if listas == VANOS.size():
			return


func test_cerrar_de_golpe_pone_la_hoja_en_su_lugar_en_el_mismo_paso() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	for hoja: String in VANOS:
		var malla: Node3D = almacen.get_node(hoja)
		var cerrada := malla.transform
		var cuerpo: Node = almacen.get_node(hoja + "/CuerpoDeLaHoja")
		cuerpo.call("interactuar")
		for cuadro in 5:
			await get_tree().physics_frame
		assert_bool(malla.transform.is_equal_approx(cerrada)).is_false()
		cuerpo.call("cerrar_de_golpe")
		assert_bool(cuerpo.call("puerta").abierta()).is_false()
		assert_bool(malla.transform.is_equal_approx(cerrada)).is_true()


## Anota cada aviso de las puertas, en orden, como `[ruta, señal]`.
func _escuchar(almacen: Node3D, rutas: Array) -> Array:
	var avisos := []
	for ruta: String in rutas:
		var cuerpo: Node = almacen.get_node(ruta + "/CuerpoDeLaHoja")
		for senal: StringName in AVISOS:
			cuerpo.connect(senal, func(_puerta: Node3D) -> void: avisos.append([ruta, senal]))
	return avisos


func test_tres_puertas_estan_trabadas_y_las_dos_interiores_no() -> void:  # AC-PLY-040
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	for ruta: String in TRABADAS:
		var cuerpo: StaticBody3D = almacen.get_node(ruta + "/CuerpoDeLaHoja")
		assert_bool(cuerpo.is_in_group(ReglasDelJugador.GRUPO_INTERACTUABLE)).is_true()
		assert_bool(cuerpo.has_method(ReglasDeLosObjetos.METODO_INTERACTUAR)).is_true()
		var mallas: Variant = cuerpo.get("mallas")
		assert_bool(mallas is Array and not mallas.is_empty()).is_true()
		assert_bool(cuerpo.call("puerta").trabada()).override_failure_message(ruta).is_true()
	for ruta: String in VANOS:
		var puerta: Puerta = almacen.get_node(ruta + "/CuerpoDeLaHoja").call("puerta")
		assert_bool(puerta.trabada()).override_failure_message(ruta).is_false()


func test_tocar_una_trabada_diez_veces_avisa_diez_veces_y_no_gira() -> void:  # AC-PLY-041
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	var avisos := _escuchar(almacen, TRABADAS.keys())
	var quietas := {}
	for ruta: String in TRABADAS:
		quietas[ruta] = (almacen.get_node(ruta) as Node3D).global_transform
		for _vez in 10:
			assert_object(almacen.get_node(ruta + "/CuerpoDeLaHoja").call("interactuar")).is_null()
	for _cuadro in 10:
		await get_tree().physics_frame
	for ruta: String in TRABADAS:
		var suyos := avisos.filter(func(aviso: Array) -> bool: return aviso[0] == ruta)
		assert_int(suyos.size()).override_failure_message(ruta).is_equal(10)
		for aviso: Array in suyos:
			assert_str(aviso[1]).is_equal(TRABADAS[ruta])
		var cuerpo: Node = almacen.get_node(ruta + "/CuerpoDeLaHoja")
		assert_bool(cuerpo.call("puerta").abierta()).is_false()
		var malla: Node3D = almacen.get_node(ruta)
		assert_bool(malla.global_transform.is_equal_approx(quietas[ruta])).is_true()


func test_dos_toques_seguidos_avisan_abrir_y_despues_cerrar() -> void:  # AC-PLY-041
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	var avisos := _escuchar(almacen, VANOS.keys())
	for ruta: String in VANOS:
		var cuerpo: Node = almacen.get_node(ruta + "/CuerpoDeLaHoja")
		cuerpo.call("interactuar")
		await get_tree().physics_frame
		assert_bool(cuerpo.call("puerta").quieta()).is_false()
		cuerpo.call("interactuar")
	for _cuadro in 60:
		await get_tree().physics_frame
	var esperado := []
	for ruta: String in VANOS:
		esperado.append_array([[ruta, &"puerta_abierta"], [ruta, &"puerta_cerrada"]])
	assert_array(avisos).is_equal(esperado)


func test_cerrar_al_abrir_la_jornada_no_avisa() -> void:  # AC-PLY-041
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	for ruta: String in VANOS:
		almacen.get_node(ruta + "/CuerpoDeLaHoja").call("interactuar")
	var avisos := _escuchar(almacen, VANOS.keys() + TRABADAS.keys())
	almacen.call("_al_abrir_la_jornada", ReglasDeLaPartida.PRIMERA_JORNADA + 1)
	for ruta: String in VANOS:
		assert_bool(almacen.get_node(ruta + "/CuerpoDeLaHoja").call("puerta").abierta()).is_false()
	assert_array(avisos).is_empty()


func test_cada_puerta_pide_su_sonido_al_tocarla() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	var reproductor: ReproductorDeSonidos = almacen.get_node(
		"Servicios/AudioDelAlmacen/Reproductor"
	)
	var pedidos := []
	reproductor.sonido_pedido.connect(
		func(evento: EntradaSonora.Evento) -> void: pedidos.append(evento)
	)
	var esperado := []
	for ruta: String in VANOS:
		var cuerpo: Node = almacen.get_node(ruta + "/CuerpoDeLaHoja")
		cuerpo.call("interactuar")
		cuerpo.call("interactuar")
		esperado.append_array(
			[EntradaSonora.Evento.PUERTA_ABIERTA, EntradaSonora.Evento.PUERTA_CERRADA]
		)
	for ruta: String in TRABADAS:
		almacen.get_node(ruta + "/CuerpoDeLaHoja").call("interactuar")
		esperado.append(
			(
				EntradaSonora.Evento.PORTON_TRABADO
				if TRABADAS[ruta] == &"porton_trabado"
				else EntradaSonora.Evento.PUERTA_TRABADA
			)
		)
	assert_array(pedidos).is_equal(esperado)


func test_las_puertas_suenan_desde_la_puerta_con_su_audio() -> void:
	var tabla := TablaDeSonidos.desde_disco()
	assert_object(tabla).is_not_null()
	var esperado := {
		EntradaSonora.Evento.PUERTA_ABIERTA: ["puerta_abierta", "SFX_NOLEV_Puerta_Abrir"],
		EntradaSonora.Evento.PUERTA_CERRADA: ["puerta_cerrada", "SFX_NOLEV_Puerta_Cerrar"],
		EntradaSonora.Evento.PUERTA_TRABADA: ["puerta_trabada", "SFX_NOLEV_Puerta_NoAbre"],
		EntradaSonora.Evento.PORTON_TRABADO: ["porton_trabado", "SFX_NOLEV_Puerta_Garage"],
	}
	for evento: EntradaSonora.Evento in esperado:
		var entrada := tabla.de(evento)
		assert_object(entrada).is_not_null()
		if entrada == null:
			continue
		assert_str(entrada.senal).is_equal(esperado[evento][0])
		assert_str(entrada.bus).is_equal(EntradaSonora.BUS_DE_EFECTOS)
		assert_bool(entrada.posicional).is_true()
		assert_str(entrada.stream.resource_path.get_file().get_basename()).is_equal(
			esperado[evento][1]
		)
