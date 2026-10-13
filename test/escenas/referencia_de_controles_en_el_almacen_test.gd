## La referencia de controles en el local de verdad: lo que el jugador enfoca y lleva, publicado
## al HUD con los controles de la asignación de fábrica.
##
## La mira del jugador está apagada en todos los casos: lo enfocado lo pone el caso, y la
## referencia se publica a mano. Así cada caso afirma la combinación que arma, sin depender de
## dónde mire la cámara.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const BolsaEnLaMano := preload("res://test/escenas/bolsa_en_la_mano.gd")

const LAVATORIO := "Estructura/vanitory/StaticBody3D"
const TACHO := "Estructura/tachitobasura/StaticBody3D"
const PORTON := "Estructura/porton/CuerpoDeLaHoja"
const LECTOR := "Estructura/Lector"


func _abrir() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	for cuadro in 4:
		await get_tree().physics_frame
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	# La premisa: la jornada corre y nada tiene suspendido al jugador.
	jugador.call("reanudar")
	assert_bool(jugador.call("suspendido")).is_false()
	return almacen


## Publica lo que el jugador tiene adelante y en la mano, y devuelve lo que el HUD pinta.
func _referencia(almacen: Node3D, enfocado: Node3D) -> Array[String]:
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set("_enfocado", enfocado)
	jugador.call("_publicar_la_referencia")
	return _pintado(almacen)


func _pintado(almacen: Node3D) -> Array[String]:
	var hud: Node = almacen.get("_hud")
	var controles := hud.get_node("Controles") as Label
	var lineas: Array[String] = []
	for linea in controles.text.split("\n", false):
		lineas.append(linea)
	return lineas


func _agarrar(almacen: Node3D, objeto: Node3D) -> void:
	var agarre: Agarre = almacen.get("_agarre")
	assert_bool(agarre.pedir_agarrar(objeto.get("datos"), objeto)).is_true()


func _unidad(almacen: Node3D, id: Producto.Id) -> Node3D:
	var unidad: Node3D = load("res://src/escenas/objetos/objeto_agarrable.tscn").instantiate()
	unidad.set("datos", UnidadDeProducto.new(Catalogo.de(id)))
	almacen.add_child(unidad)
	return unidad


func test_los_dos_ejemplos_de_la_ficha_en_el_local() -> void:  # AC-PLY-082
	var almacen := await _abrir()
	var lavatorio: Node3D = almacen.get_node(LAVATORIO)
	assert_array(_referencia(almacen, lavatorio)).contains_exactly(["[E] Examinar"])
	_agarrar(almacen, almacen.get_node("Objetos/Balde"))
	assert_array(_referencia(almacen, lavatorio)).contains_exactly(
		["[E] Examinar (mano)", "[Click Izq] Dejar", "[Click Der] Interactuar"]
	)
	# El contador de tareas sigue arriba de la primera línea.
	var hud: Node = almacen.get("_hud")
	var tareas := hud.get_node("Tareas") as Label
	var controles := hud.get_node("Controles") as Label
	assert_str(tareas.text).is_not_empty()
	assert_float(tareas.get_global_rect().end.y).is_less_equal(
		controles.get_global_rect().position.y
	)


func test_la_caja_del_deposito_saca_y_mete_en_el_local() -> void:  # AC-PLY-083
	var almacen := await _abrir()
	var caja: Node3D = almacen.get("_cajas_de_productos")[0]
	assert_array(_referencia(almacen, caja)).contains_exactly(
		["[E] Examinar", "[Click Izq] Agarrar", "[Click Der] Sacar producto"]
	)
	# Sacar una por el camino del clic deja la caja con una menos y la unidad en la mano.
	almacen.get("_reposicion_manual").call("usar_la_caja", caja)
	var agarre: Agarre = almacen.get("_agarre")
	assert_object(agarre.manos().sostenido()).is_instanceof(UnidadDeProducto)
	assert_array(_referencia(almacen, caja)).contains_exactly(
		["[E] Examinar (mano)", "[Click Izq] Dejar", "[Click Der] Meter producto"]
	)
	# Otra caja en la mano mirando ésta: sin línea del derecho.
	almacen.get("_reposicion_manual").call("usar_la_caja", caja)
	assert_object(agarre.manos().sostenido()).is_null()
	_agarrar(almacen, almacen.get("_cajas_de_productos")[1])
	assert_array(_referencia(almacen, caja)).contains_exactly(
		["[E] Examinar (mano)", "[Click Izq] Dejar"]
	)


