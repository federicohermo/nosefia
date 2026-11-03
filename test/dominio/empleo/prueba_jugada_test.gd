## Las dos noches de prueba jugadas de punta a punta: la ventanilla, la planilla y la góndola de
## cada jornada, cerradas con el mismo estado que el jugador ve al cerrar.
extends GdUnitTestSuite

const T := Tarea.Tipo
const PRIMERA := ReglasDeLaPartida.PRIMERA_JORNADA
const SEGUNDA := ReglasDeLaPartida.PRIMERA_JORNADA + 1
const TERCERA := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA
const CASILLEROS_POR_PRODUCTO := 4
const UMBRAL := Reglas.APERCIBIMIENTOS_QUE_PIERDEN_LA_PRUEBA


## Cómo juega el empleado una noche de prueba.
class Juego:
	extends RefCounted
	## Por comprador, en orden de llegada: si se le vende o se lo deja vencer.
	var atiende: Array[bool] = [true, true]
	## Si anota en la planilla lo que vendió.
	var anota := true
	## Si anota también el pedido de quien no compró.
	var anota_de_mas := false
	var repone := true
	var limpia := true
	var llamados: Array[Partida.Llamado] = []


static func juego(cambios: Dictionary = {}) -> Juego:
	var nuevo := Juego.new()
	for campo: String in cambios:
		nuevo.set(campo, cambios[campo])
	return nuevo


static func atiende(primero: bool, segundo: bool) -> Array[bool]:
	return [primero, segundo]


## Lo que queda abierto al cerrar, que es lo que el juego cuenta.
class Noche:
	extends RefCounted
	var atender: TareaDeAtender
	var registro: RegistroDeVentas
	var estante: Estante
	var pudo_irse_antes := false


## Juega la noche que la partida tiene abierta y la cierra como el ciclo de jornadas.
static func jugar(partida: Partida, como: Juego) -> Noche:
	var jornada := partida.jornada()
	partida.abrir_la_jornada()
	var productos := Catalogo.de_la_jornada(jornada)
	var casilleros: Dictionary[Producto.Id, int] = {}
	for producto in productos:
		casilleros[producto.id] = CASILLEROS_POR_PRODUCTO
	var compradores := Compradores.de_la_jornada(jornada)
	var azar := RandomNumberGenerator.new()
	azar.seed = jornada
	var inventario := Apertura.inventario_de_la_jornada(
		jornada, compradores, casilleros, casilleros, azar
	)
	var noche := Noche.new()
	noche.estante = Estante.new(inventario, productos)
	noche.atender = TareaDeAtender.new(compradores, inventario)
	noche.registro = RegistroDeVentas.new(Catalogo.todos(), noche.atender)
	for indice in compradores.size():
		var comprador := compradores[indice]
		if comprador.tiene_horario():
			noche.atender.avanzar(comprador.horario.x)
			if como.atiende[indice]:
				_vender(noche)
			else:
				noche.atender.avanzar(comprador.horario.y)
		else:
			noche.atender.atender()
			if como.atiende[indice]:
				noche.atender.atencion().cobrar()
			else:
				noche.atender.atencion().despachar_sin_vender()
		if (
			(como.anota and como.atiende[indice])
			or (como.anota_de_mas and not como.atiende[indice])
		):
			for producto in comprador.pedido().productos():
				for _unidad in comprador.pedido().unidades_de(producto):
					noche.registro.sumar(producto)
	if como.repone:
		for producto in productos:
			while noche.estante.colocar(producto) == Estante.Rechazo.NINGUNO:
				pass
	for llamado in como.llamados:
		partida.anotar_llamado(llamado)
	_marcar(partida, noche, como.limpia, false)
	noche.pudo_irse_antes = CierreAnticipado.corresponde(jornada, partida.obligatorias())
	# El cierre primero termina la agenda y después revisa la planilla con el cero ya válido.
	noche.atender.avanzar(Reglas.DURACION_DEL_TURNO)
	var cumplidas := _marcar(partida, noche, como.limpia, true)
	partida.cerrar_la_jornada(cumplidas, noche.atender.mal_atendidos())
	return noche


