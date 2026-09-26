## El reproductor en el local: los bucles, cada uno en su voz, y lo que suena desde un lugar.
##
## Va aparte de `reproductor_de_sonidos_test.gd` por el tope de métodos públicos por archivo.
## Como allá, ningún caso afirma sobre el estado de reproducción: se mira qué se pidió.
extends GdUnitTestSuite

var _rechazos: Array = []
var _pedidos: Array = []


func before_test() -> void:
	_rechazos = []
	_pedidos = []


func test_la_musica_y_el_ambiente_suenan_a_la_vez() -> void:  # AC-AMB-014
	var musica := _entrada(
		EntradaSonora.Evento.MUSICA_DE_LA_NOCHE, true, EntradaSonora.BUS_DE_MUSICA, true
	)
	var ambiente := _entrada(
		EntradaSonora.Evento.AMBIENTE_DEL_LOCAL, true, EntradaSonora.BUS_DE_AMBIENTE, true
	)
	var reproductor := _reproductor([musica, ambiente] as Array[EntradaSonora])
	assert_bool(reproductor.pedir(EntradaSonora.Evento.MUSICA_DE_LA_NOCHE)).is_true()
	assert_bool(reproductor.pedir(EntradaSonora.Evento.AMBIENTE_DEL_LOCAL)).is_true()
	var de_la_musica := reproductor.voz_en_bucle(EntradaSonora.Evento.MUSICA_DE_LA_NOCHE)
	var del_ambiente := reproductor.voz_en_bucle(EntradaSonora.Evento.AMBIENTE_DEL_LOCAL)
	assert_object(de_la_musica).is_not_same(del_ambiente)
	assert_object(de_la_musica.stream).is_same(musica.stream)
	assert_str(de_la_musica.bus).is_equal(EntradaSonora.BUS_DE_MUSICA)
	assert_object(del_ambiente.stream).is_same(ambiente.stream)
	assert_int(_voces_ocupadas(reproductor)).is_equal(0)


func test_la_musica_no_empieza_de_nuevo_y_se_corta_al_callarla() -> void:  # AC-AMB-015
	var musica := _entrada(
		EntradaSonora.Evento.MUSICA_DE_LA_NOCHE, true, EntradaSonora.BUS_DE_MUSICA, true
	)
	var reproductor := _reproductor([musica] as Array[EntradaSonora])
	reproductor.pedir(EntradaSonora.Evento.MUSICA_DE_LA_NOCHE)
	assert_bool(reproductor.pedir(EntradaSonora.Evento.MUSICA_DE_LA_NOCHE)).is_true()
	assert_int(_pedidos.size()).is_equal(1)
	reproductor.callar(EntradaSonora.Evento.MUSICA_DE_LA_NOCHE)
	var voz := reproductor.voz_en_bucle(EntradaSonora.Evento.MUSICA_DE_LA_NOCHE)
	assert_object(voz.stream).is_null()
	reproductor.pedir(EntradaSonora.Evento.MUSICA_DE_LA_NOCHE)
	assert_int(_pedidos.size()).is_equal(2)
	assert_object(voz.stream).is_same(musica.stream)


func test_una_fila_del_espacio_suena_donde_esta_el_objeto() -> void:  # AC-AMB-016
	var entrada := _de_objeto(EntradaSonora.Evento.OBJETO_AGARRADO, EntradaSonora.Sonoridad.LATA)
	entrada.posicional = true
	var reproductor := _reproductor([entrada] as Array[EntradaSonora])
	var objeto := _objeto(EntradaSonora.Sonoridad.LATA)
	add_child(objeto)
	objeto.global_position = Vector3(1, 0, 2)
	assert_bool(reproductor.recibir(EntradaSonora.Evento.OBJETO_AGARRADO, objeto)).is_true()
	assert_int(_voces_ocupadas(reproductor)).is_equal(0)
	var voz := reproductor.voces_en_el_espacio()[0]
	assert_object(voz.stream).is_same(entrada.stream)
	objeto.global_position = Vector3(9, 9, 9)
	assert_vector(voz.global_position).is_equal_approx(Vector3(1, 0, 2), Vector3.ONE * 0.001)


func test_una_fila_del_espacio_sin_objeto_suena_en_su_emisor() -> void:  # AC-AMB-016
	var entrada := _entrada(EntradaSonora.Evento.TIMBRE_DEL_COMPRADOR)
	entrada.posicional = true
	entrada.emisor = &"Ventanilla"
	var reproductor := _reproductor([entrada] as Array[EntradaSonora])
	reproductor.registrar_emisores(_emisores({&"Ventanilla": [Vector3(5, 1, 8)]}))
	assert_bool(reproductor.pedir(EntradaSonora.Evento.TIMBRE_DEL_COMPRADOR)).is_true()
	var voz := reproductor.voces_en_el_espacio()[0]
	assert_vector(voz.global_position).is_equal_approx(Vector3(5, 1, 8), Vector3.ONE * 0.001)