func test_el_derecho_no_adelanta_el_resultado_en_el_local() -> void:  # AC-PLY-084
	var almacen := await _abrir()
	# La puerta trabada con la mano vacía avisa: tiene efecto.
	assert_array(_referencia(almacen, almacen.get_node(PORTON))).contains_exactly(
		["[E] Examinar", "[Click Der] Interactuar"]
	)
	# El lector con la mano vacía no; con una unidad sí, aunque los renglones estén llenos.
	var lector: Node3D = almacen.get_node(LECTOR)
	assert_array(_referencia(almacen, lector)).contains_exactly(["[E] Examinar"])
	var caja: CajaRegistradora = almacen.get("_caja")
	var unidad := _unidad(almacen, Producto.Id.ACTRONCITO)
	while caja.generador().anotar(unidad.get("datos")) == GeneradorDeTickets.Resultado.ANOTADO:
		pass
	var renglones := caja.generador().renglones().size()
	_agarrar(almacen, unidad)
	assert_array(_referencia(almacen, lector)).contains_exactly(
		["[E] Examinar (mano)", "[Click Izq] Dejar", "[Click Der] Interactuar"]
	)
	assert_int(caja.generador().renglones().size()).is_equal(renglones)
	# El inodoro con la unidad no; el lavatorio con la unidad tampoco.
	var inodoro := _destino(almacen, ReglasDeLaLimpieza.ID_DEL_INODORO)
	assert_object(inodoro).is_not_null()
	assert_array(_referencia(almacen, inodoro)).contains_exactly(
		["[E] Examinar (mano)", "[Click Izq] Dejar"]
	)
	# Con el programa manual, el hueco del lector no tiene efecto.
	caja.arrancar(GeneradorDeTickets.para_la_jornada(GeneradorDeTickets.JORNADA_SIN_LECTOR))
	assert_array(_referencia(almacen, lector)).contains_exactly(
		["[E] Examinar (mano)", "[Click Izq] Dejar"]
	)


func test_el_ticket_sobre_el_inodoro_cuenta_en_el_local() -> void:  # AC-PLY-084
	var almacen := await _abrir()
	var inodoro := _destino(almacen, ReglasDeLaLimpieza.ID_DEL_INODORO)
	var papel: Node3D = load("res://src/escenas/objetos/ticket.tscn").instantiate()
	papel.set("datos", Ticket.new())
	almacen.add_child(papel)
	_agarrar(almacen, papel)
	assert_array(_referencia(almacen, inodoro)).contains_exactly(
		["[E] Examinar (mano)", "[Click Izq] Dejar", "[Click Der] Interactuar"]
	)


func test_lo_que_se_tira_al_contenedor_se_lee_dejar_en_el_local() -> void:  # AC-PLY-086
	var almacen := await _abrir()
	assert_object(BolsaEnLaMano.sacar(almacen)).is_not_null()
	for parte: Node3D in [almacen.get("_contenedor"), almacen.get("_tapa_del_contenedor")]:
		var lineas := _referencia(almacen, parte)
		assert_array(lineas).contains_exactly(
			["[E] Examinar (mano)", "[Click Izq] Dejar", "[Click Der] Interactuar"]
		)