static func _vender(noche: Noche) -> void:
	var atencion := noche.atender.atencion()
	while not atencion.conversacion_iniciada() or not atencion.puede_abandonar():
		atencion.interactuar(null)
	var renglones: Array[Producto] = []
	var pedido := atencion.comprador().pedido()
	for producto in pedido.productos():
		for _unidad in pedido.unidades_de(producto):
			var ocupados := noche.estante.casilleros_ocupados(producto)
			atencion.interactuar(
				(
					noche.estante.agarrar(producto, ocupados[0])
					if not ocupados.is_empty()
					else noche.estante.retirar(producto)
				)
			)
			renglones.append(producto)
	atencion.interactuar(Ticket.new(renglones))


static func _marcar(partida: Partida, noche: Noche, limpia: bool, al_cerrar: bool) -> int:
	var hechas: Dictionary[Tarea.Tipo, bool] = {
		T.CAJA: noche.atender.completada(),
		T.REGISTRAR: noche.registro.completada(al_cerrar),
		T.REPONER: noche.estante.completada(),
		T.LIMPIAR: limpia,
	}
	var cumplidas := 0
	for tarea: Tarea in partida.obligatorias():
		if hechas[tarea.tipo()]:
			tarea.completar()
			cumplidas += 1
		else:
			tarea.descompletar()
	return cumplidas


static func jugar_la_prueba(noches: Array) -> Partida:
	var partida := Partida.nueva()
	for como: Juego in noches:
		jugar(partida, como)
	return partida


func _condicion(partida: Partida, jornada: int) -> StringName:
	return CondicionesDelJefe.elegidas(partida.noches_de_prueba)[jornada - SEGUNDA]


func test_la_noche_1_elige_cada_mensaje_1_de_la_jornada_2() -> void:  # AC-EMP-084, AC-EMP-078
	var casos := [
		[{}, CondicionesDelJefe.J2_SIN_FALLAS, 0],
		[{"anota": false}, CondicionesDelJefe.J2_REGISTRO_MAL, 1],
		[{"repone": false}, CondicionesDelJefe.J2_REPOSICION_MAL, 1],
		[{"atiende": atiende(true, false)}, CondicionesDelJefe.J2_UN_CLIENTE_MAL, 1],
		[{"atiende": atiende(false, false)}, CondicionesDelJefe.J2_NINGUNO_EN_CERO, 2],
		[
			{"atiende": atiende(false, false), "anota_de_mas": true},
			CondicionesDelJefe.J2_NINGUNO_ANOTADO,
			3
		],
	]
	for caso: Array in casos:
		var partida := Partida.nueva()
		jugar(partida, juego(caso[0]))
		assert_str(_condicion(partida, SEGUNDA)).is_equal(caso[1])
		assert_int(partida.apercibimientos()).is_equal(caso[2])


func test_un_cliente_vencido_y_el_registro_mal_tienen_su_fila() -> void:  # AC-EMP-084
	var partida := Partida.nueva()
	jugar(partida, juego({"atiende": atiende(false, true), "anota_de_mas": true}))
	assert_str(_condicion(partida, SEGUNDA)).is_equal(
		CondicionesDelJefe.J2_UN_CLIENTE_Y_REGISTRO_MAL
	)
	assert_int(partida.apercibimientos()).is_equal(2)


func test_la_jornada_1_pide_reponer_lo_vendido() -> void:  # AC-EMP-078
	var partida := Partida.nueva()
	var noche := jugar(partida, juego({"repone": false}))
	assert_bool(noche.estante.completada()).is_false()
	assert_int(partida.apercibimientos()).is_equal(1)
	assert_str(_condicion(partida, SEGUNDA)).is_equal(CondicionesDelJefe.J2_REPOSICION_MAL)


