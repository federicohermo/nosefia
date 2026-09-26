## El nodo que pide los sonidos: qué `stream`, por qué bus y en qué voz.
##
## **Ningún caso de esta suite afirma sobre el estado de reproducción, y ésa es la decisión que
## hace existir al spec.** Está medido que en `--headless` —que es exactamente cómo corre el nodo
## `tests`— un `play()` deja el estado de reproducción sin cambiar doscientos frames después:
## el driver dummy no mezcla. El criterio obvio sería **rojo permanente** y el arreglo tentador
## sería apagar el test.
## Lo que se verifica es **qué se le pidió** al reproductor.
extends GdUnitTestSuite

## Los cuatro `.gd` de este spec que llevan espejo, más el quinto, para el caso de los espejos.
const ARCHIVOS_CON_ESPEJO = [
	"res://src/dominio/ambiente/entrada_sonora.gd",
	"res://src/dominio/ambiente/tabla_de_sonidos.gd",
	"res://src/dominio/ambiente/ronda_de_voces.gd",
	"res://src/sistemas/marco/reproductor_de_sonidos.gd",
	"res://src/sistemas/marco/enlace_de_audio.gd",
]

const BUS_INVENTADO := "Efectoss"

var _rechazos: Array = []
var _pedidos: Array = []


func before_test() -> void:
	_rechazos = []
	_pedidos = []


func _entrada(
	evento: EntradaSonora.Evento,
	con_sonido: bool = true,
	bus: String = EntradaSonora.BUS_DE_EFECTOS,
	en_bucle: bool = false
) -> EntradaSonora:
	var entrada := EntradaSonora.new()
	entrada.evento = evento
	entrada.bus = bus
	entrada.en_bucle = en_bucle
	if con_sonido:
		entrada.stream = AudioStreamGenerator.new()
	return entrada


## Un reproductor **entrado al árbol**, porque sus voces se crean en `_ready()`. Es lo único que
## esta suite necesita del árbol: ningún caso espera un frame ni mira si algo suena.
func _reproductor(entradas: Array[EntradaSonora]) -> ReproductorDeSonidos:
	var reproductor: ReproductorDeSonidos = auto_free(ReproductorDeSonidos.new())
	add_child(reproductor)
	var tabla := TablaDeSonidos.new()
	tabla.entradas = entradas
	reproductor.arrancar(tabla)
	reproductor.sonido_rechazado.connect(_anotar_rechazo)
	reproductor.sonido_pedido.connect(_anotar_pedido)
	return reproductor


## Cuántas voces quedaron con algo pedido.
func _voces_ocupadas(reproductor: ReproductorDeSonidos) -> int:
	var ocupadas := 0
	for voz in reproductor.voces():
		if voz.stream != null:
			ocupadas += 1
	return ocupadas


func test_pedir_un_evento_con_sonido_deja_una_voz_con_ese_stream_y_ese_bus() -> void:
	var entrada := _entrada(EntradaSonora.Evento.OBJETO_AGARRADO)
	var reproductor := _reproductor([entrada] as Array[EntradaSonora])
	assert_bool(reproductor.pedir(EntradaSonora.Evento.OBJETO_AGARRADO)).is_true()
	assert_int(_voces_ocupadas(reproductor)).is_equal(1)
	var voz := reproductor.voces()[0]
	assert_object(voz.stream).is_same(entrada.stream)
	assert_str(voz.bus).is_equal(EntradaSonora.BUS_DE_EFECTOS)
	assert_int(_pedidos.size()).is_equal(1)


func test_una_fila_sin_stream_no_ocupa_ninguna_voz() -> void:
	var reproductor := _reproductor(
		[_entrada(EntradaSonora.Evento.OBJETO_AGARRADO, false)] as Array[EntradaSonora]
	)
	assert_bool(reproductor.pedir(EntradaSonora.Evento.OBJETO_AGARRADO)).is_false()
	assert_int(_voces_ocupadas(reproductor)).is_equal(0)
	assert_int(_rechazos.size()).is_equal(1)
	assert_int(_rechazos[0]).is_equal(ReproductorDeSonidos.Motivo.SIN_SONIDO)


func test_un_evento_sin_fila_se_rechaza_y_se_declara() -> void:
	var reproductor := _reproductor([] as Array[EntradaSonora])
	assert_bool(reproductor.pedir(EntradaSonora.Evento.TURNO_CERRADO)).is_false()
	assert_int(_rechazos.size()).is_equal(1)
	assert_int(_rechazos[0]).is_equal(ReproductorDeSonidos.Motivo.SIN_FILA)


