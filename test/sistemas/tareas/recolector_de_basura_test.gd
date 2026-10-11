## El tiro entrega sólo después del permiso y conserva el inventario y las obligatorias.
extends GdUnitTestSuite

var _turno: Turno
var _depositos := 0
var _tirados: Array[Node3D] = []
var _avisos := 0


func before_test() -> void:
	_depositos = 0
	_tirados.clear()
	_avisos = 0


func _recolector(
	presupuesto: float = Reglas.DURACION_DEL_TURNO, jornada: int = 2
) -> RecolectorDeBasura:
	var obligatorias := Apertura.obligatorias(jornada)
	_turno = Turno.new(presupuesto, obligatorias)
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	reloj.arrancar(_turno, obligatorias)
	reloj.tarea_completada.connect(func(_cantidad: int) -> void: _avisos += 1)
	var agarre: Agarre = auto_free(Agarre.new())
	agarre.punto_de_carga = auto_free(Node3D.new())
	var repositor: Repositor = auto_free(Repositor.new())
	repositor.agarre = agarre
	repositor.reloj = reloj
	var producto := Catalogo.de(Producto.Id.ACTRONCITO)
	var inventario := Inventario.new([producto], {producto.id: 2})
	inventario.ingresar(producto, Inventario.Ubicacion.DEPOSITO, 8)
	repositor.arrancar(Estante.new(inventario, [producto]))
	var recolector: RecolectorDeBasura = auto_free(RecolectorDeBasura.new())
	recolector.reloj = reloj
	recolector.agarre = agarre
	recolector.repositor = repositor
	recolector.arrancar(TareaDeLaBasura.de_la_jornada(jornada))
	recolector.bolsa_depositada.connect(func(_cuantas: int) -> void: _depositos += 1)
	recolector.objeto_tirado.connect(func(nodo: Node3D) -> void: _tirados.append(nodo))
	return recolector


func _sostener(recolector: RecolectorDeBasura, datos: ObjetoDelAlmacen) -> Node3D:
	var cuerpo: Node3D = auto_free(Node3D.new())
	assert_bool(recolector.agarre.pedir_agarrar(datos, cuerpo)).is_true()
	return cuerpo


func test_el_tiro_aceptado_entrega_el_mismo_cuerpo_sin_soltar() -> void:  # AC-CLN-036
	var recolector := _recolector()
	var bolsa := ObjetoDelAlmacen.new()
	bolsa.id = ReglasDeLaBasura.id_de_la_bolsa(1)
	var cuerpo := _sostener(recolector, bolsa)
	var soltados: Array[Node3D] = []
	recolector.agarre.objeto_soltado.connect(func(nodo: Node3D) -> void: soltados.append(nodo))
	assert_int(recolector.pedir_tirar(true)).is_equal(ReglasDeLaBasura.Tiro.TIRADO)
	assert_object(recolector.agarre.manos().sostenido()).is_null()
	assert_array(_tirados).contains_exactly([cuerpo])
	assert_array(soltados).is_empty()
	assert_int(_depositos).is_equal(1)
	assert_float(_turno.tiempo_restante()).is_equal(Reglas.DURACION_DEL_TURNO)


func test_mano_vacia_caja_y_tapa_no_abierta_conservan_todo() -> void:  # AC-CLN-037 AC-CLN-035
	var recolector := _recolector()
	assert_int(recolector.pedir_tirar(true)).is_equal(ReglasDeLaBasura.Tiro.MANO_VACIA)
	var caja := ObjetoDelAlmacen.new()
	caja.entra_en_el_contenedor = false
	var cuerpo := _sostener(recolector, caja)
	var padre := cuerpo.get_parent()
	assert_int(recolector.pedir_tirar(true)).is_equal(ReglasDeLaBasura.Tiro.NO_ENTRA)
	assert_object(recolector.agarre.manos().sostenido()).is_same(caja)
	assert_object(cuerpo.get_parent()).is_same(padre)
	recolector.agarre.entregar()
	var bolsa := ObjetoDelAlmacen.new()
	bolsa.id = ReglasDeLaBasura.id_de_la_bolsa(1)
	_sostener(recolector, bolsa)
	assert_int(recolector.pedir_tirar(false)).is_equal(ReglasDeLaBasura.Tiro.TAPA_NO_ABIERTA)
	assert_object(recolector.agarre.manos().sostenido()).is_same(bolsa)
	assert_array(_tirados).is_empty()
	assert_int(_depositos).is_zero()
	assert_int(recolector.tarea().depositadas()).is_zero()


func test_la_ultima_bolsa_completa_una_vez_sin_mover_el_turno() -> void:  # AC-CLN-012 AC-CLN-011
	var recolector := _recolector()
	for numero in range(1, ReglasDeLaBasura.BOLSAS_DE_LA_JORNADA + 1):
		assert_int(_avisos).is_zero()
		var bolsa := ObjetoDelAlmacen.new()
		bolsa.id = ReglasDeLaBasura.id_de_la_bolsa(numero)
		_sostener(recolector, bolsa)
		recolector.pedir_tirar(true)
	assert_bool(recolector.tarea().completada()).is_true()
	assert_int(_avisos).is_equal(1)
	var repetida := ObjetoDelAlmacen.new()
	repetida.id = ReglasDeLaBasura.id_de_la_bolsa(1)
	_sostener(recolector, repetida)
	recolector.pedir_tirar(true)
	assert_int(_depositos).is_equal(ReglasDeLaBasura.BOLSAS_DE_LA_JORNADA)
	assert_int(_avisos).is_equal(1)
	assert_float(_turno.tiempo_restante()).is_equal(Reglas.DURACION_DEL_TURNO)


