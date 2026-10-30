## Qué audio elige el reproductor según el estado de cada objeto y el contexto del gesto, con la
## tabla del disco. Se afirma qué se pidió y con qué stream: el driver de los tests no mezcla.
extends GdUnitTestSuite


## Un objeto del almacén que puede declarar cómo suena ahora, como el balde.
class ObjetoSonoro:
	extends Node3D
	var datos: ObjetoDelAlmacen
	var sonoridad_vigente: EntradaSonora.Sonoridad = EntradaSonora.Sonoridad.NINGUNA


var _pedidos: Array = []
var _rechazos: Array = []


func before_test() -> void:
	_pedidos = []
	_rechazos = []


func _reproductor() -> ReproductorDeSonidos:
	var reproductor: ReproductorDeSonidos = auto_free(ReproductorDeSonidos.new())
	add_child(reproductor)
	reproductor.arrancar(TablaDeSonidos.desde_disco())
	reproductor.sonido_pedido.connect(
		func(evento: EntradaSonora.Evento) -> void: _pedidos.append(evento)
	)
	reproductor.sonido_rechazado.connect(
		func(evento: EntradaSonora.Evento, _motivo: ReproductorDeSonidos.Motivo) -> void:
			_rechazos.append(evento)
	)
	return reproductor


func _objeto(ruta: String) -> ObjetoSonoro:
	var objeto: ObjetoSonoro = auto_free(ObjetoSonoro.new())
	objeto.datos = load(ruta)
	add_child(objeto)
	return objeto


## Los audios que quedaron pedidos, sin carpeta ni extensión.
static func _audios(reproductor: ReproductorDeSonidos) -> Array[String]:
	var nombres: Array[String] = []
	var voces: Array = reproductor.voces() + reproductor.voces_en_el_espacio()
	for voz in voces:
		if voz.stream != null:
			nombres.append(voz.stream.resource_path.get_file().get_basename())
	return nombres


func test_cada_balde_suena_segun_su_propio_estado_y_los_datos_no_cambian() -> void:
	var reproductor := _reproductor()
	var vacio := _objeto("res://src/dominio/almacen/balde.tres")
	var lleno := _objeto("res://src/dominio/almacen/balde.tres")
	vacio.sonoridad_vigente = EntradaSonora.sonoridad_del_balde(false)
	lleno.sonoridad_vigente = EntradaSonora.sonoridad_del_balde(true)
	assert_bool(reproductor.recibir(EntradaSonora.Evento.OBJETO_AGARRADO, vacio)).is_true()
	assert_array(_audios(reproductor)).contains_exactly(["SFX_OBJETO_Balde_AlzarVacio"])
	reproductor.silenciar()
	assert_bool(reproductor.recibir(EntradaSonora.Evento.OBJETO_AGARRADO, lleno)).is_true()
	assert_array(_audios(reproductor)).contains_exactly(["SFX_OBJETO_Balde_Alzar"])
	assert_object(vacio.datos).is_same(lleno.datos)
	assert_int(vacio.datos.sonoridad).is_equal(EntradaSonora.Sonoridad.BALDE)
	assert_array(_rechazos).is_empty()


func test_el_balde_cambia_de_audio_al_cambiar_su_estado_entre_gestos() -> void:
	var reproductor := _reproductor()
	var balde := _objeto("res://src/dominio/almacen/balde.tres")
	for con_agua: bool in [false, true, false]:
		balde.sonoridad_vigente = EntradaSonora.sonoridad_del_balde(con_agua)
		reproductor.silenciar()
		reproductor.recibir(EntradaSonora.Evento.OBJETO_SOLTADO, balde, 3.0)
		var esperado := "SFX_OBJETO_Balde_Dejar" if con_agua else "SFX_OBJETO_Balde_DejarVacio"
		assert_array(_audios(reproductor)).contains_exactly([esperado])


func test_un_objeto_sin_estado_propio_suena_como_dicen_sus_datos() -> void:
	var reproductor := _reproductor()
	var lata := _objeto("res://src/dominio/almacen/lata_de_tomate.tres")
	reproductor.recibir(EntradaSonora.Evento.OBJETO_AGARRADO, lata)
	assert_array(_audios(reproductor)).contains_exactly(["SFX_OBJETO_Lata_Alzar"])