func test_un_bus_no_declarado_se_rechaza_en_vez_de_salir_por_master() -> void:
	# **Es el bug que no se ve**: el motor no dice nada y el sonido sale por el canal equivocado.
	# Se rechaza y se declara, que es lo único que lo vuelve visible.
	var reproductor := _reproductor(
		(
			[
				_entrada(EntradaSonora.Evento.OBJETO_AGARRADO, true, BUS_INVENTADO),
			]
			as Array[EntradaSonora]
		)
	)
	assert_bool(reproductor.pedir(EntradaSonora.Evento.OBJETO_AGARRADO)).is_false()
	assert_int(_voces_ocupadas(reproductor)).is_equal(0)
	assert_int(_rechazos[0]).is_equal(ReproductorDeSonidos.Motivo.BUS_NO_DECLARADO)


func test_cinco_pedidos_seguidos_ocupan_cinco_voces_distintas() -> void:
	# Sin la ronda, el segundo sonido cortaría al primero. Y no se puede preguntar cuál está
	# libre: en headless el estado de reproducción no cambia nunca.
	var reproductor := _reproductor(
		[_entrada(EntradaSonora.Evento.PASADA_DADA)] as Array[EntradaSonora]
	)
	for _pedido in range(5):
		reproductor.pedir(EntradaSonora.Evento.PASADA_DADA)
	assert_int(_voces_ocupadas(reproductor)).is_equal(5)


func test_una_fila_en_bucle_ocupa_la_voz_de_ambiente_y_no_la_ronda() -> void:
	# Adentro de la ronda, el ambiente se cortaría solo al quinto efecto.
	var entrada := _entrada(
		EntradaSonora.Evento.AMBIENTE_DEL_LOCAL, true, EntradaSonora.BUS_DE_AMBIENTE, true
	)
	var reproductor := _reproductor([entrada] as Array[EntradaSonora])
	assert_bool(reproductor.pedir(EntradaSonora.Evento.AMBIENTE_DEL_LOCAL)).is_true()
	var voz := reproductor.voz_en_bucle(EntradaSonora.Evento.AMBIENTE_DEL_LOCAL)
	assert_object(voz.stream).is_same(entrada.stream)
	assert_int(_voces_ocupadas(reproductor)).is_equal(0)


func test_silenciar_deja_todas_las_voces_sin_stream() -> void:
	# Se limpia el `stream` y no se llama a `stop()`: `stop()` deja el stream puesto, y lo que un
	# caso puede leer en headless es justamente el stream.
	var reproductor := _reproductor(
		(
			[
				_entrada(EntradaSonora.Evento.PASADA_DADA),
				_entrada(
					EntradaSonora.Evento.AMBIENTE_DEL_LOCAL,
					true,
					EntradaSonora.BUS_DE_AMBIENTE,
					true
				),
			]
			as Array[EntradaSonora]
		)
	)
	reproductor.pedir(EntradaSonora.Evento.PASADA_DADA)
	reproductor.pedir(EntradaSonora.Evento.AMBIENTE_DEL_LOCAL)
	reproductor.silenciar()
	assert_int(_voces_ocupadas(reproductor)).is_equal(0)
	var voz := reproductor.voz_en_bucle(EntradaSonora.Evento.AMBIENTE_DEL_LOCAL)
	assert_object(voz.stream).is_null()


func test_los_cinco_archivos_de_dominio_y_sistemas_tienen_su_espejo() -> void:
	# La mitad falsable del criterio de terminado: sin los espejos el nodo `tdd` no pasa.
	assert_int(ARCHIVOS_CON_ESPEJO.size()).is_equal(5)
	for ruta: String in ARCHIVOS_CON_ESPEJO:
		var espejo := ruta.replace("res://src/", "res://test/").replace(".gd", "_test.gd")
		(
			assert_bool(FileAccess.file_exists(espejo))
			. override_failure_message("falta el espejo `%s` de `%s`" % [espejo, ruta])
			. is_true()
		)


func test_una_sonoridad_sin_audio_no_suena_ni_cae_a_otro() -> void:  # AC-AMB-010
	var caja := _de_objeto(EntradaSonora.Evento.OBJETO_AGARRADO, EntradaSonora.Sonoridad.CAJA)
	caja.stream = null
	var lata := _de_objeto(EntradaSonora.Evento.OBJETO_AGARRADO, EntradaSonora.Sonoridad.LATA)
	var reproductor := _reproductor([caja, lata] as Array[EntradaSonora])
	var objeto := _objeto(EntradaSonora.Sonoridad.CAJA)
	assert_bool(reproductor.recibir(EntradaSonora.Evento.OBJETO_AGARRADO, objeto)).is_false()
	assert_int(_voces_ocupadas(reproductor)).is_equal(0)
	assert_array(_rechazos).is_equal([ReproductorDeSonidos.Motivo.SIN_SONIDO])