func test_consultar_el_tacho_no_le_saca_la_bolsa() -> void:  # AC-PLY-085
	var almacen := await _abrir()
	var recolector: RecolectorDeBasura = almacen.get("_recolector")
	BolsaEnLaMano.abrir(almacen)
	var tacho: Node3D = almacen.get_node(TACHO)
	var cual: TareaDeLaBasura.Tacho = tacho.get("tacho")
	assert_bool(recolector.tarea().tiene_bolsa(cual)).is_true()
	assert_array(_referencia(almacen, tacho)).contains_exactly(
		["[E] Examinar", "[Click Der] Interactuar"]
	)
	assert_bool(recolector.tarea().tiene_bolsa(cual)).is_true()
	var agarre: Agarre = almacen.get("_agarre")
	assert_object(agarre.manos().sostenido()).is_null()
	_agarrar(almacen, _unidad(almacen, Producto.Id.ACTRONCITO))
	assert_array(_referencia(almacen, tacho)).contains_exactly(
		["[E] Examinar (mano)", "[Click Izq] Dejar"]
	)


func test_sin_nada_que_hacer_la_referencia_esta_vacia() -> void:  # AC-PLY-087
	var almacen := await _abrir()
	assert_array(_referencia(almacen, null)).is_empty()


func test_suspendido_la_referencia_esta_vacia_y_vuelve() -> void:  # AC-PLY-089
	var almacen := await _abrir()
	var jugador: Node3D = almacen.get("_jugador")
	var lavatorio: Node3D = almacen.get_node(LAVATORIO)
	_agarrar(almacen, almacen.get_node("Objetos/Balde"))
	var con_el_balde: Array[String] = [
		"[E] Examinar (mano)", "[Click Izq] Dejar", "[Click Der] Interactuar"
	]
	assert_array(_referencia(almacen, lavatorio)).contains_exactly(con_el_balde)
	# Una nota, la computadora, la caja, la ventanilla y el examen suspenden por la misma puerta.
	jugador.call("suspender")
	assert_array(_pintado(almacen)).is_empty()
	jugador.call("reanudar")
	assert_array(_referencia(almacen, lavatorio)).contains_exactly(con_el_balde)
	# El celular.
	almacen.call("_al_abrir_el_celular")
	assert_array(_pintado(almacen)).is_empty()
	almacen.call("_al_cerrar_el_celular")
	assert_array(_referencia(almacen, lavatorio)).contains_exactly(con_el_balde)
	# La pausa: el árbol no corre, así que la referencia se vacía al pausar y vuelve al reanudar.
	var pausa: ControlDePausa = almacen.get_node("Interfaz/ControlDePausa")
	pausa.pausado.emit()
	assert_array(_pintado(almacen)).is_empty()
	pausa.reanudado.emit()
	assert_array(_pintado(almacen)).contains_exactly(con_el_balde)


func test_el_foco_y_la_mano_cambian_en_el_mismo_cuadro() -> void:  # AC-PLY-090
	var almacen := await _abrir()
	var jugador: Node3D = almacen.get("_jugador")
	assert_array(_referencia(almacen, almacen.get_node(LAVATORIO))).contains_exactly(
		["[E] Examinar"]
	)
	var publicadas: Array[Array] = []
	jugador.connect(
		"referencia_cambiada",
		func(lineas: Array[ReferenciaDeControles.Linea]) -> void: publicadas.append(lineas)
	)
	_agarrar(almacen, almacen.get_node("Objetos/Balde"))
	jugador.set("_enfocado", almacen.get("_cajas_de_productos")[0])
	jugador.call("_publicar_la_referencia")
	assert_int(publicadas.size()).is_equal(1)
	assert_array(_pintado(almacen)).contains_exactly(["[E] Examinar (mano)", "[Click Izq] Dejar"])


## El artefacto del baño que recibe con ese destino.
func _destino(almacen: Node3D, destino: StringName) -> Node3D:
	for nodo in almacen.find_children("*", "StaticBody3D", true, false):
		if nodo.has_method("destino_del_uso") and nodo.call("destino_del_uso") == destino:
			return nodo
	return null
