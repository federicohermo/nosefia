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


func test_pedir_un_evento_con_sonido_deja_una_voz_con_ese_stream_y_ese_bus() -> void:  # 021-AC4
	var entrada := _entrada(EntradaSonora.Evento.OBJETO_AGARRADO)
	var reproductor := _reproductor([entrada] as Array[EntradaSonora])
	assert_bool(reproductor.pedir(EntradaSonora.Evento.OBJETO_AGARRADO)).is_true()
	assert_int(_voces_ocupadas(reproductor)).is_equal(1)
	var voz := reproductor.voces()[0]
	assert_object(voz.stream).is_same(entrada.stream)
	assert_str(voz.bus).is_equal(EntradaSonora.BUS_DE_EFECTOS)
	assert_int(_pedidos.size()).is_equal(1)


func test_una_fila_sin_stream_no_ocupa_ninguna_voz() -> void:  # 021-AC4
	var reproductor := _reproductor(
		[_entrada(EntradaSonora.Evento.OBJETO_AGARRADO, false)] as Array[EntradaSonora]
	)
	assert_bool(reproductor.pedir(EntradaSonora.Evento.OBJETO_AGARRADO)).is_false()
	assert_int(_voces_ocupadas(reproductor)).is_equal(0)
	assert_int(_rechazos.size()).is_equal(1)
	assert_int(_rechazos[0]).is_equal(ReproductorDeSonidos.Motivo.SIN_SONIDO)


func test_un_evento_sin_fila_se_rechaza_y_se_declara() -> void:  # 021-AC5
	var reproductor := _reproductor([] as Array[EntradaSonora])
	assert_bool(reproductor.pedir(EntradaSonora.Evento.TURNO_CERRADO)).is_false()
	assert_int(_rechazos.size()).is_equal(1)
	assert_int(_rechazos[0]).is_equal(ReproductorDeSonidos.Motivo.SIN_FILA)


func test_un_bus_no_declarado_se_rechaza_en_vez_de_salir_por_master() -> void:  # 021-AC5
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


func test_cinco_pedidos_seguidos_ocupan_cinco_voces_distintas() -> void:  # 021-AC6
	# Sin la ronda, el segundo sonido cortaría al primero. Y no se puede preguntar cuál está
	# libre: en headless el estado de reproducción no cambia nunca.
	var reproductor := _reproductor(
		[_entrada(EntradaSonora.Evento.PASADA_DADA)] as Array[EntradaSonora]
	)
	for _pedido in range(5):
		reproductor.pedir(EntradaSonora.Evento.PASADA_DADA)
	assert_int(_voces_ocupadas(reproductor)).is_equal(5)


func test_una_fila_en_bucle_ocupa_la_voz_de_ambiente_y_no_la_ronda() -> void:  # 021-AC6
	# Adentro de la ronda, el ambiente se cortaría solo al quinto efecto.
	var entrada := _entrada(
		EntradaSonora.Evento.AMBIENTE_DEL_LOCAL, true, EntradaSonora.BUS_DE_AMBIENTE, true
	)
	var reproductor := _reproductor([entrada] as Array[EntradaSonora])
	assert_bool(reproductor.pedir(EntradaSonora.Evento.AMBIENTE_DEL_LOCAL)).is_true()
	assert_object(reproductor.ambiente().stream).is_same(entrada.stream)
	assert_int(_voces_ocupadas(reproductor)).is_equal(0)


func test_silenciar_deja_todas_las_voces_sin_stream() -> void:  # 021-AC6
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
	assert_object(reproductor.ambiente().stream).is_null()


func test_los_cinco_archivos_de_dominio_y_sistemas_tienen_su_espejo() -> void:  # 021-AC11
	# La mitad falsable del criterio de terminado: sin los espejos el nodo `tdd` no pasa.
	assert_int(ARCHIVOS_CON_ESPEJO.size()).is_equal(5)
	for ruta: String in ARCHIVOS_CON_ESPEJO:
		var espejo := ruta.replace("res://src/", "res://test/").replace(".gd", "_test.gd")
		(
			assert_bool(FileAccess.file_exists(espejo))
			. override_failure_message("falta el espejo `%s` de `%s`" % [espejo, ruta])
			. is_true()
		)


func _anotar_rechazo(_evento: EntradaSonora.Evento, motivo: ReproductorDeSonidos.Motivo) -> void:
	_rechazos.append(motivo)


func _anotar_pedido(evento: EntradaSonora.Evento) -> void:
	_pedidos.append(evento)