func test_irse_por_la_puerta_antes_de_las_8_no_suma() -> void:  # AC-SHF-036, AC-EMP-078
	var partida := Partida.nueva()
	for jornada: int in [PRIMERA, SEGUNDA]:
		assert_int(partida.jornada()).is_equal(jornada)
		var noche := jugar(partida, juego())
		assert_bool(noche.pudo_irse_antes).is_true()
	assert_int(partida.jornada()).is_equal(TERCERA)
	assert_int(partida.legajo().apercibimientos_de_la_prueba()).is_zero()


func test_con_un_comprador_que_no_llego_la_puerta_no_deja_salir() -> void:  # AC-SHF-036
	var partida := Partida.nueva()
	partida.abrir_la_jornada()
	var compradores := Compradores.de_la_jornada(PRIMERA)
	var productos := Catalogo.de_la_jornada(PRIMERA)
	var casilleros: Dictionary[Producto.Id, int] = {}
	for producto in productos:
		casilleros[producto.id] = CASILLEROS_POR_PRODUCTO
	var inventario := Apertura.inventario_de_la_jornada(
		PRIMERA, compradores, casilleros, casilleros, RandomNumberGenerator.new()
	)
	var noche := Noche.new()
	noche.estante = Estante.new(inventario, productos)
	noche.atender = TareaDeAtender.new(compradores, inventario)
	noche.registro = RegistroDeVentas.new(Catalogo.todos(), noche.atender)
	for indice in compradores.size():
		var comprador := compradores[indice]
		noche.atender.avanzar(comprador.horario.x)
		_vender(noche)
		for producto in comprador.pedido().productos():
			for _unidad in comprador.pedido().unidades_de(producto):
				noche.registro.sumar(producto)
		var todos_llegaron := indice == compradores.size() - 1
		assert_bool(noche.atender.atencion().vendida()).is_true()
		assert_int(noche.atender.mal_atendidos()).is_zero()
		assert_bool(noche.registro.coincide()).is_true()
		assert_bool(noche.registro.completada()).is_true()
		assert_bool(noche.atender.cumplida()).is_true()
		assert_bool(noche.atender.completada()).is_equal(todos_llegaron)
		if todos_llegaron:
			for producto in productos:
				while noche.estante.colocar(producto) == Estante.Rechazo.NINGUNO:
					pass
		_marcar(partida, noche, true, false)
		assert_bool(CierreAnticipado.corresponde(PRIMERA, partida.obligatorias())).is_equal(
			todos_llegaron
		)


func test_las_dos_noches_eligen_el_mensaje_1_de_la_jornada_3() -> void:  # AC-EMP-089, AC-EMP-080
	var perfecta := juego()
	var nada := juego({"atiende": atiende(false, false), "repone": false})
	var sucia := juego({"limpia": false})
	var casos := [
		[[perfecta, perfecta], CondicionesDelJefe.J3_SIN_FALLAS],
		[[nada, sucia], CondicionesDelJefe.J3_CON_ALTIBAJOS],
		[[perfecta, nada], CondicionesDelJefe.J3_CON_ALTIBAJOS],
	]
	for caso: Array in casos:
		var noches: Array[Juego] = []
		noches.assign(caso[0])
		var partida := jugar_la_prueba(noches)
		assert_bool(partida.terminada()).is_false()
		assert_int(partida.jornada()).is_equal(TERCERA)
		assert_str(_condicion(partida, TERCERA)).is_equal(caso[1])


func test_se_pierde_solo_con_el_umbral_y_la_segunda_sin_cumplir() -> void:  # AC-EMP-080, AC-EMP-090
	var nada := juego({"atiende": atiende(false, false), "repone": false})
	var peor := juego(
		{"atiende": atiende(false, false), "anota_de_mas": true, "repone": false, "limpia": false}
	)
	var perdida := jugar_la_prueba([nada, peor])
	assert_int(perdida.legajo().apercibimientos_de_la_prueba()).is_greater_equal(UMBRAL)
	assert_int(perdida.final()).is_equal(Partida.Final.DESPEDIDO)
	assert_array(DevolucionDelJefe.new(SEGUNDA, perdida).mensajes()).is_equal(
		[DevolucionDelJefe.DESPIDO_DE_LA_PRUEBA]
	)
	var un_cliente := juego({"atiende": atiende(true, false)})
	var debajo := jugar_la_prueba([un_cliente, juego({"atiende": atiende(false, true)})])
	assert_int(debajo.legajo().apercibimientos_de_la_prueba()).is_less(UMBRAL)
	assert_bool(debajo.terminada()).is_false()
	assert_int(debajo.jornada()).is_equal(TERCERA)