func test_la_mopa_suena_dejar_al_tocar_y_limpiar_al_pasar_y_no_al_reves() -> void:
	var reproductor := _reproductor()
	var mopa := _objeto("res://src/dominio/almacen/mopa.tres")
	reproductor.recibir(EntradaSonora.Evento.OBJETO_SOLTADO, mopa, 3.0)
	assert_array(_audios(reproductor)).contains_exactly(["SFX_OBJETO_Mopa_Dejar"])
	reproductor.silenciar()
	reproductor.recibir(EntradaSonora.Evento.PASADA_DADA)
	assert_array(_audios(reproductor)).contains_exactly(["SFX_OBJETO_Mopa_Limpiar"])
	assert_array(_rechazos).is_empty()


func test_sacar_la_bolsa_del_tacho_suena_sacar_una_vez_y_alzar_la_suelta_suena_alzar() -> void:
	var reproductor := _reproductor()
	var bolsa := _objeto("res://src/dominio/almacen/bolsa_de_basura_1.tres")
	(
		assert_bool(reproductor.recibir(EntradaSonora.Evento.OBJETO_AGARRADO, bolsa, 0.0, true))
		. is_true()
	)
	assert_array(_pedidos).contains_exactly([EntradaSonora.Evento.BOLSA_SACADA])
	assert_array(_audios(reproductor)).contains_exactly(["SFX_OBJETO_Basura_SacarBolsa"])
	reproductor.silenciar()
	_pedidos.clear()
	assert_bool(reproductor.recibir(EntradaSonora.Evento.OBJETO_AGARRADO, bolsa)).is_true()
	assert_array(_pedidos).contains_exactly([EntradaSonora.Evento.OBJETO_AGARRADO])
	assert_array(_audios(reproductor)).contains_exactly(["SFX_OBJETO_Bolsa_Alzar"])


func test_sacar_la_bolsa_del_tacho_reinicia_los_golpes_de_la_bolsa() -> void:
	var reproductor := _reproductor()
	var bolsa := _objeto("res://src/dominio/almacen/bolsa_de_basura_1.tres")
	var rapido := ContadorDeGolpes.UMBRAL_DE_GOLPE + 1.0
	for _golpe in ContadorDeGolpes.VOLUMEN_POR_GOLPE.size():
		reproductor.recibir(EntradaSonora.Evento.OBJETO_SOLTADO, bolsa, rapido)
	_pedidos.clear()
	reproductor.recibir(EntradaSonora.Evento.OBJETO_SOLTADO, bolsa, rapido)
	assert_array(_pedidos).is_empty()
	reproductor.recibir(EntradaSonora.Evento.OBJETO_AGARRADO, bolsa, 0.0, true)
	_pedidos.clear()
	reproductor.recibir(EntradaSonora.Evento.OBJETO_SOLTADO, bolsa, rapido)
	assert_array(_pedidos).contains_exactly([EntradaSonora.Evento.OBJETO_SOLTADO])


func test_desechar_cualquier_objeto_pide_un_solo_contenedor_plano() -> void:
	var reproductor := _reproductor()
	for ruta: String in [
		"res://src/dominio/almacen/bolsa_de_basura_1.tres",
		"res://src/dominio/almacen/lata_de_tomate.tres",
		"res://src/dominio/almacen/mopa.tres",
		"res://src/dominio/almacen/jabon_azul.tres",
	]:
		reproductor.silenciar()
		_pedidos.clear()
		var objeto := _objeto(ruta)
		assert_bool(reproductor.recibir(EntradaSonora.Evento.OBJETO_DESECHADO, objeto)).is_true()
		assert_array(_pedidos).contains_exactly([EntradaSonora.Evento.OBJETO_DESECHADO])
		assert_array(_audios(reproductor)).contains_exactly(["SFX_OBJETO_Basura_Contenedor"])
	assert_array(_rechazos).is_empty()


func test_mensajes_consecutivos_suenan_siempre_el_mismo_audio() -> void:
	var reproductor := _reproductor()
	for _vez in 6:
		reproductor.silenciar()
		reproductor.pedir(EntradaSonora.Evento.MENSAJE_DEL_CELULAR)
		assert_array(_audios(reproductor)).contains_exactly(
			["SFX_INTERFAZ_Celular_Mensaje_Recibido"]
		)