func test_una_fila_del_espacio_sin_lugar_se_rechaza() -> void:  # AC-AMB-016
	var entrada := _entrada(EntradaSonora.Evento.TIMBRE_DEL_COMPRADOR)
	entrada.posicional = true
	var reproductor := _reproductor([entrada] as Array[EntradaSonora])
	assert_bool(reproductor.pedir(EntradaSonora.Evento.TIMBRE_DEL_COMPRADOR)).is_false()
	assert_array(_rechazos).is_equal([ReproductorDeSonidos.Motivo.SIN_POSICION])
	for voz in reproductor.voces_en_el_espacio():
		assert_object(voz.stream).is_null()


func test_una_fila_plana_suena_en_una_voz_plana() -> void:  # AC-AMB-016
	var reproductor := _reproductor(
		[_entrada(EntradaSonora.Evento.TURNO_CERRADO)] as Array[EntradaSonora]
	)
	assert_bool(reproductor.pedir(EntradaSonora.Evento.TURNO_CERRADO)).is_true()
	assert_int(_voces_ocupadas(reproductor)).is_equal(1)
	for voz in reproductor.voces_en_el_espacio():
		assert_object(voz.stream).is_null()


func test_el_ambiente_suena_en_sus_emisores_mas_cercanos() -> void:  # AC-AMB-017
	var entrada := _entrada(
		EntradaSonora.Evento.AMBIENTE_DEL_LOCAL, true, EntradaSonora.BUS_DE_AMBIENTE, true
	)
	entrada.posicional = true
	entrada.emisor = &"Neon"
	var reproductor := _reproductor([entrada] as Array[EntradaSonora])
	var posiciones: Array = []
	for indice in range(EmisoresDelAmbiente.TOPE + 1):
		posiciones.append(Vector3(indice, 0, 0))
	reproductor.registrar_emisores(_emisores({&"Neon": posiciones}))
	assert_bool(reproductor.pedir(EntradaSonora.Evento.AMBIENTE_DEL_LOCAL)).is_true()
	reproductor.actualizar_emisores(Vector3.ZERO)
	var emisores := reproductor.emisores_en_bucle(EntradaSonora.Evento.AMBIENTE_DEL_LOCAL)
	assert_int(emisores.size()).is_equal(posiciones.size())
	for indice in range(emisores.size()):
		assert_object(emisores[indice].stream).is_same(entrada.stream)
		assert_str(emisores[indice].bus).is_equal(EntradaSonora.BUS_DE_AMBIENTE)
	var cercanos: Array[int] = []
	cercanos.assign(range(EmisoresDelAmbiente.TOPE))
	var evento := EntradaSonora.Evento.AMBIENTE_DEL_LOCAL
	assert_array(reproductor.emisores_que_suenan(evento)).is_equal(cercanos)
	reproductor.actualizar_emisores(Vector3(EmisoresDelAmbiente.TOPE, 0, 0))
	assert_array(reproductor.emisores_que_suenan(evento)).not_contains([0])
	assert_int(_voces_ocupadas(reproductor)).is_equal(0)


func test_el_ambiente_sin_emisores_no_suena_ni_falla() -> void:  # AC-AMB-017
	var entrada := _entrada(
		EntradaSonora.Evento.AMBIENTE_DEL_LOCAL, true, EntradaSonora.BUS_DE_AMBIENTE, true
	)
	entrada.posicional = true
	entrada.emisor = &"Neon"
	var reproductor := _reproductor([entrada] as Array[EntradaSonora])
	assert_bool(reproductor.pedir(EntradaSonora.Evento.AMBIENTE_DEL_LOCAL)).is_false()
	reproductor.actualizar_emisores(Vector3.ZERO)
	assert_array(reproductor.emisores_en_bucle(EntradaSonora.Evento.AMBIENTE_DEL_LOCAL)).is_empty()


## Un nodo con un hijo por emisor. Cada emisor tiene un hijo por posición, como en la escena.
func _emisores(posiciones_por_nombre: Dictionary) -> Node3D:
	var raiz: Node3D = auto_free(Node3D.new())
	add_child(raiz)
	for nombre: StringName in posiciones_por_nombre:
		var emisor := Node3D.new()
		emisor.name = nombre
		raiz.add_child(emisor)
		for posicion: Vector3 in posiciones_por_nombre[nombre]:
			var punto := Marker3D.new()
			emisor.add_child(punto)
			punto.global_position = posicion
	return raiz


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


func _reproductor(entradas: Array[EntradaSonora]) -> ReproductorDeSonidos:
	var reproductor: ReproductorDeSonidos = auto_free(ReproductorDeSonidos.new())
	add_child(reproductor)
	var tabla := TablaDeSonidos.new()
	tabla.entradas = entradas
	reproductor.arrancar(tabla)
	reproductor.sonido_rechazado.connect(
		func(_evento: EntradaSonora.Evento, motivo: ReproductorDeSonidos.Motivo) -> void:
			_rechazos.append(motivo)
	)
	reproductor.sonido_pedido.connect(
		func(evento: EntradaSonora.Evento) -> void: _pedidos.append(evento)
	)
	return reproductor


func _voces_ocupadas(reproductor: ReproductorDeSonidos) -> int:
	var ocupadas := 0
	for voz in reproductor.voces():
		if voz.stream != null:
			ocupadas += 1
	return ocupadas


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
