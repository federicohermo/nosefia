## El aviso de que falta reponer: dura mientras el jugador está en una zona con faltante, y no
## tiene temporizador. La zona y el faltante los contesta `ZonasDeReposicion`; acá se ejerce lo que
## el aviso hace con esa respuesta, sin una escena.
extends GdUnitTestSuite

const CASILLEROS := 2
const EN_DEPOSITO := 8
const ZONA_CENTRAL := 4
const ZONA_VECINA := 5
const ZONA_DE_LA_PUNTA := 6


func _jornada_con_reposicion() -> int:
	return ReglasDeLaPartida.PRIMERA_JORNADA + 1


func _centro(zona: int) -> Vector3:
	var limites := ZonasDeReposicion.LIMITES[zona]
	return Vector3((limites.x + limites.z) / 2.0, 0.0, (limites.y + limites.w) / 2.0)


## Un estante de la jornada con las góndolas llenas, o con todas vacías.
func _estante(jornada: int, llenas: bool = true) -> Estante:
	var productos := Catalogo.de_la_jornada(jornada)
	var casilleros: Dictionary[Producto.Id, int] = {}
	for producto in productos:
		casilleros[producto.id] = CASILLEROS
	var inventario := Inventario.new(productos, casilleros)
	for producto in productos:
		if llenas:
			inventario.ingresar(producto, Inventario.Ubicacion.GONDOLA, CASILLEROS)
		inventario.ingresar(producto, Inventario.Ubicacion.DEPOSITO, EN_DEPOSITO)
	return Estante.new(inventario, productos)


func _producto_de(zonas: ZonasDeReposicion, zona: int, indice: int = 0) -> Producto:
	return Catalogo.de(zonas.productos_de(zona)[indice])


func _vaciar_un_casillero(estante: Estante, producto: Producto) -> void:
	assert_object(estante.agarrar(producto, estante.casilleros_ocupados(producto)[0])).is_not_null()


## Lo que hace la escena cada cuadro: preguntar si donde está el jugador falta reponer.
func _mirar(
	estado: Notificaciones, zonas: ZonasDeReposicion, estante: Estante, donde: Vector3
) -> void:
	estado.actualizar_faltante(zonas.hay_faltante_en(donde, estante))


func test_entrar_en_una_zona_con_faltante_lo_muestra_primero_y_no_vence() -> void:  # AC-NTF-033
	var jornada := _jornada_con_reposicion()
	var zonas := ZonasDeReposicion.new(jornada)
	var estante := _estante(jornada)
	_vaciar_un_casillero(estante, _producto_de(zonas, ZONA_CENTRAL))
	var estado := Notificaciones.new()
	estado.pista_anotada()
	_mirar(estado, zonas, estante, _centro(ZONA_CENTRAL))
	assert_array(estado.visibles()).is_equal(
		[Notificaciones.Tipo.FALTA_REPONER, Notificaciones.Tipo.PISTA]
	)
	estado.avanzar(Notificaciones.DURACION)
	estado.avanzar(600.0)
	assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.FALTA_REPONER])
	estado.avanzar(0.0)
	estado.avanzar(-1.0)
	assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.FALTA_REPONER])


func test_salir_de_la_zona_lo_retira_y_volver_lo_muestra_una_vez() -> void:  # AC-NTF-033
	var jornada := _jornada_con_reposicion()
	var zonas := ZonasDeReposicion.new(jornada)
	var estante := _estante(jornada)
	_vaciar_un_casillero(estante, _producto_de(zonas, ZONA_CENTRAL))
	var estado := Notificaciones.new()
	_mirar(estado, zonas, estante, _centro(ZONA_CENTRAL))
	_mirar(estado, zonas, estante, _centro(ZONA_DE_LA_PUNTA))
	assert_array(estado.visibles()).is_empty()
	_mirar(estado, zonas, estante, _centro(ZONA_CENTRAL))
	_mirar(estado, zonas, estante, _centro(ZONA_CENTRAL))
	assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.FALTA_REPONER])


func test_fuera_de_las_siete_zonas_no_se_ve_aunque_falte_todo() -> void:  # AC-NTF-033
	var jornada := _jornada_con_reposicion()
	var zonas := ZonasDeReposicion.new(jornada)
	var estante := _estante(jornada, false)
	var estado := Notificaciones.new()
	_mirar(estado, zonas, estante, _centro(1) + Vector3.FORWARD * 20.0)
	assert_array(estado.visibles()).is_empty()
	_mirar(estado, zonas, estante, _centro(ZONA_CENTRAL))
	assert_array(estado.visibles()).has_size(1)


func test_solo_importa_la_zona_donde_esta_el_jugador() -> void:  # AC-NTF-034
	var jornada := _jornada_con_reposicion()
	var zonas := ZonasDeReposicion.new(jornada)
	var estante := _estante(jornada)
	var de_la_central := _producto_de(zonas, ZONA_CENTRAL)
	var de_la_punta := _producto_de(zonas, ZONA_DE_LA_PUNTA)
	_vaciar_un_casillero(estante, de_la_central)
	_vaciar_un_casillero(estante, de_la_punta)
	var estado := Notificaciones.new()
	var donde := _centro(ZONA_CENTRAL)
	_mirar(estado, zonas, estante, donde)
	assert_int(estante.colocar(de_la_punta)).is_equal(Estante.Rechazo.NINGUNO)
	_mirar(estado, zonas, estante, donde)
	assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.FALTA_REPONER])
	assert_int(estante.colocar(de_la_central)).is_equal(Estante.Rechazo.NINGUNO)
	_mirar(estado, zonas, estante, donde)
	assert_array(estado.visibles()).is_empty()
	_vaciar_un_casillero(estante, de_la_central)
	_mirar(estado, zonas, estante, donde)
	assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.FALTA_REPONER])


