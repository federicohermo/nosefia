## Lo que suena al sacar una bolsa del tacho y al desechar algo en el contenedor, con el
## recolector, el agarre, el enlace y el reproductor reales. Se afirma qué se pidió: el driver de
## los tests no mezcla.
extends GdUnitTestSuite


## Un cuerpo que dice qué es, como una bolsa del almacén.
class CuerpoConDatos:
	extends Node3D
	var datos := ObjetoDelAlmacen.new()


var _pedidos: Array = []
var _rechazos: Array = []
var _reproductor: ReproductorDeSonidos
var _recolector: RecolectorDeBasura


func before_test() -> void:
	_pedidos = []
	_rechazos = []
	var jornada := 5
	var obligatorias := Apertura.obligatorias(jornada)
	var turno := Turno.new(Reglas.DURACION_DEL_TURNO, obligatorias)
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	reloj.arrancar(turno, obligatorias)
	var agarre: Agarre = auto_free(Agarre.new())
	var mano: Node3D = auto_free(Node3D.new())
	add_child(mano)
	agarre.punto_de_carga = mano
	var repositor: Repositor = auto_free(Repositor.new())
	repositor.agarre = agarre
	repositor.reloj = reloj
	var producto := Catalogo.de(Producto.Id.ACTRONCITO)
	var inventario := Inventario.new([producto], {producto.id: 2})
	inventario.ingresar(producto, Inventario.Ubicacion.DEPOSITO, 8)
	repositor.arrancar(Estante.new(inventario, [producto]))
	_recolector = auto_free(RecolectorDeBasura.new())
	_recolector.reloj = reloj
	_recolector.agarre = agarre
	_recolector.repositor = repositor
	_recolector.arrancar(TareaDeLaBasura.de_la_jornada(jornada))
	for numero in range(1, 4):
		var bolsa: CuerpoConDatos = auto_free(CuerpoConDatos.new())
		bolsa.datos.id = ReglasDeLaBasura.id_de_la_bolsa(numero)
		bolsa.datos.sonoridad = EntradaSonora.Sonoridad.BOLSA
		add_child(bolsa)
		_recolector.bolsas.append(bolsa)
	_reproductor = auto_free(ReproductorDeSonidos.new())
	add_child(_reproductor)
	var tabla := TablaDeSonidos.desde_disco()
	_reproductor.arrancar(tabla)
	_reproductor.sonido_pedido.connect(
		func(evento: EntradaSonora.Evento) -> void: _pedidos.append(evento)
	)
	_reproductor.sonido_rechazado.connect(
		func(evento: EntradaSonora.Evento, _motivo: ReproductorDeSonidos.Motivo) -> void:
			_rechazos.append(evento)
	)
	var enlace: EnlaceDeAudio = auto_free(EnlaceDeAudio.new())
	enlace.reproductor = _reproductor
	enlace.arrancar(tabla)
	enlace.enlazar_todo([_recolector, agarre])


func _audios() -> Array[String]:
	var nombres: Array[String] = []
	for voz in _reproductor.voces():
		if voz.stream != null:
			nombres.append(voz.stream.resource_path.get_file().get_basename())
	for voz in _reproductor.voces_en_el_espacio():
		if voz.stream != null:
			nombres.append(voz.stream.resource_path.get_file().get_basename())
	return nombres


func _sostener(datos: ObjetoDelAlmacen) -> void:
	var cuerpo: CuerpoConDatos = auto_free(CuerpoConDatos.new())
	cuerpo.datos = datos
	add_child(cuerpo)
	assert_bool(_recolector.agarre.pedir_agarrar(datos, cuerpo)).is_true()
	_reproductor.silenciar()
	_pedidos.clear()


func test_sacar_la_bolsa_del_tacho_pide_sacar_una_vez_y_no_alzar() -> void:
	assert_bool(_recolector.sacar_bolsa(TareaDeLaBasura.Tacho.LOCAL)).is_true()
	assert_array(_pedidos).contains_exactly([EntradaSonora.Evento.BOLSA_SACADA])
	assert_array(_audios()).contains_exactly(["SFX_OBJETO_Basura_SacarBolsa"])
	assert_array(_rechazos).is_empty()


func test_sacar_con_las_manos_ocupadas_o_el_tacho_vacio_no_suena() -> void:
	assert_bool(_recolector.sacar_bolsa(TareaDeLaBasura.Tacho.LOCAL)).is_true()
	_pedidos.clear()
	assert_bool(_recolector.sacar_bolsa(TareaDeLaBasura.Tacho.ESCRITORIO)).is_false()
	_recolector.agarre.entregar()
	assert_bool(_recolector.sacar_bolsa(TareaDeLaBasura.Tacho.LOCAL)).is_false()
	assert_array(_pedidos).is_empty()


func test_agarrar_una_bolsa_suelta_conserva_su_alzar() -> void:
	var bolsa: CuerpoConDatos = _recolector.bolsas[0]
	assert_bool(_recolector.agarre.pedir_agarrar(bolsa.datos, bolsa)).is_true()
	assert_array(_pedidos).contains_exactly([EntradaSonora.Evento.OBJETO_AGARRADO])
	assert_array(_audios()).contains_exactly(["SFX_OBJETO_Bolsa_Alzar"])


func test_desechar_una_bolsa_pide_un_solo_contenedor() -> void:
	assert_bool(_recolector.sacar_bolsa(TareaDeLaBasura.Tacho.LOCAL)).is_true()
	_reproductor.silenciar()
	_pedidos.clear()
	var depositos := []
	_recolector.bolsa_depositada.connect(func(_cuantas: int) -> void: depositos.append(1))
	assert_int(_recolector.pedir_tirar(true)).is_equal(ReglasDeLaBasura.Tiro.TIRADO)
	assert_array(depositos).has_size(1)
	assert_array(_pedidos).contains_exactly([EntradaSonora.Evento.OBJETO_DESECHADO])
	assert_array(_audios()).contains_exactly(["SFX_OBJETO_Basura_Contenedor"])


func test_desechar_un_producto_o_cualquier_objeto_aceptado_pide_un_solo_contenedor() -> void:
	var desconocido := ObjetoDelAlmacen.new()
	for datos: ObjetoDelAlmacen in [
		load("res://src/dominio/almacen/lata_de_tomate.tres"),
		load("res://src/dominio/almacen/cuaderno_del_deposito.tres"),
		desconocido,
	]:
		_sostener(datos)
		assert_int(_recolector.pedir_tirar(true)).is_equal(ReglasDeLaBasura.Tiro.TIRADO)
		assert_array(_pedidos).contains_exactly([EntradaSonora.Evento.OBJETO_DESECHADO])
		assert_array(_audios()).contains_exactly(["SFX_OBJETO_Basura_Contenedor"])


func test_un_descarte_rechazado_no_suena() -> void:
	for ruta: String in [
		"res://src/dominio/almacen/balde.tres",
		"res://src/dominio/almacen/mopa.tres",
		"res://src/dominio/almacen/jabon_azul.tres",
	]:
		_sostener(load(ruta))
		assert_int(_recolector.pedir_tirar(true)).is_equal(ReglasDeLaBasura.Tiro.NO_ENTRA)
		assert_array(_pedidos).is_empty()
		_recolector.agarre.entregar()
	_sostener(ObjetoDelAlmacen.new())
	assert_int(_recolector.pedir_tirar(false)).is_equal(ReglasDeLaBasura.Tiro.TAPA_NO_ABIERTA)
	assert_array(_pedidos).is_empty()