func test_la_primera_no_se_pierde_jugando_mal() -> void:  # AC-EMP-079
	var nada := juego({"atiende": atiende(false, false), "anota_de_mas": true, "repone": false})
	var partida := Partida.nueva()
	jugar(partida, nada)
	assert_bool(partida.terminada()).is_false()
	assert_int(partida.jornada()).is_equal(SEGUNDA)
	assert_int(partida.apercibimientos()).is_greater(0)


func test_los_llamados_de_la_prueba_no_cuentan() -> void:  # AC-EMP-078, AC-EMP-059
	var todos: Array[Partida.Llamado] = []
	todos.assign(Partida.Llamado.values())
	var con_llamados := juego({"llamados": todos})
	var partida := jugar_la_prueba([con_llamados, con_llamados])
	assert_int(partida.legajo().apercibimientos_de_la_prueba()).is_zero()
	assert_str(_condicion(partida, TERCERA)).is_equal(CondicionesDelJefe.J3_SIN_FALLAS)
	assert_bool(partida.antecedentes().hubo_llamados()).is_false()
	for motivo: Partida.Llamado in todos:
		assert_int(partida.antecedentes().llamados(motivo)).is_zero()
	partida.abrir_la_jornada()
	for tarea: Tarea in partida.obligatorias():
		tarea.completar()
	for motivo: Partida.Llamado in todos:
		partida.anotar_llamado(motivo)
	partida.cerrar_la_jornada(partida.obligatorias().size())
	assert_bool(partida.antecedentes().hubo_llamados()).is_true()
	for motivo: Partida.Llamado in todos:
		assert_int(partida.antecedentes().llamados(motivo)).is_equal(1)
	(
		assert_array(DevolucionDelJefe.new(TERCERA, partida).mensajes())
		. contains(
			[
				DevolucionDelJefe.PAPEL_1,
				DevolucionDelJefe.BASURA[0],
				DevolucionDelJefe.AFUERA[0],
				DevolucionDelJefe.DESORDEN[0],
			]
		)
	)


func test_la_tercera_cuenta_su_primera_falla() -> void:  # AC-EMP-059
	var todos: Array[Partida.Llamado] = []
	todos.assign(Partida.Llamado.values())
	var partida := jugar_la_prueba(
		[
			juego({"atiende": atiende(false, true), "anota": false, "llamados": todos}),
			juego({"repone": false, "limpia": false, "llamados": todos}),
		]
	)
	assert_bool(partida.terminada()).is_false()
	assert_int(partida.jornada()).is_equal(TERCERA)
	assert_int(partida.legajo().apercibimientos_de_la_prueba()).is_equal(4)
	for tipo: Tarea.Tipo in Antecedentes.FIJAS:
		assert_int(partida.antecedentes().fallas(tipo)).is_zero()
	assert_int(partida.antecedentes().noches_sin_sumar()).is_zero()
	partida.abrir_la_jornada()
	var cumplidas := 0
	for tarea: Tarea in partida.obligatorias():
		if tarea.tipo() != T.CAJA:
			tarea.completar()
			cumplidas += 1
	partida.cerrar_la_jornada(cumplidas)
	var mensajes := DevolucionDelJefe.new(TERCERA, partida).mensajes()
	var reprimendas: Array = DevolucionDelJefe.TAREAS[T.CAJA]
	assert_array(mensajes).contains([reprimendas[0]])
	assert_array(mensajes).not_contains(reprimendas.slice(1))