func test_el_util_tirado_no_cuenta_como_bolsa() -> void:  # AC-CLN-036
	var recolector := _recolector()
	var mopa: ObjetoDelAlmacen = load("res://src/dominio/almacen/mopa.tres")
	_sostener(recolector, mopa)
	assert_int(recolector.pedir_tirar(true)).is_equal(ReglasDeLaBasura.Tiro.TIRADO)
	assert_int(_tirados.size()).is_equal(1)
	assert_int(_depositos).is_zero()
	assert_int(recolector.tarea().depositadas()).is_zero()
	assert_int(_avisos).is_zero()


func test_la_unidad_tirada_sale_del_inventario_antes_del_aviso() -> void:  # AC-STK-053
	var recolector := _recolector()
	var estante := recolector.repositor.estante()
	var producto := Catalogo.de(Producto.Id.ACTRONCITO)
	var unidad := estante.retirar(producto)
	_sostener(recolector, unidad)
	var reservas_al_avisar: Array[int] = []
	recolector.objeto_tirado.connect(
		func(_nodo: Node3D) -> void: reservas_al_avisar.append(estante.reservadas(producto))
	)
	assert_int(recolector.pedir_tirar(true)).is_equal(ReglasDeLaBasura.Tiro.TIRADO)
	assert_array(reservas_al_avisar).contains_exactly([0])
	assert_int(estante.unidades_en_deposito(producto)).is_equal(7)
	assert_int(estante.disponibles_para_retirar(producto)).is_equal(7)
	assert_int(_depositos).is_zero()


func test_sin_cableado_no_entrega_ni_publica() -> void:
	var recolector := _recolector()
	var bolsa := ObjetoDelAlmacen.new()
	_sostener(recolector, bolsa)
	for propiedad: StringName in [&"reloj", &"repositor", &"agarre"]:
		var original: Node = recolector.get(propiedad)
		recolector.set(propiedad, null)
		(
			assert_error(func() -> void: recolector.pedir_tirar(true))
			. is_push_error("Recolector sin cablear: revisar almacen.tscn y almacen.gd")
		)
		recolector.set(propiedad, original)
		assert_object(recolector.agarre.manos().sostenido()).is_same(bolsa)
	var tarea := recolector.tarea()
	recolector.arrancar(null)
	(
		assert_error(func() -> void: recolector.pedir_tirar(true))
		. is_push_error("Recolector sin cablear: revisar almacen.tscn y almacen.gd")
	)
	recolector.arrancar(tarea)
	assert_object(recolector.agarre.manos().sostenido()).is_same(bolsa)
	assert_array(_tirados).is_empty()
	assert_int(_depositos).is_zero()


func test_tirar_las_bolsas_en_la_primera_no_cumple_otra_obligatoria() -> void:
	var recolector := _recolector(Reglas.DURACION_DEL_TURNO, 1)
	for numero in range(1, ReglasDeLaBasura.BOLSAS_DE_LA_JORNADA + 1):
		var bolsa := ObjetoDelAlmacen.new()
		bolsa.id = ReglasDeLaBasura.id_de_la_bolsa(numero)
		_sostener(recolector, bolsa)
		assert_int(recolector.pedir_tirar(true)).is_equal(ReglasDeLaBasura.Tiro.TIRADO)
	assert_int(recolector.tarea().bolsas()).is_zero()
	assert_int(_depositos).is_zero()
	assert_int(_avisos).is_zero()
	assert_int(_turno.tareas_cumplidas()).is_zero()


class BolsaDoble:
	extends Node3D
	var datos := ObjetoDelAlmacen.new()


func test_sacar_entrega_el_mismo_cuerpo_sin_depositar_y_avisa_una_vez() -> void:  # AC-CLN-053
	var recolector := _recolector()
	for numero in range(1, 4):
		var cuerpo: BolsaDoble = auto_free(BolsaDoble.new())
		cuerpo.datos.id = ReglasDeLaBasura.id_de_la_bolsa(numero)
		recolector.bolsas.append(cuerpo)
	var sacadas: Array[TareaDeLaBasura.Tacho] = []
	recolector.bolsa_sacada.connect(
		func(tacho: TareaDeLaBasura.Tacho) -> void: sacadas.append(tacho)
	)
	var cuerpo := recolector.bolsas[0]
	assert_bool(recolector.sacar_bolsa(TareaDeLaBasura.Tacho.LOCAL)).is_true()
	assert_object(recolector.agarre.cuerpo_sostenido()).is_same(cuerpo)
	assert_array(sacadas).contains_exactly([TareaDeLaBasura.Tacho.LOCAL])
	assert_int(recolector.tarea().depositadas()).is_zero()
	assert_bool(recolector.sacar_bolsa(TareaDeLaBasura.Tacho.ESCRITORIO)).is_false()
	assert_bool(recolector.tarea().tiene_bolsa(TareaDeLaBasura.Tacho.ESCRITORIO)).is_true()
	recolector.agarre.entregar()
	assert_bool(recolector.sacar_bolsa(TareaDeLaBasura.Tacho.LOCAL)).is_false()
	assert_array(sacadas).has_size(1)
	assert_float(_turno.tiempo_restante()).is_equal(Reglas.DURACION_DEL_TURNO)