func test_los_golpes_bajan_el_volumen_y_filtran() -> void:  # AC-AMB-011
	var dejar := _de_objeto(EntradaSonora.Evento.OBJETO_SOLTADO, EntradaSonora.Sonoridad.LATA)
	var reproductor := _reproductor([dejar] as Array[EntradaSonora])
	var objeto := _objeto(EntradaSonora.Sonoridad.LATA)
	var rapido := ContadorDeGolpes.UMBRAL_DE_GOLPE * 4.0
	for _golpe in range(3):
		(
			assert_bool(reproductor.recibir(EntradaSonora.Evento.OBJETO_SOLTADO, objeto, rapido))
			. is_true()
		)
	assert_bool(reproductor.recibir(EntradaSonora.Evento.OBJETO_SOLTADO, objeto, rapido)).is_false()
	var voces := reproductor.voces()
	assert_float(voces[0].volume_db).is_equal(0.0)
	assert_str(voces[0].bus).is_equal(EntradaSonora.BUS_DE_EFECTOS)
	assert_float(voces[1].volume_db).is_equal(-6.0)
	assert_float(voces[2].volume_db).is_equal(-12.0)
	var segundo := _corte_del_bus(voces[1].bus)
	var tercero := _corte_del_bus(voces[2].bus)
	assert_float(segundo).is_greater(0.0)
	assert_float(tercero).is_greater(segundo)


func test_agarrar_suena_su_alzar_y_colocar_no_deja_golpes() -> void:  # AC-AMB-013
	var alzar := _de_objeto(EntradaSonora.Evento.OBJETO_AGARRADO, EntradaSonora.Sonoridad.CAJITA)
	var dejar := _de_objeto(EntradaSonora.Evento.PRODUCTO_COLOCADO, EntradaSonora.Sonoridad.CAJITA)
	var tocar := _de_objeto(EntradaSonora.Evento.OBJETO_SOLTADO, EntradaSonora.Sonoridad.CAJITA)
	var reproductor := _reproductor([alzar, dejar, tocar] as Array[EntradaSonora])
	var objeto := _objeto(EntradaSonora.Sonoridad.CAJITA)
	assert_bool(reproductor.recibir(EntradaSonora.Evento.OBJETO_AGARRADO, objeto)).is_true()
	assert_object(reproductor.voces()[0].stream).is_same(alzar.stream)
	assert_bool(reproductor.recibir(EntradaSonora.Evento.PRODUCTO_COLOCADO, objeto)).is_true()
	var colocada := reproductor.voces()[1]
	assert_object(colocada.stream).is_same(dejar.stream)
	assert_float(colocada.volume_db).is_equal(0.0)
	assert_str(colocada.bus).is_equal(EntradaSonora.BUS_DE_EFECTOS)
	var rapido := ContadorDeGolpes.UMBRAL_DE_GOLPE * 4.0
	assert_bool(reproductor.recibir(EntradaSonora.Evento.OBJETO_SOLTADO, objeto, rapido)).is_false()


func test_un_evento_sin_objeto_suena_su_fila_de_siempre() -> void:
	var reproductor := _reproductor(
		[_entrada(EntradaSonora.Evento.PASADA_DADA)] as Array[EntradaSonora]
	)
	assert_bool(reproductor.recibir(EntradaSonora.Evento.PASADA_DADA, null)).is_true()


## Una cosa del mundo que contesta sus datos, como la cáscara de un objeto.
class ObjetoDePrueba:
	extends Node3D

	var datos := ObjetoDelAlmacen.new()

	func interactuar() -> ObjetoDelAlmacen:
		return datos


func _objeto(sonoridad: EntradaSonora.Sonoridad) -> ObjetoDePrueba:
	var objeto: ObjetoDePrueba = auto_free(ObjetoDePrueba.new())
	objeto.datos.sonoridad = sonoridad
	return objeto


func _de_objeto(evento: EntradaSonora.Evento, sonoridad: EntradaSonora.Sonoridad) -> EntradaSonora:
	var entrada := _entrada(evento)
	entrada.sonoridad = sonoridad
	return entrada


## El corte del pasa-altos del bus por el que sale una voz, o 0 si no filtra.
func _corte_del_bus(bus: String) -> float:
	var indice := AudioServer.get_bus_index(bus)
	assert_int(indice).is_greater(0)
	assert_str(String(AudioServer.get_bus_send(indice))).is_equal(EntradaSonora.BUS_DE_EFECTOS)
	for efecto in range(AudioServer.get_bus_effect_count(indice)):
		var filtro := AudioServer.get_bus_effect(indice, efecto) as AudioEffectHighPassFilter
		if filtro != null:
			return filtro.cutoff_hz
	return 0.0


func _anotar_rechazo(_evento: EntradaSonora.Evento, motivo: ReproductorDeSonidos.Motivo) -> void:
	_rechazos.append(motivo)


func _anotar_pedido(evento: EntradaSonora.Evento) -> void:
	_pedidos.append(evento)