func test_cruzar_entre_dos_zonas_con_faltante_lo_conserva_sin_renovarlo() -> void:  # AC-NTF-034
	var jornada := _jornada_con_reposicion()
	var zonas := ZonasDeReposicion.new(jornada)
	var estante := _estante(jornada)
	_vaciar_un_casillero(estante, _producto_de(zonas, ZONA_CENTRAL))
	_vaciar_un_casillero(estante, _producto_de(zonas, ZONA_VECINA))
	var estado := Notificaciones.new()
	_mirar(estado, zonas, estante, _centro(ZONA_CENTRAL))
	estado.pista_anotada()
	estado.avanzar(1.0)
	var antes := estado.visibles()
	_mirar(estado, zonas, estante, _centro(ZONA_VECINA))
	assert_array(estado.visibles()).is_equal(antes)
	assert_int(estado.visibles().count(Notificaciones.Tipo.FALTA_REPONER)).is_equal(1)
	assert_int(estado.visibles().find(Notificaciones.Tipo.FALTA_REPONER)).is_equal(
		antes.find(Notificaciones.Tipo.FALTA_REPONER)
	)


func test_la_primera_jornada_no_avisa_aunque_haya_casilleros_vacios() -> void:  # AC-NTF-035
	var jornada := ReglasDeLaPartida.PRIMERA_JORNADA
	var zonas := ZonasDeReposicion.new(jornada)
	var estante := _estante(jornada)
	for producto in Catalogo.de_la_jornada(jornada):
		_vaciar_un_casillero(estante, producto)
	var estado := Notificaciones.new()
	for zona in range(1, ZonasDeReposicion.CANTIDAD + 1):
		_mirar(estado, zonas, estante, _centro(zona))
		assert_array(estado.visibles()).is_empty()


func test_una_zona_sin_faltante_no_avisa_en_una_jornada_que_repone() -> void:  # AC-NTF-035
	var jornada := _jornada_con_reposicion()
	var zonas := ZonasDeReposicion.new(jornada)
	var estante := _estante(jornada)
	_vaciar_un_casillero(estante, _producto_de(zonas, ZONA_CENTRAL))
	var estado := Notificaciones.new()
	_mirar(estado, zonas, estante, _centro(ZONA_DE_LA_PUNTA))
	assert_array(estado.visibles()).is_empty()


func test_con_el_turno_cerrado_no_aparece_hasta_que_abre_el_siguiente() -> void:  # AC-NTF-035
	var jornada := _jornada_con_reposicion()
	var zonas := ZonasDeReposicion.new(jornada)
	var estante := _estante(jornada)
	_vaciar_un_casillero(estante, _producto_de(zonas, ZONA_CENTRAL))
	var estado := Notificaciones.new()
	var donde := _centro(ZONA_CENTRAL)
	_mirar(estado, zonas, estante, donde)
	estado.vaciar()
	assert_array(estado.visibles()).is_empty()
	_mirar(estado, zonas, estante, donde)
	assert_array(estado.visibles()).is_empty()
	estado.abrir_turno()
	assert_array(estado.visibles()).is_empty()
	_mirar(estado, zonas, estante, donde)
	assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.FALTA_REPONER])


func test_convive_sin_temporizador_y_sin_quitarle_el_tiempo_a_otros() -> void:  # AC-NTF-036
	var estado := Notificaciones.new()
	var comprador := Compradores.de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA)[0]
	estado.actualizar_faltante(true)
	estado.lectura_rechazada(GeneradorDeTickets.Resultado.LLENO)
	estado.se_fue(comprador)
	(
		assert_array(estado.visibles())
		. is_equal(
			[
				Notificaciones.Tipo.CLIENTE_CANSADO,
				Notificaciones.Tipo.LECTURA_FALLIDA,
				Notificaciones.Tipo.FALTA_REPONER,
			]
		)
	)
	estado.avanzar(Notificaciones.DURACION - 0.1)
	assert_array(estado.visibles()).has_size(3)
	estado.avanzar(0.1)
	assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.FALTA_REPONER])


func test_otro_aviso_de_un_tipo_ya_visible_no_duplica_a_falta_reponer() -> void:  # AC-NTF-036
	var estado := Notificaciones.new()
	estado.actualizar_faltante(true)
	estado.lectura_rechazada(GeneradorDeTickets.Resultado.LLENO)
	estado.lectura_rechazada(GeneradorDeTickets.Resultado.LLENO)
	estado.actualizar_faltante(true)
	assert_array(estado.visibles()).is_equal(
		[Notificaciones.Tipo.LECTURA_FALLIDA, Notificaciones.Tipo.FALTA_REPONER]
	)


func test_cerrar_el_turno_lo_retira_y_la_noche_siguiente_empieza_sin_el() -> void:  # AC-NTF-036
	var estado := Notificaciones.new()
	estado.actualizar_faltante(true)
	estado.pista_anotada()
	estado.vaciar()
	assert_array(estado.visibles()).is_empty()
	estado.abrir_turno()
	assert_array(estado.visibles()).is_empty()
	estado.actualizar_faltante(true)
	assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.FALTA_REPONER])
